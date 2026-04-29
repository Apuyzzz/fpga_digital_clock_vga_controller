// =============================================================================
// Testbench   : tb_binary_bcd_decoder
// Description : Prueba exhaustiva del convertidor binario->BCD (Double Dabble).
//               Instancia N=6 (rango 0-59) y N=5 (rango 0-23).
//               Verifica bcd_tens = bin/10, bcd_ones = bin%10.
//
//   TEST 1 - N=6 (segundos/minutos): todos los valores 0-59
//   TEST 2 - N=5 (horas)           : todos los valores 0-23
//
// Simulador   : Vivado xsim (Artix-7 / Nexys A7)
// Autor       : Taller de Diseno Digital - EL3313 - I Semestre 2026
// =============================================================================

`timescale 1ns / 1ps

module tb_binary_bcd_decoder;

    // -------------------------------------------------------------------------
    // DUT N=6 (segundos/minutos: 0-59)
    // -------------------------------------------------------------------------
    reg  [5:0] bin6;
    wire [3:0] tens6, ones6;

    binary_bcd_decoder #(.N(6)) DUT6 (
        .bin     (bin6),
        .bcd_tens(tens6),
        .bcd_ones(ones6)
    );

    // -------------------------------------------------------------------------
    // DUT N=5 (horas: 0-23, top usa bin[4:0])
    // -------------------------------------------------------------------------
    reg  [4:0] bin5;
    wire [3:0] tens5, ones5;

    binary_bcd_decoder #(.N(5)) DUT5 (
        .bin     (bin5),
        .bcd_tens(tens5),
        .bcd_ones(ones5)
    );

    integer errors_total = 0;
    integer errors_test  = 0;
    integer v;

    initial begin
        $display("============================================================");
        $display("  TESTBENCH: binary_bcd_decoder  |  N=6 y N=5");
        $display("============================================================");

        // ------------------------------------------------------------------
        // TEST 1: N=6, valores 0-59
        // ------------------------------------------------------------------
        errors_test = 0;
        $display("\n[TEST 1] N=6 - rango 0-59 (minutos/segundos)");
        for (v = 0; v <= 59; v = v + 1) begin
            bin6 = v[5:0];
            #5;
            if (tens6 !== v / 10 || ones6 !== v % 10) begin
                $display("  [FAIL] bin=%0d | tens=%0d (esp=%0d) | ones=%0d (esp=%0d)",
                         v, tens6, v/10, ones6, v%10);
                errors_test  = errors_test  + 1;
                errors_total = errors_total + 1;
            end
        end
        $display("  Verificados 60 valores (0-59)");
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 2: N=5, valores 0-23
        // ------------------------------------------------------------------
        errors_test = 0;
        $display("\n[TEST 2] N=5 - rango 0-23 (horas)");
        for (v = 0; v <= 23; v = v + 1) begin
            bin5 = v[4:0];
            #5;
            if (tens5 !== v / 10 || ones5 !== v % 10) begin
                $display("  [FAIL] bin=%0d | tens=%0d (esp=%0d) | ones=%0d (esp=%0d)",
                         v, tens5, v/10, ones5, v%10);
                errors_test  = errors_test  + 1;
                errors_total = errors_total + 1;
            end
        end
        $display("  Verificados 24 valores (0-23)");
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
        #100000;
        $display("[TIMEOUT] Simulacion excedio el tiempo limite.");
        $finish;
    end

endmodule
