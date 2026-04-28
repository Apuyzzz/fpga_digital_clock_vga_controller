// =============================================================================
// Module      : vga_controller
// Description : Generador de señales VGA 640x480 @ 60 Hz.
//               Produce contadores H/V, señales HSYNC/VSYNC y video_active.
//               Lee píxeles de la BRAM (Puerto A) usando pixel_addr.
//
// Temporización estándar 640x480 @ 60 Hz (pixel clock 25.175 MHz ≈ 25 MHz):
//   Horizontal : 640 visible | 16 front porch | 96 sync | 48 back porch = 800 total
//   Vertical   : 480 visible | 10 front porch |  2 sync | 33 back porch = 525 total
//
// Inputs  :
//   clk         - Reloj del sistema 100 MHz
//   rst         - Reset síncrono, activo alto
//   tick_25mhz  - Pulso tick del div_freq#(4), habilita avance de contadores
//   pixel_data  - Dato RGB 12-bit leído de la BRAM (Puerto A)
//
// Outputs :
//   hsync       - Señal HSYNC (activo bajo)
//   vsync       - Señal VSYNC (activo bajo)
//   vga_r       - Canal rojo   4 bits
//   vga_g       - Canal verde  4 bits
//   vga_b       - Canal azul   4 bits
//   pixel_addr  - Dirección de pixel en BRAM: y*640 + x
//   h_count     - Contador horizontal (para vram_writer)
//   v_count     - Contador vertical   (para vram_writer)
//
// Author      : Taller de Diseño Digital - EL3313 - I Semestre 2026
// =============================================================================

module vga_controller (
    input  wire        clk,
    input  wire        rst,
    input  wire        tick_25mhz,      // pixel clock enable

    // Interfaz BRAM (Puerto A - lectura)
    input  wire [11:0] pixel_data,      // RGB 4-4-4 leído de BRAM
    output reg  [18:0] pixel_addr,      // dirección: máx 640*480-1 = 307199

    // Señales VGA
    output reg         hsync,
    output reg         vsync,
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b,

    // Contadores expuestos (para vram_writer)
    output wire [9:0]  h_count,
    output wire [9:0]  v_count
);

    // -------------------------------------------------------------------------
    // Parámetros de temporización VGA 640x480 @ 60 Hz
    // -------------------------------------------------------------------------
    localparam H_VISIBLE    = 640;
    localparam H_FRONT      = 16;
    localparam H_SYNC_W     = 96;
    localparam H_BACK       = 48;
    localparam H_TOTAL      = H_VISIBLE + H_FRONT + H_SYNC_W + H_BACK; // 800

    localparam V_VISIBLE    = 480;
    localparam V_FRONT      = 10;
    localparam V_SYNC_W     = 2;
    localparam V_BACK       = 33;
    localparam V_TOTAL      = V_VISIBLE + V_FRONT + V_SYNC_W + V_BACK; // 525

    localparam H_SYNC_START = H_VISIBLE + H_FRONT;         // 656
    localparam H_SYNC_END   = H_SYNC_START + H_SYNC_W;     // 752
    localparam V_SYNC_START = V_VISIBLE + V_FRONT;         // 490
    localparam V_SYNC_END   = V_SYNC_START + V_SYNC_W;     // 492

    // -------------------------------------------------------------------------
    // Contadores H y V
    // -------------------------------------------------------------------------
    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    assign h_count = h_cnt;
    assign v_count = v_cnt;

    // -------------------------------------------------------------------------
    // Señal de área visible
    // -------------------------------------------------------------------------
    wire video_active = (h_cnt < H_VISIBLE) && (v_cnt < V_VISIBLE);

    // -------------------------------------------------------------------------
    // Lógica secuencial de contadores
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            h_cnt <= 10'd0;
            v_cnt <= 10'd0;
        end else if (tick_25mhz) begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= 10'd0;
                if (v_cnt == V_TOTAL - 1)
                    v_cnt <= 10'd0;
                else
                    v_cnt <= v_cnt + 1'b1;
            end else begin
                h_cnt <= h_cnt + 1'b1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Generación de HSYNC y VSYNC (activos bajos)
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            hsync <= 1'b1;
            vsync <= 1'b1;
        end else if (tick_25mhz) begin
            hsync <= ~((h_cnt >= H_SYNC_START) && (h_cnt < H_SYNC_END));
            vsync <= ~((v_cnt >= V_SYNC_START) && (v_cnt < V_SYNC_END));
        end
    end

    // -------------------------------------------------------------------------
    // Dirección BRAM y salida RGB
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            pixel_addr <= 19'd0;
            vga_r      <= 4'h0;
            vga_g      <= 4'h0;
            vga_b      <= 4'h0;
        end else if (tick_25mhz) begin
            if (video_active) begin
                pixel_addr <= v_cnt * H_VISIBLE + h_cnt;
                vga_r      <= pixel_data[11:8];
                vga_g      <= pixel_data[7:4];
                vga_b      <= pixel_data[3:0];
            end else begin
                pixel_addr <= 19'd0;
                vga_r      <= 4'h0;
                vga_g      <= 4'h0;
                vga_b      <= 4'h0;
            end
        end
    end

endmodule
