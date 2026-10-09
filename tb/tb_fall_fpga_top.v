```verilog
`timescale 1ns / 1ps

module tb_fall_fpga_top;

    // --------------------------------------------------
    // Testbench inputs
    // --------------------------------------------------
    reg clk100 = 1'b0;
    reg btnC   = 1'b1;
    reg ser_rx = 1'b1;

    // Simulated MPU6050 acceleration inputs
    reg signed [15:0] sim_ax = 16'sd0;
    reg signed [15:0] sim_ay = 16'sd0;
    reg signed [15:0] sim_az = 16'sd16384;

    // I2C bus
    tri1 i2c_sda;
    tri1 i2c_scl;

    // DUT outputs
    wire ser_tx;
    wire led_alarm;
    wire led_free_fall;
    wire led_impact;

    // 100 MHz clock: 10 ns period
    always #5 clk100 = ~clk100;

    // --------------------------------------------------
    // Device Under Test
    // --------------------------------------------------
    fall_fpga_top #(
        .CLK_FREQ_HZ(100000000)
    ) dut (
        .clk100        (clk100),
        .btnC          (btnC),
        .ser_rx        (ser_rx),
        .ser_tx        (ser_tx),
        .i2c_sda       (i2c_sda),
        .i2c_scl       (i2c_scl),
        .led_alarm     (led_alarm),
        .led_free_fall (led_free_fall),
        .led_impact    (led_impact)
    );

    // --------------------------------------------------
    // Simulated MPU6050 sensor
    // --------------------------------------------------
    mpu6050_sim_model sensor_model (
        .sda    (i2c_sda),
        .scl    (i2c_scl),
        .resetn (dut.resetn),
        .sim_ax (sim_ax),
        .sim_ay (sim_ay),
        .sim_az (sim_az)
    );

    // --------------------------------------------------
    // Test sequence
    // --------------------------------------------------
    initial begin
        $dumpfile("tb_fall_fpga_top.vcd");
        $dumpvars(0, tb_fall_fpga_top);

        $display("----------------------------------------");
        $display("Fall Detection System Simulation");
        $display("----------------------------------------");

        // Apply reset
        btnC = 1'b1;
        repeat (10) @(posedge clk100);

        // Release reset
        @(negedge clk100);
        btnC = 1'b0;

        wait (dut.resetn === 1'b1);
        $display("[%0t] Reset released", $time);

        // Allow sensor initialization and I2C activity
        #2000000;

        // ----------------------------------------------
        // Test 1: Normal acceleration
        // ----------------------------------------------
        $display("[%0t] TEST 1: Normal acceleration", $time);

        sim_ax = 16'sd0;
        sim_ay = 16'sd0;
        sim_az = 16'sd16384;

        #2000000;

        $display("Normal: alarm=%b free_fall=%b impact=%b",
                 led_alarm, led_free_fall, led_impact);

        // ----------------------------------------------
        // Test 2: Free fall
        // ----------------------------------------------
        $display("[%0t] TEST 2: Free fall", $time);

        sim_ax = 16'sd0;
        sim_ay = 16'sd0;
        sim_az = 16'sd1000;

        #2000000;

        $display("Free fall: alarm=%b free_fall=%b impact=%b",
                 led_alarm, led_free_fall, led_impact);

        // ----------------------------------------------
        // Test 3: Impact after free fall
        // ----------------------------------------------
        $display("[%0t] TEST 3: Impact after free fall", $time);

        sim_ax = 16'sd0;
        sim_ay = 16'sd0;
        sim_az = 16'sd28000;

        #2000000;

        $display("Impact: alarm=%b free_fall=%b impact=%b",
                 led_alarm, led_free_fall, led_impact);

        // ----------------------------------------------
        // Finish
        // ----------------------------------------------
        $display("----------------------------------------");
        $display("Simulation completed");
        $display("----------------------------------------");

        $finish;
    end

    // Simulation timeout
    initial begin
        #10000000;
        $display("Simulation timeout");
        $finish;
    end

endmodule
```
