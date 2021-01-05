MIDI controller on Xilinx Arty A7 FPGA board
=============================================

Setting up on Linux.
---------------------

```
./setup_env.sh
```

This will install `symbiflow`, required packages and set up working
environment using `conda`.

After that you can compile and upload the bitstream to the connected device:

```
source activate_env.sh
make
```

Another way of uploading is:

```
make upload
```

Or:

```
xc3sprog -c nexys4 build/top.bit
```

Tested on Arch Linux.

Simulation
-----------

Install `iverilog` and `gtkwave` packages. Then:

```
iverilog -g2012 -I. midi_ctrl_tb.sv midi_ctrl.sv
vvp a.out
gtkwave test.vcd
```
