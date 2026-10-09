`timescale 1ns / 1ps

module mpu6050_sim_model (
    inout wire sda,
    input wire scl,
    input wire resetn,
    input reg signed [15:0] sim_ax,
    input reg signed [15:0] sim_ay,
    input reg signed [15:0] sim_az
);

    // Open-drain SDA: the model can pull low or release the bus.
    reg sda_low = 0;
    assign sda = sda_low ? 1'b0 : 1'bz;

    localparam RX_ADDR = 0;
    localparam ACK_CLK = 1;
    localparam RX_REG  = 2;
    localparam RX_DATA = 3;
    localparam TX_DATA = 4;
    localparam RX_MACK = 5;

    integer state = RX_ADDR;
    integer next_state = RX_REG;
    integer bit_count = 0;
    integer tx_bit = 7;
    integer data_index = 0;

    reg [7:0] shift_byte = 0;
    reg [7:0] reg_pointer = 0;
    reg [7:0] tx_byte = 0;
    reg read_mode = 0;

    function [7:0] accel_byte;
        input [7:0] address;
        begin
            case (address)
                8'h3B: accel_byte = sim_ax[15:8];
                8'h3C: accel_byte = sim_ax[7:0];
                8'h3D: accel_byte = sim_ay[15:8];
                8'h3E: accel_byte = sim_ay[7:0];
                8'h3F: accel_byte = sim_az[15:8];
                8'h40: accel_byte = sim_az[7:0];
                default: accel_byte = 8'h00;
            endcase
        end
    endfunction

    // START or repeated START.
    always @(negedge sda) begin
        if (resetn && scl === 1'b1) begin
            state = RX_ADDR;
            bit_count = 0;
            shift_byte = 0;
            sda_low = 0;
        end
    end

    // STOP condition.
    always @(posedge sda) begin
        if (scl === 1'b1) begin
            state = RX_ADDR;
            bit_count = 0;
            sda_low = 0;
        end
    end

    // Receive bytes on SCL rising edges.
    always @(posedge scl or negedge resetn) begin
        if (!resetn) begin
            state = RX_ADDR;
            bit_count = 0;
            shift_byte = 0;
            reg_pointer = 0;
            read_mode = 0;
            sda_low = 0;
        end else begin
            case (state)
                RX_ADDR, RX_REG, RX_DATA: begin
                    shift_byte = {shift_byte[6:0], sda};

                    if (bit_count == 7) begin
                        bit_count = 0;

                        case (state)
                            RX_ADDR: begin
                                // 0xD0 = write, 0xD1 = read
                                if (shift_byte[7:1] == 7'h68) begin
                                    read_mode = shift_byte[0];
                                    next_state = shift_byte[0]
                                               ? TX_DATA : RX_REG;
                                    if (shift_byte[0]) begin
                                        tx_byte = accel_byte(reg_pointer);
                                        tx_bit = 7;
                                    end
                                end else begin
                                    next_state = RX_ADDR;
                                end
                                state = ACK_CLK;
                            end

                            RX_REG: begin
                                reg_pointer = shift_byte;
                                next_state = RX_DATA;
                                state = ACK_CLK;
                            end

                            RX_DATA: begin
                                // Configuration writes are acknowledged.
                                reg_pointer = reg_pointer + 1'b1;
                                next_state = RX_DATA;
                                state = ACK_CLK;
                            end
                        endcase

                        shift_byte = 0;
                    end else begin
                        bit_count = bit_count + 1;
                    end
                end

                TX_DATA: begin
                    // The master samples each bit on this rising edge.
                end

                RX_MACK: begin
                    // The master ACKs bytes 0..4 and NACKs byte 5.
                end
            endcase
        end
    end

    // Change SDA while SCL is low.
    always @(negedge scl or negedge resetn) begin
        if (!resetn) begin
            sda_low = 0;
        end else begin
            case (state)
                ACK_CLK: begin
                    // First falling edge: assert slave ACK.
                    if (!sda_low) begin
                        sda_low = 1;
                    end else begin
                        // ACK clock completed; prepare the next byte.
                        sda_low = 0;
                        state = next_state;
                        bit_count = 0;

                        if (next_state == TX_DATA) begin
                            tx_byte = accel_byte(reg_pointer);
                            tx_bit = 7;
                            sda_low = ~tx_byte[7];
                        end
                    end
                end

                TX_DATA: begin
                    if (tx_bit > 0) begin
                        tx_bit = tx_bit - 1;
                        sda_low = ~tx_byte[tx_bit];
                    end else begin
                        // Release SDA for the master's ACK/NACK.
                        sda_low = 0;
                        state = RX_MACK;
                    end
                end

                RX_MACK: begin
                    data_index = data_index + 1;

                    if (data_index < 6) begin
                        reg_pointer = reg_pointer + 1'b1;
                        tx_byte = accel_byte(reg_pointer);
                        tx_bit = 7;
                        sda_low = ~tx_byte[7];
                        state = TX_DATA;
                    end else begin
                        sda_low = 0;
                        state = RX_ADDR;
                    end
                end

                default: begin
                    sda_low = 0;
                end
            endcase
        end
    end

endmodule
