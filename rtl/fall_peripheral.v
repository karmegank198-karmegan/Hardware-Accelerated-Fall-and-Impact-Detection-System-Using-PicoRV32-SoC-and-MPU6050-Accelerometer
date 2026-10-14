// PicoRV32 memory-mapped fall-detection peripheral.
// Base address: 0x04000000
// +0x00 STATUS/MAGNITUDE
//        bit 0 = fall_detected, bit 1 = free_fall, bit 2 = impact
//        bits 31:16 = magnitude in mg
// +0x04 ACCEL_X (signed 16-bit in bits 15:0)
// +0x08 ACCEL_Y/Z (Y in 15:0, Z in 31:16)
module fall_peripheral (
    input wire clk,
    input wire resetn,
    input wire iomem_valid,
    output reg iomem_ready,
    input wire [3:0] iomem_wstrb,
    input wire [31:0] iomem_addr,
    input wire [31:0] iomem_wdata,
    output reg [31:0] iomem_rdata,
    input wire fall_detected,
    input wire free_fall,
    input wire impact,
    input wire [31:0] magnitude_mg,
    input wire signed [15:0] accel_x,
    input wire signed [15:0] accel_y,
    input wire signed [15:0] accel_z
);
    wire selected = iomem_valid && (iomem_addr[31:24] == 8'h04);
    always @(posedge clk) begin
        if (!resetn) begin
            iomem_ready <= 1'b0;
            iomem_rdata <= 32'd0;
        end else begin
            iomem_ready <= 1'b0;
            if (selected) begin
                iomem_ready <= 1'b1;
                case (iomem_addr[5:2])
                    4'd0: iomem_rdata <= {magnitude_mg[15:0],13'd0,impact,free_fall,fall_detected};
                    4'd1: iomem_rdata <= {{16{accel_x[15]}},accel_x};
                    4'd2: iomem_rdata <= {accel_z,accel_y};
                    default: iomem_rdata <= 32'd0;
                endcase
            end
        end
    end
endmodule
