#!/bin/bash
#SBATCH --account=tg
#SBATCH --partition=partition2
#SBATCH --cpus-per-task=4
#SBATCH --output=/shared/users/grupo2/slurm_%x-%j.out
#SBATCH --error=/shared/users/grupo2/slurm_%x-%j.err

# ======================================================
# Este script NO se llama directo con sbatch.
# Lo invocan fioE0_cubefs.sh / fioE1_cubefs.sh / fioE2_cubefs.sh
# que exportan:
#   TEST_NAME, BS, RW1, RW2, SIZE, NUMJOBS, RESULTS_DIR
#   NETEM_ESCENARIO  (uno de: reset, combined, combined_e2)
# y definen --nodes/--ntasks/--job-name al momento de enviarlo.
#
# Diferencias respecto a test_runner.sh (NFS):
#   - WORKDIR apunta a /home/grupo2/cubefs-mount/ en vez de /shared/scratch/
#   - No usa module load Core/fio (CubeFS no requiere modulo extra)
#   - El resto es identico: srun bash -c, SAR sin limite, write+read separados
# ======================================================

module load Core/fio

export RESULTS=${RESULTS_DIR}
mkdir -p $RESULTS

NETEM_SCRIPT=/shared/software/scripts/cluster-netem

echo "=================================================="
echo "Prueba: $TEST_NAME  [CubeFS]"
echo "bs=$BS rw=$RW1/$RW2 size=$SIZE numjobs=$NUMJOBS"
echo "Escenario de red (cluster-netem): $NETEM_ESCENARIO"
echo "Nodos: $SLURM_NTASKS | Job ID: $SLURM_JOB_ID"
echo "=================================================="

srun --ntasks=$SLURM_NTASKS bash -c '
    # CubeFS: WORKDIR dentro del punto de montaje, por nodo
    WORKDIR=/home/grupo2/cubefs-mount/${USER}_${SLURM_JOB_ID}_$(hostname)
    FIO_DIR=$WORKDIR/fio_test
    mkdir -p $FIO_DIR
    HOST=$(hostname)
    FIO_FILE="$FIO_DIR/datos.dat"
    rm -f "$FIO_FILE"

    # ======================================================
    # APLICAR CONDICION DE RED con cluster-netem (solo si != reset)
    # ======================================================
    if [ "'"$NETEM_ESCENARIO"'" != "reset" ]; then
        sudo '"$NETEM_SCRIPT"' '"$NETEM_ESCENARIO"'
        echo "[$(date "+%T.%3N")] $HOST: red aplicada (cluster-netem '"$NETEM_ESCENARIO"')"
        sudo '"$NETEM_SCRIPT"' status
    else
    	echo "[$(date "+%T.%3N")] $HOST: netem gestionado externamente (ver aplicar_netem_todos en el orquestador)"
    	sudo '"$NETEM_SCRIPT"' status
    fi
    # ======================================================
    # INICIAR SAR -- SIN limite de muestras (corre hasta que lo matemos)
    # ======================================================
    sar -u -r -n DEV 5 > $RESULTS/sar_'"$TEST_NAME"'_${HOST}_${SLURM_JOB_ID}.log &
    SAR_PID=$!
    echo "[$(date "+%T.%3N")] $HOST: SAR iniciado sin limite de muestras (PID=$SAR_PID)"

    # ======================================================
    # FASE WRITE
    # ======================================================
    echo "[$(date "+%T.%3N")] $HOST: iniciando WRITE ('"$RW1"')"
    fio --name="'"$TEST_NAME"'_write_${HOST}" \
        --filename="$FIO_FILE" \
        --direct=1 \
        --ioengine=sync \
        --rw='"$RW1"' \
        --bs='"$BS"' \
        --size='"$SIZE"' \
        --numjobs='"$NUMJOBS"' \
        --group_reporting \
        --output-format=json \
        --output="$RESULTS/fio_'"$TEST_NAME"'_write_${HOST}_${SLURM_JOB_ID}.json"
    echo "[$(date "+%T.%3N")] $HOST: WRITE finalizado"

    # ======================================================
    # FASE READ (mismo archivo -- intencional)
    # ======================================================
    echo "[$(date "+%T.%3N")] $HOST: iniciando READ ('"$RW2"')"
    fio --name="'"$TEST_NAME"'_read_${HOST}" \
        --filename="$FIO_FILE" \
        --direct=1 \
        --ioengine=sync \
        --rw='"$RW2"' \
        --bs='"$BS"' \
        --size='"$SIZE"' \
        --numjobs='"$NUMJOBS"' \
        --group_reporting \
        --output-format=json \
        --output="$RESULTS/fio_'"$TEST_NAME"'_read_${HOST}_${SLURM_JOB_ID}.json"
    echo "[$(date "+%T.%3N")] $HOST: READ finalizado"

    # --- SAR se detiene aqui, justo cuando fio termino ---
    kill "$SAR_PID" 2>/dev/null
    echo "[$(date "+%T.%3N")] $HOST: SAR detenido (duro exactamente lo que fio)"

    # ======================================================
    # RESTAURAR CONDICION DE RED (siempre, para dejar el nodo limpio)
    # ======================================================
    if [ "'"$NETEM_ESCENARIO"'" != "reset" ]; then
        sudo '"$NETEM_SCRIPT"' reset
        echo "[$(date "+%T.%3N")] $HOST: red restaurada (reset)"
    fi

    rm -rf "$WORKDIR"
    echo "[$(date "+%T.%3N")] $HOST: limpieza completada"
'

echo "=================================================="
echo "Prueba $TEST_NAME finalizada."
echo "JSON en: $RESULTS"
echo "=================================================="
