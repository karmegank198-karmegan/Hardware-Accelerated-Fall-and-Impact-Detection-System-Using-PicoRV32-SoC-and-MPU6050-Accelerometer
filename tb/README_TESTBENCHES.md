# ModelSim / Questa testbenches (no hardware required)

## Tests
- `tb_fall_detector.sv`: actual detector; REST → FREE FALL → IMPACT, automatic checks, short hold time.
- `tb_fall_peripheral.sv`: reads status, signed X, packed Y/Z via CPU memory map.
- `tb_mpu6050_i2c.sv`: **state-aware behavioral** virtual sensor. Models ACK/data against RTL internal states; not a fully protocol-accurate MPU6050 slave. Check `error` and data values. This may expose bugs in I2C master.
- `tb_picosoc_fall.sv`: injects MPU6050-like acceleration values into internal sensor outputs using `force`, then checks detector and LED outputs. **Bypasses real I2C and CPU firmware**.
- `tb_fall_fpga_top.sv`: same sensor-sample injection through actual top module, checks LED pins after reset counter.

The CPU/SoC support RTL (`picorv32.v`, `picosoc.v`, `spimemio.v`, `simpleuart.v`, `ice40up5k_spram.v`) is compiled as part of integration tests. They are not individually functionally verified here; CPU boot/UART tests require a suitable compiled firmware image and SPI flash model.

## ModelSim
From the project directory (folder containing `rtl/` and `tb/`):
```
vlib work
vlog -sv rtl/*.v tb/*.sv
vsim work.tb_fall_detector
add wave -r sim:/tb_fall_detector/*
run -all
```
Repeat `vsim work.tb_fall_peripheral`, `vsim work.tb_mpu6050_i2c`, `vsim work.tb_picosoc_fall`, or `vsim work.tb_fall_fpga_top`. Run one TB at a time.

## Synthetic MPU6050 data (+/-4g, 8192 LSB/g)
- Rest: X=0, Y=0, Z=8192
- Free fall: X=100, Y=150, Z=200
- Impact: X=16000, Y=12000, Z=8000

Note: detector uses L1 (|X|+|Y|+|Z|), not Euclidean magnitude. Its free_fall is latched until impact; alarm is asserted only for impact after free fall. These tests are simulation-only and do not establish physical sensor correctness or FPGA synthesis success.
