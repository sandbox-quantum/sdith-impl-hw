/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module mat_vec_mul_tb #(
    
    parameter PARAMETER_SET = "TOY",
    parameter MAT_ROW_SIZE_BYTES = (PARAMETER_SET == "L1")? 104:
                                   (PARAMETER_SET == "L2")? 159:
                                   (PARAMETER_SET == "L3")? 202:
                                                            8,
                                                            
    parameter MAT_COL_SIZE_BYTES  =(PARAMETER_SET == "L1")? 126:
                                   (PARAMETER_SET == "L2")? 193:
                                   (PARAMETER_SET == "L3")? 278:
                                                            8,
    parameter VEC_SIZE_BYTES = (PARAMETER_SET == "L1")? 126:
                               (PARAMETER_SET == "L2")? 193:
                               (PARAMETER_SET == "L3")? 278:
                                                        8,
    
    
    parameter MAT_ROW_SIZE = MAT_ROW_SIZE_BYTES*8,
    parameter MAT_COL_SIZE = MAT_COL_SIZE_BYTES*8,
    parameter VEC_SIZE = VEC_SIZE_BYTES*8,
    parameter N_GF = 2, 
    
    parameter MAT_SIZE = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES*8,
    parameter PROC_SIZE = N_GF*8
)
(

    );
    
reg i_clk = 0;
reg i_rst = 0;
reg i_start = 0;
reg i_res_en = 0;

wire [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0] o_mat_addr;
wire [`CLOG2(VEC_SIZE/PROC_SIZE)-1:0] o_vec_addr;

wire [PROC_SIZE-1:0] i_mat;
wire [PROC_SIZE-1:0] i_vec;
wire [PROC_SIZE-1:0] o_res;
wire [`CLOG2(VEC_SIZE/PROC_SIZE)-1:0] i_res_addr;
wire o_done;


mat_vec_mul
#(
.MAT_ROW_SIZE_BYTES(MAT_ROW_SIZE_BYTES),
.MAT_COL_SIZE_BYTES(MAT_COL_SIZE_BYTES),
.VEC_SIZE_BYTES(VEC_SIZE_BYTES),
.N_GF(N_GF)
)
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
    .i_res_en(i_res_en),
    .i_res_addr(i_res_addr),
    .o_done(o_done)
);
 
 integer start_time, end_time;
 initial
 begin
     i_start <= 0;
     i_rst <= 0;
     #100
     
     i_start <= 1;
     start_time = $time;
     #10 
     
     i_start <= 0;
     
     @(posedge o_done)
     end_time = $time;
     $display("Total Clock Cycles = %d", (end_time-start_time-5)/10);
     #100
     $finish;
     
 end
 
 always #5 i_clk = ~i_clk;
 
// input wire                     clock,
//    input wire [WIDTH-1:0]         data,
//    input wire [`CLOG2(DEPTH)-1:0] address,
//    input wire                     wr_en,
//    output reg [WIDTH-1:0]         q
 
 mem_single #(.WIDTH(PROC_SIZE), .DEPTH(VEC_SIZE/PROC_SIZE), .FILE("IN_VECTOR_16.mem")) 
 VECTOR
 (
 .clock(i_clk),
 .data(0),
 .address(o_vec_addr),
 .wr_en(0),
 .q(i_vec)
 );
 
  mem_single #(.WIDTH(PROC_SIZE), .DEPTH(MAT_SIZE/PROC_SIZE), .FILE("IN_MATRIX_16.mem")) 
 MATRIX
 (
 .clock(i_clk),
 .data(0),
 .address(o_mat_addr),
 .wr_en(0),
 .q(i_mat)
 );
 
endmodule
