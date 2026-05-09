// -----------------------------------------------------------------------------
// Module      : bram_dualport
// Description : True Dual-Port Block RAM inferred for Xilinx Artix-7.
//               Port A is read-only (VGA pixel fetch).
//               Port B is write-only (vram_writer pixel store).
//               Vivado infers this as RAMB36E1/RAMB18E1 primitives.
//               Capacity: 2^ADDR_WIDTH words of DATA_WIDTH bits each.
//               For 640x480: DATA_WIDTH=12, ADDR_WIDTH=19 (512K > 307200).
// Author      : JustinAlfaro
// Date        : 2026-04-21
// Parameters:
//   DATA_WIDTH - Bits per pixel (default 12 for 4-4-4 RGB)
//   ADDR_WIDTH - Address bits   (default 19 → 524288 locations)
// -----------------------------------------------------------------------------
// Port A (read):
//   clk_a   - Clock for port A
//   addr_a  - Read address [ADDR_WIDTH-1:0]
//   dout_a  - Read data output [DATA_WIDTH-1:0]
// Port B (write):
//   clk_b   - Clock for port B
//   addr_b  - Write address [ADDR_WIDTH-1:0]
//   din_b   - Write data input [DATA_WIDTH-1:0]
//   we_b    - Write enable
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

module bram_dualport #(
    parameter integer DATA_WIDTH = 12,
    parameter integer ADDR_WIDTH = 19,
    parameter integer DEPTH      = 307200  // exact 640x480 — avoids 2^19=524K over-allocation
)(
    // Port A — read
    input  wire                  clk_a,
    input  wire [ADDR_WIDTH-1:0] addr_a,
    output reg  [DATA_WIDTH-1:0] dout_a,

    // Port B — write
    input  wire                  clk_b,
    input  wire [ADDR_WIDTH-1:0] addr_b,
    input  wire [DATA_WIDTH-1:0] din_b,
    input  wire                  we_b
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
