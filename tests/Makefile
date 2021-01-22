TOPLEVEL_LANG = systemverilog
SRC_DIR = ../src
VERILOG_SOURCES  = $(foreach sdir,$(SRC_DIR),$(wildcard $(sdir)/*.sv))
#TOPLEVEL = midi_ctrl
MODULE = test_midi_ctrl
COMPILE_ARGS = -P midi_ctrl.BAUD_CNT_HALF=32 -P midi_ctrl.DEBOUNCE_CNT=10
SIM = icarus

include $(shell cocotb-config --makefiles)/Makefile.sim
