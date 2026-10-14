`timescale 1ns/1ps
module tb_fall_peripheral;
 reg clk=0; always #5 clk=~clk;
 reg resetn=0,iomem_valid=0;wire iomem_ready;reg [3:0] iomem_wstrb=0;
 reg [31:0] iomem_addr=0,iomem_wdata=0;wire [31:0] iomem_rdata;
 reg fall_detected=1,free_fall=0,impact=1;reg [31:0] magnitude_mg=2500;
 reg signed [15:0] accel_x=16000,accel_y=-12000,accel_z=8000;
 fall_peripheral dut(.*);
 task readreg(input [31:0] address,input [31:0] expected);
 begin @(negedge clk);iomem_addr=address;iomem_valid=1;
 @(posedge clk);#1;if(!iomem_ready||iomem_rdata!==expected) $fatal(1,"read %h got %h expected %h",address,iomem_rdata,expected);
 $display("PASS address=%h data=%h",address,iomem_rdata);
 @(negedge clk);iomem_valid=0;end endtask
 initial begin
 $dumpfile("tb_fall_peripheral.vcd");$dumpvars(0,tb_fall_peripheral);
 repeat(2) @(negedge clk);resetn=1;
 readreg(32'h04000000,{16'd2500,13'd0,3'b101});
 readreg(32'h04000004,{{16{accel_x[15]}},accel_x});
 readreg(32'h04000008,{accel_z,accel_y});
 $display("PASS: fall_peripheral");$finish;end
endmodule
