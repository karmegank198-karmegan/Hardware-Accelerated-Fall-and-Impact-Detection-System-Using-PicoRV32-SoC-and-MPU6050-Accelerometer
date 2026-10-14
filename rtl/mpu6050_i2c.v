// Simple synthesizable I2C master for MPU6050 at 7-bit address 0x68.
// Initializes PWR_MGMT_1 (0x6B) to 0,
// configures ACCEL_CONFIG (0x1C) to +/-4g,
// then repeatedly reads 0x3B..0x40.
module mpu6050_i2c #(
    parameter integer CLK_FREQ_HZ = 50000000,
    parameter integer I2C_FREQ_HZ = 100000
)(
    input wire clk,
    input wire resetn,
    inout wire sda,
    inout wire scl,
    output reg signed [15:0] accel_x,
    output reg signed [15:0] accel_y,
    output reg signed [15:0] accel_z,
    output reg sample_valid,
    output reg busy,
    output reg error
);

    localparam integer DIVIDER =
        (CLK_FREQ_HZ/(I2C_FREQ_HZ*2) < 1) ?
        1 : CLK_FREQ_HZ/(I2C_FREQ_HZ*2);

    localparam [4:0] S_IDLE=0,S_START_A=1,S_START_B=2,S_SEND_BIT=3,S_SEND_HIGH=4,S_SEND_LOW=5,
                     S_ACK_HIGH=6,S_ACK_LOW=7,S_RESTART_A=8,S_RESTART_B=9,S_READ_BIT=10,
                     S_READ_HIGH=11,S_READ_LOW=12,S_READ_ACK=13,S_READ_ACK_HIGH=14,S_READ_ACK_LOW=15,
                     S_STOP_A=16,S_STOP_B=17,S_DONE=18,S_RESTART_C=19;

    reg [31:0] divcnt;
    reg tick;
    reg sda_low, scl_low;
    reg [7:0] tx_byte, rx_byte;
    reg [3:0] bitcnt;
    reg [2:0] byte_index;
    reg [4:0] state;

    // Increased to 3 bits so initialization can include:
    // 0 = start
    // 1 = PWR_MGMT_1 register
    // 2 = PWR_MGMT_1 data
    // 3 = ACCEL_CONFIG register
    // 4 = ACCEL_CONFIG data
    reg [2:0] phase;

    reg init_done;
    reg [15:0] xreg,yreg,zreg;

    assign sda = sda_low ? 1'b0 : 1'bz;
    assign scl = scl_low ? 1'b0 : 1'bz;

    always @(posedge clk) begin
        if (!resetn) begin
            divcnt<=0; tick<=0; sda_low<=0; scl_low<=0; tx_byte<=0; rx_byte<=0;
            bitcnt<=0; byte_index<=0; state<=S_IDLE; phase<=0; init_done<=0;
            accel_x<=0; accel_y<=0; accel_z<=0; xreg<=0; yreg<=0; zreg<=0;
            sample_valid<=0; busy<=0; error<=0;
        end else begin
            sample_valid <= 1'b0;
            tick <= 1'b0;

            if (divcnt == DIVIDER-1) begin
                divcnt<=0;
                tick<=1'b1;
            end
            else
                divcnt<=divcnt+1'b1;

            if (tick) begin
                case (state)

                    S_IDLE: begin
                        busy<=1'b1;
                        error<=1'b0;
                        sda_low<=0;
                        scl_low<=0;
                        bitcnt<=0;
                        byte_index<=0;
                        phase<=0;
                        tx_byte<=8'hD0;
                        state<=S_START_A;
                    end

                    S_START_A: begin
                        sda_low<=1'b1;
                        state<=S_START_B;
                    end

                    S_START_B: begin
                        scl_low<=1'b1;
                        bitcnt<=0;
                        state<=S_SEND_BIT;
                    end

                    S_SEND_BIT: begin
                        // Open-drain: drive low for 0, release for 1.
                        sda_low <= ~tx_byte[7-bitcnt];
                        state <= S_SEND_HIGH;
                    end

                    S_SEND_HIGH: begin
                        scl_low<=0;
                        state<=S_SEND_LOW;
                    end

                    S_SEND_LOW: begin
                        scl_low<=1;

                        if (bitcnt==7) begin
                            sda_low<=0;
                            state<=S_ACK_HIGH;
                        end
                        else begin
                            bitcnt<=bitcnt+1'b1;
                            state<=S_SEND_BIT;
                        end
                    end

                    S_ACK_HIGH: begin
                        scl_low<=0;

                        if (sda !== 1'b0)
                            error<=1'b1;

                        state<=S_ACK_LOW;
                    end

                    S_ACK_LOW: begin
                        // ACK/NACK was sampled in S_ACK_HIGH. Do not sample
                        // SDA again here: the slave may release SDA after ACK.
                        scl_low<=1;

                        // MPU6050 initialization
                        if (!init_done && phase==0) begin
                            // PWR_MGMT_1 register = 0x6B
                            phase<=1;
                            tx_byte<=8'h6B;
                            bitcnt<=0;
                            state<=S_SEND_BIT;
                        end

                        else if (!init_done && phase==1) begin
                            // PWR_MGMT_1 data = 0x00
                            phase<=2;
                            tx_byte<=8'h00;
                            bitcnt<=0;
                            state<=S_SEND_BIT;
                        end

                        else if (!init_done && phase==2) begin
                            // ACCEL_CONFIG register = 0x1C
                            phase<=3;
                            tx_byte<=8'h1C;
                            bitcnt<=0;
                            state<=S_SEND_BIT;
                        end

                        else if (!init_done && phase==3) begin
                            // ACCEL_CONFIG = 0x08
                            // AFS_SEL = 01 -> +/-4g
                            phase<=4;
                            tx_byte<=8'h08;
                            bitcnt<=0;
                            state<=S_SEND_BIT;
                        end

                        else if (!init_done && phase==4) begin
                            // Initialization completed
                            init_done<=1'b1;
                            state<=S_STOP_A;
                        end

                        // Normal acceleration read sequence
                        else if (init_done && phase==0) begin
                            phase<=1;
                            tx_byte<=8'h3B;
                            bitcnt<=0;
                            state<=S_SEND_BIT;
                        end

                        else if (init_done && phase==1) begin
                            // Register pointer 0x3B was ACKed. Repeated START
                            // and then transmit read address 0xD1.
                            phase<=2;
                            tx_byte<=8'hD1;
                            bitcnt<=0;
                            state<=S_RESTART_A;
                        end

                        else if (init_done && phase==2) begin
                            // Read address 0xD1 was ACKed: receive six bytes.
                            byte_index<=0;
                            bitcnt<=0;
                            rx_byte<=0;
                            state<=S_READ_BIT;
                        end

                        else begin
                            state<=S_STOP_A;
                        end
                    end

                    S_RESTART_A: begin
                        // release SDA and SCL, then create a repeated START
                        sda_low<=0;
                        scl_low<=0;
                        state<=S_RESTART_B;
                    end

                    S_RESTART_B: begin
                        // Pull SDA low while SCL is still high: repeated START.
                        sda_low<=1'b1;
                        state<=S_RESTART_C;
                    end

                    S_RESTART_C: begin
                        // Now pull SCL low and begin transmitting 0xD1.
                        scl_low<=1'b1;
                        bitcnt<=0;
                        state<=S_SEND_BIT;
                    end

                    S_READ_BIT: begin
                        sda_low<=0;
                        state<=S_READ_HIGH;
                    end

                    S_READ_HIGH: begin
                        scl_low<=0;
                        rx_byte[7-bitcnt] <= sda;
                        state<=S_READ_LOW;
                    end

                    S_READ_LOW: begin
                        scl_low<=1;

                        if (bitcnt==7)
                            state<=S_READ_ACK;
                        else begin
                            bitcnt<=bitcnt+1'b1;
                            state<=S_READ_BIT;
                        end
                    end

                    S_READ_ACK: begin
                        // ACK bytes 0..4, NACK byte 5.
                        sda_low <= (byte_index < 5);
                        state<=S_READ_ACK_HIGH;
                    end

                    S_READ_ACK_HIGH: begin
                        scl_low<=0;
                        state<=S_READ_ACK_LOW;
                    end

                    S_READ_ACK_LOW: begin
                        scl_low<=1;

                        case (byte_index)
                            0: xreg[15:8] <= rx_byte;
                            1: xreg[7:0]  <= rx_byte;
                            2: yreg[15:8] <= rx_byte;
                            3: yreg[7:0]  <= rx_byte;
                            4: zreg[15:8] <= rx_byte;
                            5: zreg[7:0]  <= rx_byte;
                        endcase

                        if (byte_index==5)
                            state<=S_STOP_A;
                        else begin
                            byte_index<=byte_index+1'b1;
                            bitcnt<=0;
                            rx_byte<=0;
                            state<=S_READ_BIT;
                        end
                    end

                    S_STOP_A: begin
                        sda_low<=1;
                        scl_low<=0;
                        state<=S_STOP_B;
                    end

                    S_STOP_B: begin
                        sda_low<=0;
                        scl_low<=0;
                        state<=S_DONE;
                    end

                    S_DONE: begin
                        busy<=0;

                        if (init_done && byte_index==5) begin
                            // Include the last Z low byte received on this clock.
                            accel_x<=xreg;
                            accel_y<=yreg;
                            accel_z<={zreg[15:8],rx_byte};
                            sample_valid<=1'b1;
                        end

                        state<=S_IDLE;
                    end

                    default:
                        state<=S_IDLE;

                endcase
            end
        end
    end

endmodule
