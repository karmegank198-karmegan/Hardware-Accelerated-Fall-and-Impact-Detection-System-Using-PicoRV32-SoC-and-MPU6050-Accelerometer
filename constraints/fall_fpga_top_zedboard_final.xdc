## ZedBoard constraints for fall_fpga_top.v
## Pin locations are based on Digilent's ZedBoard Master XDC.
## Top-level ports: clk100, btnC, ser_rx, ser_tx, i2c_sda, i2c_scl,
## led_alarm, led_free_fall, led_impact.

## 100 MHz PL clock
set_property PACKAGE_PIN Y9 [get_ports {clk100}]
set_property IOSTANDARD LVCMOS33 [get_ports {clk100}]
create_clock -name clk100 -period 10.000 [get_ports {clk100}]

## Center pushbutton (ZedBoard bank 34 is configured for 1.8 V by default)
set_property PACKAGE_PIN P16 [get_ports {btnC}]
set_property IOSTANDARD LVCMOS18 [get_ports {btnC}]

## User LEDs: LD0, LD1, LD2
set_property PACKAGE_PIN T22 [get_ports {led_alarm}]
set_property PACKAGE_PIN T21 [get_ports {led_free_fall}]
set_property PACKAGE_PIN U22 [get_ports {led_impact}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_alarm led_free_fall led_impact}]

## Pmod JA pins for MPU6050 I2C
## JA1 = Y11 -> SDA; JA2 = AA11 -> SCL
set_property PACKAGE_PIN Y11 [get_ports {i2c_sda}]
set_property PACKAGE_PIN AA11 [get_ports {i2c_scl}]
set_property IOSTANDARD LVCMOS33 [get_ports {i2c_sda i2c_scl}]

## Pmod JA pins for UART signals (requires an external 3.3 V USB-to-UART adapter)
## JA3 = Y10 -> ser_rx; JA4 = AA9 -> ser_tx
set_property PACKAGE_PIN Y10 [get_ports {ser_rx}]
set_property PACKAGE_PIN AA9 [get_ports {ser_tx}]
set_property IOSTANDARD LVCMOS33 [get_ports {ser_rx ser_tx}]
