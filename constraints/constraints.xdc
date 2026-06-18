set_property -dict {PACKAGE_PIN A20 IOSTANDARD LVCMOS33} [get_ports {trig}];
set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVCMOS33} [get_ports {echo}];

set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS33} [get_ports {debug_uart_tx}];

set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports {clk}];
create_clock -name clk -period 83.33 [get_ports {clk}];

set_property CFGBVS VCCO [current_design];
set_property CONFIG_VOLTAGE 3.3 [current_design];
