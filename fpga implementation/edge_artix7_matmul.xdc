## ============================================================================
## Edge Artix 7 FPGA Board — Matrix Multiplier Constraints
## ============================================================================
## Board:  Edge Artix 7 (XC7A35T-1FTG256C)
## Clock:  50 MHz on-board oscillator
## UART:   USB-to-UART converter (115200 baud)
## ============================================================================

## ── Clock (50 MHz) ─────────────────────────────────────────────────
set_property -dict { PACKAGE_PIN N11  IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk -period 20.000 -waveform {0 10} [get_ports { clk }];

## ── Reset push button (active-high, active when pressed) ───────────
## Using center push button (active-high with on-board pull-down)
set_property -dict { PACKAGE_PIN M14  IOSTANDARD LVCMOS33  PULLDOWN true } [get_ports { rst_btn }];

## ── USB UART ───────────────────────────────────────────────────────
## uart_txd = FPGA TX output → USB chip → PC
## uart_rxd = FPGA RX input  ← USB chip ← PC
set_property -dict { PACKAGE_PIN C4   IOSTANDARD LVCMOS33 } [get_ports { uart_txd }];
set_property -dict { PACKAGE_PIN D4   IOSTANDARD LVCMOS33 } [get_ports { uart_rxd }];

## ── Status LEDs ────────────────────────────────────────────────────
## led[0] = heartbeat (~1 Hz blink = board alive)
## led[1] = computing (high during matrix multiplication)
## led[2] = UART active (high while receiving or transmitting)
set_property -dict { PACKAGE_PIN J3   IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN H3   IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS33 } [get_ports { led[2] }];

## ── Bitstream configuration ────────────────────────────────────────
set_property CFGBVS VCCO [current_design];
set_property CONFIG_VOLTAGE 3.3 [current_design];
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design];
