/*
 * This file is the Matrix Vector Multiplication module [UNDERDEVELOPMENT].
 *
 * Copyright (C) 2021
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/

`define assert(signal, value) \
        if (signal !== value) begin \
            $display("ASSERTION FAILED in %m: signal != value"); \
            $finish; \
        end

module mat_vec_mul
#(
    parameter MAT_ROW_SIZE = 8,
    parameter MAT_COL_SIZE = 8,
    parameter VEC_SIZE = 8,
    parameter N_GF = 8, 

    parameter MAT_SIZE = MAT_ROW_SIZE*MAT_COL_SIZE,
    parameter PROC_SIZE = N_GF*8
)(
    input i_clk,
    input i_rst,
    input [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0] i_mat_addr,
    input [`CLOG2(VEC_SIZE/PROC_SIZE)-1:0] i_vec_addr,
    input [PROC_SIZE-1:0] i_mat,
    input [PROC_SIZE-1:0] i_vec,

    output [PROC_SIZE-1:0] o_res

)

`assert(MAT_ROW_SIZE, VECTOR_SIZE);

wire [PROC_SIZE-1:0]    mul_out;

wire [8-1:0]    add_out;
genvar i;
generate
    for(i=0;i<N_GF;i=i+1) begin
        gf_mul 
        GF_MULT 
        (
            .clk(i_clk), 
            .start(1) 
            .in_1(i_mat[PROC_SIZE-i*8-1 : PROC_SIZE-i*8-8]), 
            .in_2(i_vec[PROC_SIZE-i*8-1 : PROC_SIZE-i*8-8]),
            .done() 
            .out(mul_out[PROC_SIZE-i*8-1 : PROC_SIZE-i*8-8]) 
        );
    end
endgenerate

    temp(0) <= inp(0);
    gen: for i in 1 to N-1 generate
        temp(i) <= temp(i-1) and inp(i);
    end generate; 

wire [PROC_SIZE-1:0]    temp;
 
assign temp[7:0] = mul_out[7:0];

genvar j;
generate
    for(j=1;j<N_GF;j=j+1) begin
        assign temp[i*8-1 : i*8-8] = mul_out[PROC_SIZE-i*8-1 : PROC_SIZE-i*8-8] ^ temp[PROC_SIZE-i*8-1 : PROC_SIZE-i*8-8];
    end
endgenerate

assign add_out = temp[PROC_SIZE-1:0]; 

endmodule