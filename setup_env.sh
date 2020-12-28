#!/usr/bin/env bash

# Instructions from
# https://symbiflow-examples.readthedocs.io/en/latest/getting-symbiflow.html

export ROOT_DIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
export ENV_DIR=${ROOT_DIR}/env
export INSTALL_DIR=${ENV_DIR}/symbiflow
export FPGA_FAM=xc7

mkdir -p ${ENV_DIR}
pushd ${ENV_DIR}

export CONDA_SCRIPT=conda_installer.sh
if [ -f "$CONDA_SCRIPT" ]; then
    echo "$CONDA_SCRIPT already downloaded."
else
    wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ${CONDA_SCRIPT}
fi
bash ${CONDA_SCRIPT} -u -b -p ${INSTALL_DIR}/${FPGA_FAM}/conda;
source "$INSTALL_DIR/$FPGA_FAM/conda/etc/profile.d/conda.sh";
conda env create -f ${ROOT_DIR}/$FPGA_FAM/environment.yml

echo "downloading packages ..."
mkdir -p $INSTALL_DIR/xc7/install
wget -qO- https://storage.googleapis.com/symbiflow-arch-defs/artifacts/prod/foss-fpga-tools/symbiflow-arch-defs/continuous/install/112/20201208-080919/symbiflow-arch-defs-install-7c1267b7.tar.xz | tar -xJC $INSTALL_DIR/xc7/install
wget -qO- https://storage.googleapis.com/symbiflow-arch-defs/artifacts/prod/foss-fpga-tools/symbiflow-arch-defs/continuous/install/112/20201208-080919/symbiflow-arch-defs-xc7a50t_test-7c1267b7.tar.xz | tar -xJC $INSTALL_DIR/xc7/install
echo "done"

popd
