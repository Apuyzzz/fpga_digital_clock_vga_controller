/**
 * @title Testbench — integración del sistema de reloj
 * @file tb_integration.v
 * @brief Verifica la cadena completa: temporización, FSM de ajuste y conversión de display.
 * @details
 *   Instancia bcd_counter ×3, fsm_adjust_mode, binary_bcd_decoder ×3,
 *   hour_converter y mux2 ×2 conectados como en top_vga. El tick_1hz se
 *   controla directamente desde el TB para acelerar la simulación.
 *
 *   TEST 1 - Reset                 : contadores en 0, FSM en RUN
 *   TEST 2 - Cadena sec→min        : 60 ticks → minutes=1, seconds=0
 *   TEST 3 - Cadena min→hour       : rollover minutos propagado a horas
 *   TEST 4 - Ajuste de horas       : FSM ADJ_HOUR, inc/dec, reloj pausado
 *   TEST 5 - sec_rst en transición : activación en ADJ_HOUR→ADJ_MIN
 *   TEST 6 - Ajuste de minutos     : FSM ADJ_MIN, inc/dec, retorno a RUN
 *   TEST 7 - Conversión BCD        : binary_bcd_decoder ×3 para hora actual
 *   TEST 8 - Conversión 12h/24h    : hour_converter + mux2, modo 12h y 24h
 *   TEST 9 - Rollover 23:59:58→0   : cadena completa día a día
 *
 * @author JustinAlfaro
 * @date 2026-05-08
 */

`timescale 1ns / 1ps

module tb_integration;

    parameter CLK_PERIOD = 10;

    // -------------------------------------------------------------------------
    // Señales de control
    // -------------------------------------------------------------------------
    reg clk, rst;
    reg tick_1hz;      // controlado directamente; equivale a salida de div_freq 1 Hz
    reg mode_12h;      // equivale a sw_sync[0]

    // Botones inyectados ya debounced (sin pasar por sync+debounce)
    reg btn_mode, btn_up, btn_down, btn_ajuste;

    // -------------------------------------------------------------------------
    // Salidas FSM
    // -------------------------------------------------------------------------
    wire       adj_hour, adj_min, sec_en;
    wire       hour_inc, hour_dec, min_inc, min_dec, sec_rst;
    wire [1:0] mode_leds;

    // -------------------------------------------------------------------------
    // Contadores
    // -------------------------------------------------------------------------
    wire [5:0] seconds, minutes, hours;
    wire       sec_carry, min_carry;
    wire       hour_carry_nc;

    // -------------------------------------------------------------------------
    // BCD y 12h
    // -------------------------------------------------------------------------
    wire [3:0] sec_tens,  sec_ones;
    wire [3:0] min_tens,  min_ones;
    wire [3:0] hour_tens, hour_ones;
    wire [3:0] h12_tens,  h12_ones;
    wire       is_pm;
    wire [3:0] disp_hour_tens, disp_hour_ones;

    // =========================================================================
    // DUTs — misma topología que top_vga
    // =========================================================================

    fsm_adjust_mode u_fsm (
        .clk       (clk),
        .rst       (rst),
        .btn_mode  (btn_mode),
        .btn_up    (btn_up),
        .btn_down  (btn_down),
        .btn_ajuste(btn_ajuste),
        .adj_hour  (adj_hour),
        .adj_min   (adj_min),
        .sec_en    (sec_en),
        .hour_inc  (hour_inc),
        .hour_dec  (hour_dec),
        .min_inc   (min_inc),
        .min_dec   (min_dec),
        .sec_rst   (sec_rst),
        .mode_leds (mode_leds)
    );

    wire sec_clk_en = tick_1hz & sec_en;

    bcd_counter #(.MAX_VAL(59)) u_sec (
        .clk      (clk),
        .rst      (rst | sec_rst),
        .clk_en   (sec_clk_en),
        .inc      (1'b0),
        .dec      (1'b0),
        .count    (seconds),
        .carry_out(sec_carry)
    );

    bcd_counter #(.MAX_VAL(59)) u_min (
        .clk      (clk),
        .rst      (rst),
        .clk_en   (sec_carry),
        .inc      (min_inc),
        .dec      (min_dec),
        .count    (minutes),
        .carry_out(min_carry)
    );

    bcd_counter #(.MAX_VAL(23)) u_hour (
        .clk      (clk),
        .rst      (rst),
        .clk_en   (min_carry),
        .inc      (hour_inc),
        .dec      (hour_dec),
        .count    (hours),
        .carry_out(hour_carry_nc)
    );

    binary_bcd_decoder #(.N(6)) u_bcd_sec (
        .bin     (seconds),
        .bcd_tens(sec_tens),
        .bcd_ones(sec_ones)
    );

    binary_bcd_decoder #(.N(6)) u_bcd_min (
        .bin     (minutes),
        .bcd_tens(min_tens),
        .bcd_ones(min_ones)
    );

    binary_bcd_decoder #(.N(5)) u_bcd_hour (
        .bin     (hours[4:0]),
        .bcd_tens(hour_tens),
        .bcd_ones(hour_ones)
    );

    hour_converter u_hconv (
        .hours_24(hours),
        .h12_tens(h12_tens),
        .h12_ones(h12_ones),
        .is_pm   (is_pm)
    );

    mux2 #(.WIDTH(4)) u_mux_htens (
        .d0(hour_tens), .d1(h12_tens), .sel(mode_12h), .y(disp_hour_tens));

    mux2 #(.WIDTH(4)) u_mux_hones (
        .d0(hour_ones), .d1(h12_ones), .sel(mode_12h), .y(disp_hour_ones));

    // =========================================================================
    // Reloj y contadores de error
    // =========================================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    integer errors_total = 0;
    integer errors_test  = 0;

    // -------------------------------------------------------------------------
    // Tick de 1 segundo simulado.
    // Dos ciclos de settle permiten que el carry sec->min y min->hour
    // se propaguen completamente antes de que el TB verifique.
    // -------------------------------------------------------------------------
    task tick_second;
        begin
            @(posedge clk); #1; tick_1hz = 1'b1;
            @(posedge clk); #1; tick_1hz = 1'b0;
            @(posedge clk); #1;   // settle: carry sec->min
            @(posedge clk); #1;   // settle: carry min->hour
        end
    endtask

    // -------------------------------------------------------------------------
    // Pulsos de botón.
    // Los outputs de la FSM son registrados: se estabilizan 1 ciclo después
    // de que el estado transiciona. pulse_mode incluye ese ciclo de settle.
    // -------------------------------------------------------------------------
    task pulse_mode;
        begin
            @(posedge clk); #1; btn_mode = 1'b1;
            @(posedge clk); #1; btn_mode = 1'b0;
            @(posedge clk); #1;   // settle: nuevos outputs activos
        end
    endtask

    task pulse_up;
        begin
            @(posedge clk); #1; btn_up = 1'b1;
            @(posedge clk); #1; btn_up = 1'b0;
        end
    endtask

    task pulse_down;
        begin
            @(posedge clk); #1; btn_down = 1'b1;
            @(posedge clk); #1; btn_down = 1'b0;
        end
    endtask

    task pulse_ajuste;
        begin
            @(posedge clk); #1; btn_ajuste = 1'b1;
            @(posedge clk); #1; btn_ajuste = 1'b0;
            @(posedge clk); #1;
        end
    endtask

    // -------------------------------------------------------------------------
    // Verificación de tiempo
    // -------------------------------------------------------------------------
    task check_time;
        input [5:0]  exp_sec;
        input [5:0]  exp_min;
        input [5:0]  exp_hour;
        input integer step;
        begin
            if (seconds !== exp_sec) begin
                $display("  [FAIL] T%0d: seconds=%0d (esp=%0d)", step, seconds, exp_sec);
                errors_test  = errors_test  + 1;
                errors_total = errors_total + 1;
            end
            if (minutes !== exp_min) begin
                $display("  [FAIL] T%0d: minutes=%0d (esp=%0d)", step, minutes, exp_min);
                errors_test  = errors_test  + 1;
                errors_total = errors_total + 1;
            end
            if (hours !== exp_hour) begin
                $display("  [FAIL] T%0d: hours=%0d (esp=%0d)", step, hours, exp_hour);
                errors_test  = errors_test  + 1;
                errors_total = errors_total + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Verificación de salida BCD
    // -------------------------------------------------------------------------
    task check_bcd;
        input [3:0]  exp_st, exp_so;
        input [3:0]  exp_mt, exp_mo;
        input [3:0]  exp_ht, exp_ho;
        input integer step;
        begin
            if (sec_tens !== exp_st || sec_ones !== exp_so) begin
                $display("  [FAIL] T%0d: sec BCD=%0d%0d (esp=%0d%0d)",
                         step, sec_tens, sec_ones, exp_st, exp_so);
                errors_test  = errors_test  + 1;
                errors_total = errors_total + 1;
            end
            if (min_tens !== exp_mt || min_ones !== exp_mo) begin
                $display("  [FAIL] T%0d: min BCD=%0d%0d (esp=%0d%0d)",
                         step, min_tens, min_ones, exp_mt, exp_mo);
                errors_test  = errors_test  + 1;
                errors_total = errors_total + 1;
            end
            if (hour_tens !== exp_ht || hour_ones !== exp_ho) begin
                $display("  [FAIL] T%0d: hour BCD=%0d%0d (esp=%0d%0d)",
                         step, hour_tens, hour_ones, exp_ht, exp_ho);
                errors_test  = errors_test  + 1;
                errors_total = errors_total + 1;
            end
        end
    endtask

    // =========================================================================
    // ESTÍMULOS
    // =========================================================================
    integer i;

    initial begin
        rst      = 1'b1;
        tick_1hz = 1'b0;
        mode_12h = 1'b0;
        btn_mode = 1'b0; btn_up = 1'b0; btn_down = 1'b0; btn_ajuste = 1'b0;

        $display("============================================================");
        $display("  TESTBENCH: integracion del sistema de reloj");
        $display("============================================================");

        repeat(4) @(posedge clk); #1;
        rst = 1'b0;
        @(posedge clk); #1;   // FSM output settle: sec_en=1, adj_*=0

        // ======================================================================
        // TEST 1: Reset — contadores en 0, FSM en RUN
        // ======================================================================
        errors_test = 0;
        $display("\n[TEST 1] Reset — estado inicial");
        check_time(6'd0, 6'd0, 6'd0, 1);
        if (sec_en !== 1'b1 || adj_hour !== 1'b0 || adj_min !== 1'b0) begin
            $display("  [FAIL] FSM: sec_en=%b adj_hour=%b adj_min=%b (esp: 1,0,0)",
                     sec_en, adj_hour, adj_min);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end
        $display("  sec=%0d min=%0d hour=%0d | sec_en=%b adj_hour=%b adj_min=%b",
                 seconds, minutes, hours, sec_en, adj_hour, adj_min);
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ======================================================================
        // TEST 2: Cadena sec→min — 60 ticks = 1 minuto
        // Estado inicial: sec=0, min=0, hour=0
        // ======================================================================
        errors_test = 0;
        $display("\n[TEST 2] Cadena sec->min: 60 ticks -> minutes=1, seconds=0");
        for (i = 0; i < 60; i = i + 1) tick_second;
        check_time(6'd0, 6'd1, 6'd0, 2);
        $display("  sec=%0d min=%0d hour=%0d", seconds, minutes, hours);
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ======================================================================
        // TEST 3: Cadena min→hour — avanzar 58 min más, luego 60 ticks
        // Estado inicial: sec=0, min=1, hour=0
        // ======================================================================
        errors_test = 0;
        $display("\n[TEST 3] Cadena min->hour: carry de minutos a horas");
        for (i = 0; i < 58 * 60; i = i + 1) tick_second;   // min=59, sec=0
        check_time(6'd0, 6'd59, 6'd0, 3);
        $display("  En min=59: sec=%0d min=%0d hour=%0d", seconds, minutes, hours);
        for (i = 0; i < 60; i = i + 1) tick_second;          // carry -> hour=1
        check_time(6'd0, 6'd0, 6'd1, 3);
        $display("  Tras carry: sec=%0d min=%0d hour=%0d", seconds, minutes, hours);
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ======================================================================
        // TEST 4: Ajuste de horas — FSM ADJ_HOUR, inc/dec, reloj pausado
        // Estado: sec=0, min=0, hour=1
        // ======================================================================
        errors_test = 0;
        $display("\n[TEST 4] Ajuste de horas (FSM ADJ_HOUR)");
        pulse_mode;   // RUN -> ADJ_HOUR; sec_rst=1 -> sec=0
        if (adj_hour !== 1'b1 || sec_en !== 1'b0) begin
            $display("  [FAIL] ADJ_HOUR: adj_hour=%b sec_en=%b (esp: 1,0)",
                     adj_hour, sec_en);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else
            $display("  ADJ_HOUR activo: adj_hour=%b sec_en=%b -> OK", adj_hour, sec_en);

        tick_second; tick_second;   // sec_en=0: reloj debe quedar pausado
        if (seconds !== 6'd0) begin
            $display("  [FAIL] reloj avanzo en ADJ_HOUR: sec=%0d (esp=0)", seconds);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else
            $display("  Reloj pausado en ADJ_HOUR: sec=%0d -> OK", seconds);

        repeat(5) pulse_up;         // hour: 1->6 (cada pulse_up incrementa 1)
        @(posedge clk); #1;
        if (hours !== 6'd6) begin
            $display("  [FAIL] hour_inc x5: hours=%0d (esp=6)", hours);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else
            $display("  hour_inc x5: hours=%0d -> PASS", hours);

        repeat(2) pulse_down;       // hour: 6->4
        @(posedge clk); #1;
        if (hours !== 6'd4) begin
            $display("  [FAIL] hour_dec x2: hours=%0d (esp=4)", hours);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else
            $display("  hour_dec x2: hours=%0d -> PASS", hours);

        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ======================================================================
        // TEST 5: sec_rst — activación en transición ADJ_HOUR→ADJ_MIN
        // ======================================================================
        errors_test = 0;
        $display("\n[TEST 5] sec_rst en transicion ADJ_HOUR->ADJ_MIN");
        @(posedge clk); #1; btn_mode = 1'b1;
        @(posedge clk); #1;   // estado->ADJ_MIN; output(ADJ_HOUR,btn_mode=1): sec_rst=1
        if (sec_rst !== 1'b1) begin
            $display("  [FAIL] sec_rst=%b en transicion (esp=1)", sec_rst);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else
            $display("  sec_rst=1 en transicion -> PASS");
        btn_mode = 1'b0;
        @(posedge clk); #1;   // output(ADJ_MIN): adj_min=1, sec_rst=0; u_sec: sec=0
        if (adj_min !== 1'b1 || sec_rst !== 1'b0) begin
            $display("  [FAIL] ADJ_MIN: adj_min=%b sec_rst=%b (esp: 1,0)", adj_min, sec_rst);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else
            $display("  ADJ_MIN activo, sec_rst=%b -> OK", sec_rst);
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ======================================================================
        // TEST 6: Ajuste de minutos — FSM ADJ_MIN, inc/dec, retorno a RUN
        // Estado: hour=4, min=0, sec=0
        // ======================================================================
        errors_test = 0;
        $display("\n[TEST 6] Ajuste de minutos (FSM ADJ_MIN)");

        repeat(10) pulse_up;        // min: 0->10
        @(posedge clk); #1;
        if (minutes !== 6'd10) begin
            $display("  [FAIL] min_inc x10: minutes=%0d (esp=10)", minutes);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else
            $display("  min_inc x10: minutes=%0d -> PASS", minutes);

        repeat(3) pulse_down;       // min: 10->7
        @(posedge clk); #1;
        if (minutes !== 6'd7) begin
            $display("  [FAIL] min_dec x3: minutes=%0d (esp=7)", minutes);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else
            $display("  min_dec x3: minutes=%0d -> PASS", minutes);

        pulse_mode;   // ADJ_MIN -> RUN
        if (sec_en !== 1'b1 || adj_min !== 1'b0) begin
            $display("  [FAIL] RUN: sec_en=%b adj_min=%b (esp: 1,0)", sec_en, adj_min);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else
            $display("  Volvio a RUN: sec_en=%b adj_min=%b -> OK", sec_en, adj_min);
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ======================================================================
        // TEST 7: Conversión BCD — decodificadores para hora actual
        // Estado: hour=4, min=7, sec=0
        // ======================================================================
        errors_test = 0;
        $display("\n[TEST 7] Conversion BCD (hour=4, min=7, sec=0)");
        #1;
        check_bcd(4'd0, 4'd0,    // sec  -> 00
                  4'd0, 4'd7,    // min  -> 07
                  4'd0, 4'd4,    // hour -> 04
                  7);
        $display("  sec=%0d%0d min=%0d%0d hour=%0d%0d",
                 sec_tens, sec_ones, min_tens, min_ones, hour_tens, hour_ones);
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ======================================================================
        // TEST 8: Conversión 12h/24h — mux2 y hour_converter
        // Sub-caso A: hour=4 en modo 24h y 12h
        // Sub-caso B: ajustar hour=13, verificar PM
        // ======================================================================
        errors_test = 0;
        $display("\n[TEST 8] Conversion 12h/24h (hour=4 y hour=13)");

        mode_12h = 1'b0; #5;
        if (disp_hour_tens !== 4'd0 || disp_hour_ones !== 4'd4) begin
            $display("  [FAIL] 24h hour=4: disp=%0d%0d (esp=04)",
                     disp_hour_tens, disp_hour_ones);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else
            $display("  24h hour=4: disp=%0d%0d -> PASS", disp_hour_tens, disp_hour_ones);

        mode_12h = 1'b1; #5;
        if (disp_hour_tens !== 4'd0 || disp_hour_ones !== 4'd4 || is_pm !== 1'b0) begin
            $display("  [FAIL] 12h hour=4: disp=%0d%0d pm=%b (esp=04 AM)",
                     disp_hour_tens, disp_hour_ones, is_pm);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else
            $display("  12h hour=4: disp=%0d%0d AM -> PASS", disp_hour_tens, disp_hour_ones);

        // Ajustar hour a 13 (4+9=13)
        mode_12h = 1'b0;
        pulse_mode;              // RUN -> ADJ_HOUR; sec_rst
        repeat(9) pulse_up;
        @(posedge clk); #1;     // hours = 13
        pulse_ajuste;            // ADJ_HOUR -> RUN; sec_rst

        mode_12h = 1'b0; #5;
        if (disp_hour_tens !== 4'd1 || disp_hour_ones !== 4'd3) begin
            $display("  [FAIL] 24h hour=13: disp=%0d%0d (esp=13)",
                     disp_hour_tens, disp_hour_ones);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else
            $display("  24h hour=13: disp=%0d%0d -> PASS", disp_hour_tens, disp_hour_ones);

        mode_12h = 1'b1; #5;
        if (disp_hour_tens !== 4'd0 || disp_hour_ones !== 4'd1 || is_pm !== 1'b1) begin
            $display("  [FAIL] 12h hour=13: disp=%0d%0d pm=%b (esp=01 PM)",
                     disp_hour_tens, disp_hour_ones, is_pm);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else
            $display("  12h hour=13: disp=%0d%0d PM -> PASS", disp_hour_tens, disp_hour_ones);

        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ======================================================================
        // TEST 9: Rollover 23:59:58 -> 00:00:00
        // Estado: hour=13, min=7, sec=0
        // ======================================================================
        errors_test = 0;
        mode_12h = 1'b0;
        $display("\n[TEST 9] Rollover 23:59:58 -> 00:00:00");

        // Fijar hour=23 (13+10)
        pulse_mode;              // RUN -> ADJ_HOUR; sec_rst
        repeat(10) pulse_up;
        @(posedge clk); #1;     // hours = 23

        // Fijar min=59 (7+52)
        pulse_mode;              // ADJ_HOUR -> ADJ_MIN; sec_rst
        repeat(52) pulse_up;
        @(posedge clk); #1;     // minutes = 59

        pulse_mode;              // ADJ_MIN -> RUN; sec_rst -> sec=0

        for (i = 0; i < 58; i = i + 1) tick_second;   // sec=0->58
        check_time(6'd58, 6'd59, 6'd23, 9);
        $display("  En 23:59:58: sec=%0d min=%0d hour=%0d", seconds, minutes, hours);

        tick_second;    // 23:59:58 -> 23:59:59
        tick_second;    // 23:59:59 -> 00:00:00
        check_time(6'd0, 6'd0, 6'd0, 9);
        $display("  Tras rollover: sec=%0d min=%0d hour=%0d", seconds, minutes, hours);
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ======================================================================
        // Resumen global
        // ======================================================================
        $display("\n============================================================");
        if (errors_total == 0)
            $display("  RESULTADO GLOBAL: TODOS LOS TESTS PASARON - OK");
        else
            $display("  RESULTADO GLOBAL: %0d ERROR(ES) - REVISAR", errors_total);
        $display("============================================================\n");

        $finish;
    end

    initial begin
        #(CLK_PERIOD * 2_000_000);
        $display("[TIMEOUT] Simulacion excedio el tiempo limite.");
        $finish;
    end

endmodule
