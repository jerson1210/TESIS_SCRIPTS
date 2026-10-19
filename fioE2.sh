#!/bin/bash
# ======================================================
# Escenario E2 -- Condicion de red limitada
# cluster-netem "combined_e2" = 50 Mbit/s, 70 ms delay, 2% perdida
# (coincide exactamente con tu Tabla 3.3)
# numjobs=2 en TODAS las pruebas base; solo "concurrencia"
# varia numjobs (1,2,4,8,16). Cada prueba x3 repeticiones.
# ======================================================

RUNNER=/shared/projects/grupo2/proyectoTesis/scripts/test_runner.sh
RESULTS_DIR=/shared/projects/grupo2/proyectoTesis/resultados/fioE2

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
    NETEM_ESCENARIO=$netem_escenario RESULTS_DIR=$RESULTS_DIR \
    sbatch --wait --job-name="$test_name" --nodes=$nodos --ntasks=$nodos "$RUNNER"

    echo ">> $test_name completado"
}

for rep in 1 ; do
    echo ""
    echo "#################### REPETICION $rep ####################"

    # ======================================================
    # 1. ESCALABILIDAD BASE -- bs=4k, write/read, 100M, numjobs=2
    #    Nodos: 1,2,3,4,5
    # ======================================================
    lanzar "fioE2_escalabilidad_n1_rep${rep}" 1 4k write read 100M 2 combined_e2
    lanzar "fioE2_escalabilidad_n2_rep${rep}" 2 4k write read 100M 2 combined_e2
    lanzar "fioE2_escalabilidad_n3_rep${rep}" 3 4k write read 100M 2 combined_e2
    lanzar "fioE2_escalabilidad_n4_rep${rep}" 4 4k write read 100M 2 combined_e2
    lanzar "fioE2_escalabilidad_n5_rep${rep}" 5 4k write read 100M 2 combined_e2

    # ======================================================
    # 2. TAMAÑO DE BLOQUE -- 64K y 1M (nodos=3, numjobs=2)
    # ======================================================
    lanzar "fioE2_tamano_bloque_64k_rep${rep}" 3 64k write read 100M 2 combined_e2
    lanzar "fioE2_tamano_bloque_1m_rep${rep}"  3 1M  write read 100M 2 combined_e2

    # ======================================================
    # 3. ACCESO ALEATORIO -- randwrite/randread (nodos=3, numjobs=2)
    #    Con 3 tamanos de bloque: 4k, 64k, 1M
    # ======================================================
    lanzar "fioE2_acceso_aleatorio_4k_rep${rep}"  3 4k  randwrite randread 100M 2 combined_e2
    lanzar "fioE2_acceso_aleatorio_64k_rep${rep}" 3 64k randwrite randread 100M 2 combined_e2
    lanzar "fioE2_acceso_aleatorio_1m_rep${rep}"  3 1M  randwrite randread 100M 2 combined_e2

    # ======================================================
    # 4. CARGA MEDIA Y ALTA -- 500M y 1G (nodos=3, numjobs=2)
    # ======================================================
    lanzar "fioE2_carga_media_rep${rep}" 3 4k write read 500M 2 combined_e2
    lanzar "fioE2_carga_alta_rep${rep}"  3 4k write read 1G   2 combined_e2

    # ======================================================
    # 5. CONCURRENCIA -- numjobs = 1, 2, 4, 8, 16 (nodos=3, bs=4k)
    #    ESTA es la UNICA prueba que varia numjobs
    # ======================================================
    lanzar "fioE2_concurrencia_n1_rep${rep}"  3 4k write read 100M 1  combined_e2
    lanzar "fioE2_concurrencia_n2_rep${rep}"  3 4k write read 100M 2  combined_e2
    lanzar "fioE2_concurrencia_n4_rep${rep}"  3 4k write read 100M 4  combined_e2
    lanzar "fioE2_concurrencia_n8_rep${rep}"  3 4k write read 100M 8  combined_e2
    lanzar "fioE2_concurrencia_n16_rep${rep}" 3 4k write read 100M 16 combined_e2

done

echo ""
echo "=================================================="
echo "Escenario E2 completo (17 pruebas x 3 repeticiones = 51 corridas)."
echo "Resultados en: $RESULTS_DIR"
echo "=================================================="
