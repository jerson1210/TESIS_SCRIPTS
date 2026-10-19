#!/bin/bash
# ======================================================
# Escenario E1 -- Condicion de red moderada
# cluster-netem "combined" = 100 Mbit/s, 30 ms delay, 1% perdida
# Corre cada prueba 3 veces (repeticiones), en carpetas separadas
# ======================================================
RUNNER=/shared/projects/grupo2/proyectoTesis/scripts/auto.sh

lanzar() {
    local etiqueta=$1
    local nodos=$2
    local fsize=$3
    local files=$4
    local fpdir=$5
    local threads=$6
    local resultsdir=$7

    echo ">> Enviando: $etiqueta (nodos=$nodos fsize=${fsize}KB files=$files fpdir=$fpdir threads=$threads) -> $resultsdir"
    ETIQUETA=$etiqueta FSIZE=$fsize FILES=$files FPDIR=$fpdir THREADS=$threads \
    NETEM_ESCENARIO=combined RESULTS_DIR=$resultsdir \
    sbatch --wait --job-name="E1_$etiqueta" --nodes=$nodos --ntasks=$nodos "$RUNNER"
    echo ">> $etiqueta completado"
}

for rep in 1 2 3; do
    RESULTS_DIR=/shared/projects/grupo2/proyectoTesis/resultados/E1/smallfile_rep${rep}

    echo "=================================================="
    echo "Escenario E1 - Smallfile CFS - Repeticion $rep"
    echo "=================================================="

    lanzar "e1_n1" 1 10 1000 100 2 "$RESULTS_DIR"
    lanzar "e1_n2" 2 10 1000 100 2 "$RESULTS_DIR"
    lanzar "e1_n3" 3 10 1000 100 2 "$RESULTS_DIR"
    lanzar "e1_n4" 4 10 1000 100 2 "$RESULTS_DIR"
    lanzar "e1_n5" 5 10 1000 100 2 "$RESULTS_DIR"

    lanzar "archivo_pequeno"      3 1  1000  100  2 "$RESULTS_DIR"
    lanzar "archivo_mediano"      3 100 1000 100  2 "$RESULTS_DIR"
    lanzar "jerarquia_ancha"      3 10 1000  1000 2 "$RESULTS_DIR"
    lanzar "jerarquia_profunda"   3 10 1000  10   2 "$RESULTS_DIR"
    lanzar "carga_media"          3 10 5000  100  2 "$RESULTS_DIR"
    lanzar "carga_alta"           3 10 10000 100  2 "$RESULTS_DIR"

    lanzar "concurrencia_t1"   3 10 1000 100 1  "$RESULTS_DIR"
    lanzar "concurrencia_t2"   3 10 1000 100 2  "$RESULTS_DIR"
    lanzar "concurrencia_t4"   3 10 1000 100 4  "$RESULTS_DIR"
    lanzar "concurrencia_t8"   3 10 1000 100 8  "$RESULTS_DIR"
    lanzar "concurrencia_t16"  3 10 1000 100 16 "$RESULTS_DIR"

    echo ""
    echo "=================================================="
    echo "Repeticion $rep completa. Resultados en: $RESULTS_DIR"
    echo "=================================================="
done
