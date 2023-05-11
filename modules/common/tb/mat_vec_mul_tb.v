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


module mat_vec_mul_tb #(
    parameter MAT_ROW_SIZE_BYTES = 8,
    parameter MAT_COL_SIZE_BYTES  = 8,
    parameter VEC_SIZE_BYTES  = 8,
    
    
    parameter MAT_ROW_SIZE = MAT_ROW_SIZE_BYTES*8,
    parameter MAT_COL_SIZE = MAT_COL_SIZE_BYTES*8,
    parameter VEC_SIZE = VEC_SIZE_BYTES*8,
    parameter N_GF = 2, 
    
    parameter MAT_SIZE = MAT_ROW_SIZE*MAT_COL_SIZE,
    parameter PROC_SIZE = N_GF*8
)
(

    );
    
reg i_clk = 0;
reg i_rst = 0;
reg i_start = 0;

wire [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0] o_mat_addr;
wire [`CLOG2(VEC_SIZE/PROC_SIZE)-1:0] o_vec_addr;

wire [PROC_SIZE-1:0] i_mat;
wire [PROC_SIZE-1:0] i_vec;
wire [PROC_SIZE-1:0] o_res;
wire [`CLOG2(VEC_SIZE/PROC_SIZE)-1:0] i_res_addr;
wire o_done;


mat_vec_mul
DUT
(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_start(i_start),
    .o_mat_addr(o_mat_addr),
    .o_vec_addr(o_vec_addr),
    .i_mat(i_mat),
    .i_vec(i_vec),
    .o_res(o_res),
    .i_res_addr(i_res_addr),
    .o_done(o_done)
);
 
 initial
 begin
     i_start <= 0;
     i_rst <= 0;
     #100
     
     i_start <= 1;
     #10 
     
     i_start <= 0;
     
     @(posedge o_done)
     
     #100
     $finish;
     
 end
 
 always #5 i_clk = ~i_clk;
 
endmodule
