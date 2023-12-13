`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/26/2023 02:51:47 PM
// Design Name: 
// Module Name: gf_mul_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module gf251_mul_tb(

    );
    
reg i_clk = 0;
reg start = 0;
reg [7:0] in_1;
reg [7:0] in_2;
wire [7:0] out;
wire done;


gf251_mul
DUT
(
    .i_clk(i_clk),
    .in_1(in_1),
    .in_2(in_2),
    .start(start),
    .out(out),
    .done(done)
);
 
 initial
 begin
     start <= 0;
     in_1 <= 0;
     in_2 <= 0;
     #100
     start <= 1;
     in_1  <= 1;
     in_2  <= 20;
     
     #10 
     start <= 1;
     in_1  <= 34;
     in_2  <= 31;
     
     #10 
     start <= 1;
     in_1  <= 62;
     in_2  <= 85;
     
     #10 
     start <= 0;
 
 end
 
 always #5 i_clk = ~i_clk;
 
endmodule
