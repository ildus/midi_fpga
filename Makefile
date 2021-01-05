PRJNAME  = midi_ctrl
TOPLEVEL = midi_ctrl
SOURCES  = midi_ctrl.sv
SOURCES_TB = midi_ctrl_tb.sv
XDC      = arty.xdc

# Don't change anything below this line
ARCH     = xc7
#PART     = xc7a100tcsg324-1
#PART 	  = xc7a35ticsg324-1L
BUILDDIR = build

all: ${BUILDDIR}/top.bit

${BUILDDIR}:
	mkdir -p ${BUILDDIR}

${BUILDDIR}/top.bit: ${BUILDDIR}/top.v ${XDC}
	cp ${XDC} ${BUILDDIR}/top.xdc
	cp build_top.sh ${BUILDDIR}/
	cp build.tcl ${BUILDDIR}/
	cd ${BUILDDIR} && ${SHELL} build_top.sh

${BUILDDIR}/top.v: ${BUILDDIR}/a.out ${XDC}
	cp ${SOURCES} $@
	#yosys -p "read_verilog -sv ${SOURCES}; synth_xilinx -flatten -nobram -arch $(ARCH) -top $(TOPLEVEL); rename -top top; write_verilog $@"

simulation: ${BUILDDIR}/a.out

${BUILDDIR}/a.out: $(SOURCES) | ${BUILDDIR}
	cp ${SOURCES} ${BUILDDIR}/
	cp ${SOURCES_TB} ${BUILDDIR}/
	cd ${BUILDDIR} && iverilog -g2012 -I. ${SOURCES} ${SOURCES_TB}

clean:
	rm -rf ${BUILDDIR}
