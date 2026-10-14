`timescale 1ns/1ps
// Sensor SAMPLE INJECTION: checks actual detector/LED/register wiring;
// does NOT verify physical I2C transaction or CPU firmware execution.
module tb_picosoc_fall;
 reg clk=0;always #5 clk=~clk;
 reg resetn=0,ser_rx=1;
 wire ser_tx,led_alarm,led_free_fall,led_impact;
 wire [31:0] magnitude_mg;wire [15:0] accel_x,accel_y,accel_z;
 tri1 i2c_sda,i2c_scl;wire flash_csb,flash_clk;tri flash_io0,flash_io1,flash_io2,flash_io3;
 picosoc_fall #(.CLK_FREQ_HZ(1000000)) dut(.*);
 task sample(input signed [15:0] x,y,z);
 begin
 @(negedge clk);
 force dut.ax=x;force dut.ay=y;force dut.az=z;force dut.sample_valid=1'b1;
 @(negedge clk);release dut.sample_valid;
 #1;$display("t=%0t x=%0d y=%0d z=%0d LED alarm/free/impact=%b%b%b",$time,x,y,z,led_alarm,led_free_fall,led_impact);
 end endtask
 initial begin
 $dumpfile("tb_picosoc_fall.vcd");$dumpvars(0,tb_picosoc_fall);
 repeat(5) @(negedge clk);resetn=1;
 sample(0,0,8192);if(led_alarm||led_free_fall||led_impact) $fatal(1,"rest");
 sample(100,150,200);if(!led_free_fall) $fatal(1,"freefall");
 sample(16000,12000,8000);if(!led_alarm||!led_impact) $fatal(1,"alarm");
 release dut.ax;release dut.ay;release dut.az;
 $display("PASS: picosoc_fall datapath injection");$finish;
 end
endmodule
