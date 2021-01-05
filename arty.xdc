## Master Clock: 100 MHz
set_property PACKAGE_PIN E3 [get_ports {clk}]
set_property IOSTANDARD LVCMOS33 [get_ports {clk}]

## LEDs
set_property PACKAGE_PIN H5 [get_ports {led1}]
set_property IOSTANDARD LVCMOS33 [get_ports {led1}]
set_property PACKAGE_PIN J5 [get_ports {led2}]
set_property IOSTANDARD LVCMOS33 [get_ports {led2}]

## Buttons
set_property PACKAGE_PIN D9 [get_ports {btn1}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn1}]
set_property PACKAGE_PIN C9 [get_ports {btn2}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn2}]
set_property PACKAGE_PIN B9 [get_ports {btn3}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn3}]
set_property PACKAGE_PIN B8 [get_ports {btn4}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn4}]

## Reset Button
set_property PACKAGE_PIN C2 [get_ports {rst}]
set_property IOSTANDARD LVCMOS33 [get_ports {rst}]

## MIDI out
set_property PACKAGE_PIN G13 [get_ports {midi_tx}]
set_property IOSTANDARD LVCMOS33 [get_ports {midi_tx}]

## Clocks
create_clock -period 10.0 [get_ports {clk}]
