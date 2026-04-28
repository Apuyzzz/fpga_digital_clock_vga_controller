// =============================================================================
// Module      : div_freq
// Description : Divisor de frecuencia genérico. Genera un pulso de 1 ciclo
//               (tick) cada N ciclos de reloj. Se instancia dos veces:
//                 - div_freq #(4)    → tick_25mhz  (100MHz / 4  = 25 MHz)
//                 - div_freq #(100M) → tick_1hz    (100MHz / 100_000_000 = 1 Hz)
//
// Parameters  :
//   DIVISOR - Número de ciclos entre cada pulso de salida
//
// Inputs  :
//   clk   - Reloj del sistema (100 MHz, Nexys A7)
//   rst   - Reset síncrono, activo alto
//
// Outputs :
//   tick  - Pulso de 1 ciclo cada DIVISOR ciclos
//
// Author      : Taller de Diseño Digital - EL3313 - I Semestre 2026
// =============================================================================

module div_freq #(
    parameter DIVISOR = 100_000_000     // Default: genera tick_1hz
)(
    input  wire clk,
    input  wire rst,
    output reg  tick
);

    // -------------------------------------------------------------------------
    // Ancho del contador: clog2(DIVISOR) bits
    // -------------------------------------------------------------------------
    localparam CNT_WIDTH = $clog2(DIVISOR);

    reg [CNT_WIDTH-1:0] count;

    // -------------------------------------------------------------------------
    // Lógica secuencial
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        tick <= 1'b0;               // tick dura solo 1 ciclo de reloj

        if (rst) begin
            count <= 0;
        end else begin
            if (count == DIVISOR - 1) begin
                count <= 0;
                tick  <= 1'b1;      // pulso de salida
            end else begin
                count <= count + 1'b1;
            end
        end
    end

endmodule
