# FPGA Digital Clock — VGA Controller

**Taller de Diseño Digital · Semestre I 2026 · Instituto Tecnológico de Costa Rica**

Implementación de un reloj digital en FPGA con salida VGA, desarrollado sobre la tarjeta **Nexys A7-100T** (Xilinx Artix-7, xc7a100tcsg324-1).

---

## Características

| Característica | Descripción |
|---|---|
| Resolución VGA | 640 × 480 @ 60 Hz |
| Formato de tiempo | 24 h o 12 h (AM/PM) seleccionable por switch |
| Fuente | Pixel-art bold 8 × 16, renderizada a escala 4× (32 × 64 px por carácter) |
| Modos de ajuste | Ajuste manual de horas y minutos mediante botones |
| Parpadeo en ajuste | Dígito seleccionado parpadea a 0.5 Hz sin módulo dedicado |
| VRAM | Dual-port BRAM 12-bit RGB (4-4-4), 640 × 480 = 307 200 píxeles |
| Dominio de reloj | Único: 100 MHz con clock-enables (sin CDC) |

---

## Hardware requerido

- Nexys A7-100T
- Monitor VGA con cable DB-15

---

## Controles

| Entrada | Función |
|---|---|
| `BTNC` | Ciclar modo: RUN → ADJ\_HOUR → ADJ\_MIN → RUN |
| `BTNU` | Incrementar campo seleccionado |
| `BTND` | Decrementar campo seleccionado |
| `BTNR` | **Aceptar** — confirma los cambios y regresa a RUN |
| `SW[0]` | `0` = display 24 h · `1` = display 12 h con sufijo AM/PM |
| `CPU_RESETN` | Reset general (activo bajo) |

### LEDs indicadores

| LED | Significado |
|---|---|
| `LD[1:0]` | Modo: `00`=RUN · `01`=ADJ\_HOUR · `10`=ADJ\_MIN |
| `LD[2]` | VRAM redibujando (pulso ~3 ms/s) |
| `LD[3]` | Modo 12 h activo |
| `LD[4]` | PM activo (solo en modo 12 h) |

---

## Arquitectura del sistema

```
CLK100MHZ
    ├─ div_freq(4)      → tick_25mhz  → vga_controller
    └─ div_freq(100M)   → tick_1hz    → bcd_counter (sec) / blink_phase / redraw_req

bcd_counter (sec/min/hour)
    └─ binary_bcd_decoder  → [24h BCD]
                              └─ mux2 ──────────────────────┐
hour_converter             → [12h BCD + is_pm]             │
                              └─ mux2 ──────────────────────┤
                                                            ▼
fsm_adjust_mode  ──────────────────────────────→  text_renderer (combinacional)
                                                       │  font ROM inline (caso)
                                                       ▼
                                                  vram_writer  →  bram_dualport (Port B)
                                                                        │
vga_controller → [h_count, v_count] → bram_dualport (Port A) ─────────┘
                                                │
                                           pixel_mux  →  VGA_R/G/B
```

---

## Estructura de módulos

| Módulo | Archivo | Descripción |
|---|---|---|
| `top_vga` | `top_vga.v` | Integración raíz, conecta todos los módulos |
| `div_freq` | `div_frec.v` | Divisor de frecuencia genérico (salida pulso) |
| `debounce` | `debounce.v` | Antirrebote con contador de saturación |
| `sync_signal` | `sync_signal.v` | Sincronizador 2-etapas para entradas asíncronas |
| `fsm_adjust_mode` | `fsm_adjust_mode.v` | FSM de ajuste: RUN / ADJ\_HOUR / ADJ\_MIN |
| `bcd_counter` | `bcd_counter.v` | Contador BCD paramétrico (con carry) |
| `binary_bcd_decoder` | `binary_bcd_decoder.v` | Double Dabble: binario → BCD 2 dígitos |
| `hour_converter` | `hour_converter.v` | Conversión 24 h → 12 h BCD + flag AM/PM |
| `mux2` | `mux2.v` | Multiplexor 2:1 genérico parametrizable |
| `vga_controller` | `vga_controller.v` | Generador de señales VGA 640×480@60 Hz |
| `bram_dualport` | `bram_dualport.v` | BRAM dual-port inferida (VRAM 12-bit) |
| `bg_generator` | `bg_generator.v` | Generador combinacional de fondo (tema espacial) |
| `text_renderer` | `text_render.v` | Renderizador combinacional de caracteres |
| `vram_writer` | `vram_writer.v` | FSM que escribe un frame completo en BRAM |
| `pixel_mux` | `pixel_mux.v` | Mux de salida VGA (blanking + routing RGB) |
| `bcd_ascii_decoder` | `bcd_ascii_decoder.v` | BCD → ASCII (utilidad, no instanciado) |
| `rom_bitmap` | `rom_bitmap.v` | ROM de bitmaps referencia (no instanciado) |

---

## Mecanismo de parpadeo (sin módulo dedicado)

Durante el ajuste de horas o minutos, el campo seleccionado parpadea. En lugar de un módulo blink separado, se aprovecha el pipeline binario → BCD → fuente:

1. `blink_phase` (registro en `top_vga`) alterna cada `tick_1hz` → 0.5 Hz.
2. Cuando `adj_field & blink_phase == 1`, `text_renderer` sustituye el `char_idx` con `4'hF`.
3. El índice `4'hF` no tiene entrada en el `case` de la ROM de fuente → `font_row = 8'h00` → ningún píxel encendido.
4. El `vram_writer` escribe ese frame con el dígito invisible.
5. Presionar cualquier botón reinicia `blink_phase = 0` para que el dígito sea visible inmediatamente.

---

## Modo 12 h / 24 h

El contador de horas siempre opera en 24 h internamente (0–23). El módulo `hour_converter` convierte combinacionalmente a representación 12 h (1–12) y genera la señal `is_pm`. Dos instancias de `mux2` en `top_vga` seleccionan qué dígitos de hora se envían al renderizador según `SW[0]`. En modo 12 h, el display muestra 11 caracteres (`HH:MM:SS AM/PM`) centrados en 640 px; en modo 24 h, 8 caracteres (`HH:MM:SS`).

---

## Fuente pixel-art

La fuente es un bitmap bold 8 × 16 diseñado para verse limpio a escala 4×. Strokes anchos (patrón `0xC3` = dos bits a cada lado), cierres redondeados (`0x7E`). Glifos adicionales más allá de `0`–`9` y `:`

| Índice | Glifo |
|---|---|
| `0xA` | `:` (dos puntos con dots gruesos) |
| `0xB` | `A` |
| `0xC` | `P` |
| `0xD` | `M` |
| `0xF` | *(en blanco — usado para parpadeo)* |


