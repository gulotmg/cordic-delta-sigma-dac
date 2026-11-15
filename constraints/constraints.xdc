set_property -dict { PACKAGE_PIN H4  IOSTANDARD LVCMOS33 } [get_ports { CLK }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { CLK }];

set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports pdm_out]; # FPGA_IO0
set_property SLEW SLOW [get_ports pdm_out]
set_property DRIVE 4 [get_ports pdm_out]

set_property -dict { PACKAGE_PIN E11 IOSTANDARD LVCMOS33 } [get_ports interrupt]; # FPGA_IO9
set_property SLEW SLOW [get_ports interrupt]
set_property DRIVE 4 [get_ports interrupt]
