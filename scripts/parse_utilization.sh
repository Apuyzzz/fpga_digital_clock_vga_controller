#!/bin/bash
# Script      : parse_utilization.sh
# Descripcion : Lee el reporte de utilizacion de recursos generado por Vivado
#               (synthsis) y extrae LUTs, FFs, BRAM y DSPs en un CSV.
# Uso         : ./scripts/parse_utilization.sh  (desde la raiz del repositorio)
# Salida      : synth_results/utilizacion.csv

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SYNTH_DIR="$REPO_ROOT/Project_1/Project_1.runs/synth_1"
RESULTS_DIR="$REPO_ROOT/synth_results"
OUTPUT_CSV="$RESULTS_DIR/utilizacion.csv"

RPT_FILE=$(ls "$SYNTH_DIR"/*_utilization_synth.rpt 2>/dev/null | head -1)

if [[ -z "$RPT_FILE" ]]; then
    echo "Error: No se encontro reporte de utilizacion en $SYNTH_DIR/"
    echo "  Ejecuta primero la sintesis en Vivado (Run Synthesis)."
    exit 1
fi

echo "Reporte: $RPT_FILE"

# Extrae el valor de Used y Available de una fila de la tabla pipe-delimitada.
# Uso: parse_row "patron" archivo
parse_row() {
    local pattern="$1"
    local file="$2"
    grep -m1 "| $pattern" "$file" | awk -F'|' '{
        gsub(/[[:space:]]/,"",$3); gsub(/[[:space:]]/,"",$6); gsub(/[[:space:]]/,"",$7);
        print $3","$6","$7
    }'
}

luts=$(parse_row "Slice LUTs" "$RPT_FILE")
ffs=$(parse_row "Slice Registers" "$RPT_FILE")
bram=$(parse_row "Block RAM Tile" "$RPT_FILE")
dsps=$(parse_row "DSPs" "$RPT_FILE")

# Valores por defecto si no se encontro la fila
luts=${luts:-"N/A,N/A,N/A"}
ffs=${ffs:-"N/A,N/A,N/A"}
bram=${bram:-"N/A,N/A,N/A"}
dsps=${dsps:-"N/A,N/A,N/A"}

mkdir -p "$RESULTS_DIR"

echo "recurso,usado,disponible,util_pct" > "$OUTPUT_CSV"
echo "Slice LUTs,$luts"       >> "$OUTPUT_CSV"
echo "Slice Registers,$ffs"   >> "$OUTPUT_CSV"
echo "Block RAM Tile,$bram"   >> "$OUTPUT_CSV"
echo "DSPs,$dsps"             >> "$OUTPUT_CSV"

echo ""
printf "%-20s %8s %12s %8s\n" "Recurso" "Usado" "Disponible" "Util%"
echo "----------------------------------------------------"
while IFS=',' read -r recurso usado disponible util; do
    [[ "$recurso" == "recurso" ]] && continue
    printf "%-20s %8s %12s %8s\n" "$recurso" "$usado" "$disponible" "$util"
done < "$OUTPUT_CSV"
echo ""
echo "CSV generado en: $OUTPUT_CSV"
