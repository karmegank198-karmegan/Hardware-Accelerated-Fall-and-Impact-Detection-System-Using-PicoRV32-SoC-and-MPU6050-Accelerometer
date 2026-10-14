`timescale 1ns/1ps
// Hierarchical acceleration injection; validates top-level LED connectivity.
module tb_fall_fpga_top;
 reg clk100=0;always #5 clk100=~clk100;
 reg btnC=1,ser_rx=1;wire ser_tx,led_alarm,led_free_fall,led_impact;
 tri1 i2c_sda,i2c_scl;
 fall_fpga_top #(.CLK_FREQ_HZ(1000000)) dut(.*);
 task sample(input signed [15:0] x,y,z);
 begin @(negedge clk100);
 force dut.system.ax=x;force dut.system.ay=y;force dut.system.az=z;
 force dut.system.sample_valid=1'b1;
 @(negedge clk100);release dut.system.sample_valid;
 #1;$display("t=%0t x=%0d y=%0d z=%0d LEDs=%b%b%b",$time,x,y,z,led_alarm,led_free_fall,led_impact);
 end endtask
 initial begin
 $dumpfile("tb_fall_fpga_top.vcd");$dumpvars(0,tb_fall_fpga_top);
 repeat(5) @(negedge clk100);btnC=0;
 wait(dut.resetn);repeat(3) @(negedge clk100);
 sample(0,0,8192);if(led_alarm||led_free_fall||led_impact) $fatal(1,"rest");
 sample(100,150,200);if(!led_free_fall) $fatal(1,"freefall");
 sample(16000,12000,8000);if(!led_alarm||!led_impact) $fatal(1,"alarm");
 release dut.system.ax;release dut.system.ay;release dut.system.az;
 $display("PASS: fall_fpga_top LED connectivity");$finish;
 end
endmodule
