// -----------------------------------------------------------------------------
// Module      : vram_writer
// Description : Sequential FSM that redraws the entire 640x480 VRAM once per
//               redraw request. Runs at 100 MHz; a full frame takes 307 200
//               cycles (~3.07 ms, well within the 1-second update window).
//
//               bg_color comes from bg_rom (synchronous, 1-cycle latency from
//               h_wr/v_wr). A 1-cycle internal pipeline compensates: Stage 1
//               latches the pixel's address and text data while bg_rom reads;
//               Stage 2 commits to BRAM once bg_color is valid.
//
// Author      : JustinAlfaro
// Date        : 2026-04-21
// -----------------------------------------------------------------------------
// Ports:
//   clk          - 100 MHz system clock
//   rst          - Synchronous active-high reset
//   redraw_req   - Pulse: triggers a full-frame redraw
//   h_wr         - Current write column [9:0] → bg_rom + text_renderer
//   v_wr         - Current write row    [9:0] → bg_rom + text_renderer
//   bg_color     - 12-bit background from bg_rom (valid 1 cycle after h_wr/v_wr)
//   pixel_on     - 1 if current pixel is a character foreground (combinational)
//   text_color   - 12-bit text color from text_renderer (combinational)
//   bram_addr    - Write address to BRAM port B [18:0]
//   bram_din     - Write data to BRAM port B [11:0]
//   bram_we      - Write enable for BRAM port B
//   drawing      - High while a redraw is in progress
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

module vram_writer (
    input  wire        clk,
    input  wire        rst,
    input  wire        redraw_req,

    output reg  [9:0]  h_wr,
    output reg  [9:0]  v_wr,

    input  wire [11:0] bg_color,
    input  wire        pixel_on,
    input  wire [11:0] text_color,

    output reg  [18:0] bram_addr,
    output reg  [11:0] bram_din,
    output reg         bram_we,

    output reg         drawing
);

    localparam [1:0] IDLE = 2'd0, DRAW = 2'd1, DONE = 2'd2;
    localparam H_MAX = 10'd639, V_MAX = 10'd479;

    reg [1:0]  state;
    reg [18:0] px_addr;

    // Stage 1 pipeline registers: latch while bg_rom performs its read
    reg [18:0] addr_pipe;
    reg        we_pipe;
    reg        on_pipe;
    reg [11:0] tcolor_pipe;

    // Stage 2: commit to BRAM — bg_color is now valid for the latched pixel
    always @(posedge clk) begin
        if (rst) begin
            bram_addr <= 19'd0;
            bram_din  <= 12'd0;
            bram_we   <= 1'b0;
        end else begin
            bram_addr <= addr_pipe;
            bram_din  <= on_pipe ? tcolor_pipe : bg_color;
            bram_we   <= we_pipe;
        end
    end

    // FSM + Stage 1
    always @(posedge clk) begin
        if (rst) begin
            state       <= IDLE;
            h_wr        <= 10'd0;
            v_wr        <= 10'd0;
            px_addr     <= 19'd0;
            drawing     <= 1'b0;
            addr_pipe   <= 19'd0;
            we_pipe     <= 1'b0;
            on_pipe     <= 1'b0;
            tcolor_pipe <= 12'd0;
        end else begin
            addr_pipe <= 19'd0;
            we_pipe   <= 1'b0;

            case (state)
                IDLE: begin
                    drawing <= 1'b0;
                    if (redraw_req) begin
                        h_wr    <= 10'd0;
                        v_wr    <= 10'd0;
                        px_addr <= 19'd0;
                        state   <= DRAW;
                        drawing <= 1'b1;
                    end
                end

                DRAW: begin
                    drawing     <= 1'b1;
                    // Stage 1: latch pixel data while bg_rom reads (h_wr, v_wr)
                    addr_pipe   <= px_addr;
                    we_pipe     <= 1'b1;
                    on_pipe     <= pixel_on;
                    tcolor_pipe <= text_color;

                    if (h_wr == H_MAX) begin
                        h_wr <= 10'd0;
                        if (v_wr == V_MAX)
                            state <= DONE;
                        else
                            v_wr <= v_wr + 10'd1;
                    end else
                        h_wr <= h_wr + 10'd1;

                    if (px_addr == 19'd307199)
                        px_addr <= 19'd0;
                    else
                        px_addr <= px_addr + 19'd1;
                end

                DONE: begin
                    drawing <= 1'b0;
                    if (redraw_req) begin
                        h_wr    <= 10'd0;
                        v_wr    <= 10'd0;
                        px_addr <= 19'd0;
                        state   <= DRAW;
                        drawing <= 1'b1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
