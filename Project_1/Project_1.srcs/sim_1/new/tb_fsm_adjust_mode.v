// =============================================================================
// Testbench   : tb_fsm_adjust_mode
// Description : Verifica la FSM de ajuste de reloj.
//               Los outputs son REGISTRADOS (clocked), por lo que la salida
//               de un estado aparece 1 ciclo despues de la transicion.
//
//   TEST 1 - Reset            : state=RUN, sec_en=1, adj_hour=0, mode_leds=00
//   TEST 2 - RUN->ADJ_HOUR    : btn_mode cicla el estado; adj_hour=1 al ciclo sig
//   TEST 3 - hour_inc/dec     : btn_up/btn_down generan pulso de 1 ciclo
//   TEST 4 - ADJ_HOUR->ADJ_MIN: btn_mode cicla; adj_min=1, mode_leds=10
//   TEST 5 - min_inc/dec      : btn_up/btn_down generan pulso de 1 ciclo
//   TEST 6 - ADJ_MIN->RUN     : btn_mode cicla; sec_en=1, mode_leds=00
//   TEST 7 - btn_ajuste       : retorno inmediato a RUN desde ADJ_HOUR
//   TEST 8 - sec_rst          : se activa en cada transicion de estado
//
// Simulador   : Vivado xsim (Artix-7 / Nexys A7)
// Autor       : Taller de Diseno Digital - EL3313 - I Semestre 2026
// =============================================================================

`timescale 1ns / 1ps

module tb_fsm_adjust_mode;

    parameter CLK_PERIOD = 10;

    reg clk, rst;
    reg btn_mode, btn_up, btn_down, btn_ajuste;

    wire       adj_hour, adj_min, sec_en;
    wire       hour_inc, hour_dec, min_inc, min_dec, sec_rst;
    wire [1:0] mode_leds;

    fsm_adjust_mode DUT (
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

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    integer errors_total = 0;
    integer errors_test  = 0;

    // -------------------------------------------------------------------------
    // Tarea: pulso de 1 ciclo en una senal de boton
    // Los outputs registrados de la FSM son visibles 2 ciclos despues:
    //   ciclo N  : senal de boton en alto
    //   ciclo N+1: estado transiciona, output usa estado ANTERIOR
    //   ciclo N+2: output usa NUEVO estado -> verificar aqui
    // -------------------------------------------------------------------------
    task pulse_mode;   begin @(posedge clk); #1; btn_mode   = 1; @(posedge clk); #1; btn_mode   = 0; @(posedge clk); #1; end endtask
    task pulse_up;     begin @(posedge clk); #1; btn_up     = 1; @(posedge clk); #1; btn_up     = 0; end endtask
    task pulse_down;   begin @(posedge clk); #1; btn_down   = 1; @(posedge clk); #1; btn_down   = 0; end endtask
    task pulse_ajuste; begin @(posedge clk); #1; btn_ajuste = 1; @(posedge clk); #1; btn_ajuste = 0; @(posedge clk); #1; end endtask

    task check_state;
        input       exp_adj_hour;
        input       exp_adj_min;
        input       exp_sec_en;
        input [1:0] exp_leds;
        input integer step;
        begin
            if (adj_hour !== exp_adj_hour) begin
                $display("  [FAIL] T%0d: adj_hour=%b (esp=%b)", step, adj_hour, exp_adj_hour);
                errors_test  = errors_test  + 1;
                errors_total = errors_total + 1;
            end
            if (adj_min !== exp_adj_min) begin
                $display("  [FAIL] T%0d: adj_min=%b (esp=%b)", step, adj_min, exp_adj_min);
                errors_test  = errors_test  + 1;
                errors_total = errors_total + 1;
            end
            if (sec_en !== exp_sec_en) begin
                $display("  [FAIL] T%0d: sec_en=%b (esp=%b)", step, sec_en, exp_sec_en);
                errors_test  = errors_test  + 1;
                errors_total = errors_total + 1;
            end
            if (mode_leds !== exp_leds) begin
                $display("  [FAIL] T%0d: mode_leds=%b (esp=%b)", step, mode_leds, exp_leds);
                errors_test  = errors_test  + 1;
                errors_total = errors_total + 1;
            end
        end
    endtask

    // =========================================================================
    initial begin
        rst = 1; btn_mode = 0; btn_up = 0; btn_down = 0; btn_ajuste = 0;

        $display("============================================================");
        $display("  TESTBENCH: fsm_adjust_mode");
        $display("============================================================");

        repeat(3) @(posedge clk); #1;
        rst = 0;

        // ------------------------------------------------------------------
        // TEST 1: Reset - state=RUN, sec_en=1 (output update 1 ciclo despues)
        // ------------------------------------------------------------------
        errors_test = 0;
        $display("\n[TEST 1] Reset - estado inicial RUN");
        @(posedge clk); #1;  // output se actualiza con state=RUN
        check_state(0, 0, 1, 2'b00, 1);
        $display("  adj_hour=%b adj_min=%b sec_en=%b mode_leds=%b",
                 adj_hour, adj_min, sec_en, mode_leds);
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 2: RUN -> ADJ_HOUR
        // ------------------------------------------------------------------
        errors_test = 0;
        $display("\n[TEST 2] RUN -> ADJ_HOUR (btn_mode)");
        pulse_mode;  // espera 2 ciclos extra (ver tarea)
        check_state(1, 0, 0, 2'b01, 2);
        $display("  adj_hour=%b adj_min=%b sec_en=%b mode_leds=%b",
                 adj_hour, adj_min, sec_en, mode_leds);
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 3: hour_inc en ADJ_HOUR (btn_up = 1 ciclo)
        //         hour_inc aparece al mismo ciclo que se samplea btn_up
        // ------------------------------------------------------------------
        errors_test = 0;
        $display("\n[TEST 3] hour_inc y hour_dec en ADJ_HOUR");

        // btn_up
        @(posedge clk); #1; btn_up = 1;
        @(posedge clk); #1;
        if (hour_inc !== 1'b1) begin
            $display("  [FAIL] hour_inc no se activo con btn_up");
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else $display("  hour_inc=1 con btn_up -> PASS");
        btn_up = 0;
        @(posedge clk); #1;
        if (hour_inc !== 1'b0) begin
            $display("  [FAIL] hour_inc no volvio a 0");
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else $display("  hour_inc=0 tras btn_up=0 -> PASS");

        // btn_down
        @(posedge clk); #1; btn_down = 1;
        @(posedge clk); #1;
        if (hour_dec !== 1'b1) begin
            $display("  [FAIL] hour_dec no se activo con btn_down");
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else $display("  hour_dec=1 con btn_down -> PASS");
        btn_down = 0;
        @(posedge clk); #1;

        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 4: ADJ_HOUR -> ADJ_MIN
        // ------------------------------------------------------------------
        errors_test = 0;
        $display("\n[TEST 4] ADJ_HOUR -> ADJ_MIN (btn_mode)");
        pulse_mode;
        check_state(0, 1, 0, 2'b10, 4);
        $display("  adj_hour=%b adj_min=%b sec_en=%b mode_leds=%b",
                 adj_hour, adj_min, sec_en, mode_leds);
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 5: min_inc y min_dec en ADJ_MIN
        // ------------------------------------------------------------------
        errors_test = 0;
        $display("\n[TEST 5] min_inc y min_dec en ADJ_MIN");

        @(posedge clk); #1; btn_up = 1;
        @(posedge clk); #1;
        if (min_inc !== 1'b1) begin
            $display("  [FAIL] min_inc no se activo");
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else $display("  min_inc=1 con btn_up -> PASS");
        btn_up = 0;
        @(posedge clk); #1;

        @(posedge clk); #1; btn_down = 1;
        @(posedge clk); #1;
        if (min_dec !== 1'b1) begin
            $display("  [FAIL] min_dec no se activo");
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else $display("  min_dec=1 con btn_down -> PASS");
        btn_down = 0;
        @(posedge clk); #1;

        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 6: ADJ_MIN -> RUN
        // ------------------------------------------------------------------
        errors_test = 0;
        $display("\n[TEST 6] ADJ_MIN -> RUN (btn_mode)");
        pulse_mode;
        check_state(0, 0, 1, 2'b00, 6);
        $display("  adj_hour=%b adj_min=%b sec_en=%b mode_leds=%b",
                 adj_hour, adj_min, sec_en, mode_leds);
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 7: btn_ajuste retorna a RUN desde ADJ_HOUR
        // ------------------------------------------------------------------
        errors_test = 0;
        $display("\n[TEST 7] btn_ajuste retorna directo a RUN desde ADJ_HOUR");
        pulse_mode;  // RUN -> ADJ_HOUR
        check_state(1, 0, 0, 2'b01, 7);
        pulse_ajuste;  // ADJ_HOUR -> RUN
        check_state(0, 0, 1, 2'b00, 7);
        $display("  Volvio a RUN: adj_hour=%b sec_en=%b mode_leds=%b",
                 adj_hour, sec_en, mode_leds);
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 8: sec_rst se activa en cada transicion de estado
        // ------------------------------------------------------------------
        errors_test = 0;
        $display("\n[TEST 8] sec_rst activo exactamente 1 ciclo en transicion");

        // RUN->ADJ_HOUR: sec_rst debe activarse en el ciclo de la transicion
        @(posedge clk); #1; btn_mode = 1;
        @(posedge clk); #1;
        if (sec_rst !== 1'b1) begin
            $display("  [FAIL] sec_rst=0 en transicion RUN->ADJ_HOUR (esperado 1)");
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else $display("  sec_rst=1 en transicion -> PASS");
        btn_mode = 0;
        @(posedge clk); #1;
        if (sec_rst !== 1'b0) begin
            $display("  [FAIL] sec_rst no volvio a 0");
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else $display("  sec_rst=0 al ciclo siguiente -> PASS");

        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // Resumen
        // ------------------------------------------------------------------
        $display("\n============================================================");
        if (errors_total == 0)
            $display("  RESULTADO GLOBAL: TODOS LOS TESTS PASARON - OK");
        else
            $display("  RESULTADO GLOBAL: %0d ERROR(ES) - REVISAR", errors_total);
        $display("============================================================\n");

        $finish;
    end

    initial begin
        #(CLK_PERIOD * 10000);
        $display("[TIMEOUT] Simulacion excedio el tiempo limite.");
        $finish;
    end

endmodule
