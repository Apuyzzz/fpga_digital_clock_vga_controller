/**
 * @title Decodificador binario a BCD (Double Dabble)
 * @file binary_bcd_decoder.v
 * @brief Convierte un número binario de N bits a dos dígitos BCD empaquetados usando el algoritmo Double Dabble.
 * @details
 *   Implementación combinacional del algoritmo Shift-and-Add-3.
 *   Soporta valores 0-99. Instanciado para horas (N=5, rango 0-23)
 *   y para minutos/segundos (N=6, rango 0-59).
 *   Resultado: bcd_tens en nibble superior, bcd_ones en nibble inferior.
 *
 * @author JustinAlfaro
 * @date 2026-04-21
 */

`timescale 1ns / 1ps

module binary_bcd_decoder #(
    parameter integer N = 6  ///< Ancho de la entrada binaria (6 para rango 0-59, 5 para 0-23)
)(
    input  wire [N-1:0] bin,      ///< Valor binario de entrada
    output reg  [3:0]   bcd_tens, ///< Dígito de decenas BCD [3:0]
    output reg  [3:0]   bcd_ones  ///< Dígito de unidades BCD [3:0]
);

    reg [N+7:0] work;
    integer i;

    always @(*) begin
        work = {{8{1'b0}}, bin};

        for (i = 0; i < N; i = i + 1) begin
            if (work[N+3:N] >= 4'd5)
                work[N+3:N] = work[N+3:N] + 4'd3;
            if (work[N+7:N+4] >= 4'd5)
                work[N+7:N+4] = work[N+7:N+4] + 4'd3;
            work = work << 1;
        end

        bcd_tens = work[N+7:N+4];
        bcd_ones = work[N+3:N];
    end

endmodule
