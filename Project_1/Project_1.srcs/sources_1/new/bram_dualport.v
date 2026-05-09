/**
 * @title BRAM de doble puerto (VRAM)
 * @file bram_dualport.v
 * @brief Memoria de video (VRAM) de doble puerto inferida como BRAM en Xilinx Artix-7.
 * @details
 *   Puerto A: solo lectura (controlador VGA fetch de píxeles).
 *   Puerto B: solo escritura (vram_writer actualiza el frame).
 *   Vivado infiere primitivas RAMB36E1/RAMB18E1.
 *   DEPTH=307200 (exactamente 640×480) evita la sobre-asignación de 2^19=524K
 *   entradas que causaba el DRC UTLZ-1 al exceder los 4.86 Mbit disponibles.
 *
 * @author JustinAlfaro
 * @date 2026-04-21
 */

`timescale 1ns / 1ps

module bram_dualport #(
    parameter integer DATA_WIDTH = 12,    ///< Bits por píxel (12 para RGB 4-4-4)
    parameter integer ADDR_WIDTH = 19,    ///< Bits de dirección (19 bits cubre hasta 524K)
    parameter integer DEPTH      = 307200 ///< Profundidad real: 640×480 píxeles
)(
    input  wire                  clk_a,  ///< Reloj del puerto A (lectura VGA)
    input  wire [ADDR_WIDTH-1:0] addr_a, ///< Dirección de lectura
    output reg  [DATA_WIDTH-1:0] dout_a, ///< Dato leído (píxel RGB)

    input  wire                  clk_b,  ///< Reloj del puerto B (escritura vram_writer)
    input  wire [ADDR_WIDTH-1:0] addr_b, ///< Dirección de escritura
    input  wire [DATA_WIDTH-1:0] din_b,  ///< Dato a escribir (píxel RGB)
    input  wire                  we_b    ///< Habilitación de escritura
);

    // RAM array — Vivado infers BRAM when (* ram_style = "block" *) is set
    (* ram_style = "block" *)
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Initialize VRAM to black at bitstream load time
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = {DATA_WIDTH{1'b0}};
    end

    // Port A: synchronous read
    always @(posedge clk_a) begin
        dout_a <= mem[addr_a];
    end

    // Port B: synchronous write
    always @(posedge clk_b) begin
        if (we_b)
            mem[addr_b] <= din_b;
    end

endmodule
