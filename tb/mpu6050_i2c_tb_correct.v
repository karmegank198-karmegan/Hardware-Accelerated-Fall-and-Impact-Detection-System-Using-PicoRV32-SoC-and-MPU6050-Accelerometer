`timescale 1ns/1ps

module mpu6050_i2c_tb;

    reg clk = 1'b0;
    reg resetn = 1'b0;

    tri sda;
    tri scl;

    wire signed [15:0] accel_x;
    wire signed [15:0] accel_y;
    wire signed [15:0] accel_z;
    wire sample_valid;
    wire busy;
    wire error;

    reg slave_sda_low;

    reg [3:0] bit_count;
    reg [7:0] rx_byte;

    integer pass_count;
    integer fail_count;
    integer byte_count;

    reg [7:0] read_mem [0:5];

    /*
     * Simulated MPU6050:
     *
     * PWR_MGMT_1    : 0x6B = 0x00
     * ACCEL_CONFIG  : 0x1C = 0x08  (+/-4g)
     *
     * ACCEL_XOUT_H..ACCEL_ZOUT_L:
     * 0x3B..0x40 = 12 34 FF 00 20 00
     */
    initial begin
        read_mem[0] = 8'h12;
        read_mem[1] = 8'h34;
        read_mem[2] = 8'hFF;
        read_mem[3] = 8'h00;
        read_mem[4] = 8'h20;
        read_mem[5] = 8'h00;

        slave_sda_low = 1'b0;
        bit_count     = 4'd0;
        rx_byte       = 8'h00;

        pass_count = 0;
        fail_count = 0;
        byte_count = 0;
    end

    pullup(sda);
    pullup(scl);

    assign sda = slave_sda_low ? 1'b0 : 1'bz;

    always #10 clk = ~clk;

    mpu6050_i2c #(
        .CLK_FREQ_HZ(50_000_000),
        .I2C_FREQ_HZ(100_000)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .sda(sda),
        .scl(scl),
        .accel_x(accel_x),
        .accel_y(accel_y),
        .accel_z(accel_z),
        .sample_valid(sample_valid),
        .busy(busy),
        .error(error)
    );

    /*
     * Simulated MPU6050 ACK and read-data driver.
     *
     * DUT state numbers:
     *   6  = S_ACK_HIGH
     *   10 = S_READ_BIT
     *   11 = S_READ_HIGH
     *   12 = S_READ_LOW
     *
     * ACK is pulled LOW while the DUT samples the ACK bit.
     *
     * During a read, the simulated MPU6050 places each data bit
     * on SDA while SCL is LOW and keeps it stable while SCL is HIGH.
     */
    always @* begin
        slave_sda_low = 1'b0;

        if (resetn) begin

            /* Slave ACK */
            if ((dut.state == 5'd6) || (dut.state == 5'd7))
                slave_sda_low = 1'b1;

            /* Slave read data */
            if ((dut.state == 5'd10) ||
                (dut.state == 5'd11) ||
                (dut.state == 5'd12)) begin

                case (dut.byte_index)
                    3'd0: slave_sda_low = ~read_mem[0][7-dut.bitcnt];
                    3'd1: slave_sda_low = ~read_mem[1][7-dut.bitcnt];
                    3'd2: slave_sda_low = ~read_mem[2][7-dut.bitcnt];
                    3'd3: slave_sda_low = ~read_mem[3][7-dut.bitcnt];
                    3'd4: slave_sda_low = ~read_mem[4][7-dut.bitcnt];
                    3'd5: slave_sda_low = ~read_mem[5][7-dut.bitcnt];
                    default: slave_sda_low = 1'b0;
                endcase
            end
        end
    end

    /*
     * Check each transmitted byte once, at the controller ACK state.
     * This avoids counting individual bits as separate bytes.
     */
    integer tx_index = 0;
    always @(posedge clk) begin
        if (resetn && dut.tick && dut.state == 5'd6) begin
            case (tx_index)
                0: if (dut.tx_byte == 8'hD0) $display("PASS: I2C WRITE address 0xD0"); else begin $display("FAIL: expected D0, got %02h",dut.tx_byte); fail_count=fail_count+1; end
                1: if (dut.tx_byte == 8'h6B) $display("PASS: PWR_MGMT_1 register 0x6B"); else begin $display("FAIL: expected 6B, got %02h",dut.tx_byte); fail_count=fail_count+1; end
                2: if (dut.tx_byte == 8'h00) $display("PASS: PWR_MGMT_1 data 0x00"); else begin $display("FAIL: expected 00, got %02h",dut.tx_byte); fail_count=fail_count+1; end
                3: if (dut.tx_byte == 8'h1C) $display("PASS: ACCEL_CONFIG register 0x1C"); else begin $display("FAIL: expected 1C, got %02h",dut.tx_byte); fail_count=fail_count+1; end
                4: if (dut.tx_byte == 8'h08) $display("PASS: ACCEL_CONFIG data 0x08 (+/-4g)"); else begin $display("FAIL: expected 08, got %02h",dut.tx_byte); fail_count=fail_count+1; end
                5: if (dut.tx_byte == 8'hD0) $display("PASS: I2C WRITE address for sensor read 0xD0"); else begin $display("FAIL: expected D0, got %02h",dut.tx_byte); fail_count=fail_count+1; end
                6: if (dut.tx_byte == 8'h3B) $display("PASS: accelerometer start register 0x3B"); else begin $display("FAIL: expected 3B, got %02h",dut.tx_byte); fail_count=fail_count+1; end
                7: if (dut.tx_byte == 8'hD1) $display("PASS: I2C READ address 0xD1"); else begin $display("FAIL: expected D1, got %02h",dut.tx_byte); fail_count=fail_count+1; end
                default: begin end
            endcase
            tx_index = tx_index + 1;
        end
    end

    /*
     * Check the six bytes received by the DUT.
     *
     * Expected:
     *   X = 0x1234
     *   Y = 0xFF00
     *   Z = 0x2000
     */
    always @(posedge sample_valid) begin

        $display("----------------------------------------");
        $display("sample_valid = 1");

        if (accel_x === 16'h1234) begin
            $display("PASS: accel_x = 0x%04h", accel_x);
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL: accel_x = 0x%04h, expected 0x1234", accel_x);
            fail_count = fail_count + 1;
        end

        if (accel_y === 16'hFF00) begin
            $display("PASS: accel_y = 0x%04h", accel_y);
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL: accel_y = 0x%04h, expected 0xFF00", accel_y);
            fail_count = fail_count + 1;
        end

        if (accel_z === 16'h2000) begin
            $display("PASS: accel_z = 0x%04h", accel_z);
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL: accel_z = 0x%04h, expected 0x2000", accel_z);
            fail_count = fail_count + 1;
        end

        if (error === 1'b0) begin
            $display("PASS: I2C error = 0");
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL: I2C error = 1");
            fail_count = fail_count + 1;
        end

        #100;

        $display("----------------------------------------");
        $display("MPU6050 I2C VERIFICATION COMPLETE");
        $display("PASS COUNT = %0d", pass_count);
        $display("FAIL COUNT = %0d", fail_count);
        $display("BYTE COUNT = %0d", byte_count);
        $display("----------------------------------------");

        if (fail_count == 0)
            $display("***** ALL MPU6050 TESTS PASSED *****");
        else
            $display("***** MPU6050 TEST FAILED *****");

        $finish;
    end

    /*
     * Reset.
     */
    initial begin
        #100;
        resetn = 1'b1;
    end

    /*
     * Timeout prevents a broken I2C transaction from running forever.
     */
    initial begin
        #20_000_000;

        $display("----------------------------------------");
        $display("FAIL: TIMEOUT");
        $display("busy         = %b", busy);
        $display("error        = %b", error);
        $display("sample_valid = %b", sample_valid);
        $display("accel_x      = %04h", accel_x);
        $display("accel_y      = %04h", accel_y);
        $display("accel_z      = %04h", accel_z);
        $display("----------------------------------------");

        $finish;
    end

endmodule
