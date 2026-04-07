#!/bin/bash
# User-specific paths. Edit before running.

CONDA_ENV="${CONDA_ENV:-<INSERT_PATH_HERE>}"

export HF_HOME="${HF_HOME:-<INSERT_PATH_HERE>}"
export MODELSCOPE_CACHE="${MODELSCOPE_CACHE:-<INSERT_PATH_HERE>}"

# Root of the edm2 directory (parent of bash_scripts/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OUTPUTS_DIR="${OUTPUTS_DIR:-${REPO_ROOT}/outputs}"
