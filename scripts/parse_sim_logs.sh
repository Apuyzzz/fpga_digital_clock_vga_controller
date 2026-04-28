#!/bin/bash
# Script      : parse_sim_logs.sh
# Descripcion : Lee los logs de simulacion en sim_logs/ y genera un CSV
#               con el resultado global y el conteo de errores por testbench.
# Uso         : ./scripts/parse_sim_logs.sh  (desde la raiz del repositorio)
# Salida      : sim_results/resultados.csv

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$REPO_ROOT/sim_logs"
RESULTS_DIR="$REPO_ROOT/sim_results"
OUTPUT_CSV="$RESULTS_DIR/resultados.csv"

if [[ ! -d "$LOG_DIR" ]] || [[ -z "$(ls "$LOG_DIR"/*.log 2>/dev/null)" ]]; then
    echo "Error: No se encontraron logs en $LOG_DIR/"
    echo "  Ejecuta primero: ./scripts/run_sim.sh"
    exit 1
fi

mkdir -p "$RESULTS_DIR"

# Encabezado del CSV
echo "testbench,resultado,errores,tests_fallidos" > "$OUTPUT_CSV"

for logfile in "$LOG_DIR"/tb_*.log; do
    tb=$(basename "$logfile" .log)

    # Detectar errores de pipeline (compilacion / elaboracion)
    if grep -q "XVLOG_FAILED" "$logfile"; then
        resultado="COMPILE_ERROR"
        errores="-"
        tests_fallidos="-"

    elif grep -q "XELAB_FAILED" "$logfile"; then
        resultado="ELAB_ERROR"
        errores="-"
        tests_fallidos="-"

    elif grep -q "TIMEOUT" "$logfile"; then
        resultado="TIMEOUT"
        errores="-"
        tests_fallidos="-"

    elif grep -q "TODOS LOS TESTS PASARON" "$logfile"; then
        resultado="PASS"
        errores=0
        tests_fallidos=0

    elif grep -qE "ERROR\(ES\)" "$logfile"; then
        resultado="FAIL"
        # Extraer el numero de errores del resumen (ej: "3 ERROR(ES)")
        errores=$(grep -oE "[0-9]+ ERROR\(ES\)" "$logfile" | tail -1 | grep -oE "^[0-9]+")
        tests_fallidos=$(grep -c "\[FAIL\]" "$logfile" || echo 0)

    else
        resultado="UNKNOWN"
        errores="-"
        tests_fallidos="-"
    fi

    echo "$tb,$resultado,$errores,$tests_fallidos" >> "$OUTPUT_CSV"
    echo "  $tb -> $resultado  (errores=$errores, tests_fallidos=$tests_fallidos)"
done

echo ""
echo "CSV generado en: $OUTPUT_CSV"
