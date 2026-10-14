

`timescale 1ns / 1ps

module fall_fpga_top #(
    parameter integer CLK_FREQ_HZ = 100000000
)(
    input  wire clk100,
    input  wire btnC,

    input  wire ser_rx,
    output wire ser_tx,

    inout  wire i2c_sda,
    inout  wire i2c_scl,

    output wire led_alarm,
    output wire led_free_fall,
    output wire led_impact
);

    // --------------------------------------------------
    // Use the ZedBoard 100 MHz clock directly
    // --------------------------------------------------

    wire clk_sys;
    assign clk_sys = clk100;

    // --------------------------------------------------
    // Active-high reset
    // --------------------------------------------------

    reg [5:0] reset_cnt = 6'd0;
    wire resetn;

    always @(posedge clk_sys) begin
        if (btnC)
            reset_cnt <= 6'd0;
        else if (!(&reset_cnt))
            reset_cnt <= reset_cnt + 1'b1;
    end

    assign resetn = !btnC && (&reset_cnt);

    // --------------------------------------------------
    // Sensor and fall-detection signals
    // --------------------------------------------------

    wire [31:0] magnitude_mg;
    wire [15:0] ax;
    wire [15:0] ay;
    wire [15:0] az;

    // Original PicoSoC SPI signals.
    // These are internal and are not connected to the
    // ZedBoard onboard QSPI flash.
    wire flash_csb;
    wire flash_clk;

    tri flash_io0;
    tri flash_io1;
    tri flash_io2;
    tri flash_io3;

    // --------------------------------------------------
    // PicoRV32 SoC + MPU6050 + fall detector
    // --------------------------------------------------

    picosoc_fall #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) system (
        .clk           (clk_sys),
        .resetn        (resetn),

        .ser_rx        (ser_rx),
        .ser_tx        (ser_tx),

        .i2c_sda       (i2c_sda),
        .i2c_scl       (i2c_scl),

        .led_alarm     (led_alarm),
        .led_free_fall (led_free_fall),
        .led_impact    (led_impact),

        .magnitude_mg  (magnitude_mg),
        .accel_x       (ax),
        .accel_y       (ay),
        .accel_z       (az),

        .flash_csb     (flash_csb),
        .flash_clk     (flash_clk),
        .flash_io0     (flash_io0),
        .flash_io1     (flash_io1),
        .flash_io2     (flash_io2),
        .flash_io3     (flash_io3)
    );

endmodule
