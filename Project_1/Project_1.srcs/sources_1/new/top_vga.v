// -----------------------------------------------------------------------------
// Module      : top_vga
// Description : Root integration module for the FPGA Digital Clock VGA
//               Controller on Nexys A7-100T. Single 100 MHz clock domain with
//               pixel-clock and 1 Hz clock-enables (no CDC required).
//               VGA timing: 640x480 @ 60 Hz (25 MHz pixel clock enable).
//
//               bg_rom (BRAM ROM, 160x120 pixel-art, 4x scaled) provides the
//               background with 1-cycle latency; text_renderer outputs are
//               registered by the same 1 cycle. All signals align with the
//               1-cycle-delayed sync signals from the VGA controller.
//
//   Controls:
//     BTNC  — cycle adjust mode: RUN → ADJ_HOUR → ADJ_MIN → RUN
//     BTNU  — increment selected field
//     BTND  — decrement selected field
//     BTNR  — accept (btn_ajuste): confirm changes and return to RUN
//     SW[0] — 12h/24h display mode (0=24h, 1=12h)
//
//   Blink (no blink module): blink_phase toggles every tick_1hz.  When a
//   field is being adjusted the text_renderer substitutes its BCD digits with
//   4'hF (absent from font ROM → font_row=0 → invisible). Button press resets
//   blink_phase to 0 so the digit is immediately visible after adjustment.
//
// Author      : JustinAlfaro
// Date        : 2026-04-22
// -----------------------------------------------------------------------------
// Board: Nexys A7-100T (xc7a100tcsg324-1)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

module top_vga (
    // Clock & Reset
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,   // Active-low board reset

    // Buttons (active-high after debounce)
    input  wire        BTNC,         // Mode cycle
    input  wire        BTNU,         // Increment
    input  wire        BTND,         // Decrement
    input  wire        BTNR,         // Accept / confirm (btn_ajuste)

    // Switches
    input  wire [15:0] SW,

    // VGA
    output wire        VGA_HS,
    output wire        VGA_VS,
    output wire [3:0]  VGA_R,
    output wire [3:0]  VGA_G,
    output wire [3:0]  VGA_B,

    // LEDs (mode indicator on LD[1:0])
    output wire [15:0] LED
);

    // ---- Internal reset (active-high) ----------------------------------------
    wire rst = ~CPU_RESETN;

    // =========================================================================
    // 1. Clock enables
    // =========================================================================

    wire tick_25mhz;
    div_freq #(.DIVISOR(4)) u_clk_25 (
        .clk_in  (CLK100MHZ),
        .rst     (rst),
        .clk_out (tick_25mhz)
    );

    wire tick_1hz;
    div_freq #(.DIVISOR(100_000_000)) u_clk_1hz (
        .clk_in  (CLK100MHZ),
        .rst     (rst),
        .clk_out (tick_1hz)
    );

    // =========================================================================
    // 2. Input conditioning
    // =========================================================================

    wire btn_mode_db, btn_up_db, btn_down_db, btn_ajuste_db;

    debounce #(.DEBOUNCE_MS(20), .CLK_FREQ_HZ(100_000_000)) u_db_mode (
        .clk(CLK100MHZ), .rst(rst), .btn_in(BTNC), .btn_out(btn_mode_db));

    debounce #(.DEBOUNCE_MS(20), .CLK_FREQ_HZ(100_000_000)) u_db_up (
        .clk(CLK100MHZ), .rst(rst), .btn_in(BTNU), .btn_out(btn_up_db));

    debounce #(.DEBOUNCE_MS(20), .CLK_FREQ_HZ(100_000_000)) u_db_down (
        .clk(CLK100MHZ), .rst(rst), .btn_in(BTND), .btn_out(btn_down_db));

    debounce #(.DEBOUNCE_MS(20), .CLK_FREQ_HZ(100_000_000)) u_db_ajuste (
        .clk(CLK100MHZ), .rst(rst), .btn_in(BTNR), .btn_out(btn_ajuste_db));

    wire [15:0] sw_sync;
    sync_signal #(.WIDTH(16)) u_sw_sync (
        .clk(CLK100MHZ), .rst(rst), .async_in(SW), .sync_out(sw_sync));

    wire mode_12h = sw_sync[0]; // SW[0]: 0=24h, 1=12h

    // =========================================================================
    // 3. Blink phase (no separate blink module)
    // Toggles every second. Any button press resets to 0 (digit immediately
    // visible) so the user gets instant visual feedback on adjustments.
    // =========================================================================

    wire any_btn = btn_mode_db | btn_up_db | btn_down_db | btn_ajuste_db;

    reg blink_phase;
    always @(posedge CLK100MHZ) begin
        if (rst || any_btn)
            blink_phase <= 1'b0;
        else if (tick_1hz)
            blink_phase <= ~blink_phase;
    end

    // =========================================================================
    // 4. FSM adjust mode
    // =========================================================================

    wire        adj_hour, adj_min, sec_en;
    wire        hour_inc, hour_dec, min_inc, min_dec, sec_rst;
    wire [1:0]  mode_leds;

    fsm_adjust_mode u_fsm (
        .clk       (CLK100MHZ),
        .rst       (rst),
        .btn_mode  (btn_mode_db),
        .btn_up    (btn_up_db),
        .btn_down  (btn_down_db),
        .btn_ajuste(btn_ajuste_db),
        .adj_hour  (adj_hour),
        .adj_min   (adj_min),
        .sec_en    (sec_en),
        .hour_inc  (hour_inc),
        .hour_dec  (hour_dec),
        .min_inc   (min_inc),
        .min_dec   (min_dec),
        .sec_rst   (sec_rst),
        .mode_leds (mode_leds)
    );

    // =========================================================================
    // 5. BCD counters (seconds always run in RUN state)
    // =========================================================================

    wire [5:0] seconds, minutes, hours;
    wire       sec_carry, min_carry;

    wire sec_clk_en = tick_1hz & sec_en;

    bcd_counter #(.MAX_VAL(59)) u_sec (
        .clk(CLK100MHZ), .rst(rst | sec_rst), .clk_en(sec_clk_en),
        .inc(1'b0), .dec(1'b0), .count(seconds), .carry_out(sec_carry));

    bcd_counter #(.MAX_VAL(59)) u_min (
        .clk(CLK100MHZ), .rst(rst), .clk_en(sec_carry),
        .inc(min_inc), .dec(min_dec), .count(minutes), .carry_out(min_carry));

    bcd_counter #(.MAX_VAL(23)) u_hour (
        .clk(CLK100MHZ), .rst(rst), .clk_en(min_carry),
        .inc(hour_inc), .dec(hour_dec), .count(hours), .carry_out(/* unused */));

    // =========================================================================
    // 6. Binary → BCD conversion
    // =========================================================================

    wire [3:0] sec_tens,  sec_ones;
    wire [3:0] min_tens,  min_ones;
    wire [3:0] hour_tens, hour_ones;

    binary_bcd_decoder #(.N(6)) u_bcd_sec (
        .bin(seconds), .bcd_tens(sec_tens), .bcd_ones(sec_ones));

    binary_bcd_decoder #(.N(6)) u_bcd_min (
        .bin(minutes), .bcd_tens(min_tens), .bcd_ones(min_ones));

    binary_bcd_decoder #(.N(5)) u_bcd_hour (
        .bin(hours[4:0]), .bcd_tens(hour_tens), .bcd_ones(hour_ones));

    // =========================================================================
    // 7. 12-hour conversion
    // =========================================================================

    wire [3:0] h12_tens, h12_ones;
    wire       is_pm;

    hour_converter u_hconv (
        .hours_24(hours),
        .h12_tens(h12_tens),
        .h12_ones(h12_ones),
        .is_pm   (is_pm)
    );

    // Select 24h or 12h hour digits using generic mux2
    wire [3:0] disp_hour_tens, disp_hour_ones;

    mux2 #(.WIDTH(4)) u_mux_htens (
        .d0(hour_tens), .d1(h12_tens), .sel(mode_12h), .y(disp_hour_tens));

    mux2 #(.WIDTH(4)) u_mux_hones (
        .d0(hour_ones), .d1(h12_ones), .sel(mode_12h), .y(disp_hour_ones));

    // =========================================================================
    // 8. VGA controller
    // =========================================================================

    wire [9:0] h_count, v_count;
    wire       hsync_raw, vsync_raw, blank_raw;

    vga_controller u_vga (
        .clk       (CLK100MHZ),
        .rst       (rst),
        .tick_25mhz(tick_25mhz),
        .hsync     (hsync_raw),
        .vsync     (vsync_raw),
        .blank     (blank_raw),
        .h_count   (h_count),
        .v_count   (v_count)
    );

    // 1-cycle delay on sync signals to align with the registered pixel pipeline
    reg hsync_d, vsync_d, blank_d;
    always @(posedge CLK100MHZ) begin
        hsync_d <= hsync_raw;
        vsync_d <= vsync_raw;
        blank_d <= blank_raw;
    end

    assign VGA_HS = hsync_d;
    assign VGA_VS = vsync_d;

    // =========================================================================
    // 9. Background ROM + Text renderer
    //
    //    bg_rom is a synchronous BRAM ROM (1-cycle read latency).
    //    text_renderer is combinational; its outputs are registered 1 cycle
    //    to match the ROM latency. bg_color, pixel_on_d, text_color_d and
    //    blank_d/hsync_d/vsync_d are all 1-cycle delayed → aligned.
    // =========================================================================

    wire [11:0] bg_color;
    wire        pixel_on;
    wire [11:0] text_color_w;

    bg_rom u_bg (
        .clk    (CLK100MHZ),
        .h_count(h_count),
        .v_count(v_count),
        .bg_color(bg_color)
    );

    text_renderer u_text (
        .h_count   (h_count),
        .v_count   (v_count),
        .hour_tens (disp_hour_tens),
        .hour_ones (disp_hour_ones),
        .min_tens  (min_tens),
        .min_ones  (min_ones),
        .sec_tens  (sec_tens),
        .sec_ones  (sec_ones),
        .adj_hour  (adj_hour),
        .adj_min   (adj_min),
        .blink_phase(blink_phase),
        .mode_12h  (mode_12h),
        .is_pm     (is_pm),
        .pixel_on  (pixel_on),
        .text_color(text_color_w)
    );

    // Delay text outputs 1 cycle to match bg_rom synchronous read latency
    reg        pixel_on_d;
    reg [11:0] text_color_d;
    always @(posedge CLK100MHZ) begin
        pixel_on_d   <= pixel_on;
        text_color_d <= text_color_w;
    end

    wire [11:0] pixel_reg = pixel_on_d ? text_color_d : bg_color;

    // =========================================================================
    // 10. Pixel output mux
    // =========================================================================

    pixel_mux u_pmux (
        .blank     (blank_d),
        .pixel_data(pixel_reg),
        .vga_r     (VGA_R),
        .vga_g     (VGA_G),
        .vga_b     (VGA_B)
    );

    // =========================================================================
    // 11. LED indicators
    // =========================================================================

    assign LED[1:0]  = mode_leds;        // 00=RUN, 01=ADJ_HOUR, 10=ADJ_MIN
    assign LED[2]    = 1'b0;             // unused (was VRAM redraw indicator)
    assign LED[3]    = mode_12h;         // 12h mode active
    assign LED[4]    = is_pm;            // PM indicator
    assign LED[15:5] = sw_sync[15:5];   // mirror unused switches

endmodule
