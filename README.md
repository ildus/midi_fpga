MIDI controller on Xilinx Arty A7 FPGA board
=============================================

Getting started
---------------

`yosys`, `vivado`, `openocd` and `iverilog` packages are needed.

Compilation:

```
make
```

Upload the bitstream to Arty A7:

```
make upload
```

Or:

```
xc3sprog -c nexys4 build/top.bit
```

Look for any detals in Makefile. Tested on Arch Linux.

Simulation
-----------

Install `iverilog` and `gtkwave` packages. Then:

```
make sim
```
