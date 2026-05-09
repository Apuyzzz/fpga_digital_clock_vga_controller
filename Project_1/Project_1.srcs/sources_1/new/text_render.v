/**
 * @title Renderizador de texto del reloj
 * @file text_render.v
 * @brief Renderer combinacional de píxeles para el display del reloj digital.
 * @details
 *   Layout (escala=4; cada carácter = 32×64 px en pantalla):
 *     Modo 24h: 8 chars "HH:MM:SS"        → H_START=192, H_END=448 (centrado)
 *     Modo 12h: 11 chars "HH:MM:SS AM/PM" → H_START=144, H_END=496 (centrado)
 *
 *   Parpadeo sin módulo dedicado: cuando adj_hour|adj_min y blink_phase=1,
 *   el char_idx del campo seleccionado se fuerza a 4'hF (ausente en la ROM de
 *   fuente → font_row=0 → pixel_on=0 → dígito invisible). El vram_writer
 *   redibuja cada tick_1hz; blink_phase también alterna cada tick_1hz, logrando
 *   parpadeo a 0.5 Hz sin contador adicional.
 *
 *   Glyphs AM/PM: índice 0xB='A', 0xC='P', 0xD='M'.
 *   Fuente: pixel-art bold 8×16 bitmap (escala 4 → 32×64 en pantalla).
 *
 * @author JustinAlfaro
 * @date 2026-04-22
 */

`timescale 1ns / 1ps

module text_renderer (
    input  wire [9:0]  h_count,     ///< Coordenada horizontal del píxel [9:0]
    input  wire [9:0]  v_count,     ///< Coordenada vertical del píxel [9:0]
    input  wire [3:0]  hour_tens,   ///< Decenas de hora pre-muxeadas (24h o 12h) [BCD]
    input  wire [3:0]  hour_ones,   ///< Unidades de hora pre-muxeadas [BCD]
    input  wire [3:0]  min_tens,    ///< Decenas de minutos [BCD]
    input  wire [3:0]  min_ones,    ///< Unidades de minutos [BCD]
    input  wire [3:0]  sec_tens,    ///< Decenas de segundos [BCD]
    input  wire [3:0]  sec_ones,    ///< Unidades de segundos [BCD]
    input  wire        adj_hour,    ///< Alto en estado ADJ_HOUR (activa parpadeo de horas)
    input  wire        adj_min,     ///< Alto en estado ADJ_MIN (activa parpadeo de minutos)
    input  wire        blink_phase, ///< Fase de parpadeo: 1=campo seleccionado invisible
    input  wire        mode_12h,    ///< 1=display en formato 12h con sufijo AM/PM
    input  wire        is_pm,       ///< 1=PM; selecciona glyph 'P' vs 'A' en modo 12h
    output reg         pixel_on,    ///< 1 si el píxel actual es foreground de texto
    output reg  [11:0] text_color   ///< Color RGB 4-4-4 para píxel de texto
);

    // ---- Vertical region (constant for both modes) ---------------------------
    localparam V_START = 10'd208;   // (480 - 64) / 2
    localparam V_END   = 10'd272;

    // ---- Horizontal region (mode-dependent) ----------------------------------
    // 24-h: 8 chars × 32 px = 256 px  → center at (640-256)/2 = 192
    // 12-h: 11 chars × 32 px = 352 px → center at (640-352)/2 = 144
    wire [9:0] h_start = mode_12h ? 10'd144 : 10'd192;
    wire [9:0] h_end   = mode_12h ? 10'd496 : 10'd448;

    // ---- Relative coordinates ------------------------------------------------
    wire [9:0] rel_x = h_count - h_start;
    wire [9:0] rel_y = v_count - V_START;

    // char_num = rel_x / 32 = rel_x[8:5]  (4 bits, 0-10 within visible range)
    wire [3:0] char_num  = rel_x[8:5];
    wire [2:0] pixel_col = rel_x[4:2];   // column within glyph (0-7 at scale 4)
    wire [3:0] pixel_row = rel_y[5:2];   // row within glyph   (0-15 at scale 4)

    wire in_region = (h_count >= h_start) && (h_count < h_end) &&
                     (v_count >= V_START)  && (v_count < V_END);

    // ---- Character index selection -------------------------------------------
    // Blink: substitute selected-field digits with 4'hF (no ROM entry → blank)
    wire hour_blank = adj_hour & blink_phase;
    wire min_blank  = adj_min  & blink_phase;

    reg [3:0] char_idx;
    always @(*) begin
        case (char_num)
            4'd0:  char_idx = hour_blank ? 4'hF : hour_tens;
            4'd1:  char_idx = hour_blank ? 4'hF : hour_ones;
            4'd2:  char_idx = 4'hA;  // ':'
            4'd3:  char_idx = min_blank  ? 4'hF : min_tens;
            4'd4:  char_idx = min_blank  ? 4'hF : min_ones;
            4'd5:  char_idx = 4'hA;  // ':'
            4'd6:  char_idx = sec_tens;
            4'd7:  char_idx = sec_ones;
            4'd8:  char_idx = 4'hF;  // blank space before AM/PM
            4'd9:  char_idx = mode_12h ? (is_pm ? 4'hC : 4'hB) : 4'hF;
            4'd10: char_idx = mode_12h ? 4'hD : 4'hF;
            default: char_idx = 4'hF;
        endcase
    end

    // ---- Pixel-art font ROM (8×16, combinational case) -----------------------
    // Glyphs: 0-9 (digits), 0xA (':'), 0xB ('A'), 0xC ('P'), 0xD ('M')
    // Any other index (including 0xF = blank) falls to default → 8'h00
    reg [7:0] font_row;
    always @(*) begin
        case ({char_idx, pixel_row})
            // ---- '0' --------------------------------------------------------
            8'h00: font_row = 8'h7E; 8'h01: font_row = 8'hC3;
            8'h02: font_row = 8'hC3; 8'h03: font_row = 8'hC3;
            8'h04: font_row = 8'hC3; 8'h05: font_row = 8'hC3;
            8'h06: font_row = 8'hC3; 8'h07: font_row = 8'hC3;
            8'h08: font_row = 8'hC3; 8'h09: font_row = 8'hC3;
            8'h0A: font_row = 8'hC3; 8'h0B: font_row = 8'hC3;
            8'h0C: font_row = 8'hC3; 8'h0D: font_row = 8'hC3;
            8'h0E: font_row = 8'hC3; 8'h0F: font_row = 8'h7E;
            // ---- '1' --------------------------------------------------------
            8'h10: font_row = 8'h18; 8'h11: font_row = 8'h38;
            8'h12: font_row = 8'h78; 8'h13: font_row = 8'hD8;
            8'h14: font_row = 8'h18; 8'h15: font_row = 8'h18;
            8'h16: font_row = 8'h18; 8'h17: font_row = 8'h18;
            8'h18: font_row = 8'h18; 8'h19: font_row = 8'h18;
            8'h1A: font_row = 8'h18; 8'h1B: font_row = 8'h18;
            8'h1C: font_row = 8'h18; 8'h1D: font_row = 8'h18;
            8'h1E: font_row = 8'h18; 8'h1F: font_row = 8'h7E;
            // ---- '2' --------------------------------------------------------
            8'h20: font_row = 8'h7E; 8'h21: font_row = 8'hC3;
            8'h22: font_row = 8'hC3; 8'h23: font_row = 8'h03;
            8'h24: font_row = 8'h03; 8'h25: font_row = 8'h06;
            8'h26: font_row = 8'h0C; 8'h27: font_row = 8'h18;
            8'h28: font_row = 8'h30; 8'h29: font_row = 8'h60;
            8'h2A: font_row = 8'hC0; 8'h2B: font_row = 8'hC0;
            8'h2C: font_row = 8'hC0; 8'h2D: font_row = 8'hC0;
            8'h2E: font_row = 8'hC0; 8'h2F: font_row = 8'hFF;
            // ---- '3' --------------------------------------------------------
            8'h30: font_row = 8'h7E; 8'h31: font_row = 8'hC3;
            8'h32: font_row = 8'hC3; 8'h33: font_row = 8'h03;
            8'h34: font_row = 8'h03; 8'h35: font_row = 8'h3E;
            8'h36: font_row = 8'h03; 8'h37: font_row = 8'h03;
            8'h38: font_row = 8'h03; 8'h39: font_row = 8'h03;
            8'h3A: font_row = 8'h03; 8'h3B: font_row = 8'h03;
            8'h3C: font_row = 8'hC3; 8'h3D: font_row = 8'hC3;
            8'h3E: font_row = 8'hC3; 8'h3F: font_row = 8'h7E;
            // ---- '4' --------------------------------------------------------
            8'h40: font_row = 8'h06; 8'h41: font_row = 8'h0E;
            8'h42: font_row = 8'h1E; 8'h43: font_row = 8'h36;
            8'h44: font_row = 8'h66; 8'h45: font_row = 8'hC6;
            8'h46: font_row = 8'hC6; 8'h47: font_row = 8'hFF;
            8'h48: font_row = 8'h06; 8'h49: font_row = 8'h06;
            8'h4A: font_row = 8'h06; 8'h4B: font_row = 8'h06;
            8'h4C: font_row = 8'h06; 8'h4D: font_row = 8'h06;
            8'h4E: font_row = 8'h06; 8'h4F: font_row = 8'h06;
            // ---- '5' --------------------------------------------------------
            8'h50: font_row = 8'hFF; 8'h51: font_row = 8'hC0;
            8'h52: font_row = 8'hC0; 8'h53: font_row = 8'hC0;
            8'h54: font_row = 8'hC0; 8'h55: font_row = 8'hFE;
            8'h56: font_row = 8'hC3; 8'h57: font_row = 8'h03;
            8'h58: font_row = 8'h03; 8'h59: font_row = 8'h03;
            8'h5A: font_row = 8'h03; 8'h5B: font_row = 8'h03;
            8'h5C: font_row = 8'hC3; 8'h5D: font_row = 8'hC3;
            8'h5E: font_row = 8'hC3; 8'h5F: font_row = 8'h7E;
            // ---- '6' --------------------------------------------------------
            8'h60: font_row = 8'h3E; 8'h61: font_row = 8'h60;
            8'h62: font_row = 8'hC0; 8'h63: font_row = 8'hC0;
            8'h64: font_row = 8'hC0; 8'h65: font_row = 8'hFE;
            8'h66: font_row = 8'hC3; 8'h67: font_row = 8'hC3;
            8'h68: font_row = 8'hC3; 8'h69: font_row = 8'hC3;
            8'h6A: font_row = 8'hC3; 8'h6B: font_row = 8'hC3;
            8'h6C: font_row = 8'hC3; 8'h6D: font_row = 8'hC3;
            8'h6E: font_row = 8'h63; 8'h6F: font_row = 8'h3E;
            // ---- '7' --------------------------------------------------------
            8'h70: font_row = 8'hFF; 8'h71: font_row = 8'hC3;
            8'h72: font_row = 8'h03; 8'h73: font_row = 8'h03;
            8'h74: font_row = 8'h06; 8'h75: font_row = 8'h06;
            8'h76: font_row = 8'h0C; 8'h77: font_row = 8'h0C;
            8'h78: font_row = 8'h18; 8'h79: font_row = 8'h18;
            8'h7A: font_row = 8'h18; 8'h7B: font_row = 8'h18;
            8'h7C: font_row = 8'h18; 8'h7D: font_row = 8'h18;
            8'h7E: font_row = 8'h18; 8'h7F: font_row = 8'h18;
            // ---- '8' --------------------------------------------------------
            8'h80: font_row = 8'h7E; 8'h81: font_row = 8'hC3;
            8'h82: font_row = 8'hC3; 8'h83: font_row = 8'hC3;
            8'h84: font_row = 8'hC3; 8'h85: font_row = 8'h7E;
            8'h86: font_row = 8'hC3; 8'h87: font_row = 8'hC3;
            8'h88: font_row = 8'hC3; 8'h89: font_row = 8'hC3;
            8'h8A: font_row = 8'hC3; 8'h8B: font_row = 8'hC3;
            8'h8C: font_row = 8'hC3; 8'h8D: font_row = 8'hC3;
            8'h8E: font_row = 8'hC3; 8'h8F: font_row = 8'h7E;
            // ---- '9' --------------------------------------------------------
            8'h90: font_row = 8'h7E; 8'h91: font_row = 8'hC3;
            8'h92: font_row = 8'hC3; 8'h93: font_row = 8'hC3;
            8'h94: font_row = 8'hC3; 8'h95: font_row = 8'hC3;
            8'h96: font_row = 8'h7F; 8'h97: font_row = 8'h03;
            8'h98: font_row = 8'h03; 8'h99: font_row = 8'h03;
            8'h9A: font_row = 8'h03; 8'h9B: font_row = 8'h03;
            8'h9C: font_row = 8'h03; 8'h9D: font_row = 8'h63;
            8'h9E: font_row = 8'h63; 8'h9F: font_row = 8'h3E;
            // ---- ':' (index 0xA) — chunky pixel-art dots --------------------
            8'hA0: font_row = 8'h00; 8'hA1: font_row = 8'h00;
            8'hA2: font_row = 8'h00; 8'hA3: font_row = 8'h18;
            8'hA4: font_row = 8'h3C; 8'hA5: font_row = 8'h3C;
            8'hA6: font_row = 8'h18; 8'hA7: font_row = 8'h00;
            8'hA8: font_row = 8'h00; 8'hA9: font_row = 8'h18;
            8'hAA: font_row = 8'h3C; 8'hAB: font_row = 8'h3C;
            8'hAC: font_row = 8'h18; 8'hAD: font_row = 8'h00;
            8'hAE: font_row = 8'h00; 8'hAF: font_row = 8'h00;
            // ---- 'A' (index 0xB) --------------------------------------------
            8'hB0: font_row = 8'h3C; 8'hB1: font_row = 8'h66;
            8'hB2: font_row = 8'hC3; 8'hB3: font_row = 8'hC3;
            8'hB4: font_row = 8'hC3; 8'hB5: font_row = 8'hFF;
            8'hB6: font_row = 8'hC3; 8'hB7: font_row = 8'hC3;
            8'hB8: font_row = 8'hC3; 8'hB9: font_row = 8'hC3;
            8'hBA: font_row = 8'hC3; 8'hBB: font_row = 8'hC3;
            8'hBC: font_row = 8'hC3; 8'hBD: font_row = 8'hC3;
            8'hBE: font_row = 8'hC3; 8'hBF: font_row = 8'hC3;
            // ---- 'P' (index 0xC) --------------------------------------------
            8'hC0: font_row = 8'hFE; 8'hC1: font_row = 8'hC3;
            8'hC2: font_row = 8'hC3; 8'hC3: font_row = 8'hC3;
            8'hC4: font_row = 8'hC3; 8'hC5: font_row = 8'hFE;
            8'hC6: font_row = 8'hC0; 8'hC7: font_row = 8'hC0;
            8'hC8: font_row = 8'hC0; 8'hC9: font_row = 8'hC0;
            8'hCA: font_row = 8'hC0; 8'hCB: font_row = 8'hC0;
            8'hCC: font_row = 8'hC0; 8'hCD: font_row = 8'hC0;
            8'hCE: font_row = 8'hC0; 8'hCF: font_row = 8'hC0;
            // ---- 'M' (index 0xD) --------------------------------------------
            8'hD0: font_row = 8'hC3; 8'hD1: font_row = 8'hE7;
            8'hD2: font_row = 8'hFF; 8'hD3: font_row = 8'hDB;
            8'hD4: font_row = 8'hC3; 8'hD5: font_row = 8'hC3;
            8'hD6: font_row = 8'hC3; 8'hD7: font_row = 8'hC3;
            8'hD8: font_row = 8'hC3; 8'hD9: font_row = 8'hC3;
            8'hDA: font_row = 8'hC3; 8'hDB: font_row = 8'hC3;
            8'hDC: font_row = 8'hC3; 8'hDD: font_row = 8'hC3;
            8'hDE: font_row = 8'hC3; 8'hDF: font_row = 8'hC3;
            // ---- blank / any other index ------------------------------------
            default: font_row = 8'h00;
        endcase
    end

    // ---- Field membership flags ----------------------------------------------
    wire in_hour_field = (char_num == 4'd0) || (char_num == 4'd1);
    wire in_min_field  = (char_num == 4'd3) || (char_num == 4'd4);
    wire in_ampm_field = (char_num == 4'd9) || (char_num == 4'd10);

    // ---- Output logic --------------------------------------------------------
    always @(*) begin
        pixel_on   = 1'b0;
        text_color = 12'hFFF;

        if (in_region) begin
            pixel_on = font_row[3'd7 - pixel_col];

            if (adj_hour && in_hour_field)
                text_color = 12'hFD0;        // gold — selected hours field
            else if (adj_min && in_min_field)
                text_color = 12'hFD0;        // gold — selected minutes field
            else if (in_ampm_field)
                text_color = 12'hABF;        // soft blue-violet — AM/PM suffix
            else
                text_color = 12'hFFF;        // bright white — normal digits
        end
    end

endmodule
