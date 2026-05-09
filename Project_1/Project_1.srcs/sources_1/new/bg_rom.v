// -----------------------------------------------------------------------------
// Module      : bg_rom
// Description : Synchronous BRAM ROM storing the 160x120 pixel-art night-sky
//               background image in RGB 4-4-4 (12-bit) format.
//
//   Scale : 4x (each ROM pixel maps to a 4x4 block on the 640x480 display)
//   Address: {v_count[8:2], h_count[9:2]}  — pure bit extraction, no maths
//             v_count[8:2] = row  (0-119, 7 bits)
//             h_count[9:2] = col  (0-159, 8 bits)
//             → 15-bit address, 32768-entry ROM (256 cols × 128 rows)
//
//   Entries outside the 160x120 image area (col>=160 or row>=120) are 12'h000
//   and are never accessed during active video (blank signal masks those pixels).
//
//   Read latency : 1 clock cycle (BRAM synchronous output register).
//   top_vga delays text_renderer outputs by the same 1 cycle so all pixel
//   data stays aligned with the VGA sync signals.
//
// Author      : JustinAlfaro
// Date        : 2026-05-08
// -----------------------------------------------------------------------------
// Ports:
//   clk      - 100 MHz system clock
//   h_count  - Horizontal pixel coordinate [9:0] (from vga_controller)
//   v_count  - Vertical pixel coordinate [9:0]   (from vga_controller)
//   bg_color - Output background color [11:0] = {R[3:0], G[3:0], B[3:0]}
//              Valid 1 clock cycle after h_count/v_count change.
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

module bg_rom (
    input  wire        clk,
    input  wire [9:0]  h_count,
    input  wire [9:0]  v_count,
    output reg  [11:0] bg_color
);

    (* rom_style = "block" *) reg [11:0] mem [0:32767];

    initial $readmemh("/home/alpha/Documentos/Proyecto_1/fpga_digital_clock_vga_controller/Project_1/Project_1.srcs/sources_1/new/bg_image.mem", mem);

    always @(posedge clk)
        bg_color <= mem[{v_count[8:2], h_count[9:2]}];

endmodule
