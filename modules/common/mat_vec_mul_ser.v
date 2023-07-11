/*
 * This file is the Matrix Vector Multiplication module [UNDERDEVELOPMENT].
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/

`define assert(signal, value) \
        if (signal != value) begin \
            $display("ASSERTION FAILED in %m: signal != value"); \
            $finish; \
        end

module mat_vec_mul_ser
#(

    parameter PARAMETER_SET = "L3",
    parameter N_GF = 8, 

    parameter MAT_ROW_SIZE_BYTES = (PARAMETER_SET == "L1")? 104:
                                   (PARAMETER_SET == "L3")? 159:
                                   (PARAMETER_SET == "L5")? 202:
                                                            8,
                                                            
    parameter MAT_COL_SIZE_BYTES  =(PARAMETER_SET == "L1")? 126:
                                   (PARAMETER_SET == "L3")? 193:
                                   (PARAMETER_SET == "L5")? 278:
                                                            8,
    parameter VEC_SIZE_BYTES = (PARAMETER_SET == "L1")? 126:
                               (PARAMETER_SET == "L3")? 193:
                               (PARAMETER_SET == "L5")? 278:
                                                        8,

    parameter PROC_SIZE = N_GF*8,

    // parameter MAT_SIZE_BYTES = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES,
    
    
    

    // parameter MAT_COL_SIZE_BITS = MAT_COL_SIZE_BYTES*8,
    // parameter MAT_ROW_SIZE_BITS = MAT_ROW_SIZE_BYTES*8,


    // parameter MAT_COL_SIZE = MAT_COL_SIZE_BITS + (PROC_SIZE - MAT_COL_SIZE_BITS%PROC_SIZE)%PROC_SIZE,
    // parameter MAT_ROW_SIZE = MAT_ROW_SIZE_BITS + (PROC_SIZE - MAT_ROW_SIZE_BITS%PROC_SIZE)%PROC_SIZE,

    parameter VEC_SIZE = VEC_SIZE_BYTES*8,
    
    parameter VEC_WEIGHT = (PARAMETER_SET == "L1")? 126:
                           (PARAMETER_SET == "L3")? 193:
                           (PARAMETER_SET == "L5")? 278:
                                                     8,

    
    
    // parameter MAT_SIZE = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES*8

    parameter MAT_SIZE_BYTES = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES,
    

    parameter MRS_BITS = MAT_ROW_SIZE_BYTES*8,
    parameter MCS_BITS = MAT_COL_SIZE_BYTES*8,
    
    parameter MAT_ROW_SIZE = MRS_BITS + (PROC_SIZE - MRS_BITS%PROC_SIZE)%PROC_SIZE,
    parameter MAT_COL_SIZE = MCS_BITS + (PROC_SIZE - MCS_BITS%PROC_SIZE)%PROC_SIZE,

    
    // parameter MAT_SIZE = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE,
    parameter MAT_SIZE = MAT_ROW_SIZE*MAT_COL_SIZE_BYTES
    
    
)(
    input i_clk,
    input i_rst,
    input i_start,
    output reg o_mat_vec_rd,
    output reg [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0] o_mat_addr,
    output reg [`CLOG2(VEC_WEIGHT):0] o_vec_addr,
    
    input [PROC_SIZE-1:0] i_mat,
    input [8-1:0] i_vec,
    
    input  [`CLOG2(MAT_ROW_SIZE/PROC_SIZE)-1:0] i_res_addr,
    input  i_res_en,
    output [PROC_SIZE-1:0] o_res,
    output o_done,

    input [`CLOG2(MAT_ROW_SIZE/PROC_SIZE)-1:0] i_vec_add_addr,
    input  i_vec_add_wen,
    output [PROC_SIZE-1:0] i_vec_add
);

//`assert(MAT_ROW_SIZE, VECTOR_SIZE)

wire [PROC_SIZE-1:0]    mul_out;




assign o_done = done_int;


reg start_dot_mul;
wire [N_GF-1:0] done_dot_mul;
genvar i;
generate
    for(i=0;i<N_GF;i=i+1) begin
        gf_mul 
        GF_MULT 
        (
            .clk(i_clk), 
            .start(start_dot_mul), 
            .in_1(i_mat[PROC_SIZE-i*8-1 : PROC_SIZE-i*8-8]), 
            .in_2(i_vec),
            .done(done_dot_mul[i]), 
            .out(mul_out[PROC_SIZE-i*8-1 : PROC_SIZE-i*8-8]) 
        );
    end
endgenerate


reg start_addr_0_en; 

always@(posedge i_clk)
begin
    if (start_addr_0_en) begin
       addr_1 <= 0;
    end
    else if (done_dot_mul[0]) begin
        // if (addr_1 == MAT_ROW_SIZE_BYTES/N_GF - 1) begin
        if (addr_1 == MAT_ROW_SIZE/PROC_SIZE - 1) begin
            addr_1 <= 0;
        end
        else begin
            addr_1 <= addr_1 + 1;  
        end
    end
end

always@(mul_out_reg, q_1)
begin
    data_0 <= mul_out_reg ^ q_1;
end

always@(posedge i_clk)
begin
  addr_0 <= addr_1;
  wren_0 <= done_dot_mul[0];
  mul_out_reg <= mul_out;
end

reg  [PROC_SIZE-1:0]    mul_out_reg; 
reg  [PROC_SIZE-1:0]    data_0;        
wire [PROC_SIZE-1:0]     data_1;        
reg [`CLOG2(VEC_SIZE*8/PROC_SIZE)-1:0] addr_0; 
reg [`CLOG2(VEC_SIZE*8/PROC_SIZE)-1:0] addr_1;
reg                    wren_0;        
wire                    wren_1;        
wire  [PROC_SIZE-1:0]     q_0;           
wire  [PROC_SIZE-1:0]     q_1;            


assign o_res = q_1;

mem_dual #(.WIDTH(PROC_SIZE), .DEPTH(MAT_ROW_SIZE/PROC_SIZE), .FILE("zero.mem"))
RESULT_MEM 
(
  .clock(i_clk),
  .data_0(i_vec_add_wen? i_vec_add :data_0),
  .data_1(0),
  .address_0(i_vec_add_wen? i_vec_add_addr :addr_0),
  .address_1(i_res_en?i_res_addr:addr_1),
  .wren_0(wren_0 | i_vec_add_wen),
  .wren_1(0),
  .q_0(q_0),
  .q_1(q_1)

);

parameter s_wait_start      = 0;
parameter s_set_up          = 1;
parameter s_stall_0         = 2;
parameter s_proc_mul        = 3;
parameter s_done            = 4;

reg [2:0] state = 0;
reg [7:0] vect_shift_count;
reg [7:0] count;
reg done_int;

always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        o_mat_addr <= 0;
        o_vec_addr <= 0;
        done_int <= 0;
        count <= 0;
        o_mat_vec_rd <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            o_mat_addr <= 0;
            o_vec_addr <= 0;
            done_int <= 0;
            count <= 0;
            if (i_start) begin
                state <= s_set_up;
                done_int <= 0;
                o_mat_vec_rd <= 1;
            end
            else begin
                o_mat_vec_rd <= 0;
            end
        end

        else if (state == s_set_up) begin
            done_int <= 0;
            o_mat_addr <= o_mat_addr + 1;
            count <= count + 1;
            state <= s_proc_mul;
            o_mat_vec_rd <= 1;
        end
        

        else if (state == s_proc_mul) begin
           done_int <= 0;
           o_mat_vec_rd <= 1;
           if (o_mat_addr == MAT_SIZE/PROC_SIZE) begin
                o_mat_addr <= 0;
                o_vec_addr <= 0;
                state <= s_done;
           end
           else begin
                o_mat_addr <= o_mat_addr + 1;
                state <= s_proc_mul;
                if (count == MAT_ROW_SIZE/PROC_SIZE - 1) begin
                    count <= 0;
                    o_vec_addr <= o_vec_addr+1;
                end
                else begin
                    count <= count + 1;
                end
           end
        end
        
        else if (state == s_done) begin
            if (addr_0 == MAT_ROW_SIZE/PROC_SIZE - 1) begin
                state <= s_wait_start;
                done_int <= 1;
                o_mat_vec_rd <= 0;
            end
            else begin
                done_int <= 0;
                o_mat_vec_rd <= 0;
            end
        end
       
    end
end

always@(state, i_start)
begin

    case(state)
        
    s_wait_start: begin
                    if (i_start) begin
                        start_addr_0_en <= 1;
                        start_dot_mul <= 0;
                    end
                    else begin
                        start_addr_0_en <= 0;
                        start_dot_mul <= 0;
                    end
                  end
    
    s_set_up: begin
                    start_addr_0_en <= 0;
                    start_dot_mul <= 0;
                end
    

    s_proc_mul: begin
                    start_addr_0_en <= 0;
                    start_dot_mul <= 1;
                end
                
     s_done: begin
                start_addr_0_en <= 0;
                start_dot_mul <= 0;
             end
     
     default: begin
                start_addr_0_en <= 0;
                start_dot_mul <= 0;
               end
    
    endcase
    
end

endmodule