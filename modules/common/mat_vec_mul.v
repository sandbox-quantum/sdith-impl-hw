/*
 * This file is the Matrix Vector Multiplication module [UNDERDEVELOPMENT].
 *
 * Copyright (C) 2021
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/

`define assert(signal, value) \
        if (signal != value) begin \
            $display("ASSERTION FAILED in %m: signal != value"); \
            $finish; \
        end

module mat_vec_mul
#(
    parameter MAT_ROW_SIZE_BYTES = 8,
    parameter MAT_COL_SIZE_BYTES  = 8,
    parameter VEC_SIZE_BYTES  = 8,
    parameter MAT_SIZE_BYTES = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES,
    
    
    parameter MAT_ROW_SIZE = MAT_ROW_SIZE_BYTES*8,
    parameter MAT_COL_SIZE = MAT_COL_SIZE_BYTES*8,
    parameter VEC_SIZE = VEC_SIZE_BYTES*8,
    parameter N_GF = 2, 
    
    parameter MAT_SIZE = MAT_ROW_SIZE*MAT_COL_SIZE,
    parameter PROC_SIZE = N_GF*8
)(
    input i_clk,
    input i_rst,
    input i_start,
    output reg [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0] o_mat_addr,
    output reg [`CLOG2(VEC_SIZE/PROC_SIZE):0] o_vec_addr,
    input [PROC_SIZE-1:0] i_mat,
    input [PROC_SIZE-1:0] i_vec,
    
    input  [`CLOG2(VEC_SIZE/PROC_SIZE)-1:0] i_res_addr,
    output [PROC_SIZE-1:0] o_res,
    output reg o_done

);

//`assert(MAT_ROW_SIZE, VECTOR_SIZE)

wire [PROC_SIZE-1:0]    mul_out;

wire [8-1:0]    add_out;
genvar i;
generate
    for(i=0;i<N_GF;i=i+1) begin
        gf_mul 
        GF_MULT 
        (
            .clk(i_clk), 
            .start(1), 
            .in_1(i_mat[PROC_SIZE-i*8-1 : PROC_SIZE-i*8-8]), 
            .in_2(i_vec[PROC_SIZE-i*8-1 : PROC_SIZE-i*8-8]),
            .done(), 
            .out(mul_out[PROC_SIZE-i*8-1 : PROC_SIZE-i*8-8]) 
        );
    end
endgenerate

//    assign temp[0] = inp[0];
//    gen: for i in 1 to N-1 generate
//        assign temp[i] = temp[i-1] and inp[i];
//    end generate; 

//wire [PROC_SIZE-1:0]    temp;
 
 
//assign temp[7:0] = mul_out[7:0];

//genvar j;
//generate
//    for(j=1;j<N_GF;j=j+1) begin
//        assign temp[i*8-1 : i*8-8] = mul_out[PROC_SIZE-i*8-1 : PROC_SIZE-i*8-8] ^ temp[PROC_SIZE-i*8-1 : PROC_SIZE-i*8-8];
//    end
//endgenerate

assign data_0 = mul_out ^ q_1;

wire [PROC_SIZE-1:0]     data_0;        
wire [PROC_SIZE-1:0]     data_1;        
reg [`CLOG2(VEC_SIZE*8/PROC_SIZE)-1:0] addr_0; 
reg [`CLOG2(VEC_SIZE*8/PROC_SIZE)-1:0] addr_1;
reg                     wren_0;        
reg                     wren_1;        
wire  [PROC_SIZE-1:0]     q_0;           
wire  [PROC_SIZE-1:0]     q_1;            

mem_dual #(.WIDTH(PROC_SIZE), .DEPTH(VEC_SIZE/PROC_SIZE))
RESULT_MEM 
(
  .clock(i_clk),
  .data_0(data_0),
  .data_1(data_1),
  .address_0(addr_0),
  .address_1(addr_1),
  .wren_0(wren_0),
  .wren_1(wren_1),
  .q_0(q_0),
  .q_1(q_1)

);

parameter s_wait_start  = 0;
parameter s_proc_mul    = 1;
parameter s_done        = 2;

reg [2:0] state = 0;

always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        addr_0 <= 0;
        addr_1 <= 1;
        o_mat_addr <= 0;
        o_vec_addr <= 0;
        o_done <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            o_mat_addr <= 0;
            o_vec_addr <= 0;
            o_done <= 0;
            if (i_start) begin
                state <= s_proc_mul;
            end
        end
        
        else if (state == s_proc_mul) begin
           if (o_mat_addr == MAT_SIZE_BYTES/N_GF - 1) begin
                o_mat_addr <= 0;
                o_vec_addr <= 0;
                state <= s_done;
           end
           else begin
                o_mat_addr <= o_mat_addr + 1;
                if ((o_mat_addr % 4) == (2) ) begin
                    o_vec_addr <= o_vec_addr + 1;
                end
           end
        end
        
        else if (state == s_done) begin
            state <= s_wait_start;
            o_done <= 1;
        end
       
    end
end

endmodule