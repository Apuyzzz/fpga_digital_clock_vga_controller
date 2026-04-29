#!/bin/bash
# Script      : run_sim.sh
# Descripcion : Simula cada testbench del proyecto usando Vivado xsim.
#               Para cada TB: compila con xvlog, elabora con xelab y
#               ejecuta con xsim. Guarda el resultado en sim_logs/.
# Uso         : ./scripts/run_sim.sh  (desde la raiz del repositorio)

VIVADO_SETTINGS="/tools/Xilinx/Vivado/2024.1/settings64.sh"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$REPO_ROOT/Project_1/Project_1.srcs/sources_1/new"
TB_DIR="$REPO_ROOT/Project_1/Project_1.srcs/sim_1/new"
LOG_DIR="$REPO_ROOT/sim_logs"

# Cargar entorno de Vivado
if [[ ! -f "$VIVADO_SETTINGS" ]]; then
    echo "Error: No se encontro Vivado en $VIVADO_SETTINGS"
    exit 1
fi
source "$VIVADO_SETTINGS"

mkdir -p "$LOG_DIR"

# --------------------------------------------------------------------------
# Orden de ejecucion de los testbenches
# --------------------------------------------------------------------------
TB_NAMES=(
    "tb_bcd_counter"
    "tb_debounce"
    "tb_div_freq"
    "tb_vga_controller"
    "tb_fsm_adjust_mode"
    "tb_binary_bcd_decoder"
    "tb_hour_converter"
)

# --------------------------------------------------------------------------
# DUTs requeridos por cada testbench (nombres de archivo en sources_1/new/)
# --------------------------------------------------------------------------
declare -A TB_DEPS=(
    ["tb_bcd_counter"]="bcd_counter.v"
    ["tb_debounce"]="sync_signal.v debounce.v bcd_counter.v"
    ["tb_div_freq"]="div_frec.v"
    ["tb_vga_controller"]="vga_controller.v"
    ["tb_fsm_adjust_mode"]="fsm_adjust_mode.v"
    ["tb_binary_bcd_decoder"]="binary_bcd_decoder.v"
    ["tb_hour_converter"]="hour_converter.v"
)

PASS_COUNT=0
FAIL_COUNT=0

for tb in "${TB_NAMES[@]}"; do
    echo ""
    echo "========================================"
    echo "  Simulando: $tb"
    echo "========================================"

    log_file="$LOG_DIR/${tb}.log"
    rm -f "$log_file"

    # Construir lista absoluta de archivos DUT
    dut_files=""
    for dut in ${TB_DEPS[$tb]}; do
        dut_files="$dut_files $SRC_DIR/$dut"
    done

    # Directorio temporal aislado para que xsim.dir no colisione entre TBs
    tmp_dir=$(mktemp -d)

    (
        cd "$tmp_dir"

        # Paso 1: Compilar
        xvlog --nolog $dut_files "$TB_DIR/${tb}.v" 2>&1
        if [[ $? -ne 0 ]]; then
            echo "[PIPELINE] XVLOG_FAILED — error de compilacion en $tb"
            exit 1
        fi

        # Paso 2: Elaborar
        xelab --nolog "$tb" -s "${tb}_snap" 2>&1
        if [[ $? -ne 0 ]]; then
            echo "[PIPELINE] XELAB_FAILED — error de elaboracion en $tb"
            exit 1
        fi

        # Paso 3: Simular (stdout captura los $display del testbench)
        xsim "${tb}_snap" --nolog -runall 2>&1

    ) > "$log_file"

    sim_exit=$?
    rm -rf "$tmp_dir"

    # Evaluar resultado leyendo el log
    if grep -q "TODOS LOS TESTS PASARON" "$log_file"; then
        echo "  Resultado: PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    elif grep -qE "ERROR\(ES\)|XVLOG_FAILED|XELAB_FAILED" "$log_file"; then
        echo "  Resultado: FAIL  (ver $log_file)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    elif grep -q "TIMEOUT" "$log_file"; then
        echo "  Resultado: TIMEOUT  (ver $log_file)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    else
        echo "  Resultado: DESCONOCIDO  (ver $log_file)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

echo ""
echo "========================================"
echo "  Simulacion completada"
echo "  PASS: $PASS_COUNT | FAIL: $FAIL_COUNT"
echo "  Logs guardados en: sim_logs/"
echo "========================================"

[[ $FAIL_COUNT -eq 0 ]] && exit 0 || exit 1
