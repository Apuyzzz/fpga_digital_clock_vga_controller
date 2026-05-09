/**
 * @title Contador BCD paramétrico
 * @file bcd_counter.v
 * @brief Contador BCD con límite superior configurable, auto-incremento y ajuste manual.
 * @details
 *   Soporta auto-incremento por clock enable (tick de 1 Hz), incremento/decremento
 *   manual para el modo de ajuste, y salida de acarreo para encadenamiento
 *   (segundos → minutos → horas).
 *
 * @author JustinAlfaro
 * @date 2026-04-21
 */

`timescale 1ns / 1ps

module bcd_counter #(
    parameter integer MAX_VAL = 59  ///< Valor máximo inclusive (59 para min/seg, 23 para horas)
)(
    input  wire       clk,       ///< Reloj del sistema (100 MHz)
    input  wire       rst,       ///< Reset síncrono activo alto
    input  wire       clk_en,    ///< Clock enable: auto-incrementa cuando alto (pulso de 1 Hz)
    input  wire       inc,       ///< Pulso de incremento manual (desde FSM en modo ajuste)
    input  wire       dec,       ///< Pulso de decremento manual (desde FSM en modo ajuste)
    output reg  [5:0] count,     ///< Valor actual del contador [0-MAX_VAL]
    output reg        carry_out  ///< Alto un ciclo cuando el contador hace rollover a 0
);

    always @(posedge clk) begin
        if (rst) begin
            count     <= 6'd0;
            carry_out <= 1'b0;
        end else begin
            carry_out <= 1'b0;

            if (clk_en) begin
                if (count == MAX_VAL[5:0]) begin
                    count     <= 6'd0;
                    carry_out <= 1'b1;
                end else begin
                    count <= count + 1'b1;
                end
            end else if (inc) begin
                if (count == MAX_VAL[5:0])
                    count <= 6'd0;
                else
                    count <= count + 1'b1;
            end else if (dec) begin
                if (count == 6'd0)
                    count <= MAX_VAL[5:0];
                else
                    count <= count - 1'b1;
            end
        end
    end

endmodule
