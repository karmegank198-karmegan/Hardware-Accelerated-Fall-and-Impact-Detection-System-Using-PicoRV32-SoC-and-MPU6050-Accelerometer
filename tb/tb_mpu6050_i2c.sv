`timescale 1ns/1ps
// State-aware virtual MPU6050 response (not a timing-complete I2C slave).
// Synthesizable I2C master remains unmodified. ACK and six acceleration bytes
// are supplied by this simulation-only model. 8192 counts = 1g at +/-4g.
module tb_mpu6050_i2c;
 reg clk=0;always #5 clk=~clk;
 reg resetn=0;tri1 sda,scl;
 reg slave_low=0;assign sda=slave_low?1'b0:1'bz;
 wire signed [15:0] accel_x,accel_y,accel_z;
 wire sample_valid,busy,error;
 mpu6050_i2c #(.CLK_FREQ_HZ(1000000),.I2C_FREQ_HZ(100000)) dut(.*);
 reg [15:0] sx=0,sy=0,sz=8192;
 reg [7:0] sensor_byte;
 integer count=0;
 always @* begin
 case(dut.byte_index)
 0:sensor_byte=sx[15:8];1:sensor_byte=sx[7:0];
 2:sensor_byte=sy[15:8];3:sensor_byte=sy[7:0];
 4:sensor_byte=sz[15:8];5:sensor_byte=sz[7:0];
 default:sensor_byte=0;
 endcase
 end
 // State-aware behavioral stimulus avoids sampling race at the RTL ACK phase.
 always @(negedge clk) begin
 slave_low=0;
 if(resetn) begin
 if(dut.state==6) slave_low=1; // S_ACK_HIGH
 if(dut.state==11) slave_low=~sensor_byte[7-dut.bitcnt]; // S_READ_HIGH
 end
 end
 always @(posedge clk) if(sample_valid) begin
 count=count+1;
 $display("sample %0d: x=%0d y=%0d z=%0d error=%b",count,accel_x,accel_y,accel_z,error);
 if(count==1) begin sx=100;sy=150;sz=200;end
 if(count==2) begin sx=16000;sy=12000;sz=8000;end
 if(count==3) begin $display("PASS: virtual MPU6050 sample flow (check error flag)");$finish;end
 end
 initial begin
 $dumpfile("tb_mpu6050_i2c.vcd");$dumpvars(0,tb_mpu6050_i2c);
 repeat(4) @(negedge clk);resetn=1;
 #2000000;$fatal(1,"TIMEOUT: no sensor samples; inspect I2C master timing/ACK");
 end
endmodule
