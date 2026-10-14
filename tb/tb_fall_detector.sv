`timescale 1ns/1ps
module tb_fall_detector;
  reg clk=0; always #5 clk=~clk;
  reg resetn=0, sample_valid=0;
  reg signed [15:0] accel_x=0,accel_y=0,accel_z=0;
  wire free_fall,impact,fall_detected; wire [31:0] magnitude_mg;
  fall_detector #(.HOLD_CYCLES(12)) dut(.*);
  task sample(input signed [15:0] x,y,z);
    begin @(negedge clk); accel_x=x;accel_y=y;accel_z=z;sample_valid=1;
      @(negedge clk);sample_valid=0; #1;
      $display("t=%0t x=%0d y=%0d z=%0d mag=%0dmg free=%b impact=%b alarm=%b",$time,x,y,z,magnitude_mg,free_fall,impact,fall_detected);
    end
  endtask
  initial begin
    $dumpfile("tb_fall_detector.vcd");$dumpvars(0,tb_fall_detector);
    repeat(3) @(negedge clk);resetn=1;
    sample(0,0,8192);if(free_fall||impact||fall_detected) $fatal(1,"rest failure");
    sample(100,150,200);if(!free_fall) $fatal(1,"freefall failure");
    sample(16000,12000,8000);if(!impact||!fall_detected||free_fall) $fatal(1,"impact sequence failure");
    repeat(15) @(negedge clk);
    if(fall_detected) $fatal(1,"hold timeout failure");
    $display("PASS: fall_detector");$finish;
  end
endmodule
