#!/bin/bash
#SBATCH -J edm2
#SBATCH -o watch_folder/%x_%j.out     # output file (%j expands to jobID)
#SBATCH -N 1                          # Total number of nodes requested
#SBATCH --get-user-env                # retrieve the users login environment
#SBATCH --mem=8G
#SBATCH -t 1:00:00                    # Time limit (hh:mm:ss)
#SBATCH --partition=main
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:a100l:1            # Type/number of GPUs needed
#SBATCH -c 1  
#SBATCH --open-mode=append            # Do not overwrite logs
#SBATCH --requeue                     # Requeue upon pre-emption
#SBATCH --array=0
#SBATCH --signal=SIGUSR1@120


source "$(dirname "$0")/config.sh"

MODE="fkc"  # "fkc" or "cfg"

NUM_SAMPLES=10000
steps=32
s_churn=10
BS=$1
SLURM_ARRAY_TASK_ID=0

if [ "$MODE" = "fkc" ]; then
    outdir=fkc_classlabels_${NUM_SAMPLES}_bs${BS}
    python "$REPO_ROOT/generate_class_labels.py" \
          --preset=edm2-img512-xs-guid-fid --outdir=$outdir \
          --subdirs --seeds=$(($SLURM_ARRAY_TASK_ID * $BS * $NUM_SAMPLES))-$(($SLURM_ARRAY_TASK_ID * $BS * $NUM_SAMPLES + $NUM_SAMPLES * $BS - 1)) \
          --steps=$steps --fkc --S_churn $s_churn --batch $BS
else
    outdir=cfg_classlabels_${NUM_SAMPLES}_bs${BS}
    python "$REPO_ROOT/generate_class_labels.py" \
          --preset=edm2-img512-xs-guid-fid --outdir=$outdir \
          --subdirs --seeds=$(($SLURM_ARRAY_TASK_ID * $NUM_SAMPLES))-$(($SLURM_ARRAY_TASK_ID * $NUM_SAMPLES + $NUM_SAMPLES - 1)) \
          --steps=$steps --S_churn $s_churn
fi
echo $outdir
