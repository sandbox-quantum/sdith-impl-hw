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
    
    parameter MAT_SIZE = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES*8,
    parameter PROC_SIZE = N_GF*8,
    
    parameter COL_SIZE_MEM = MAT_COL_SIZE_BYTES/N_GF,
    parameter ROW_SIZE_MEM = MAT_ROW_SIZE_BYTES/N_GF
    
    
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
reg [PROC_SIZE-1:0]    vec_sreg;
wire [PROC_SIZE-1:0]    mul_out;


reg load_vec, shift_vec;
reg [8-1:0] vec_s_in;
always@(posedge i_clk)
begin
    if (load_vec) begin
        vec_sreg <= i_vec;
    end
    else if (shift_vec) begin
        vec_sreg <= {vec_sreg[PROC_SIZE-8-1:0],8'b00000000};
    end
    vec_s_in <= vec_sreg[PROC_SIZE-1:PROC_SIZE-8];
end

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
            .in_2(vec_s_in),
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
    else if (done_dot_mul) begin
        if (addr_1 == VEC_SIZE_BYTES/N_GF - 1) begin
            addr_1 <= 0;
    end
        addr_1 <= addr_1 + 1;  
    end
end

assign data_0 = mul_out ^ q_1;

always@(posedge i_clk)
begin
  addr_0 <= addr_1;
  wren_0 <= done_dot_mul[0];
end

wire  [PROC_SIZE-1:0]    data_0;        
wire [PROC_SIZE-1:0]     data_1;        
reg [`CLOG2(VEC_SIZE*8/PROC_SIZE)-1:0] addr_0; 
reg [`CLOG2(VEC_SIZE*8/PROC_SIZE)-1:0] addr_1;
reg                     wren_0;        
reg                     wren_1;        
wire  [PROC_SIZE-1:0]     q_0;           
wire  [PROC_SIZE-1:0]     q_1;            

//assign wren_0 = done_dot_mul[0];

mem_dual #(.WIDTH(PROC_SIZE), .DEPTH(VEC_SIZE/PROC_SIZE), .FILE("zero.mem"))
RESULT_MEM 
(
  .clock(i_clk),
  .data_0(data_0),
  .data_1(0),
  .address_0(addr_0),
  .address_1(addr_1),
  .wren_0(wren_0),
  .wren_1(0),
  .q_0(q_0),
  .q_1(q_1)

);

parameter s_wait_start      = 0;
parameter s_proc_mul        = 1;
parameter s_load_new_vec    = 2;
parameter s_done            = 3;

reg [2:0] state = 0;
reg [7:0] vect_shift_count;
always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        o_mat_addr <= 0;
        o_vec_addr <= 0;
        o_done <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            o_done <= 0;
            if (i_start) begin
                state <= s_proc_mul;
//                o_mat_addr <= o_mat_addr + 1;
            end
            else begin
                o_mat_addr <= 0;
                o_vec_addr <= 0;
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
                if (o_mat_addr%(MAT_ROW_SIZE_BYTES) == MAT_ROW_SIZE_BYTES-2) begin
                    state <= s_load_new_vec;
                    o_vec_addr <= o_vec_addr + 1;
                end
           end
        end
        
        else if (state == s_load_new_vec) begin
            if (o_mat_addr == MAT_SIZE_BYTES/N_GF - 1) begin
                o_mat_addr <= 0;
                o_vec_addr <= 0;
                state <= s_done; 
            end
            else begin
                state <= s_proc_mul;
                o_mat_addr <= o_mat_addr + 1;
            end
        end
        
        else if (state == s_done) begin
            state <= s_wait_start;
            o_done <= 1;
        end
       
    end
end

always@(i_start, o_mat_addr, o_vec_addr)
begin

    case(state)
        
    s_wait_start: begin
                    shift_vec <= 0;
                    if (i_start) begin
                        load_vec <= 1;
                        start_addr_0_en <= 1;
                        start_dot_mul <= 0;
                    end
                    else begin
                        load_vec <= 0;
                        start_addr_0_en <= 0;
                        start_dot_mul <= 0;
                    end
                  end
    
    s_proc_mul: begin
                    start_addr_0_en <= 0;
                    start_dot_mul <= 1;
                    if (o_mat_addr%(MAT_ROW_SIZE_BYTES/N_GF) == MAT_ROW_SIZE_BYTES/N_GF-1) begin
                        shift_vec <= 1;
                        load_vec <= 0;
                    end
                    else begin
                        shift_vec <= 0;
                        load_vec <= 0;
                    end 
                end
                
    s_load_new_vec: begin
                    start_addr_0_en <= 0;
                    shift_vec <= 0;
                    load_vec <= 1;
                    start_dot_mul <= 1;
                end
                
     s_done: begin
                shift_vec <= 0;
                start_addr_0_en <= 0;
                load_vec <= 0;
                start_dot_mul <= 0;
             end
     
     default: begin
                shift_vec <= 0;
                start_addr_0_en <= 0;
                load_vec <= 0;
                start_dot_mul <= 0;
               end
    
    endcase
    
end

endmodule