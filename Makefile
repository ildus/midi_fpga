PRJNAME  = midi_ctrl
TOPLEVEL = midi_ctrl
SOURCES  = midi_ctrl.sv debounce.v
SOURCES_TB = midi_ctrl_tb.sv
XDC      = xc7/arty.xdc
PCF      = ice40/ice40hx1.pcf
BUILDDIR = build
BUILDDIR_ARTY = ${BUILDDIR}/arty
BUILDDIR_ICE40 = ${BUILDDIR}/ice40

all: xc7 ice40
xc7: ${BUILDDIR_ARTY}/top.bit
ice40: ${BUILDDIR_ICE40}/${PRJNAME}.bin

${BUILDDIR}:
	mkdir -p ${BUILDDIR}
	mkdir -p ${BUILDDIR_ARTY}
	mkdir -p ${BUILDDIR_ICE40}

${BUILDDIR_ARTY}/top.bit: ${BUILDDIR_ARTY}/top.sv ${XDC} build.tcl build_top.sh
	cp ${XDC} ${BUILDDIR_ARTY}/top.xdc
	cp build_top.sh ${BUILDDIR_ARTY}/
	cp build.tcl ${BUILDDIR_ARTY}/
	cd ${BUILDDIR_ARTY} && ${SHELL} build_top.sh

${BUILDDIR_ARTY}/top.sv: ${BUILDDIR}/a.out
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

upload_xc7: ${BUILDDIR_ARTY}/top.bit
	openocd -f xc7/digilent_arty.cfg -c "init; pld load 0 ${BUILDDIR_ARTY}/top.bit; exit"

upload_ice40: ${BUILDDIR_ICE40}/${PRJNAME}.bin
	rm -f ${BUILDDIR_ICE40}/padded_binary
	truncate -s 2M ${BUILDDIR_ICE40}/padded_binary
	dd if=${BUILDDIR_ICE40}/${PRJNAME}.bin conv=notrunc of=padded_binary
	scp padded_binary banana:~/${PRJNAME}.bin

${BUILDDIR_ICE40}/${PRJNAME}.bin: ${BUILDDIR_ICE40}/${PRJNAME}.asc
	icepack ${BUILDDIR_ICE40}/${PRJNAME}.asc ${BUILDDIR_ICE40}/packed.bin

${BUILDDIR_ICE40}/${PRJNAME}.asc: ${BUILDDIR_ICE40}/${PRJNAME}.json ${PCF}
	nextpnr-ice40 --hx1k --package vq100 --json ${BUILDDIR_ICE40}/${PRJNAME}.json --pcf ${PCF}  --asc $@

${BUILDDIR_ICE40}/${PRJNAME}.json: ${BUILDDIR}/a.out
	yosys -p "read_verilog -sv ${SOURCES}; synth_ice40 -top ${TOPLEVEL} -json $@"

check:
	+make -C tests SIM=icarus
