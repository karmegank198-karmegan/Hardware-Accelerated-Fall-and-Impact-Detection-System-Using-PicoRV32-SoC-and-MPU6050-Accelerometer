# Hardware-Accelerated Fall and Impact Detection System Using PicoRV32 SoC and MPU6050

# Project Overview

The **Hardware-Accelerated Fall and Impact Detection System** is an FPGA-based embedded system designed to detect falls, free-fall events, and sudden impacts using an MPU6050 accelerometer and gyroscope sensor.

The system integrates a **PicoRV32 RISC-V soft processor**, custom Verilog hardware peripherals, an MPU6050 I²C interface, and embedded C firmware to provide real-time fall detection.

Hardware acceleration enables detection-related operations to be performed by dedicated FPGA logic, reducing the processing burden on the RISC-V processor.

The project includes Verilog RTL modules, simulation testbenches, and embedded C firmware for hardware-software integration.

# Objectives

- Interface the MPU6050 sensor with an FPGA using I²C communication.
- Integrate the PicoRV32 RISC-V processor for embedded control.
- Implement hardware-based fall, free-fall, and impact detection.
- Develop memory-mapped peripherals for processor-to-hardware communication.
- Display detection events using onboard FPGA LEDs.
- Transmit sensor and detection information through UART.
- Verify system functionality using Verilog simulation testbenches.

# System Architecture

The system consists of the following major components:

1. **MPU6050 Sensor:** Provides acceleration and gyroscope measurements.
2. **I²C Controller:** Reads sensor data through the SDA and SCL lines.
3. **Fall Detection Hardware:** Processes acceleration information and generates detection flags.
4. **PicoRV32 Processor:** Executes embedded C firmware and accesses memory-mapped peripherals.
5. **UART Interface:** Provides serial output for monitoring system information.
6. **FPGA LEDs:** Indicate alarm, free-fall, and impact events.

### System Flow

```text
         MPU6050 Sensor
                |
          I²C Interface
           SDA / SCL
                |
                v
       FPGA Sensor Controller
                |
                v
       Acceleration Data
                |
          +-----+------+
          |            |
          v            v
    Fall Detection   PicoRV32
      Hardware       Processor
          |            |
          v            v
      Event Flags   Embedded C
          |         Firmware
          v            |
    +-----+------+     v
    |     |      |   UART Output
    v     v      v
  Alarm Free-  Impact
   LED  Fall LED LED
