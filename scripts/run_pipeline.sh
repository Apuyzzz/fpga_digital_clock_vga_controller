#!/bin/bash
# Script      : run_pipeline.sh
# Descripcion : Script maestro que ejecuta el pipeline completo de pruebas:
#               1. Simula todos los testbenches (run_sim.sh)
#               2. Parsea los logs y genera el CSV de resultados (parse_sim_logs.sh)
# Uso         : ./scripts/run_pipeline.sh  (desde la raiz del repositorio)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS=("run_sim.sh" "parse_sim_logs.sh")
NAMES=("Ejecutar simulaciones" "Parsear logs y generar CSV")

for i in "${!SCRIPTS[@]}"; do
    script="$SCRIPT_DIR/${SCRIPTS[$i]}"
    name="${NAMES[$i]}"

    echo ""
    echo "========================================"
    echo "Paso $((i+1))/${#SCRIPTS[@]}: $name"
    echo "========================================"

    if [[ ! -x "$script" ]]; then
        echo "Error: $script no encontrado o sin permisos de ejecucion."
        echo "  Ejecuta: chmod +x scripts/*.sh"
        exit 1
    fi

    bash "$script"

    if [[ $? -ne 0 ]]; then
        echo ""
        echo "Error: fallo el paso $((i+1)) ($script). Pipeline detenido."
        exit 1
    fi
done

echo ""
echo "========================================"
echo "Pipeline completado."
echo "Resultados en: sim_results/resultados.csv"
echo "========================================"
