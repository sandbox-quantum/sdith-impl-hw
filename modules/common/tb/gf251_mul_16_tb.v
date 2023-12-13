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


module gf251_mul_16_tb(

    );
    
reg i_clk = 0;
reg i_start = 0;
reg [15:0] i_x;
reg [15:0] i_y;
wire [15:0] o_o;
wire o_done;


gf251_mul_16
DUT
(
    .i_clk(i_clk),
    .i_x(i_x),
    .i_y(i_y),
    .i_start(i_start),
    .o_o(o_o),
    .o_done(o_done)
);
 
 initial
 begin
     i_start <= 0;
     i_x <= 0;
     i_y <= 0;
     #100
     i_start <= 1;
     i_x  <= 16'h2222;
     i_y  <= 16'h4444;
     
     #10
     i_start <= 1;
     i_x  <= 16'h3322;
     i_y  <= 16'h5566;
     
     #10
     i_start <= 1;
     i_x  <= 16'h1234;
     i_y  <= 16'h4321;
     
     #10 
     i_start <= 0;
 
 end
 
 always #5 i_clk = ~i_clk;
 
endmodule
