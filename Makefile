PRJNAME  = midi_ctrl
TOPLEVEL = midi_ctrl
SOURCES  = midi_ctrl.sv debounce.v
SOURCES_TB = midi_ctrl_tb.sv
XDC      = arty.xdc

ARCH     = xc7
BUILDDIR = build

all: ${BUILDDIR}/top.bit

${BUILDDIR}:
	mkdir -p ${BUILDDIR}

${BUILDDIR}/top.bit: ${BUILDDIR}/top.sv ${XDC} build.tcl build_top.sh
	cp ${XDC} ${BUILDDIR}/top.xdc
	cp build_top.sh ${BUILDDIR}/
	cp build.tcl ${BUILDDIR}/
	cd ${BUILDDIR} && ${SHELL} build_top.sh

${BUILDDIR}/top.sv: ${BUILDDIR}/a.out ${XDC}
	#cat ${SOURCES} > $@
	yosys -p "read_verilog -sv ${SOURCES}; synth -flatten -lut -abc9 -auto-top; rename -top top; write_verilog $@"

sim: ${BUILDDIR}/a.out
	cd ${BUILDDIR} && vvp a.out && gtkwave test.vcd

${BUILDDIR}/a.out: $(SOURCES) | ${BUILDDIR}
	cp ${SOURCES} ${BUILDDIR}/
	cp ${SOURCES_TB} ${BUILDDIR}/
	cd ${BUILDDIR} && xvlog -sv ${SOURCES}
	cd ${BUILDDIR} && iverilog -g2012 -I. ${SOURCES} ${SOURCES_TB}

clean:
	rm -rf ${BUILDDIR}

upload:
	openocd -f env/symbiflow/${ARCH}/conda/envs/${ARCH}/share/openocd/scripts/board/digilent_arty.cfg -c "init; pld load 0 ${BUILDDIR}/top.bit; exit"
