## Master Clock: 100 MHz
set_property PACKAGE_PIN E3 [get_ports {clk}]
set_property IOSTANDARD LVCMOS33 [get_ports {clk}]

## LEDs
set_property PACKAGE_PIN H5 [get_ports {led}]
set_property IOSTANDARD LVCMOS33 [get_ports {led}]

## Buttons
set_property PACKAGE_PIN D9 [get_ports {btn}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn}]

## Reset Button
set_property PACKAGE_PIN C2 [get_ports {rst}]
set_property IOSTANDARD LVCMOS33 [get_ports {rst}]

## MIDI out
set_property PACKAGE_PIN A1 [get_ports {midi_tx}]
set_property IOSTANDARD LVCMOS33 [get_ports {midi_tx}]

## Clocks
create_clock -period 10.0 [get_ports {clk}]
