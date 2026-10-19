#!/bin/bash
#SBATCH --job-name=smallfileCFS
#SBATCH --account=tg
#SBATCH --partition=partition2
#SBATCH --cpus-per-task=4
#SBATCH --output=/shared/users/grupo2/slurm_%x-%j.out
#SBATCH --error=/shared/users/grupo2/slurm_%x-%j.err

module load Core/smallfile
export PATH=/shared/projects/grupo2/proyectoTesis/smallfile_local:$PATH

NETEM_SCRIPT=/shared/software/scripts/cluster-netem

export RESULTS=${RESULTS_DIR}
mkdir -p $RESULTS

echo "=================================================="
echo "Prueba: $ETIQUETA"
echo "file-size=${FSIZE}KB files=$FILES files-per-dir=$FPDIR threads=$THREADS"
echo "Escenario de red (cluster-netem): $NETEM_ESCENARIO"
echo "Nodos: $SLURM_NTASKS | Job ID: $SLURM_JOB_ID"
echo "=================================================="

srun --ntasks=$SLURM_NTASKS bash -c '
    WORKDIR=/shared/scratch/${USER}_${SLURM_JOB_ID}_$(hostname)
    SMALLFILE_DIR=$WORKDIR/smallfile_test
    mkdir -p $SMALLFILE_DIR
    HOST=$(hostname)

    echo "[$(date "+%T.%3N")] $HOST: experimento iniciado (prueba='"$ETIQUETA"')"

    if [ "'"$NETEM_ESCENARIO"'" != "reset" ]; then
        sudo '"$NETEM_SCRIPT"' '"$NETEM_ESCENARIO"'
        sleep 2
        echo "[$(date "+%T.%3N")] $HOST: red aplicada (cluster-netem '"$NETEM_ESCENARIO"')"
    else
        echo "[$(date "+%T.%3N")] $HOST: sin restriccion de red (E0)"
    fi

    sar -u -r -n DEV 5 > $RESULTS/sar_'"$ETIQUETA"'_${HOST}_${SLURM_JOB_ID}.log &
    SAR_PID=$!
    echo "[$(date "+%T.%3N")] $HOST: SAR iniciado (PID=$SAR_PID)"

    mkdir -p $RESULTS/response_times

    echo "[$(date "+%T.%3N")] $HOST: iniciando Smallfile CREATE"
    smallfile_cli.py \
        --operation create \
        --threads '"$THREADS"' \
        --files '"$FILES"' \
        --file-size '"$FSIZE"' \
        --files-per-dir '"$FPDIR"' \
        --top "$SMALLFILE_DIR" \
        --response-times Y \
        --stonewall N \
        > $RESULTS/smallfile_create_'"$ETIQUETA"'_${HOST}_${SLURM_JOB_ID}.txt
    echo "[$(date "+%T.%3N")] $HOST: Smallfile CREATE finalizado (status=$?)"

    for f in "$WORKDIR"/smallfile_test/network_shared/rsptimes_*.csv; do
        [ -e "$f" ] || continue
        cp "$f" "$RESULTS/response_times/'"$ETIQUETA"'_${HOST}_$(basename "$f")"
    done
    echo "[$(date "+%T.%3N")] $HOST: response times de CREATE guardados"

    echo "[$(date "+%T.%3N")] $HOST: iniciando Smallfile READ"
    smallfile_cli.py \
        --operation read \
        --threads '"$THREADS"' \
        --files '"$FILES"' \
        --file-size '"$FSIZE"' \
        --files-per-dir '"$FPDIR"' \
        --top "$SMALLFILE_DIR" \
        --response-times Y \
        --stonewall N \
        > $RESULTS/smallfile_read_'"$ETIQUETA"'_${HOST}_${SLURM_JOB_ID}.txt
    echo "[$(date "+%T.%3N")] $HOST: Smallfile READ finalizado (status=$?)"

    for f in "$WORKDIR"/smallfile_test/network_shared/rsptimes_*.csv; do
        [ -e "$f" ] || continue
        cp "$f" "$RESULTS/response_times/'"$ETIQUETA"'_${HOST}_$(basename "$f")"
    done
    echo "[$(date "+%T.%3N")] $HOST: response times de READ guardados"

    kill "$SAR_PID" 2>/dev/null
    echo "[$(date "+%T.%3N")] $HOST: SAR detenido"

    if [ "'"$NETEM_ESCENARIO"'" != "reset" ]; then
        sudo '"$NETEM_SCRIPT"' reset
        echo "[$(date "+%T.%3N")] $HOST: red restaurada (reset)"
    fi

    rm -rf "$WORKDIR"
    echo "[$(date "+%T.%3N")] $HOST: limpieza completada"
'

echo "=================================================="
echo "Prueba $ETIQUETA finalizada."
echo "Resultados en: $RESULTS"
echo "=================================================="

