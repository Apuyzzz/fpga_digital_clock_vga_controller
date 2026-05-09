/**
 * @title FSM de modo de ajuste del reloj
 * @file fsm_adjust_mode.v
 * @brief FSM de Moore que controla el modo de ajuste de hora y minutos.
 * @details
 *   Estados: RUN (operación normal), ADJ_HOUR (ajuste de horas), ADJ_MIN (ajuste de minutos).
 *   btn_mode cicla RUN→ADJ_HOUR→ADJ_MIN→RUN.
 *   btn_ajuste retorna inmediatamente a RUN desde cualquier estado.
 *   Los segundos se resetean a 0 en cada transición de estado.
 *
 * @author JustinAlfaro
 * @date 2026-04-22
 */

`timescale 1ns / 1ps

module fsm_adjust_mode (
    input  wire       clk,        ///< Reloj del sistema (100 MHz)
    input  wire       rst,        ///< Reset síncrono activo alto
    input  wire       btn_mode,   ///< Pulso debounced de BTNC (cicla estado)
    input  wire       btn_up,     ///< Pulso debounced de BTNU (incrementa campo)
    input  wire       btn_down,   ///< Pulso debounced de BTND (decrementa campo)
    input  wire       btn_ajuste, ///< Pulso debounced de BTNR (acepta y vuelve a RUN)
    output reg        adj_hour,   ///< Alto en estado ADJ_HOUR
    output reg        adj_min,    ///< Alto en estado ADJ_MIN
    output reg        sec_en,     ///< Habilita auto-incremento de segundos (solo en RUN)
    output reg        hour_inc,   ///< Pulso de incremento de horas
    output reg        hour_dec,   ///< Pulso de decremento de horas
    output reg        min_inc,    ///< Pulso de incremento de minutos
    output reg        min_dec,    ///< Pulso de decremento de minutos
    output reg        sec_rst,    ///< Resetea segundos al cambiar de estado
    output reg  [1:0] mode_leds   ///< Indicador LED: 00=RUN, 01=ADJ_HOUR, 10=ADJ_MIN
);

    localparam [1:0]
        RUN      = 2'd0,
        ADJ_HOUR = 2'd1,
        ADJ_MIN  = 2'd2;

    reg [1:0] state, next_state;

    // State register
    always @(posedge clk) begin
        if (rst) state <= RUN;
        else     state <= next_state;
    end

    // Next-state logic
    always @(*) begin
        next_state = state;
        if (btn_ajuste) begin
            next_state = RUN; // accept from any state
        end else if (btn_mode) begin
            case (state)
                RUN:      next_state = ADJ_HOUR;
                ADJ_HOUR: next_state = ADJ_MIN;
                ADJ_MIN:  next_state = RUN;
                default:  next_state = RUN;
            endcase
        end
    end

    // Output logic
    always @(posedge clk) begin
        if (rst) begin
            adj_hour  <= 1'b0;
            adj_min   <= 1'b0;
            sec_en    <= 1'b0;
            hour_inc  <= 1'b0;
            hour_dec  <= 1'b0;
            min_inc   <= 1'b0;
            min_dec   <= 1'b0;
            sec_rst   <= 1'b0;
            mode_leds <= 2'b00;
        end else begin
            hour_inc <= 1'b0;
            hour_dec <= 1'b0;
            min_inc  <= 1'b0;
            min_dec  <= 1'b0;
            sec_rst  <= 1'b0;

            case (state)
                RUN: begin
                    adj_hour  <= 1'b0;
                    adj_min   <= 1'b0;
                    sec_en    <= 1'b1;
                    mode_leds <= 2'b00;
                    if (btn_mode) sec_rst <= 1'b1;
                end

                ADJ_HOUR: begin
                    adj_hour  <= 1'b1;
                    adj_min   <= 1'b0;
                    sec_en    <= 1'b0;
                    mode_leds <= 2'b01;
                    hour_inc  <= btn_up;
                    hour_dec  <= btn_down;
                    if (btn_mode || btn_ajuste) sec_rst <= 1'b1;
                end

                ADJ_MIN: begin
                    adj_hour  <= 1'b0;
                    adj_min   <= 1'b1;
                    sec_en    <= 1'b0;
                    mode_leds <= 2'b10;
                    min_inc   <= btn_up;
                    min_dec   <= btn_down;
                    if (btn_mode || btn_ajuste) sec_rst <= 1'b1;
                end

                default: begin
                    adj_hour  <= 1'b0;
                    adj_min   <= 1'b0;
                    sec_en    <= 1'b1;
                    mode_leds <= 2'b00;
                end
            endcase
        end
    end

endmodule
