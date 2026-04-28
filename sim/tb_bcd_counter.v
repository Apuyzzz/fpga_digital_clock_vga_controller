// =============================================================================
// Testbench   : tb_bcd_counter
// Description : Verifica bcd_counter parametrizado con MAX_VAL.
//               El mismo testbench corre correctamente para MAX=59 y MAX=23
//               porque todos los valores criticos (MAX-1, MAX) se calculan
//               automaticamente a partir de MAX_VAL.
//
//   Para probar seg/min: dejar MAX_VAL = 59
//   Para probar horas  : cambiar MAX_VAL = 23
//   El DUT y el TEST 3 se adaptan solos.
//
//   TEST 1 - Reset sincrono    : bcd debe quedar en 0x00
//   TEST 2 - Conteo normal     : BCD correcto de 0 a 15
//   TEST 3 - Rollover y carry  : verifica MAX-1, MAX y rollover dinamicamente
//   TEST 4 - Enable gating     : sin en=1 el contador NO avanza
//
// Simulador   : Vivado xsim (Artix-7 / Nexys A7)
// Autor       : Taller de Diseno Digital - EL3313 - I Semestre 2026
// =============================================================================

`timescale 1ns / 1ps

module tb_bcd_counter;

    // -------------------------------------------------------------------------
    // PARAMETRO PRINCIPAL — cambiar aqui para probar MAX=59 o MAX=23
    // El DUT y todos los calculos del testbench se adaptan automaticamente.
    // -------------------------------------------------------------------------
    parameter integer MAX_VAL    = 59;
    parameter integer CLK_PERIOD = 10;      // 100 MHz -> 10 ns

    // -------------------------------------------------------------------------
    // Senales DUT
    // -------------------------------------------------------------------------
    reg        clk;
    reg        rst;
    reg        en;
    wire [7:0] bcd;
    wire       carry;

    // -------------------------------------------------------------------------
    // DUT: usa MAX_VAL como parametro — no tiene valores fijos internamente
    // -------------------------------------------------------------------------
    bcd_counter #(
        .MAX(MAX_VAL[5:0])
    ) DUT (
        .clk   (clk),
        .rst   (rst),
        .en    (en),
        .bcd   (bcd),
        .carry (carry)
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
    // Tarea: verificacion de BCD y carry esperados
    // -------------------------------------------------------------------------
    task check;
        input [7:0]  exp_bcd;
        input        exp_carry;
        input integer step;
        begin
            if (bcd !== exp_bcd) begin
                $display("  [FAIL] paso=%0d | BCD esperado=0x%02h | obtenido=0x%02h",
                         step, exp_bcd, bcd);
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
    integer expected_bin_int;
    reg [7:0] expected_bcd;
    reg [7:0] bcd_at_max_minus1;
    reg [7:0] bcd_at_max;

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
        check(8'h00, 1'b0, 0);
        $display("  bcd=0x%02h | carry=%b", bcd, carry);
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 2: Conteo normal — primeros 15 pulsos
        // expected_bcd calculado en dos lineas para compatibilidad xsim
        // ------------------------------------------------------------------
        errors_test     = 0;
        expected_bin_int = 0;
        $display("\n[TEST 2] Conteo normal (15 pulsos)");
        for (i = 0; i < 15; i = i + 1) begin
            pulse_en;
            expected_bin_int  = expected_bin_int + 1;
            expected_bcd[7:4] = expected_bin_int / 10;
            expected_bcd[3:0] = expected_bin_int % 10;
            check(expected_bcd, 1'b0, i);
            $display("  pulso %02d | bcd=0x%02h | dec=%0d | tens=%0d units=%0d",
                     i+1, bcd, expected_bin_int, bcd[7:4], bcd[3:0]);
        end
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 3: Rollover y carry
        // Todos los valores criticos calculados desde MAX_VAL:
        //   MAX-1 : valor justo antes del maximo
        //   MAX   : valor maximo
        //   0x00  : valor despues del rollover
        // Esto funciona igual para MAX=59 y MAX=23
        // ------------------------------------------------------------------
        errors_test = 0;
        $display("\n[TEST 3] Rollover y carry en MAX=%0d", MAX_VAL);

        // Calcular BCD esperados desde MAX_VAL
        bcd_at_max_minus1[7:4] = (MAX_VAL - 1) / 10;
        bcd_at_max_minus1[3:0] = (MAX_VAL - 1) % 10;
        bcd_at_max[7:4]        = MAX_VAL / 10;
        bcd_at_max[3:0]        = MAX_VAL % 10;

        // Reset para partir limpio
        rst = 1'b1; @(posedge clk); #1; rst = 1'b0;

        // Avanzar hasta MAX-1
        for (i = 0; i < MAX_VAL - 1; i = i + 1) pulse_en;

        // Verificar que estamos en MAX-1
        $display("  En MAX-1 (%0d): bcd=0x%02h | esperado=0x%02h",
                 MAX_VAL-1, bcd, bcd_at_max_minus1);
        if (bcd !== bcd_at_max_minus1) begin
            $display("  [FAIL] Valor incorrecto en MAX-1");
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end

        // Un pulso mas: llegar a MAX
        pulse_en;
        $display("  En MAX   (%0d): bcd=0x%02h | esperado=0x%02h",
                 MAX_VAL, bcd, bcd_at_max);
        if (bcd !== bcd_at_max) begin
            $display("  [FAIL] Valor incorrecto en MAX");
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

        // Ciclo siguiente: carry=0 y bcd=0x00
        @(posedge clk); #1;
        check(8'h00, 1'b0, MAX_VAL);
        $display("  Despues del rollover: bcd=0x%02h | carry=%b", bcd, carry);

        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 4: Enable gating — sin en=1 el contador no avanza
        // ------------------------------------------------------------------
        errors_test = 0;
        $display("\n[TEST 4] Enable gating (en=0 no debe avanzar)");

        rst = 1'b1; @(posedge clk); #1; rst = 1'b0;
        repeat(5) pulse_en;
        $display("  bcd luego de 5 pulsos: 0x%02h", bcd);

        repeat(10) @(posedge clk); #1;
        if (bcd !== 8'h05) begin
            $display("  [FAIL] bcd cambio sin enable: 0x%02h (esperado 0x05)", bcd);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else
            $display("  bcd=0x05 tras 10 ciclos sin enable: CORRECTO");

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
        $display("  Para probar horas: cambiar MAX_VAL = 23 en linea 40");
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
