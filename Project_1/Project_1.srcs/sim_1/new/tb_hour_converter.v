// =============================================================================
// Testbench   : tb_hour_converter
// Description : Verifica la conversion 24h -> 12h + AM/PM.
//               Casos criticos y exhaustivo 0-23.
//
//   Mapeo esperado (segun spec):
//     0  -> 12 AM (medianoche)
//     1  ->  1 AM
//    11  -> 11 AM
//    12  -> 12 PM (mediodia)
//    13  ->  1 PM
//    23  -> 11 PM
//
//   TEST 1 - Casos criticos : 0, 1, 11, 12, 13, 23
//   TEST 2 - Exhaustivo     : todos los valores 0-23
//
// Simulador   : Vivado xsim (Artix-7 / Nexys A7)
// Autor       : Taller de Diseno Digital - EL3313 - I Semestre 2026
// =============================================================================

`timescale 1ns / 1ps

module tb_hour_converter;

    reg  [5:0] hours_24;
    wire [3:0] h12_tens, h12_ones;
    wire       is_pm;

    hour_converter DUT (
        .hours_24(hours_24),
        .h12_tens(h12_tens),
        .h12_ones(h12_ones),
        .is_pm   (is_pm)
    );

    integer errors_total = 0;
    integer errors_test  = 0;

    // -------------------------------------------------------------------------
    // Calcula el resultado esperado y verifica
    // -------------------------------------------------------------------------
    task check_hour;
        input integer h24;
        input integer exp_tens;
        input integer exp_ones;
        input         exp_pm;
        begin
            hours_24 = h24[5:0];
            #5;
            if (h12_tens !== exp_tens[3:0] || h12_ones !== exp_ones[3:0] || is_pm !== exp_pm) begin
                $display("  [FAIL] h24=%0d | tens=%0d ones=%0d pm=%b (esp: %0d%0d pm=%b)",
                         h24, h12_tens, h12_ones, is_pm, exp_tens, exp_ones, exp_pm);
                errors_test  = errors_test  + 1;
                errors_total = errors_total + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Calcula el expected en Verilog puro
    // -------------------------------------------------------------------------
    integer v, h12_exp, tens_exp, ones_exp, pm_exp;

    initial begin
        $display("============================================================");
        $display("  TESTBENCH: hour_converter  |  24h -> 12h");
        $display("============================================================");

        // ------------------------------------------------------------------
        // TEST 1: Casos criticos con display explicito
        // ------------------------------------------------------------------
        errors_test = 0;
        $display("\n[TEST 1] Casos criticos");

        check_hour( 0, 1, 2, 0); $display("  h24= 0 -> %0d%0d %s | is_pm=%b", h12_tens, h12_ones, (is_pm ? "PM" : "AM"), is_pm);
        check_hour( 1, 0, 1, 0); $display("  h24= 1 -> %0d%0d %s | is_pm=%b", h12_tens, h12_ones, (is_pm ? "PM" : "AM"), is_pm);
        check_hour(11, 1, 1, 0); $display("  h24=11 -> %0d%0d %s | is_pm=%b", h12_tens, h12_ones, (is_pm ? "PM" : "AM"), is_pm);
        check_hour(12, 1, 2, 1); $display("  h24=12 -> %0d%0d %s | is_pm=%b", h12_tens, h12_ones, (is_pm ? "PM" : "AM"), is_pm);
        check_hour(13, 0, 1, 1); $display("  h24=13 -> %0d%0d %s | is_pm=%b", h12_tens, h12_ones, (is_pm ? "PM" : "AM"), is_pm);
        check_hour(23, 1, 1, 1); $display("  h24=23 -> %0d%0d %s | is_pm=%b", h12_tens, h12_ones, (is_pm ? "PM" : "AM"), is_pm);

        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 2: Exhaustivo 0-23
        // ------------------------------------------------------------------
        errors_test = 0;
        $display("\n[TEST 2] Exhaustivo 0-23");
        for (v = 0; v <= 23; v = v + 1) begin
            pm_exp = (v >= 12) ? 1 : 0;

            if (v == 0 || v == 12)
                h12_exp = 12;
            else if (v > 12)
                h12_exp = v - 12;
            else
                h12_exp = v;

            tens_exp = h12_exp / 10;
            ones_exp = h12_exp % 10;

            check_hour(v, tens_exp, ones_exp, pm_exp[0]);
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
