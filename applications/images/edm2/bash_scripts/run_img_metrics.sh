#!/bin/bash
#SBATCH --time=1:30:00
#SBATCH --mem=50G
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=4
#SBATCH --job-name=fkc_images
#SBATCH --qos=m4
#SBATCH --output=./slurm_logs/eval_%j.out
#SBATCH --error=./slurm_logs/eval_%j.error
#SBATCH --requeue
#SBATCH --array=0-9
#SBATCH --exclude=gpu094,gpu084

source $HOME/.bashrc
source "$(dirname "$0")/config.sh"
conda activate "$CONDA_ENV"

#start=$SLURM_ARRAY_TASK_ID
start=$((SLURM_ARRAY_TASK_ID * 1000))

end=$((SLURM_ARRAY_TASK_ID + 1))
end=$((end * 1000))
# cfg_v2tara_64_80
DIR=$1
#DIR="cfg_v2tara_32_80"
mkdir -p "img_metrics/${DIR}"

OUTFILE="img_metrics/${DIR}/${DIR}_${SLURM_ARRAY_TASK_ID}.csv"

if [[ -f "$OUTFILE" ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $OUTFILE already exists, exiting."
  exit 0
fi
python3 "$REPO_ROOT/img_metrics.py" --img_dir "$OUTPUTS_DIR/${DIR}" --save_path "img_metrics/${DIR}/${DIR}_${SLURM_ARRAY_TASK_ID}.csv" --start=$start --end=$end
#python3 img_metrics.py --img_dir "/h/mskrt/fkc-diffusion/applications/images/edm2/outputs/${DIR}" --save_path $OUTFILE --start=$start --end=$end
#python3 img_metrics.py --img_dir "/scratch/ssd004/scratch/mskrt/fkc/edm_imgs/${DIR}" --save_path "img_metrics/${DIR}/${DIR}_${SLURM_ARRAY_TASK_ID}.csv" --start=$start --end=$end
