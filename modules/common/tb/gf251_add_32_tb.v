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


module gf251_add_32_tb(

    );
    
reg i_clk = 0;
reg i_start = 0;
reg [31:0] i_x;
reg [31:0] i_y;
wire [31:0] o_o;
wire o_done;


gf251_add_32
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
     i_x  <= 32'h22222222;
     i_y  <= 32'h44444444;
     
     #10
     i_start <= 1;
     i_x  <= 32'hffffffff;
     i_y  <= 32'hffffffff;
     
     #10
     i_start <= 1;
     i_x  <= 32'h12345678;
     i_y  <= 32'h87654321;
     
     #10 
     i_start <= 0;
 
 end
 
 always #5 i_clk = ~i_clk;
 
endmodule
