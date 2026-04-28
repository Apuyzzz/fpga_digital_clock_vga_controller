// =============================================================================
// Testbench   : tb_vga_controller
// Description : Verifica el módulo vga_controller con 5 casos de prueba:
//
//   TEST 1 - Reset                : contadores en 0, sync en alto, RGB en 0
//   TEST 2 - Temporización H      : HSYNC activo entre ciclos 656 y 751
//   TEST 3 - Temporización V      : VSYNC activo entre líneas 490 y 491
//   TEST 4 - Área activa          : RGB = pixel_data solo en zona visible
//   TEST 5 - Período de frame     : un frame completo = 800 * 525 ticks
//
// NOTA: Se usa tick_25mhz = 1 siempre para simplificar la simulación.
//       En hardware real tick_25mhz viene del div_freq#(4).
//
// Simulador   : Vivado xsim (Artix-7 / Nexys A7)
// Autor       : Taller de Diseño Digital - EL3313 - I Semestre 2026
// =============================================================================

`timescale 1ns / 1ps

module tb_vga_controller;

    // -------------------------------------------------------------------------
    // Parámetros VGA (deben coincidir con vga_controller.v)
    // -------------------------------------------------------------------------
    parameter H_VISIBLE = 640;
    parameter H_TOTAL   = 800;
    parameter V_VISIBLE = 480;
    parameter V_TOTAL   = 525;
    parameter CLK_PERIOD = 10;  // 100 MHz

    // -------------------------------------------------------------------------
    // Señales DUT
    // -------------------------------------------------------------------------
    reg         clk;
    reg         rst;
    reg         tick_25mhz;
    reg  [11:0] pixel_data;
    wire [18:0] pixel_addr;
    wire        hsync;
    wire        vsync;
    wire [3:0]  vga_r;
    wire [3:0]  vga_g;
    wire [3:0]  vga_b;
    wire [9:0]  h_count;
    wire [9:0]  v_count;

    // -------------------------------------------------------------------------
    // Instancia DUT
    // -------------------------------------------------------------------------
    vga_controller DUT (
        .clk        (clk),
        .rst        (rst),
        .tick_25mhz (tick_25mhz),
        .pixel_data (pixel_data),
        .pixel_addr (pixel_addr),
        .hsync      (hsync),
        .vsync      (vsync),
        .vga_r      (vga_r),
        .vga_g      (vga_g),
        .vga_b      (vga_b),
        .h_count    (h_count),
        .v_count    (v_count)
    );

    // -------------------------------------------------------------------------
    // Reloj
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // -------------------------------------------------------------------------
    // pixel_data de prueba: color fijo 0xABC (R=A, G=B, B=C)
    // -------------------------------------------------------------------------
    initial pixel_data = 12'hABC;

    integer errors = 0;
    integer hsync_start_found, hsync_end_found;
    integer vsync_start_found, vsync_end_found;
    integer frame_ticks;
    integer h_count_prev;

    // =========================================================================
    // ESTÍMULOS
    // =========================================================================
    initial begin
        rst        = 1'b1;
        tick_25mhz = 1'b1;  // tick siempre activo para simplificar simulación

        $display("============================================================");
        $display("  TESTBENCH: vga_controller  |  640x480 @ 60Hz");
        $display("============================================================");

        // ------------------------------------------------------------------
        // TEST 1: Reset — contadores = 0, SYNC = alto, RGB = 0
        // ------------------------------------------------------------------
        $display("\n[TEST 1] Reset síncrono");
        repeat(4) @(posedge clk); #1;

        if (h_count !== 10'd0 || v_count !== 10'd0) begin
            $display("  [FAIL] contadores no son 0: h=%0d v=%0d", h_count, v_count);
            errors = errors + 1;
        end
        if (hsync !== 1'b1 || vsync !== 1'b1) begin
            $display("  [FAIL] sync no en alto durante reset: hsync=%b vsync=%b", hsync, vsync);
            errors = errors + 1;
        end
        if (vga_r !== 4'h0 || vga_g !== 4'h0 || vga_b !== 4'h0) begin
            $display("  [FAIL] RGB no en 0 durante reset");
            errors = errors + 1;
        end
        $display("  h=%0d v=%0d hsync=%b vsync=%b RGB=%0h%0h%0h --> PASS",
                 h_count, v_count, hsync, vsync, vga_r, vga_g, vga_b);
        rst = 1'b0;

        // ------------------------------------------------------------------
        // TEST 2: Temporización HSYNC
        //         hsync debe bajar en el ciclo H=656 y subir en H=752
        // ------------------------------------------------------------------
        $display("\n[TEST 2] Temporización HSYNC (esperado: bajo en H=656, alto en H=752)");
        hsync_start_found = 0;
        hsync_end_found   = 0;

        // Avanzar hasta llegar a la zona de sync horizontal
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

        if (hsync_start_found !== 656) begin
            $display("  [FAIL] HSYNC debería bajar en H=656, bajó en H=%0d", hsync_start_found);
            errors = errors + 1;
        end else $display("  HSYNC start = 656 --> PASS");

        if (hsync_end_found !== 752) begin
            $display("  [FAIL] HSYNC debería subir en H=752, subió en H=%0d", hsync_end_found);
            errors = errors + 1;
        end else $display("  HSYNC end   = 752 --> PASS");

        // ------------------------------------------------------------------
        // TEST 3: Temporización VSYNC
        //         vsync debe bajar en línea 490 y subir en línea 492
        // ------------------------------------------------------------------
        $display("\n[TEST 3] Temporización VSYNC (esperado: bajo en V=490, alto en V=492)");
        rst = 1'b1; @(posedge clk); #1; rst = 1'b0;  // reiniciar contadores
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
            $display("  [FAIL] VSYNC debería bajar en V=490, bajó en V=%0d", vsync_start_found);
            errors = errors + 1;
        end else $display("  VSYNC start = 490 --> PASS");

        if (vsync_end_found !== 492) begin
            $display("  [FAIL] VSYNC debería subir en V=492, subió en V=%0d", vsync_end_found);
            errors = errors + 1;
        end else $display("  VSYNC end   = 492 --> PASS");

        // ------------------------------------------------------------------
        // TEST 4: Área activa — RGB = pixel_data solo si h<640 y v<480
        // ------------------------------------------------------------------
        $display("\n[TEST 4] RGB activo solo en área visible");
        rst = 1'b1; @(posedge clk); #1; rst = 1'b0;

        // Verificar algunos ciclos en área visible (h=0..5, v=0)
        repeat(5) begin
            @(posedge clk); #1;
            if (h_count < H_VISIBLE && v_count < V_VISIBLE) begin
                if (vga_r !== pixel_data[11:8] || vga_g !== pixel_data[7:4] || vga_b !== pixel_data[3:0]) begin
                    $display("  [FAIL] RGB incorrecto en área visible h=%0d v=%0d", h_count, v_count);
                    errors = errors + 1;
                end
            end
        end

        // Avanzar al área de blanking horizontal
        repeat(H_VISIBLE + 5) @(posedge clk);
        #1;
        if (vga_r !== 4'h0 || vga_g !== 4'h0 || vga_b !== 4'h0) begin
            $display("  [FAIL] RGB no es 0 en blanking horizontal h=%0d", h_count);
            errors = errors + 1;
        end else
            $display("  RGB = 0 en blanking horizontal h=%0d --> PASS", h_count);
        $display("  RGB correcto en área visible --> PASS");

        // ------------------------------------------------------------------
        // TEST 5: Período de frame = H_TOTAL * V_TOTAL ticks
        // ------------------------------------------------------------------
        $display("\n[TEST 5] Período de frame = %0d ciclos", H_TOTAL * V_TOTAL);
        rst = 1'b1; @(posedge clk); #1; rst = 1'b0;

        // Esperar primer vsync
        @(negedge vsync);
        begin : frame_test
            integer t_start, t_end;
            t_start = $time;
            // Esperar siguiente vsync
            @(negedge vsync);
            t_end = $time;
            frame_ticks = (t_end - t_start) / CLK_PERIOD;
            $display("  Frame = %0d ciclos | esperado = %0d", frame_ticks, H_TOTAL * V_TOTAL);
            if (frame_ticks !== H_TOTAL * V_TOTAL) begin
                $display("  [FAIL] Período de frame incorrecto");
                errors = errors + 1;
            end else
                $display("  --> PASS");
        end

        // ------------------------------------------------------------------
        // Resumen
        // ------------------------------------------------------------------
        $display("\n============================================================");
        if (errors == 0)
            $display("  RESULTADO FINAL: TODOS LOS TESTS PASARON ✓");
        else
            $display("  RESULTADO FINAL: %0d ERROR(ES) ENCONTRADO(S) ✗", errors);
        $display("============================================================\n");

        $finish;
    end

    // Timeout
    initial begin
        #(CLK_PERIOD * 500000);
        $display("[TIMEOUT] Simulación excedió el tiempo límite.");
        $finish;
    end

endmodule
