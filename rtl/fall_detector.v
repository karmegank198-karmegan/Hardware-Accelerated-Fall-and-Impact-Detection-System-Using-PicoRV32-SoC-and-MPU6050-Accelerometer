// Custom fall-detection hardware accelerator.
// MPU6050 +/-2g: approximately 16384 LSB = 1g.
module fall_detector #(
    parameter integer ONE_G = 16384,
    parameter integer FREE_FALL_G = 4915,   // 0.30g
    parameter integer IMPACT_G = 24576,     // 1.50g threshold
    parameter integer HOLD_CYCLES = 500000
)(
    input  wire clk,
    input  wire resetn,
    input  wire signed [15:0] accel_x,
    input  wire signed [15:0] accel_y,
    input  wire signed [15:0] accel_z,
    input  wire sample_valid,
    output reg free_fall,
    output reg impact,
    output reg fall_detected,
    output reg [31:0] magnitude_mg
);
    reg [31:0] hold_count;
    reg [31:0] mag_l1;
    reg [15:0] ax_abs, ay_abs, az_abs;

    always @* begin
        ax_abs = accel_x[15] ? (~accel_x + 16'd1) : accel_x;
        ay_abs = accel_y[15] ? (~accel_y + 16'd1) : accel_y;
        az_abs = accel_z[15] ? (~accel_z + 16'd1) : accel_z;
        mag_l1 = {16'd0,ax_abs} + {16'd0,ay_abs} + {16'd0,az_abs};
    end

    always @(posedge clk) begin
        if (!resetn) begin
            free_fall     <= 1'b0;
            impact        <= 1'b0;
            fall_detected <= 1'b0;
            magnitude_mg  <= 32'd0;
            hold_count    <= 32'd0;
        end else begin
            impact <= 1'b0;

            if (hold_count != 0) begin
                hold_count <= hold_count - 1'b1;
                fall_detected <= 1'b1;
            end else begin
                fall_detected <= 1'b0;
            end

            if (sample_valid) begin
                magnitude_mg <= (mag_l1 * 1000) / ONE_G;

                if (mag_l1 < FREE_FALL_G)
                    free_fall <= 1'b1;

                if (mag_l1 > IMPACT_G) begin
                    impact <= 1'b1;
                    if (free_fall) begin
                        fall_detected <= 1'b1;
                        hold_count <= HOLD_CYCLES;
                    end
                    free_fall <= 1'b0;
                end
            end
        end
    end
endmodule
