#!/bin/bash
#SBATCH -J edm2
#SBATCH -o watch_folder/%x_%j.out     # output file (%j expands to jobID)
#SBATCH --error=./slurm_logs/%x_%j.error
#SBATCH -N 1                          # Total number of nodes requested
#SBATCH --get-user-env                # retrieve the users login environment
#SBATCH --mem=20G
#SBATCH -t 4:00:00                    # Time limit (hh:mm:ss)
#SBATCH --qos=m3
#SBATCH --partition=a40
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1                  # Type/number of GPUs needed
#SBATCH -c 1  
#SBATCH --open-mode=append            # Do not overwrite logs
#SBATCH --requeue                     # Requeue upon pre-emption
#SBATCH --array=0-19
#SBATCH --signal=SIGUSR1@120

source $HOME/.bashrc
source "$(dirname "$0")/config.sh"
conda activate "$CONDA_ENV"

export PYTHONPATH=$PYTHONPATH:"$REPO_ROOT"

SCRATCH_DIR="$OUTPUTS_DIR"

MODE="fkc"  # "fkc" or "cfg"

NUM_SAMPLES=500
steps=64
s_churn=40
BS=8

name=steps${steps}_churn${s_churn}_bs${BS}

if [ "$MODE" = "fkc" ]; then
    outdir=$SCRATCH_DIR/fkc_$name
    python "$REPO_ROOT/generate_images.py" \
          --preset=edm2-img512-xs-guid-fid --outdir=$outdir \
          --subdirs --seeds=$(($SLURM_ARRAY_TASK_ID * $BS * $NUM_SAMPLES))-$(($SLURM_ARRAY_TASK_ID * $BS * $NUM_SAMPLES + $NUM_SAMPLES * $BS - 1)) \
          --steps=$steps --fkc --S_churn $s_churn --batch $BS
else
    outdir=$SCRATCH_DIR/cfg_$name
    python "$REPO_ROOT/generate_images.py" \
          --preset=edm2-img512-xs-guid-fid --outdir=$outdir \
          --subdirs --seeds=$(($SLURM_ARRAY_TASK_ID * $NUM_SAMPLES))-$(($SLURM_ARRAY_TASK_ID * $NUM_SAMPLES + $NUM_SAMPLES - 1)) \
          --steps=$steps --S_churn $s_churn
fi
echo $outdir
