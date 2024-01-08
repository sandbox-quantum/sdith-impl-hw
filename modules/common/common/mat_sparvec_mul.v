/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



`define assert(signal, value) \
        if (signal != value) begin \
            $display("ASSERTION FAILED in %m: signal != value"); \
            $finish; \
        end

module mat_sparvec_mul
#(

    parameter PARAMETER_SET = "L3",
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

    parameter MAT_SIZE_BYTES = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES,
    
    
    parameter MAT_ROW_SIZE = MAT_ROW_SIZE_BYTES*8,
    parameter MAT_COL_SIZE = MAT_COL_SIZE_BYTES*8,
    parameter VEC_SIZE = VEC_SIZE_BYTES*8,
    
    parameter VEC_WEIGHT = (PARAMETER_SET == "L1")? 79:
                           (PARAMETER_SET == "L2")? 120:
                           (PARAMETER_SET == "L3")? 150:
                                                     3,

    parameter N_GF = 8, 
    
    parameter MAT_SIZE = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES*8,
    parameter PROC_SIZE = N_GF*8,
    
    parameter COL_SIZE_MEM = MAT_COL_SIZE_BYTES/N_GF,
    parameter ROW_SIZE_MEM = MAT_ROW_SIZE_BYTES/N_GF
    
    
)(
    input i_clk,
    input i_rst,
    input i_start,
    output reg o_mat_vec_rd,
    output reg [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0] o_mat_addr,
    output reg [`CLOG2(VEC_WEIGHT):0] o_vec_addr,
    
    input [PROC_SIZE-1:0] i_mat,
    input [`CLOG2(VEC_SIZE_BYTES)+8-1:0] i_vec,
    
    input  [`CLOG2(MAT_ROW_SIZE/PROC_SIZE)-1:0] i_res_addr,
    input  i_res_en,
    output [PROC_SIZE-1:0] o_res,
    output o_done,

    input [`CLOG2(MAT_ROW_SIZE/PROC_SIZE)-1:0] i_vec_add_addr,
    input  i_vec_add_wen,
    output [PROC_SIZE-1:0] i_vec_add
);

//`assert(MAT_ROW_SIZE, VECTOR_SIZE)
reg [PROC_SIZE-1:0]    vec_sreg;
wire [PROC_SIZE-1:0]    mul_out;


reg load_vec, shift_vec;
reg [8-1:0] vec_s_in, vec_s_in_reg;
wire [`CLOG2(VEC_SIZE_BYTES)-1:0] vec_loc;

assign vec_loc = i_vec[8+`CLOG2(VEC_SIZE_BYTES)-1:8];

// always@(posedge i_clk)
// begin
//     if (done_int) begin
//         if (addr_0 == MAT_ROW_SIZE_BYTES/N_GF - 1) begin
//             o_done <= 1;
//         end
//         else begin
//             o_done <= 0;
//         end
//     end
//     else begin
//         o_done <= 0;
//     end
// end

assign o_done = done_int;

always@(posedge i_clk)
begin
    vec_s_in_reg <= vec_s_in;
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
            .in_2(vec_s_in_reg),
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
        if (addr_1 == MAT_ROW_SIZE_BYTES/N_GF - 1) begin
            addr_1 <= 0;
        end
        else begin
            addr_1 <= addr_1 + 1;  
        end
    end
end

assign data_0 = mul_out ^ q_1;

always@(posedge i_clk)
begin
  addr_1_reg <= addr_1;
  addr_0 <= addr_1;
  wren_0 <= done_dot_mul[0];
//   wren_0 <= wren_0_reg;
  mul_out_reg <= mul_out;
  mul_out_reg_reg <= mul_out_reg;
end

reg  [PROC_SIZE-1:0]    mul_out_reg, mul_out_reg_reg; 
wire  [PROC_SIZE-1:0]    data_0;        
wire [PROC_SIZE-1:0]     data_1;        
reg [`CLOG2(VEC_SIZE*8/PROC_SIZE)-1:0] addr_0; 
reg [`CLOG2(VEC_SIZE*8/PROC_SIZE)-1:0] addr_1, addr_1_reg;
reg                    wren_0, wren_0_reg;        
wire                    wren_1;        
wire  [PROC_SIZE-1:0]     q_0;           
wire  [PROC_SIZE-1:0]     q_1;            

//assign wren_0 = done_dot_mul[0];

assign o_res = q_1;

// assign wren_1 = i_vec_add_wen;
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
parameter s_load_new_vec    = 4;
parameter s_done            = 5;

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
            
            count <= 0;
            if (i_start) begin
                state <= s_set_up;
                done_int <= 0;
                o_mat_vec_rd <= 1;
            end
            else begin
                o_mat_addr <= 0;
                o_vec_addr <= 0;
                done_int <= 0;
                o_mat_vec_rd <= 0;
            end
        end

        else if (state == s_set_up) begin
            done_int <= 0;
            o_mat_addr <= ({vec_loc,6'b000})/N_GF;
            // vec_s_in <= i_vec[7:0];
            // state <= s_load_new_vec;
            state <= s_stall_0;
            o_mat_vec_rd <= 1;
        end
        
        else if (state == s_stall_0) begin
            done_int <= 0;
            vec_s_in <= i_vec[7:0];
            state <= s_load_new_vec;
            o_mat_vec_rd <= 1;
        end

        else if (state == s_proc_mul) begin
           done_int <= 0;
           o_mat_vec_rd <= 1;
           if (o_vec_addr == VEC_WEIGHT) begin
                o_mat_addr <= 0;
                o_vec_addr <= 0;
                state <= s_done;
           end
           else begin
                o_mat_addr <= ({vec_loc,3'b000})/N_GF;
                vec_s_in <= i_vec[7:0];
                state <= s_load_new_vec;
           end
        end
        
        else if (state == s_load_new_vec) begin
            done_int <= 0;
            o_mat_vec_rd <= 1;
            if (count == MAT_COL_SIZE_BYTES/N_GF - 2) begin
                state <= s_proc_mul; 
                count <= 0;
                o_mat_addr <= o_mat_addr + 1;
            end
            else begin
                if (count == MAT_COL_SIZE_BYTES/N_GF - 3) begin
                    o_vec_addr <= o_vec_addr + 1;
                end
                state <= s_load_new_vec;
                o_mat_addr <= o_mat_addr + 1;
                count <= count + 1;
            end

        end
        
        else if (state == s_done) begin
            state <= s_wait_start;
            done_int <= 1;
            o_mat_vec_rd <= 0;
        end
       
    end
end

always@(state, i_start, o_mat_addr, o_vec_addr)
begin

    case(state)
        
    s_wait_start: begin
                    shift_vec <= 0;
                    load_vec <= 0;
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
                    load_vec <= 0;
                end
    
    s_stall_0: begin
                    start_addr_0_en <= 0;
                    start_dot_mul <= 0;
                    load_vec <= 0;
                end

    s_proc_mul: begin
                    start_addr_0_en <= 0;
                    load_vec <= 0;
                    if (o_vec_addr <= VEC_WEIGHT -1) begin
                        start_dot_mul <= 1;
                    end
                    else begin
                        start_dot_mul <= 0;
                    end
                end
                
    s_load_new_vec: begin
                    start_addr_0_en <= 0;
                    shift_vec <= 0;
                    load_vec <= 1;
                    if (o_vec_addr <= VEC_WEIGHT -1) begin
                        start_dot_mul <= 1;
                    end
                    else begin
                        start_dot_mul <= 0;
                    end
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