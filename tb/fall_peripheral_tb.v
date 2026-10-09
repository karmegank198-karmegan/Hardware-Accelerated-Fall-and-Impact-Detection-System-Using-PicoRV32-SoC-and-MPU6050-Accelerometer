`timescale 1ns/1ps

module fall_peripheral_tb;

    reg clk = 0;
    reg resetn = 0;
    reg iomem_valid = 0;
    reg [3:0] iomem_wstrb = 0;
    reg [31:0] iomem_addr = 0;
    reg [31:0] iomem_wdata = 0;

    reg fall_detected = 0;
    reg free_fall = 0;
    reg impact = 0;
    reg [31:0] magnitude_mg = 0;
    reg signed [15:0] accel_x = 0;
    reg signed [15:0] accel_y = 0;
    reg signed [15:0] accel_z = 0;

    wire iomem_ready;
    wire [31:0] iomem_rdata;

    always #5 clk = ~clk;

    fall_peripheral dut (
        .clk(clk),
        .resetn(resetn),
        .iomem_valid(iomem_valid),
        .iomem_ready(iomem_ready),
        .iomem_wstrb(iomem_wstrb),
        .iomem_addr(iomem_addr),
        .iomem_wdata(iomem_wdata),
        .iomem_rdata(iomem_rdata),
        .fall_detected(fall_detected),
        .free_fall(free_fall),
        .impact(impact),
        .magnitude_mg(magnitude_mg),
        .accel_x(accel_x),
        .accel_y(accel_y),
        .accel_z(accel_z)
    );

    task read_register(input [31:0] address);
        begin
            @(negedge clk);
            iomem_addr = address;
            iomem_valid = 1;

            @(posedge clk);
            #1;
            if (iomem_ready)
                $display("Address %h : Data %h",
                         iomem_addr, iomem_rdata);
            else
                $display("FAIL: No ready at address %h", address);

            @(negedge clk);
            iomem_valid = 0;
        end
    endtask

    initial begin
        #20;
        resetn = 1;

        fall_detected = 1;
        free_fall = 1;
        impact = 1;
        magnitude_mg = 32'd1500;
        accel_x = -16'sd100;
        accel_y = 16'h1234;
        accel_z = 16'h5678;

        read_register(32'h04000000);
        read_register(32'h04000004);
        read_register(32'h04000008);

        #20;
        $finish;
    end

endmodule