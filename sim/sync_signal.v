// =============================================================================
// Module      : sync_signal
// Description : Sincronizador de 2 etapas para entradas asíncronas.
//               Evita metaestabilidad al cruzar señales externas (botones,
//               switches) al dominio de reloj de 100 MHz.
//               Debe colocarse ANTES del debounce en la cadena de señales.
//
// Cadena correcta de señales para botones:
//   botón físico → sync_signal → debounce → edge_detector → enable contador
//
// Inputs  :
//   clk     - Reloj del sistema (100 MHz)
//   async_in - Señal asíncrona de entrada (botón o switch crudo)
//
// Outputs :
//   sync_out - Señal sincronizada al dominio de clk (2 ciclos de latencia)
//
// Author      : Taller de Diseño Digital - EL3313 - I Semestre 2026
// =============================================================================

module sync_signal (
    input  wire clk,
    input  wire async_in,
    output wire sync_out
);

    // -------------------------------------------------------------------------
    // Dos flip-flops en serie para sincronizacion (estandar de industria).
    // El atributo ASYNC_REG = "TRUE" le indica a Vivado que son registros
    // de sincronizacion, no logica general. Esto garantiza que Vivado:
    //   - Los coloque en flip-flops reales (no en SRL)
    //   - Los ubique fisicamente cerca uno del otro en el layout
    //   - Aplique restricciones de timing adecuadas para metaestabilidad
    // -------------------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) reg ff1;
    (* ASYNC_REG = "TRUE" *) reg ff2;

    always @(posedge clk) begin
        ff1 <= async_in;
        ff2 <= ff1;
    end

    assign sync_out = ff2;

endmodule
