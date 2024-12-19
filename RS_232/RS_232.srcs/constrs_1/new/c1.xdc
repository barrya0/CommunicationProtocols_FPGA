set_property PACKAGE_PIN W5 [get_ports clk]
#set_property IO_STANDARD LVCMOS33 [get_ports clk]
create_clock -period 40.000 -name clk -waveform {0.000 20.000} [get_ports clk]
