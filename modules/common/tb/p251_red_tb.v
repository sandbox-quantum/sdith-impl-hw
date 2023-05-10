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


module p251_red_tb(

    );
    
reg i_clk = 0;
reg i_start = 0;
reg [15:0] i_a;
wire [7:0] o_c;
wire o_done;


p251_red
DUT
(
    .i_clk(i_clk),
    .i_a(i_a),
    .i_start(i_start),
    .o_c(o_c),
    .o_done(o_done)
);
 
 initial
 begin
     i_start <= 0;
     i_a <= 0;
     #100
     i_start <= 1;
     i_a  <= 251;
     
     #10 
     i_start <= 0;
     i_a <= 16476;
     
     #10 
     i_start <= 0;
     i_a <= 7218;
     
     #10 
     i_start <= 0;
     i_a <= 16'hffff;
 
 end
 
 always #5 i_clk = ~i_clk;
 
endmodule
