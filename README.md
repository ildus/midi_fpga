MIDI footswitch controller on iCE40HX1K-EVB
=============================================

Description
-----------

MIDI footswitch controller with four SPDT buttons. Supports MIDI OUT for
controlling other devices and MIDI IN to teach buttons what MIDI commands
should be send. Two LEDs indicate current processes.

Teaching is simple, connect other device's MIDI OUT to MIDI IN of footswitch
controller, trigger signal on the other device (LED2 will indicate that our
controller got the signal) and push one of the buttons and it'll accociate
the button with MIDI command.

MIDI IN and MIDI OUT schematics should be based on 3.3V (not 5V) as usual.

Getting started
---------------

Latest versions of `yosys`, `icestorm`, `nextpnr` and `iverilog` packages
are needed.

Compilation:

```
make ice40
```

Uploading is done through my Banana PI (Raspberry PI alternative), I copy
the bitstream using ssh to BPI, and I use flashrom to write the bitstream to the
flash chip on dev board. The command does all that:

```
make upload_ice40
```

Look for any detals in Makefile. Tested on Arch Linux.

Footswitches are 3-pin SPDT, center pin goes to GND, other pins go to pins
in GPIO, look which pins to use in `ice40/ice40hx1.pcf`. To determine physical
locations of pins the `iCE40HX1K-EVB` schematic will be needed, which can be found
[here](https://github.com/OLIMEX/iCE40HX1K-EVB/blob/master/iCE40HX1K-EVB_Rev_B.pdf).

Tests
-----------

```
pip install cocotb
make check
```

For simulation install `gtkwave` package and run `make check` with `TESTCASE`
option. `TESTCASE` is a name of function in `tests/test_midi_ctrl.py`.
After that run:

```
gtkwave tests/midi_ctrl.vcd
```
