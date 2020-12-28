#!/usr/bin/env bash

pushd build/arty_35
openocd -f ${INSTALL_DIR}/${FPGA_FAM}/conda/envs/${FPGA_FAM}/share/openocd/scripts/board/digilent_arty.cfg -c "init; pld load 0 midi_ctrl.bit; exit"
popd
