`timescale 1ns / 1ps
/*
 * This file is testbench for Vector Addition module.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module vec_add_tb #(
    
    parameter PARAMETER_SET = "L1",
    parameter MAT_ROW_SIZE_BYTES = (PARAMETER_SET == "L1")? 104:
                                   (PARAMETER_SET == "L2")? 159:
                                   (PARAMETER_SET == "L3")? 202:
                                                            8,

    parameter M =   (PARAMETER_SET == "L1")? 230:
                    (PARAMETER_SET == "L2")? 352:
                    (PARAMETER_SET == "L3")? 480:
                                             230,

    parameter MAT_ROW_SIZE = MAT_ROW_SIZE_BYTES*8,

    
    parameter S_START_ADDR = (PARAMETER_SET == "L1")? 126:
                            (PARAMETER_SET == "L2")? 120:
                            (PARAMETER_SET == "L3")? 150:
                                                     3,

    parameter N_GF = 8, 
    
    parameter PROC_SIZE = N_GF*8
)
(

    );
    




reg i_clk = 0;
reg i_rst = 0;
reg i_start = 0;
wire o_res_en;

wire [`CLOG2(MAT_ROW_SIZE/PROC_SIZE)-1:0] o_vec_addr;
wire [PROC_SIZE-1:0] i_vec;
wire [`CLOG2(M)-1:0] o_s_addr;
wire [8-1:0] i_s;
wire o_vec_s_rd;

wire o_res_wr_en;
wire [PROC_SIZE-1:0] o_res;
wire [`CLOG2(MAT_ROW_SIZE/PROC_SIZE)-1:0] o_res_addr;
wire o_done;


vec_add
#(
.PARAMETER_SET(PARAMETER_SET),
.MAT_ROW_SIZE_BYTES(MAT_ROW_SIZE_BYTES),
.M(M),
.S_START_ADDR(S_START_ADDR),
.N_GF(N_GF)
)
vec_add
(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_start(i_start),

    .o_vec_addr(o_vec_addr),
    .i_vec(i_vec),
    .o_s_addr(o_s_addr),
    .i_s(i_s),
    .o_vec_s_rd(o_vec_s_rd),

    .o_res_wr_en(o_res_wr_en),
    .o_res(o_res),
    .o_res_addr(o_res_addr),
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
 

 
 mem_single #(.WIDTH(8), .DEPTH(M), .FILE("S_L1.mem")) 
 S_MEM
 (
 .clock(i_clk),
 .data(0),
 .address(o_s_addr),
 .wr_en(0),
 .q(i_s)
 );
 
mem_dual #(.WIDTH(PROC_SIZE), .DEPTH(MAT_ROW_SIZE/PROC_SIZE), .FILE("HSA_L1.mem")) 
 MATRIX
 (
 .clock(i_clk),
 .data_0(0),
 .data_1(o_res),
 .address_0(o_vec_addr),
 .address_1(o_res_addr),
 .wren_0(0),
 .wren_1(o_res_wr_en),
 .q_0(i_vec),
 .q_1()
 );
 
endmodule
