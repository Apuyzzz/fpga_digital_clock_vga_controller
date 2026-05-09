/**
 * @title Escritor de VRAM
 * @file vram_writer.v
 * @brief FSM secuencial que redibuja el frame completo de 640×480 en la VRAM ante cada solicitud.
 * @details
 *   Opera a 100 MHz; un frame completo toma 307 200 ciclos (~3.07 ms).
 *   bg_color proviene de bg_rom (latencia sincrónica de 1 ciclo desde h_wr/v_wr).
 *   Se implementa un pipeline interno de 1 ciclo para compensar esta latencia:
 *   - Etapa 1: captura dirección y datos de texto mientras bg_rom realiza la lectura.
 *   - Etapa 2: escribe a BRAM cuando bg_color ya es válido para ese píxel.
 *
 * @author JustinAlfaro
 * @date 2026-04-21
 */

`timescale 1ns / 1ps

module vram_writer (
    input  wire        clk,        ///< Reloj del sistema (100 MHz)
    input  wire        rst,        ///< Reset síncrono activo alto
    input  wire        redraw_req, ///< Pulso que dispara un redibujado completo del frame

    output reg  [9:0]  h_wr,       ///< Columna actual de escritura [9:0] → bg_rom y text_renderer
    output reg  [9:0]  v_wr,       ///< Fila actual de escritura [9:0] → bg_rom y text_renderer

    input  wire [11:0] bg_color,   ///< Color de fondo desde bg_rom (válido 1 ciclo después de h/v_wr)
    input  wire        pixel_on,   ///< Alto si el píxel actual es foreground de texto (combinacional)
    input  wire [11:0] text_color, ///< Color de texto desde text_renderer (combinacional)

    output reg  [18:0] bram_addr,  ///< Dirección de escritura al puerto B de BRAM
    output reg  [11:0] bram_din,   ///< Dato a escribir al puerto B de BRAM (píxel RGB)
    output reg         bram_we,    ///< Habilitación de escritura al puerto B de BRAM

    output reg         drawing     ///< Alto mientras un redibujado está en progreso
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
