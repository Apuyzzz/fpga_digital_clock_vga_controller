// =============================================================================
// Testbench   : tb_debounce
// Description : Verifica la cadena completa sync_signal -> debounce -> bcd_counter.
//
//   TEST 1 - Reset              : btn_out=0, count_raw=0
//   TEST 2 - Rebote corto       : pulso < STABLE no genera btn_out
//   TEST 3 - Presion limpia     : btn_out=1 exactamente 1 ciclo
//   TEST 4 - bcd_counter incr.  : un pulso limpio incrementa count_raw
//   TEST 5 - Rebote al soltar   : no genera pulsos extra
//
// Simulador   : Vivado xsim (Artix-7 / Nexys A7)
// Autor       : Taller de Diseno Digital - EL3313 - I Semestre 2026
// =============================================================================

`timescale 1ns / 1ps

module tb_debounce;

    // -------------------------------------------------------------------------
    // Parametros
    // COUNT_MAX del debounce = (CLK_FREQ_HZ/1000)*DEBOUNCE_MS - 1
    //   = (1000/1000)*(STABLE+1) - 1 = STABLE
    // MARGIN absorbe latencia: 2 ciclos sync externo + 2 ciclos sync interno + STABLE
    // -------------------------------------------------------------------------
    parameter integer STABLE     = 10;
    parameter integer MARGIN     = STABLE + 15;
    parameter integer CLK_PERIOD = 10;

    // -------------------------------------------------------------------------
    // Senales
    // -------------------------------------------------------------------------
    reg  clk, rst;
    reg  btn_raw;

    wire sync_out;
    wire btn_out;

    wire [5:0] count_raw;
    wire       carry;

    // -------------------------------------------------------------------------
    // Cadena: sync_signal -> debounce -> bcd_counter
    // -------------------------------------------------------------------------
    sync_signal #(.WIDTH(1)) SYNC (
        .clk      (clk),
        .rst      (rst),
        .async_in (btn_raw),
        .sync_out (sync_out)
    );

    debounce #(
        .DEBOUNCE_MS(STABLE + 1),
        .CLK_FREQ_HZ(1000)
    ) DEB (
        .clk    (clk),
        .rst    (rst),
        .btn_in (sync_out),
        .btn_out(btn_out)
    );

    bcd_counter #(
        .MAX_VAL(59)
    ) CNT (
        .clk      (clk),
        .rst      (rst),
        .clk_en   (btn_out),
        .inc      (1'b0),
        .dec      (1'b0),
        .count    (count_raw),
        .carry_out(carry)
    );

    // -------------------------------------------------------------------------
    // Reloj
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Contadores de error
    // -------------------------------------------------------------------------
    integer errors_total = 0;
    integer errors_test  = 0;

    // -------------------------------------------------------------------------
    // Tarea: simula rebote
    // -------------------------------------------------------------------------
    task bounce;
        input integer n_bounces;
        input integer bounce_cycles;
        integer b;
        begin
            for (b = 0; b < n_bounces; b = b + 1) begin
                btn_raw = ~btn_raw;
                repeat(bounce_cycles) @(posedge clk);
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Tarea: presion limpia - sube MARGIN ciclos, baja MARGIN ciclos
    // -------------------------------------------------------------------------
    task press_clean;
        begin
            btn_raw = 1'b1;
            repeat(MARGIN) @(posedge clk);
            btn_raw = 1'b0;
            repeat(MARGIN) @(posedge clk);
        end
    endtask

    // =========================================================================
    // ESTIMULOS
    // =========================================================================
    integer pulse_count;
    integer count_antes;
    integer count_despues;

    initial begin
        rst     = 1'b1;
        btn_raw = 1'b0;

        $display("============================================================");
        $display("  TESTBENCH: sync_signal -> debounce -> bcd_counter");
        $display("  STABLE=%0d ciclos  MARGIN=%0d ciclos", STABLE, MARGIN);
        $display("============================================================");

        repeat(4) @(posedge clk); #1;

        // ------------------------------------------------------------------
        // TEST 1: Reset sincrono
        // ------------------------------------------------------------------
        errors_test = 0;
        $display("\n[TEST 1] Reset sincrono");
        if (btn_out !== 1'b0 || count_raw !== 6'd0) begin
            $display("  [FAIL] Estado incorrecto tras reset");
            $display("         btn_out=%b count_raw=%0d", btn_out, count_raw);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else
            $display("  btn_out=%b count_raw=%0d -> PASS", btn_out, count_raw);
        rst = 1'b0;
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 2: Rebote corto filtrado
        // 4 rebotes de 3 ciclos cada uno (< STABLE=10) no deben generar btn_out
        // ------------------------------------------------------------------
        errors_test = 0;
        pulse_count = 0;
        $display("\n[TEST 2] Rebote corto no pasa el filtro");
        bounce(4, 3);
        btn_raw = 1'b0;
        repeat(MARGIN) begin
            @(posedge clk); #1;
            if (btn_out) pulse_count = pulse_count + 1;
        end
        if (pulse_count !== 0) begin
            $display("  [FAIL] btn_out se activo %0d vez(es) con rebotes cortos (esperado: 0)", pulse_count);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else
            $display("  btn_out=0 tras rebotes cortos -> PASS");
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 3: Presion limpia genera btn_out exactamente 1 ciclo
        // ------------------------------------------------------------------
        errors_test = 0;
        pulse_count = 0;
        $display("\n[TEST 3] Presion limpia genera btn_out de 1 ciclo");
        btn_raw = 1'b1;
        repeat(MARGIN) begin
            @(posedge clk); #1;
            if (btn_out) pulse_count = pulse_count + 1;
        end
        btn_raw = 1'b0;
        repeat(MARGIN) @(posedge clk);

        $display("  btn_out se activo %0d vez (esperado: 1)", pulse_count);
        if (pulse_count !== 1) begin
            $display("  [FAIL] btn_out debe activarse exactamente 1 vez");
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 4: bcd_counter incrementa exactamente 1 vez por presion
        // ------------------------------------------------------------------
        errors_test  = 0;
        count_antes  = count_raw;
        $display("\n[TEST 4] bcd_counter incrementa 1 vez por presion limpia");
        $display("  count antes : %0d", count_antes);

        press_clean;

        count_despues = count_raw;
        $display("  count despues: %0d", count_despues);

        if (count_despues !== count_antes + 1) begin
            $display("  [FAIL] Incremento incorrecto: antes=%0d despues=%0d",
                     count_antes, count_despues);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 5: Rebote al soltar no genera pulsos extra
        // ------------------------------------------------------------------
        errors_test = 0;
        pulse_count = 0;
        $display("\n[TEST 5] Rebote al soltar no genera pulsos extra");

        btn_raw = 1'b1;
        repeat(MARGIN) begin
            @(posedge clk); #1;
            if (btn_out) pulse_count = pulse_count + 1;
        end

        bounce(6, 3);
        btn_raw = 1'b0;
        repeat(MARGIN) begin
            @(posedge clk); #1;
            if (btn_out) pulse_count = pulse_count + 1;
        end

        $display("  Pulsos totales=%0d (esperado: 1)", pulse_count);
        if (pulse_count !== 1) begin
            $display("  [FAIL] Rebote al soltar genero pulsos extra");
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // Resumen global
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
        #(CLK_PERIOD * 50000);
        $display("[TIMEOUT] Simulacion excedio el tiempo limite.");
        $finish;
    end

endmodule
