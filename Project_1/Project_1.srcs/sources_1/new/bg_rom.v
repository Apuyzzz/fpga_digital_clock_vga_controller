/**
 * @title ROM de fondo — Pixel art noche estrellada
 * @file bg_rom.v
 * @brief ROM BRAM sincrónica que almacena la imagen de fondo pixel art (160×120 px, escala 4×).
 * @details
 *   Cada píxel de la ROM corresponde a un bloque de 4×4 píxeles en pantalla (640×480).
 *   Direccionamiento: {v_count[8:2], h_count[9:2]} — extracción pura de bits, sin aritmética.
 *     - v_count[8:2] = fila  (0-119, 7 bits)
 *     - h_count[9:2] = columna (0-159, 8 bits)
 *     → dirección de 15 bits, ROM de 32768 entradas (256 cols × 128 filas)
 *
 *   Entradas fuera del área 160×120 contienen 12'h000 y nunca se acceden
 *   durante video activo (la señal blank las enmascara).
 *
 *   Latencia de lectura: 1 ciclo de reloj (registro de salida BRAM).
 *   El vram_writer compensa esta latencia mediante su pipeline interno de 1 ciclo.
 *
 * @author JustinAlfaro
 * @date 2026-05-08
 */

`timescale 1ns / 1ps

module bg_rom (
    input  wire        clk,      ///< Reloj del sistema (100 MHz)
    input  wire [9:0]  h_count,  ///< Coordenada horizontal del píxel [9:0]
    input  wire [9:0]  v_count,  ///< Coordenada vertical del píxel [9:0]
    output reg  [11:0] bg_color  ///< Color de fondo RGB 4-4-4; válido 1 ciclo después de h/v_count
);

    (* rom_style = "block" *) reg [11:0] mem [0:32767];

    initial $readmemh("/home/alpha/Documentos/Proyecto_1/fpga_digital_clock_vga_controller/Project_1/Project_1.srcs/sources_1/new/bg_image.mem", mem);

    always @(posedge clk)
        bg_color <= mem[{v_count[8:2], h_count[9:2]}];

endmodule
