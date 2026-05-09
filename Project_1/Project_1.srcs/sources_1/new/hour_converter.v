/**
 * @title Convertidor de hora 24h → 12h
 * @file hour_converter.v
 * @brief Convierte un valor binario de hora en formato 24h (0-23) a dígitos BCD 12h y flag AM/PM.
 * @details
 *   Mapeo: 0→12 AM, 1-11→1-11 AM, 12→12 PM, 13-23→1-11 PM.
 *   Completamente combinacional, sin latencia.
 *
 * @author JustinAlfaro
 * @date 2026-04-22
 */

`timescale 1ns / 1ps

module hour_converter (
    input  wire [5:0] hours_24,  ///< Hora en formato 24h en binario [0-23]
    output wire [3:0] h12_tens,  ///< Dígito de decenas en formato 12h (0 o 1)
    output wire [3:0] h12_ones,  ///< Dígito de unidades en formato 12h (0-9)
    output wire       is_pm      ///< Alto cuando es PM (hours_24 >= 12)
);
    assign is_pm = (hours_24 >= 6'd12);

    wire [5:0] h12 = (hours_24 == 6'd0 || hours_24 == 6'd12) ? 6'd12 :
                     (hours_24 > 6'd12)                       ? (hours_24 - 6'd12) :
                                                                 hours_24;

    assign h12_tens = (h12 >= 6'd10) ? 4'd1 : 4'd0;
    assign h12_ones = (h12 >= 6'd10) ? (h12[3:0] - 4'd10) : h12[3:0];
endmodule
