# EDM2 + FKC Image Generation

## Step 1: Models and Environment

See the [original EDM2 repo](https://github.com/NVlabs/edm2) for model checkpoints and environment setup.

## Configuration

Before running any scripts, edit `bash_scripts/config.sh` to set your environment paths:

```bash
CONDA_ENV=/path/to/conda/env
HF_HOME=/path/to/huggingface/cache
MODELSCOPE_CACHE=/path/to/modelscope/cache
OUTPUTS_DIR=/path/to/outputs  # default: <repo_root>/outputs
```

These can also be overridden at call time, e.g. `OUTPUTS_DIR=/my/dir sbatch bash_scripts/generate_images.sh`.

## Step 2: Generate Class Labels

Run `generate_class_labels.py` to pre-sample the class label assigned to each seed. This is a lightweight pass (no diffusion) that saves `class_idx.npy` and `seeds.npy` to the output directory for use during evaluation.

Set `MODE="fkc"` or `MODE="cfg"` at the top of `bash_scripts/generate_class_labels.sh`, then:

```bash
# Adjust BS for batch size; saves to fkc_classlabels_10000_bs<BS>/ or cfg_classlabels_10000_bs<BS>/
sbatch bash_scripts/generate_class_labels.sh <BS>
```

## Step 3: Inference

Generate images using either FKC sampling or CFG (baseline). Seeds and class label assignments are deterministic and match Step 2.

Set `MODE="fkc"` or `MODE="cfg"` at the top of `bash_scripts/generate_images.sh`, then:

```bash
# Array job: 20 tasks x 500 samples x BS=8 = 80k images
sbatch bash_scripts/generate_images.sh
```

Key options in `generate_images.py`:
- `--fkc` — enable FKC sampler
- `--steps` — number of diffusion steps
- `--S_churn` — stochasticity parameter
- `--batch` — batch size for FKC

## Step 4: Evaluation

Compute image metrics (e.g. FID, DINO) over generated images. Results are saved as CSV files under `img_metrics/<DIR>/`.

```bash
# DIR is the output subdirectory name from Step 3
sbatch bash_scripts/run_img_metrics.sh <DIR>
```

To aggregate results across array tasks:

```bash
python compile_edm_metrics.py
```
