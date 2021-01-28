PRJNAME  = midi_ctrl
SRC_DIR = src
XDC      = xc7/arty.xdc
PCF      = ice40/ice40hx1.pcf
BUILDDIR = build
BUILDDIR_ARTY = ${BUILDDIR}/arty
BUILDDIR_ICE40 = ${BUILDDIR}/ice40
SOURCES  = $(wildcard ${SRC_DIR}/*.sv)
FILES = $(subst src/,,${SOURCES})
export TOPLEVEL = midi_ctrl

.PHONY: all
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
	#cd ${BUILDDIR} && xvlog -sv ${FILES}
	cd ${BUILDDIR} && iverilog -g2012 -I. ${FILES}

upload_xc7: ${BUILDDIR_ARTY}/top.bit
	openocd -f xc7/digilent_arty.cfg -c "init; pld load 0 ${BUILDDIR_ARTY}/top.bit; exit"

PADDED=${BUILDDIR_ICE40}/padded.bin

upload_ice40: ${PADDED}
	scp ${PADDED} banana:~/${PRJNAME}.bin
	ssh banana 'echo 25 > /sys/class/gpio/export && echo out > /sys/class/gpio/gpio25/direction'
	ssh banana 'gpio load spi'
	ssh banana 'flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=20000 -w ~/${PRJNAME}.bin'
	ssh banana 'echo in > /sys/class/gpio/gpio25/direction && echo 25 > /sys/class/gpio/unexport'

${PADDED}: ${BUILDDIR_ICE40}/${PRJNAME}.bin
	rm -f ${PADDED}
	truncate -s 2M ${PADDED}
	dd if=${BUILDDIR_ICE40}/${PRJNAME}.bin conv=notrunc of=${PADDED}
	python3 write_default.py ${PADDED}

${BUILDDIR_ICE40}/${PRJNAME}.bin: ${BUILDDIR_ICE40}/${PRJNAME}.asc
	icepack ${BUILDDIR_ICE40}/${PRJNAME}.asc ${BUILDDIR_ICE40}/${PRJNAME}.bin

${BUILDDIR_ICE40}/${PRJNAME}.asc: ${BUILDDIR_ICE40}/${PRJNAME}.json ${PCF}
	nextpnr-ice40 --hx1k --package vq100 --json ${BUILDDIR_ICE40}/${PRJNAME}.json --pcf ${PCF}  --asc $@

${BUILDDIR_ICE40}/${PRJNAME}.json: ${BUILDDIR}/a.out
	yosys -p "read_verilog -sv ${SOURCES}; synth_ice40 -top ${TOPLEVEL} -json $@"

.PHONY: check
check:
	+make -C tests

.PHONY: clean
clean:
	rm -rf ${BUILDDIR}
