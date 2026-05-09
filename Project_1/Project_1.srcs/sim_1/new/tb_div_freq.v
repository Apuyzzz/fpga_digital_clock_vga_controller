/**
 * @title Testbench — div_freq
 * @file tb_div_freq.v
 * @brief Verifica div_freq con divisor reducido (DIVISOR=4) para simulación rápida.
 * @details
 *   TEST 1 - Reset síncrono      : tick debe permanecer en 0
 *   TEST 2 - Divisor pequeño (4) : tick cada 4 ciclos exactos
 *   TEST 3 - Tick dura 1 ciclo   : tick nunca se extiende más de 1 ciclo
 *   TEST 4 - Conteo de pulsos    : número de ticks en N ciclos = N/DIVISOR
 *
 * @author hidalgojeulin
 * @date 2026-04-27
 */

`timescale 1ns / 1ps

module tb_div_freq;

    // -------------------------------------------------------------------------
    // Para simulación se usa un DIVISOR pequeño (4) para no esperar 100M ciclos
    // -------------------------------------------------------------------------
    parameter DIVISOR    = 4;
    parameter CLK_PERIOD = 10;      // 100 MHz → 10 ns

    // -------------------------------------------------------------------------
    // Señales DUT
    // -------------------------------------------------------------------------
    reg  clk;
    reg  rst;
    wire tick;

    // -------------------------------------------------------------------------
    // Instancia DUT
    // -------------------------------------------------------------------------
    div_freq #(
        .DIVISOR(DIVISOR)
    ) DUT (
        .clk_in (clk),
        .rst    (rst),
        .clk_out(tick)
    );

    // -------------------------------------------------------------------------
    // Generador de reloj 100 MHz
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Variables auxiliares
    // -------------------------------------------------------------------------
    integer errors   = 0;
    integer tick_cnt = 0;
    integer i;

    // =========================================================================
    // ESTÍMULOS
    // =========================================================================
    initial begin
        rst = 1'b1;
        $display("============================================================");
        $display("  TESTBENCH: div_freq  |  DIVISOR = %0d", DIVISOR);
        $display("============================================================");

        // ------------------------------------------------------------------
        // TEST 1: Reset síncrono — tick debe ser 0 mientras rst=1
        // ------------------------------------------------------------------
        $display("\n[TEST 1] Reset sincrono");
        repeat(6) begin
            @(posedge clk); #1;
            if (tick !== 1'b0) begin
                $display("  [FAIL] tick = 1 durante reset (esperado 0)");
                errors = errors + 1;
            end
        end
        rst = 1'b0;
        $display("  tick = 0 durante reset --> PASS");

        // ------------------------------------------------------------------
        // TEST 2: Tick exactamente cada DIVISOR ciclos
        //         Se espera el primer tick y se mide el tiempo entre ticks
        // ------------------------------------------------------------------
        $display("\n[TEST 2] Tick cada %0d ciclos exactos", DIVISOR);
        begin : test2
            integer tick_time_a, tick_time_b, delta;
            integer sim_time;

            // Esperar primer tick
            @(posedge tick); tick_time_a = $time;
            $display("  Primer tick en t = %0d ns", tick_time_a);

            // Esperar segundo tick
            @(posedge tick); tick_time_b = $time;
            $display("  Segundo tick en t = %0d ns", tick_time_b);

            delta = tick_time_b - tick_time_a;
            if (delta !== DIVISOR * CLK_PERIOD) begin
                $display("  [FAIL] Período = %0d ns | esperado = %0d ns",
                         delta, DIVISOR * CLK_PERIOD);
                errors = errors + 1;
            end else begin
                $display("  Periodo entre ticks = %0d ns --> PASS", delta);
            end
        end

        // ------------------------------------------------------------------
        // TEST 3: Tick dura exactamente 1 ciclo de reloj
        // ------------------------------------------------------------------
        $display("\n[TEST 3] Tick dura solo 1 ciclo");
        begin : test3
            integer tick_high_start, tick_high_end, tick_width;

            @(posedge tick); tick_high_start = $time;
            @(negedge tick); tick_high_end   = $time;

            tick_width = tick_high_end - tick_high_start;
            if (tick_width !== CLK_PERIOD) begin
                $display("  [FAIL] tick activo por %0d ns | esperado %0d ns (1 ciclo)",
                         tick_width, CLK_PERIOD);
                errors = errors + 1;
            end else begin
                $display("  Ancho del tick = %0d ns (1 ciclo) --> PASS", tick_width);
            end
        end

        // ------------------------------------------------------------------
        // TEST 4: Contar pulsos en un período conocido
        //         En DIVISOR*10 ciclos deben aparecer exactamente 10 ticks
        // ------------------------------------------------------------------
        $display("\n[TEST 4] Numero de ticks en %0d ciclos", DIVISOR * 10);
        tick_cnt = 0;
        repeat(DIVISOR * 10) begin
            @(posedge clk); #1;
            if (tick) tick_cnt = tick_cnt + 1;
        end

        $display("  Ticks contados = %0d | esperados = 10", tick_cnt);
        if (tick_cnt !== 10) begin
            $display("  [FAIL] Número de ticks incorrecto");
            errors = errors + 1;
        end else begin
            $display("  --> PASS");
        end

        // ------------------------------------------------------------------
        // Resumen
        // ------------------------------------------------------------------
        $display("\n============================================================");
        if (errors == 0)
            $display("  RESULTADO GLOBAL: TODOS LOS TESTS PASARON - OK");
        else
            $display("  RESULTADO GLOBAL: %0d ERROR(ES) - REVISAR", errors);
        $display("============================================================\n");

        $finish;
    end

    // Timeout de seguridad
    initial begin
        #(CLK_PERIOD * 10000);
        $display("[TIMEOUT] Simulacion excedio el tiempo limite.");
        $finish;
    end

endmodule
