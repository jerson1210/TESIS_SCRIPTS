#!/bin/bash
#SBATCH --account=tg
#SBATCH --partition=partition2
#SBATCH --cpus-per-task=4
#SBATCH --output=/shared/users/grupo2/slurm_%x-%j.out
#SBATCH --error=/shared/users/grupo2/slurm_%x-%j.err

# ======================================================
# Este script NO se llama directo con sbatch.
# Lo invocan submit_E0.sh / submit_E1.sh / submit_E2.sh, que exportan:
#   TEST_NAME, BS, RW1, RW2, SIZE, NUMJOBS, RESULTS_DIR
#   NETEM_ESCENARIO  (uno de: reset, limited, netem, combined)
# y definen --nodes/--ntasks/--job-name al momento de enviarlo.
#
# - Usa el script cluster-netem (ya con permisos configurados) para
#   aplicar/restaurar la condicion de red, en vez de tc manual.
# - Usa --group_reporting en fio para que numjobs>1 reporte un solo
#   resultado combinado (suma de iops/bw, promedio ponderado de latencia).
# - SAR corre SIN limite de muestras, se detiene manualmente cuando
#   fio (write+read) termina, sin importar cuanto dure la prueba.
# ======================================================

module load Core/fio

export RESULTS=${RESULTS_DIR}
mkdir -p $RESULTS

NETEM_SCRIPT=/shared/software/scripts/cluster-netem

echo "=================================================="
echo "Prueba: $TEST_NAME"
echo "bs=$BS rw=$RW1/$RW2 size=$SIZE numjobs=$NUMJOBS"
echo "Escenario de red (cluster-netem): $NETEM_ESCENARIO"
echo "Nodos: $SLURM_NTASKS | Job ID: $SLURM_JOB_ID"
echo "=================================================="

srun --ntasks=$SLURM_NTASKS bash -c '
    WORKDIR=/shared/scratch/${USER}_${SLURM_JOB_ID}_$(hostname)
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
        echo "[$(date "+%T.%3N")] $HOST: sin restriccion de red (E0)"
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
        --ioengine=psync \
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
        --ioengine=psync \
        --rw='"$RW2"' \
        --bs='"$BS"' \
        --size='"$SIZE"' \
        --numjobs='"$NUMJOBS"' \
        --group_reporting \
        --output-format=json \
        --output="$RESULTS/fio_'"$TEST_NAME"'_read_${HOST}_${SLURM_JOB_ID}.json"
    echo "[$(date "+%T.%3N")] $HOST: READ finalizado"

    # --- SAR se detiene aqui, justo cuando fio termino, sin importar cuanto duro ---
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

