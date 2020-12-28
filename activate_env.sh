#!/usr/bin/env bash

# Instructions from
# https://symbiflow-examples.readthedocs.io/en/latest/building-examples.html

export ROOT_DIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
export ENV_DIR=${ROOT_DIR}/env
export INSTALL_DIR=${ENV_DIR}/symbiflow
export FPGA_FAM=xc7
export PATH="$INSTALL_DIR/$FPGA_FAM/install/bin:$PATH";

source "$INSTALL_DIR/$FPGA_FAM/conda/etc/profile.d/conda.sh"
conda activate $FPGA_FAM
