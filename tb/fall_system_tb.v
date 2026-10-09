`timescale 1ns/1ps
// Integration-level detector test. MPU6050 is bypassed here; real sensor testing is done on FPGA.
module fall_system_tb;
 reg clk=0,resetn=0; reg signed [15:0] ax=0,ay=0,az=0; reg sample_valid=0;
 wire ff,imp,fall; wire [31:0] mg;
 always #5 clk=~clk;
 fall_detector #(.HOLD_CYCLES(20)) dut(.clk(clk),.resetn(resetn),.accel_x(ax),.accel_y(ay),.accel_z(az),.sample_valid(sample_valid),.free_fall(ff),.impact(imp),.fall_detected(fall),.magnitude_mg(mg));
 task apply(input integer x,input integer y,input integer z);
  begin @(negedge clk);ax=x;ay=y;az=z;sample_valid=1;@(negedge clk);sample_valid=0; end
 endtask
 initial begin
  #20 resetn=1;
  apply(0,0,16384); $display("NORMAL: mg=%0d ff=%b fall=%b",mg,ff,fall);
  apply(0,0,0);      $display("FREEFALL: mg=%0d ff=%b fall=%b",mg,ff,fall);
  apply(30000,0,0);  $display("IMPACT: mg=%0d impact=%b fall=%b",mg,imp,fall);
  #10;
  if(fall) $display("PASS: complete fall sequence detected"); else $display("FAIL: fall not detected");
  $finish;
 end
endmodule
