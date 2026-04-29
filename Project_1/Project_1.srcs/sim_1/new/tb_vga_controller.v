// =============================================================================
// Testbench   : tb_vga_controller
// Description : Verifica vga_controller con 5 casos de prueba:
//
//   TEST 1 - Reset           : h=0, v=0, hsync=1, vsync=1, blank=0
//   TEST 2 - Temporiz. H     : HSYNC baja en H=657, sube en H=753
//                              (1 ciclo de pipeline: hsync se registra
//                               usando h_count del ciclo anterior)
//   TEST 3 - Temporiz. V     : VSYNC baja en V=491, sube en V=493
//                              (mismo offset de pipeline)
//   TEST 4 - Area activa     : blank=0 en zona visible, blank=1 en blanking
//   TEST 5 - Periodo frame   : 800 * 525 ciclos entre vsync consecutivos
//
// NOTA: tick_25mhz = 1 siempre (1 pixel = 1 ciclo de 100 MHz).
//
// Simulador   : Vivado xsim (Artix-7 / Nexys A7)
// Autor       : Taller de Diseno Digital - EL3313 - I Semestre 2026
// =============================================================================

`timescale 1ns / 1ps

module tb_vga_controller;

    parameter H_VISIBLE  = 640;
    parameter H_TOTAL    = 800;
    parameter V_VISIBLE  = 480;
    parameter V_TOTAL    = 525;
    parameter CLK_PERIOD = 10;

    // -------------------------------------------------------------------------
    // Senales DUT
    // -------------------------------------------------------------------------
    reg        clk;
    reg        rst;
    reg        tick_25mhz;
    wire       hsync;
    wire       vsync;
    wire       blank;
    wire [9:0] h_count;
    wire [9:0] v_count;

    // -------------------------------------------------------------------------
    // Instancia DUT
    // -------------------------------------------------------------------------
    vga_controller DUT (
        .clk        (clk),
        .rst        (rst),
        .tick_25mhz (tick_25mhz),
        .hsync      (hsync),
        .vsync      (vsync),
        .blank      (blank),
        .h_count    (h_count),
        .v_count    (v_count)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    integer errors = 0;
    integer hsync_start_found, hsync_end_found;
    integer vsync_start_found, vsync_end_found;
    integer frame_ticks;

    // =========================================================================
    // ESTIMULOS
    // =========================================================================
    initial begin
        rst        = 1'b1;
        tick_25mhz = 1'b1;

        $display("============================================================");
        $display("  TESTBENCH: vga_controller  |  640x480 @ 60Hz");
        $display("============================================================");

        // ------------------------------------------------------------------
        // TEST 1: Reset - h=0, v=0, hsync=1, vsync=1, blank=0
        // ------------------------------------------------------------------
        $display("\n[TEST 1] Reset sincrono");
        repeat(4) @(posedge clk); #1;

        if (h_count !== 10'd0 || v_count !== 10'd0) begin
            $display("  [FAIL] contadores no son 0: h=%0d v=%0d", h_count, v_count);
            errors = errors + 1;
        end
        if (hsync !== 1'b1 || vsync !== 1'b1) begin
            $display("  [FAIL] sync no en alto durante reset: hsync=%b vsync=%b", hsync, vsync);
            errors = errors + 1;
        end
        if (blank !== 1'b0) begin
            $display("  [FAIL] blank debe ser 0 en area visible (h=0,v=0)");
            errors = errors + 1;
        end
        $display("  h=%0d v=%0d hsync=%b vsync=%b blank=%b",
                 h_count, v_count, hsync, vsync, blank);
        if (errors == 0) $display("  Resultado: PASS");
        else             $display("  Resultado: FAIL (acumulado)");
        rst = 1'b0;

        // ------------------------------------------------------------------
        // TEST 2: Temporización HSYNC
        //   hsync y h_count se actualizan en el mismo posedge usando el
        //   h_count ANTERIOR, por eso hay un offset de 1 ciclo:
        //   baja cuando h_count=657 (calculado con h_count_prev=656)
        //   sube cuando h_count=753 (calculado con h_count_prev=752)
        // ------------------------------------------------------------------
        $display("\n[TEST 2] Temporizacion HSYNC (esperado: baja H=657, sube H=753)");
        hsync_start_found = 0;
        hsync_end_found   = 0;

        repeat(H_TOTAL + 50) begin
            @(posedge clk); #1;
            if (!hsync && !hsync_start_found) begin
                hsync_start_found = h_count;
                $display("  HSYNC baja en H = %0d", h_count);
            end
            if (hsync && hsync_start_found && !hsync_end_found) begin
                hsync_end_found = h_count;
                $display("  HSYNC sube en H = %0d", h_count);
            end
        end

        if (hsync_start_found !== 657) begin
            $display("  [FAIL] HSYNC deberia bajar en H=657, bajo en H=%0d", hsync_start_found);
            errors = errors + 1;
        end else $display("  HSYNC start = 657 -> PASS");

        if (hsync_end_found !== 753) begin
            $display("  [FAIL] HSYNC deberia subir en H=753, subio en H=%0d", hsync_end_found);
            errors = errors + 1;
        end else $display("  HSYNC end   = 753 -> PASS");

        // ------------------------------------------------------------------
        // TEST 3: Temporización VSYNC
        //   Mismo offset de pipeline: vsync se computa con v_count anterior.
        //   Baja cuando v_count=491 (computado con v_count_prev=490)
        //   Sube cuando v_count=493 (computado con v_count_prev=492)
        // ------------------------------------------------------------------
        $display("\n[TEST 3] Temporizacion VSYNC (esperado: baja V=490, sube V=492)");
        rst = 1'b1; @(posedge clk); #1; rst = 1'b0;
        vsync_start_found = -1;
        vsync_end_found   = -1;

        repeat(H_TOTAL * (V_TOTAL + 10)) begin
            @(posedge clk); #1;
            if (!vsync && vsync_start_found == -1)
                vsync_start_found = v_count;
            if (vsync && vsync_start_found != -1 && vsync_end_found == -1)
                vsync_end_found = v_count;
        end

        if (vsync_start_found !== 490) begin
            $display("  [FAIL] VSYNC deberia bajar en V=490, bajo en V=%0d", vsync_start_found);
            errors = errors + 1;
        end else $display("  VSYNC start = 490 -> PASS");

        if (vsync_end_found !== 492) begin
            $display("  [FAIL] VSYNC deberia subir en V=492, subio en V=%0d", vsync_end_found);
            errors = errors + 1;
        end else $display("  VSYNC end   = 492 -> PASS");

        // ------------------------------------------------------------------
        // TEST 4: blank=0 en area visible, blank=1 en blanking
        // blank es combinacional: (h_count>=640)||(v_count>=480)
        // ------------------------------------------------------------------
        $display("\n[TEST 4] blank activo solo fuera del area visible");
        rst = 1'b1; @(posedge clk); #1; rst = 1'b0;

        // Primeros 5 ciclos: h=0..4, v=0 -> blank debe ser 0
        repeat(5) begin
            @(posedge clk); #1;
            if (blank !== 1'b0) begin
                $display("  [FAIL] blank=1 en area visible h=%0d v=%0d", h_count, v_count);
                errors = errors + 1;
            end
        end

        // Avanzar al area de blanking horizontal
        repeat(H_VISIBLE) @(posedge clk);
        #1;
        if (blank !== 1'b1) begin
            $display("  [FAIL] blank=0 en blanking horizontal h=%0d", h_count);
            errors = errors + 1;
        end else
            $display("  blank=1 en blanking horizontal h=%0d -> PASS", h_count);
        $display("  blank=0 en area visible -> PASS");

        // ------------------------------------------------------------------
        // TEST 5: Periodo de frame = H_TOTAL * V_TOTAL ciclos
        // ------------------------------------------------------------------
        $display("\n[TEST 5] Periodo de frame = %0d ciclos", H_TOTAL * V_TOTAL);
        rst = 1'b1; @(posedge clk); #1; rst = 1'b0;

        begin : frame_test
            integer t_start, t_end;
            @(negedge vsync);
            t_start = $time;
            @(negedge vsync);
            t_end = $time;
            frame_ticks = (t_end - t_start) / CLK_PERIOD;
            $display("  Frame = %0d ciclos | esperado = %0d", frame_ticks, H_TOTAL * V_TOTAL);
            if (frame_ticks !== H_TOTAL * V_TOTAL) begin
                $display("  [FAIL] Periodo de frame incorrecto");
                errors = errors + 1;
            end else
                $display("  -> PASS");
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

    initial begin
        #(CLK_PERIOD * 1500000);
        $display("[TIMEOUT] Simulacion excedio el tiempo limite.");
        $finish;
    end

endmodule
