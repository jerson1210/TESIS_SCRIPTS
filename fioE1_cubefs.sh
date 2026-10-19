#!/bin/bash
# ======================================================
# Escenario E1 -- Degradacion moderada de red
# CubeFS -- Mount: /home/grupo2/cubefs-mount
# cluster-netem: combined (100Mbit / 30ms / 1% loss)
# numjobs=2 en TODAS las pruebas base; solo "concurrencia"
# varia numjobs (1,2,4,8,16). Cada prueba x3 repeticiones.
# ======================================================

RUNNER=/shared/projects/grupo2/proyectoTesis/scripts/test_runner_cubefs.sh
RESULTS_DIR=/shared/projects/grupo2/proyectoTesis/resultados/fioE1_cubefs
NETEM_SCRIPT=/shared/software/scripts/cluster-netem
NODOS_CLUSTER=(rbp5-6 rbp5-7 rbp5-8 rbp5-9 rbp5-10)

aplicar_netem_todos() {
    for n in "${NODOS_CLUSTER[@]}"; do
        echo "=== Aplicando en $n ==="
        ssh "$n" "sudo $NETEM_SCRIPT combined_cubefs"
    done
    echo ">> Netem aplicado en los 5 nodos."
}

resetear_netem_todos() {
    for n in "${NODOS_CLUSTER[@]}"; do
        echo "=== Reseteando en $n ==="
        ssh "$n" "sudo $NETEM_SCRIPT reset"
    done
    echo ">> Netem reseteado en los 5 nodos."
}

lanzar() {
    local test_name=$1
    local nodos=$2
    local bs=$3
    local rw1=$4
    local rw2=$5
    local size=$6
    local numjobs=$7
    local netem_escenario=$8

    echo ">> Enviando: $test_name (nodos=$nodos bs=$bs rw=$rw1/$rw2 size=$size numjobs=$numjobs netem=$netem_escenario)"

    TEST_NAME=$test_name BS=$bs RW1=$rw1 RW2=$rw2 SIZE=$size NUMJOBS=$numjobs \
    NETEM_ESCENARIO=reset RESULTS_DIR=$RESULTS_DIR \
    sbatch --wait --job-name="$test_name" --nodes=$nodos --ntasks=$nodos "$RUNNER"

    echo ">> $test_name completado"
}
aplicar_netem_todos
for rep in 1; do
    echo ""
    echo "#################### REPETICION $rep ####################"

    # ======================================================
    # 1. ESCALABILIDAD BASE -- bs=4k, write/read, 100M, numjobs=2
    # ======================================================
    lanzar "fioE1_cubefs_escalabilidad_n1_rep${rep}" 1 4k write read 100M 2 combined_cubefs
    lanzar "fioE1_cubefs_escalabilidad_n2_rep${rep}" 2 4k write read 100M 2 combined_cubefs
    lanzar "fioE1_cubefs_escalabilidad_n3_rep${rep}" 3 4k write read 100M 2 combined_cubefs
    lanzar "fioE1_cubefs_escalabilidad_n4_rep${rep}" 4 4k write read 100M 2 combined_cubefs
    lanzar "fioE1_cubefs_escalabilidad_n5_rep${rep}" 5 4k write read 100M 2 combined_cubefs

    # ======================================================
    # 2. TAMAÑO DE BLOQUE -- 64K y 1M (nodos=3, numjobs=2)
    # ======================================================
    lanzar "fioE1_cubefs_tamano_bloque_64k_rep${rep}" 3 64k write read 100M 2 combined_cubefs
    lanzar "fioE1_cubefs_tamano_bloque_1m_rep${rep}"  3 1M  write read 100M 2 combined_cubefs

    # ======================================================
    # 3. ACCESO ALEATORIO -- randwrite/randread (nodos=3, numjobs=2)
    # ======================================================
    lanzar "fioE1_cubefs_acceso_aleatorio_4k_rep${rep}"  3 4k  randwrite randread 100M 2 combined_cubefs
    lanzar "fioE1_cubefs_acceso_aleatorio_64k_rep${rep}" 3 64k randwrite randread 100M 2 combined_cubefs
    lanzar "fioE1_cubefs_acceso_aleatorio_1m_rep${rep}"  3 1M  randwrite randread 100M 2 combined_cubefs

    # ======================================================
    # 4. CARGA MEDIA Y ALTA -- 500M y 1G (nodos=3, numjobs=2)
    # ======================================================
    lanzar "fioE1_cubefs_carga_media_rep${rep}" 3 4k write read 500M 2 combined_cubefs
    lanzar "fioE1_cubefs_carga_alta_rep${rep}"  3 4k write read 1G   2 combined_cubefs

    # ======================================================
    # 5. CONCURRENCIA -- numjobs = 1, 2, 4, 8, 16 (nodos=3, bs=4k)
    # ======================================================
    lanzar "fioE1_cubefs_concurrencia_n1_rep${rep}"  3 4k write read 100M 1  combined_cubefs
    lanzar "fioE1_cubefs_concurrencia_n2_rep${rep}"  3 4k write read 100M 2  combined_cubefs
    lanzar "fioE1_cubefs_concurrencia_n4_rep${rep}"  3 4k write read 100M 4  combined_cubefs
    lanzar "fioE1_cubefs_concurrencia_n8_rep${rep}"  3 4k write read 100M 8  combined_cubefs
    lanzar "fioE1_cubefs_concurrencia_n16_rep${rep}" 3 4k write read 100M 16 combined_cubefs

done
resetear_netem_todos
echo ""
echo "=================================================="
echo "Escenario E1 CubeFS completo (17 pruebas x 3 repeticiones = 51 corridas)."
echo "Resultados en: $RESULTS_DIR"
echo "=================================================="
