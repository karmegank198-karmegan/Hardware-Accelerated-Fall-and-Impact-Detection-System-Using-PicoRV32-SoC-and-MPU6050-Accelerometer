
`timescale 1ns / 1ps

module picosoc_fall #(
    parameter integer CLK_FREQ_HZ = 100000000
)(
    input  wire clk,
    input  wire resetn,

    input  wire ser_rx,
    output wire ser_tx,

    inout  wire i2c_sda,
    inout  wire i2c_scl,

    output wire led_alarm,
    output wire led_free_fall,
    output wire led_impact,

    output wire [31:0] magnitude_mg,
    output wire [15:0] accel_x,
    output wire [15:0] accel_y,
    output wire [15:0] accel_z,

    output wire flash_csb,
    output wire flash_clk,
    inout  wire flash_io0,
    inout  wire flash_io1,
    inout  wire flash_io2,
    inout  wire flash_io3
);

    // --------------------------------------------------
    // MPU6050 sensor interface
    // --------------------------------------------------
    wire signed [15:0] ax;
    wire signed [15:0] ay;
    wire signed [15:0] az;

    wire sample_valid;
    wire sensor_busy;
    wire sensor_error;

    mpu6050_i2c #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) sensor (
        .clk         (clk),
        .resetn      (resetn),
        .sda         (i2c_sda),
        .scl         (i2c_scl),
        .accel_x     (ax),
        .accel_y     (ay),
        .accel_z     (az),
        .sample_valid(sample_valid),
        .busy        (sensor_busy),
        .error       (sensor_error)
    );

    assign accel_x = ax;
    assign accel_y = ay;
    assign accel_z = az;

    // --------------------------------------------------
    // Fall detection accelerator
    // --------------------------------------------------
    wire fall_detected;
    wire free_fall;
    wire impact;

    fall_detector detector (
        .clk           (clk),
        .resetn        (resetn),
        .accel_x       (ax),
        .accel_y       (ay),
        .accel_z       (az),
        .sample_valid  (sample_valid),
        .free_fall     (free_fall),
        .impact        (impact),
        .fall_detected (fall_detected),
        .magnitude_mg  (magnitude_mg)
    );

    // --------------------------------------------------
    // Memory-mapped peripheral
    // --------------------------------------------------
    wire        iomem_valid;
    wire        iomem_ready;
    wire [ 3:0] iomem_wstrb;
    wire [31:0] iomem_addr;
    wire [31:0] iomem_wdata;
    wire [31:0] iomem_rdata;

    fall_peripheral fall_regs (
        .clk           (clk),
        .resetn        (resetn),
        .iomem_valid   (iomem_valid),
        .iomem_ready   (iomem_ready),
        .iomem_wstrb   (iomem_wstrb),
        .iomem_addr    (iomem_addr),
        .iomem_wdata   (iomem_wdata),
        .iomem_rdata   (iomem_rdata),
        .fall_detected (fall_detected),
        .free_fall     (free_fall),
        .impact        (impact),
        .magnitude_mg  (magnitude_mg),
        .accel_x       (ax),
        .accel_y       (ay),
        .accel_z       (az)
    );

    // --------------------------------------------------
    // PicoSoC SPI flash signals
    // --------------------------------------------------
    wire flash_io0_oe, flash_io1_oe;
    wire flash_io2_oe, flash_io3_oe;

    wire flash_io0_do, flash_io1_do;
    wire flash_io2_do, flash_io3_do;

    wire flash_io0_di, flash_io1_di;
    wire flash_io2_di, flash_io3_di;

    // Convert PicoSoC's separate input/output/enable signals
    // into bidirectional top-level flash pins.
    assign flash_io0 = flash_io0_oe ? flash_io0_do : 1'bz;
    assign flash_io1 = flash_io1_oe ? flash_io1_do : 1'bz;
    assign flash_io2 = flash_io2_oe ? flash_io2_do : 1'bz;
    assign flash_io3 = flash_io3_oe ? flash_io3_do : 1'bz;

    assign flash_io0_di = flash_io0;
    assign flash_io1_di = flash_io1;
    assign flash_io2_di = flash_io2;
    assign flash_io3_di = flash_io3;

    // --------------------------------------------------
    // PicoSoC CPU and bus
    // --------------------------------------------------
    picosoc soc (
        .clk          (clk),
        .resetn       (resetn),

        .iomem_valid  (iomem_valid),
        .iomem_ready  (iomem_ready),
        .iomem_wstrb  (iomem_wstrb),
        .iomem_addr   (iomem_addr),
        .iomem_wdata  (iomem_wdata),
        .iomem_rdata  (iomem_rdata),

        // Interrupts unused in this integration
        .irq_5        (1'b0),
        .irq_6        (1'b0),
        .irq_7        (1'b0),

        .ser_tx       (ser_tx),
        .ser_rx       (ser_rx),

        .flash_csb    (flash_csb),
        .flash_clk    (flash_clk),

        .flash_io0_oe (flash_io0_oe),
        .flash_io1_oe (flash_io1_oe),
        .flash_io2_oe (flash_io2_oe),
        .flash_io3_oe (flash_io3_oe),

        .flash_io0_do (flash_io0_do),
        .flash_io1_do (flash_io1_do),
        .flash_io2_do (flash_io2_do),
        .flash_io3_do (flash_io3_do),

        .flash_io0_di (flash_io0_di),
        .flash_io1_di (flash_io1_di),
        .flash_io2_di (flash_io2_di),
        .flash_io3_di (flash_io3_di)
    );

    // --------------------------------------------------
    // Status LEDs
    // --------------------------------------------------
    assign led_alarm     = fall_detected;
    assign led_free_fall = free_fall;
    assign led_impact    = impact;

endmodule