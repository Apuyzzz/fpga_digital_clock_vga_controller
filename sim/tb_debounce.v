// =============================================================================
// Testbench   : tb_debounce
// Description : Verifica la cadena completa sync_signal -> debounce -> bcd_counter,
//               tal como se conectaria en el top del proyecto.
//
//   TEST 1 - Reset                        : btn_pulse=0, btn_level=0, bcd=0x00
//   TEST 2 - Rebote corto filtrado        : pulso < STABLE no cambia btn_level
//   TEST 3 - Presion limpia               : btn_pulse=1 exactamente 1 ciclo
//   TEST 4 - bcd_counter incrementa 1 vez : un pulso limpio incrementa el BCD
//   TEST 5 - Rebote al soltar             : no genera pulsos extra
//
// Correcciones aplicadas:
//   - Margen aumentado a STABLE+10 para absorber latencia de sync_signal (2 FF)
//   - Eliminadas variables no usadas en TEST 2 (pulses_before, pulses_after)
//   - Sin caracteres Unicode: -> en vez de flechas, PASS/FAIL en vez de simbolos
//   - TEST 5 comentado correctamente como "Rebote al soltar"
//   - TEST 4: comparacion de BCD simplificada convirtiendo a decimal
//
// Simulador   : Vivado xsim (Artix-7 / Nexys A7)
// Autor       : Taller de Diseno Digital - EL3313 - I Semestre 2026
// =============================================================================

`timescale 1ns / 1ps

module tb_debounce;

    // -------------------------------------------------------------------------
    // Parametros
    // STABLE pequeno para simulacion rapida (en hardware seria 500_000)
    // MARGIN absorbe la latencia de 2 ciclos del sync_signal
    // -------------------------------------------------------------------------
    parameter integer STABLE     = 10;
    parameter integer MARGIN     = STABLE + 10;
    parameter integer CLK_PERIOD = 10;

    // -------------------------------------------------------------------------
    // Senales
    // -------------------------------------------------------------------------
    reg  clk, rst;
    reg  btn_raw;           // boton fisico (asincrono, con rebote)

    wire sync_out;          // salida del sincronizador
    wire btn_pulse;         // pulso limpio de 1 ciclo
    wire btn_level;         // nivel estable del boton

    wire [7:0] bcd;
    wire       carry;

    // -------------------------------------------------------------------------
    // Cadena: sync_signal -> debounce -> bcd_counter
    // -------------------------------------------------------------------------
    sync_signal SYNC (
        .clk      (clk),
        .async_in (btn_raw),
        .sync_out (sync_out)
    );

    debounce #(
        .STABLE_COUNT(STABLE)
    ) DEB (
        .clk       (clk),
        .rst       (rst),
        .btn_in    (sync_out),
        .btn_pulse (btn_pulse),
        .btn_level (btn_level)
    );

    bcd_counter #(
        .MAX(6'd59)
    ) CNT (
        .clk   (clk),
        .rst   (rst),
        .en    (btn_pulse),
        .bcd   (bcd),
        .carry (carry)
    );

    // -------------------------------------------------------------------------
    // Reloj
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Contadores de error
    // -------------------------------------------------------------------------
    integer errors_total = 0;
    integer errors_test  = 0;

    // -------------------------------------------------------------------------
    // Tarea: simula rebote - la senal alterna n_bounces veces
    // Cada rebote dura bounce_cycles ciclos (debe ser < STABLE para ser filtrado)
    // -------------------------------------------------------------------------
    task bounce;
        input integer n_bounces;
        input integer bounce_cycles;
        integer b;
        begin
            for (b = 0; b < n_bounces; b = b + 1) begin
                btn_raw = ~btn_raw;
                repeat(bounce_cycles) @(posedge clk);
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Tarea: presion limpia - sube MARGIN ciclos, baja MARGIN ciclos
    // MARGIN > STABLE + 2 para absorber latencia del sync_signal
    // -------------------------------------------------------------------------
    task press_clean;
        begin
            btn_raw = 1'b1;
            repeat(MARGIN) @(posedge clk);
            btn_raw = 1'b0;
            repeat(MARGIN) @(posedge clk);
        end
    endtask

    // =========================================================================
    // ESTIMULOS
    // =========================================================================
    integer       pulse_count;
    integer       bcd_dec_antes;
    integer       bcd_dec_despues;

    initial begin
        rst     = 1'b1;
        btn_raw = 1'b0;

        $display("============================================================");
        $display("  TESTBENCH: sync_signal -> debounce -> bcd_counter");
        $display("  STABLE=%0d ciclos  MARGIN=%0d ciclos", STABLE, MARGIN);
        $display("============================================================");

        repeat(4) @(posedge clk); #1;

        // ------------------------------------------------------------------
        // TEST 1: Reset sincrono
        // ------------------------------------------------------------------
        errors_test = 0;
        $display("\n[TEST 1] Reset sincrono");
        if (btn_pulse !== 1'b0 || btn_level !== 1'b0 || bcd !== 8'h00) begin
            $display("  [FAIL] Estado incorrecto tras reset");
            $display("         btn_pulse=%b btn_level=%b bcd=0x%02h",
                     btn_pulse, btn_level, bcd);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else
            $display("  btn_pulse=%b btn_level=%b bcd=0x%02h -> PASS",
                     btn_pulse, btn_level, bcd);
        rst = 1'b0;

        // ------------------------------------------------------------------
        // TEST 2: Rebote corto filtrado
        // 4 rebotes de 3 ciclos cada uno (< STABLE=10) no deben pasar
        // Variables no usadas eliminadas
        // ------------------------------------------------------------------
        errors_test = 0;
        $display("\n[TEST 2] Rebote corto no pasa el filtro");
        bounce(4, 3);
        // Asegurar btn_raw queda en 0 al final del rebote
        btn_raw = 1'b0;
        repeat(MARGIN) @(posedge clk); #1;
        if (btn_level !== 1'b0) begin
            $display("  [FAIL] btn_level cambio con rebote corto (esperado 0)");
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end else
            $display("  btn_level=0 tras rebotes cortos -> PASS");
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 3: Presion limpia genera btn_pulse exactamente 1 ciclo
        // MARGIN absorbe latencia de sync_signal (2 FF = 2 ciclos)
        // ------------------------------------------------------------------
        errors_test = 0;
        pulse_count = 0;
        $display("\n[TEST 3] Presion limpia genera btn_pulse de 1 ciclo");
        btn_raw = 1'b1;
        repeat(MARGIN) begin
            @(posedge clk); #1;
            if (btn_pulse) pulse_count = pulse_count + 1;
        end
        btn_raw = 1'b0;
        repeat(MARGIN) @(posedge clk);

        $display("  btn_pulse se activo %0d vez (esperado: 1)", pulse_count);
        if (pulse_count !== 1) begin
            $display("  [FAIL] btn_pulse debe activarse exactamente 1 vez");
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 4: bcd_counter incrementa exactamente 1 vez por presion
        // Comparacion simplificada: convertir BCD a decimal antes y despues
        // bcd_dec = decenas*10 + unidades
        // ------------------------------------------------------------------
        errors_test   = 0;
        bcd_dec_antes = bcd[7:4] * 10 + bcd[3:0];
        $display("\n[TEST 4] bcd_counter incrementa 1 vez por presion limpia");
        $display("  BCD antes : 0x%02h (%0d decimal)", bcd, bcd_dec_antes);

        press_clean;

        bcd_dec_despues = bcd[7:4] * 10 + bcd[3:0];
        $display("  BCD despues: 0x%02h (%0d decimal)", bcd, bcd_dec_despues);

        if (bcd_dec_despues !== bcd_dec_antes + 1) begin
            $display("  [FAIL] Incremento incorrecto: antes=%0d despues=%0d",
                     bcd_dec_antes, bcd_dec_despues);
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // TEST 5: Rebote al soltar no genera pulsos extra
        // Presion limpia + rebote al soltar = exactamente 1 pulso total
        // ------------------------------------------------------------------
        errors_test = 0;
        pulse_count = 0;
        $display("\n[TEST 5] Rebote al soltar no genera pulsos extra");

        // Presion limpia
        btn_raw = 1'b1;
        repeat(MARGIN) begin
            @(posedge clk); #1;
            if (btn_pulse) pulse_count = pulse_count + 1;
        end

        // Rebote al soltar: 6 transiciones de 3 ciclos (< STABLE, filtradas)
        bounce(6, 3);
        btn_raw = 1'b0;
        repeat(MARGIN) begin
            @(posedge clk); #1;
            if (btn_pulse) pulse_count = pulse_count + 1;
        end

        $display("  Pulsos totales=%0d (esperado: 1)", pulse_count);
        if (pulse_count !== 1) begin
            $display("  [FAIL] Rebote al soltar genero pulsos extra");
            errors_test  = errors_test  + 1;
            errors_total = errors_total + 1;
        end
        if (errors_test == 0) $display("  Resultado: PASS");
        else                  $display("  Resultado: FAIL");

        // ------------------------------------------------------------------
        // Resumen global
        // ------------------------------------------------------------------
        $display("\n============================================================");
        if (errors_total == 0)
            $display("  RESULTADO GLOBAL: TODOS LOS TESTS PASARON - OK");
        else
            $display("  RESULTADO GLOBAL: %0d ERROR(ES) - REVISAR", errors_total);
        $display("============================================================\n");

        $finish;
    end

    // Timeout de seguridad
    initial begin
        #(CLK_PERIOD * 50000);
        $display("[TIMEOUT] Simulacion excedio el tiempo limite.");
        $finish;
    end

endmodule
