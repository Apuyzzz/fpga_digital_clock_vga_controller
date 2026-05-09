/**
 * @title Generador de fondo algorítmico
 * @file bg_generator.v
 * @brief Generador combinacional de color de fondo con gradiente navy y efecto vignette.
 * @details
 *   Produce un fondo temático "espacio profundo": gradiente navy oscuro con bandas
 *   horizontales sutiles y oscurecimiento en las esquinas (vignette).
 *   Solo utiliza h_count y v_count como entradas; sin latencia.
 *   Nota: este módulo está deshabilitado (AutoDisabled) en favor de bg_rom.
 *
 * @author JustinAlfaro
 * @date 2026-04-21
 */

`timescale 1ns / 1ps

module bg_generator (
    input  wire [9:0]  h_count,   ///< Coordenada horizontal del píxel [0-639]
    input  wire [9:0]  v_count,   ///< Coordenada vertical del píxel [0-479]
    output reg  [11:0] bg_color   ///< Color de fondo RGB 4-4-4: {R[3:0], G[3:0], B[3:0]}
);

    // ----- Gradient parameters -----------------------------------------------
    // Vertical gradient: dark navy at top (v=0) → deep teal at center → navy again
    // Horizontal: slight purple tint on left half
    // Decorative bands: thin horizontal lines every 60 pixels

    reg [3:0] r, g, b;

    // Distance from center (normalized approximation)
    wire [9:0] dist_v = (v_count < 10'd240) ? (10'd240 - v_count) : (v_count - 10'd240);
    wire [9:0] dist_h = (h_count < 10'd320) ? (10'd320 - h_count) : (h_count - 10'd320);

    // Band flag: true for every 60th row band (2 pixels wide)
    wire band = (v_count[5:0] < 6'd2);

    // Quadrant for color variation
    wire left_half = (h_count < 10'd320);

    always @(*) begin
        // Base color: deep navy/space blue
        r = 4'd1;
        g = 4'd1;
        b = 4'd3;

        // Vertical gradient: more blue toward center
        if (dist_v < 10'd60) begin
            r = 4'd1;
            g = 4'd2;
            b = 4'd5;
        end else if (dist_v < 10'd120) begin
            r = 4'd1;
            g = 4'd1;
            b = 4'd4;
        end

        // Add purple tint on left half
        if (left_half) begin
            r = r + 4'd1;
        end

        // Decorative subtle scan line bands
        if (band) begin
            r = (r > 4'd0) ? r - 4'd1 : 4'd0;
            g = (g > 4'd0) ? g - 4'd1 : 4'd0;
            b = (b > 4'd0) ? b - 4'd1 : 4'd0;
        end

        // Bright accent stripe at y = 240 (center horizontal line)
        if (v_count == 10'd240 || v_count == 10'd241) begin
            r = 4'd2;
            g = 4'd3;
            b = 4'd8;
        end

        // Vignette: darken corners when far from center both axes
        if (dist_v > 10'd180 && dist_h > 10'd200) begin
            r = 4'd0;
            g = 4'd0;
            b = 4'd1;
        end

        bg_color = {r, g, b};
    end

endmodule
