// =============================================================================
// Module      : debounce
// Description : Antirrebote con contador de saturación + detector de flanco.
//               Elimina el rebote eléctrico de botones físicos.
//               La salida btn_pulse es un pulso de exactamente 1 ciclo de
//               reloj, apto para conectar directamente al 'en' del bcd_counter.
//
// Principio de funcionamiento:
//   Cuando la entrada cambia de estado, el contador empieza a contar.
//   Solo si la señal permanece estable durante STABLE_COUNT ciclos consecutivos,
//   se acepta el nuevo estado. Esto filtra los rebotes, que duran típicamente
//   1-10 ms. Con clk=100MHz y STABLE_COUNT=500_000 → filtro de 5 ms.
//
// Parameters  :
//   STABLE_COUNT - Ciclos de reloj que la señal debe ser estable (default 5ms)
//
// Inputs  :
//   clk       - Reloj del sistema (100 MHz)
//   rst       - Reset síncrono, activo alto
//   btn_in    - Señal ya sincronizada (salida de sync_signal)
//
// Outputs :
//   btn_pulse - Pulso de 1 ciclo en flanco de subida del botón (para 'en')
//   btn_level - Nivel estable del botón (1 = presionado, útil para switches)
//
// Author      : Taller de Diseño Digital - EL3313 - I Semestre 2026
// =============================================================================

module debounce #(
    parameter STABLE_COUNT = 500_000    // 5 ms a 100 MHz
)(
    input  wire clk,
    input  wire rst,
    input  wire btn_in,
    output reg  btn_pulse,              // pulso 1 ciclo → conectar a 'en'
    output reg  btn_level               // nivel estable del botón
);

    // -------------------------------------------------------------------------
    // Ancho del contador
    // -------------------------------------------------------------------------
    localparam CNT_WIDTH = $clog2(STABLE_COUNT + 1);

    reg [CNT_WIDTH-1:0] cnt;

    // -------------------------------------------------------------------------
    // Logica de antirrebote con contador de saturacion
    // btn_prev es innecesario: cuando se acepta el cambio, btn_in != btn_level
    // siempre. Si btn_in=1 en ese momento, es flanco de subida por definicion.
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        btn_pulse <= 1'b0;              // pulso dura 1 solo ciclo

        if (rst) begin
            cnt       <= 0;
            btn_level <= 1'b0;
        end else begin

            if (btn_in == btn_level) begin
                // Senal igual al estado aceptado: resetear contador
                cnt <= 0;
            end else begin
                // Senal diferente: contar tiempo estable
                if (cnt == STABLE_COUNT - 1) begin
                    // Senal estable por suficiente tiempo: aceptar cambio
                    cnt       <= 0;
                    btn_level <= btn_in;
                    // btn_in=1 implica flanco de subida (venia de btn_level=0)
                    if (btn_in)
                        btn_pulse <= 1'b1;
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end
        end
    end

endmodule
