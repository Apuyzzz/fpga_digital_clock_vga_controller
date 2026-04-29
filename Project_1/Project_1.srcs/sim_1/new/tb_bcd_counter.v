// =============================================================================
// Testbench   : tb_bcd_counter
// Description : Verifica bcd_counter parametrizado con MAX_VAL.
//               El mismo testbench corre correctamente para MAX_VAL=59 y
//               MAX_VAL=23 porque todos los valores criticos se calculan
//               automaticamente a partir de MAX_VAL.
//
//   Para probar seg/min: dejar MAX_VAL = 59
//   Para probar horas  : cambiar MAX_VAL = 23
//
//   TEST 1 - Reset sincrono    : count debe quedar en 0
//   TEST 2 - Conteo normal     : count correcto de 0 a 15
//   TEST 3 - Rollover y carry  : verifica MAX_VAL-1, MAX_VAL y rollover
//   TEST 4 - Enable gating     : sin clk_en=1 el contador NO avanza
//
// Simulador   : Vivado xsim (Artix-7 / Nexys A7)
// Autor       : Taller de Diseno Digital - EL3313 - I Semestre 2026
// =============================================================================

`timescale 1ns / 1ps

module tb_bcd_counter;

    // -------------------------------------------------------------------------
    // PARAMETRO PRINCIPAL — cambiar aqui para probar MAX_VAL=59 o MAX_VAL=23
    // -------------------------------------------------------------------------
    parameter integer MAX_VAL    = 59;
    parameter integer CLK_PERIOD = 10;      // 100 MHz -> 10 ns

    // -------------------------------------------------------------------------
    // Senales DUT
    // -------------------------------------------------------------------------
    reg        clk;
    reg        rst;
    reg        en;
    wire [5:0] count_raw;
    wire       carry;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    bcd_counter #(
        .MAX_VAL(MAX_VAL)
    ) DUT (
        .clk      (clk),
        .rst      (rst),
        .clk_en   (en),
        .inc      (1'b0),
        .dec      (1'b0),
        .count    (count_raw),
        .carry_out(carry)
    );

    // -------------------------------------------------------------------------
    // Reloj 100 MHz
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Contadores de error
    // -------------------------------------------------------------------------
    integer errors_total = 0;
    integer errors_test  = 0;

    // -------------------------------------------------------------------------
    // Tarea: pulso de enable de 1 ciclo
    // -------------------------------------------------------------------------
    task pulse_en;
        begin
            @(posedge clk); #1;
            en = 1'b1;
            @(posedge clk); #1;
            en = 1'b0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Tarea: verificacion de count y carry esperados
    // -------------------------------------------------------------------------
    task check;
        input [5:0]  exp_val;
        input        exp_carry;
        input integer step;
        begin
            if (count_raw !== exp_val) begin
                $display("  [FAIL] paso=%0d | count esperado=%0d | obtenido=%0d",
                         step, exp_val, count_raw);
                errors_test  = errors_test  + 1;
                errors_total = errors_total + 1;
            end
            if (carry !== exp_carry) begin
                $display("  [FAIL] paso=%0d | carry esperado=%b | obtenido=%b",
                         step, exp_carry, carry);
                errors_test  = errors_test  + 1;
                errors_total = errors_total + 1;
            end
        end
    endtask

    // =========================================================================
    // ESTIMULOS
    // =========================================================================
    integer i;
    integer expected_val_int;
    reg [5:0] bcd_at_max_minus1;
    reg [5:0] bcd_at_max;

    initial begin
        rst = 1'b1;
        en  = 1'b0;

        $display("============================================================");
        $display("  TESTBENCH: bcd_counter  |  MAX_VAL = %0d", MAX_VAL);
        $display("============================================================");

        // ------------------------------------------------------------------
        // TEST 1: Reset sincrono
        // ------------------------------------------------------------------
        errors_test = 0;
        $display("\n[TEST 1] Reset sincrono");
        repeat(3) @(posedge clk); #1;
        rst = 1'b0;
        @(posedge clk); #1;
        check(6'd0, 1'b0, 0);
        $display("  count=%0d | carry=%b", count_raw, carry);
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 2: Conteo normal — primeros 15 pulsos
        // ------------------------------------------------------------------
        errors_test      = 0;
        expected_val_int = 0;
        $display("\n[TEST 2] Conteo normal (15 pulsos)");
        for (i = 0; i < 15; i = i + 1) begin
            pulse_en;
            expected_val_int = expected_val_int + 1;
            check(expected_val_int[5:0], 1'b0, i);
            $display("  pulso %02d | count=%0d (esperado=%0d)",
                     i+1, count_raw, expected_val_int);
        end
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 3: Rollover y carry
        // ------------------------------------------------------------------
        errors_test = 0;
        $display("\n[TEST 3] Rollover y carry en MAX_VAL=%0d", MAX_VAL);

        bcd_at_max_minus1 = MAX_VAL - 1;
        bcd_at_max        = MAX_VAL;

        rst = 1'b1; @(posedge clk); #1; rst = 1'b0;

        // Avanzar hasta MAX_VAL-1
        for (i = 0; i < MAX_VAL - 1; i = i + 1) pulse_en;

        $display("  En MAX_VAL-1 (%0d): count=%0d | esperado=%0d",
                 MAX_VAL-1, count_raw, bcd_at_max_minus1);
        if (count_raw !== bcd_at_max_minus1) begin
            $display("  [FAIL] Valor incorrecto en MAX_VAL-1");
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end

        // Un pulso mas: llegar a MAX_VAL
        pulse_en;
        $display("  En MAX_VAL (%0d): count=%0d | esperado=%0d",
                 MAX_VAL, count_raw, bcd_at_max);
        if (count_raw !== bcd_at_max) begin
            $display("  [FAIL] Valor incorrecto en MAX_VAL");
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end

        // Pulso de rollover: carry debe ser 1 en ese ciclo
        @(posedge clk); #1; en = 1'b1;
        @(posedge clk); #1;
        if (carry !== 1'b1) begin
            $display("  [FAIL] carry=0 en rollover (esperado carry=1)");
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else
            $display("  carry=1 detectado en rollover: CORRECTO");
        en = 1'b0;

        // Ciclo siguiente: carry=0 y count=0
        @(posedge clk); #1;
        check(6'd0, 1'b0, MAX_VAL);
        $display("  Despues del rollover: count=%0d | carry=%b", count_raw, carry);

        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 4: Enable gating — sin clk_en=1 el contador no avanza
        // ------------------------------------------------------------------
        errors_test = 0;
        $display("\n[TEST 4] Enable gating (clk_en=0 no debe avanzar)");

        rst = 1'b1; @(posedge clk); #1; rst = 1'b0;
        repeat(5) pulse_en;
        $display("  count luego de 5 pulsos: %0d", count_raw);

        repeat(10) @(posedge clk); #1;
        if (count_raw !== 6'd5) begin
            $display("  [FAIL] count cambio sin enable: %0d (esperado 5)", count_raw);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else
            $display("  count=5 tras 10 ciclos sin enable: CORRECTO");

        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // Resumen final
        // ------------------------------------------------------------------
        $display("\n============================================================");
        $display("  MAX_VAL = %0d", MAX_VAL);
        if (errors_total == 0)
            $display("  RESULTADO GLOBAL: TODOS LOS TESTS PASARON - OK");
        else
            $display("  RESULTADO GLOBAL: %0d ERROR(ES) - REVISAR", errors_total);
        $display("  Para probar horas: cambiar MAX_VAL = 23 en linea 27");
        $display("============================================================\n");

        $finish;
    end

    // Timeout de seguridad
    initial begin
        #(CLK_PERIOD * 200000);
        $display("[TIMEOUT] Simulacion excedio el tiempo limite.");
        $finish;
    end

endmodule
