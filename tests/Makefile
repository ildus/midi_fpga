TOPLEVEL_LANG = systemverilog
VERILOG_SOURCES = ../midi_ctrl.sv ../debounce.v
TOPLEVEL = midi_ctrl
MODULE = test_midi_ctrl
COMPILE_ARGS = -P midi_ctrl.BAUD_CNT_HALF=32 -P midi_ctrl.DEBOUNCE_CNT=10

include $(shell cocotb-config --makefiles)/Makefile.sim
