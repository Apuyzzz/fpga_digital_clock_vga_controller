// =============================================================================
// Module      : bcd_counter
// Description : Contador BCD paramétrico con carry-out.
//               Cuenta en binario internamente y expone salida BCD.
//               Tres instancias encadenadas forman el reloj: seg → min → hora.
//
// Parameters  :
//   MAX  - Valor máximo antes de rollover (59 para seg/min, 23 para hora)
//
// Inputs  :
//   clk  - Reloj del sistema (100 MHz en Nexys A7)
//   rst  - Reset síncrono, activo alto
//   en   - Enable (pulso tick_1hz para segundos, carry encadenado para min/hora)
//
// Outputs :
//   bcd  - [7:4] = decenas, [3:0] = unidades (BCD de 2 dígitos)
//   carry - Pulso de 1 ciclo cuando el contador hace rollover (0 → MAX → 0)
//
// Author      : Taller de Diseño Digital - EL3313 - I Semestre 2026
// =============================================================================

module bcd_counter #(
    parameter [5:0] MAX = 6'd59 // Tamaño explícito [5:0] evita ambigüedades
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       en,
    output wire [7:0] bcd,      // BCD: bcd[7:4]=decenas, bcd[3:0]=unidades
    output reg        carry     // Pulso 1 ciclo al llegar a MAX
);

    // -------------------------------------------------------------------------
    // Registro interno binario
    // -------------------------------------------------------------------------
    reg [5:0] count;            // 6 bits: cubre 0-59 y 0-23

    // -------------------------------------------------------------------------
    // Lógica secuencial: conteo y carry
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        carry <= 1'b0;          // carry dura solo 1 ciclo de reloj

        if (rst) begin
            count <= 6'd0;
        end else if (en) begin
            if (count == MAX) begin     // comparación limpia, MAX ya es [5:0]
                count <= 6'd0;
                carry <= 1'b1;  // rollover: notifica al siguiente contador
            end else begin
                count <= count + 1'b1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Conversión binaria → BCD (combinacional)
    // Vivado infiere esto como lógica pura, sin división real en hardware.
    // -------------------------------------------------------------------------
    assign bcd[7:4] = count / 4'd10;   // decenas
    assign bcd[3:0] = count % 4'd10;   // unidades

endmodule
