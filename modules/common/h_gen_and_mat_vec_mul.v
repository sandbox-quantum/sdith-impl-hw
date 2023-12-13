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

module h_gen_and_mat_vec_mul
#(
    
    // parameter FIELD = "P251",
   parameter FIELD = "GF256",
    
    parameter PARAMETER_SET = "L1",
    parameter N_GF = 4, 

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


    
    parameter MAT_SIZE = MAT_ROW_SIZE*MAT_COL_SIZE_BYTES,

    parameter SEED_SIZE =   (PARAMETER_SET == "L1")?    128:
                            (PARAMETER_SET == "L3")?    192:
                            (PARAMETER_SET == "L5")?    256:
                                                        128,
    
    parameter WIDTH =   32, 
    parameter FILE_MEM_INIT = "zero.mem"
    
    
)(
    input i_clk,
    input i_rst,
    input i_start,
    
    // output reg [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0] o_mat_addr,

    input [31:0]                                i_seed_h,
    input                                       i_seed_h_wr_en,
    input [`CLOG2(SEED_SIZE/32)-1:0]            i_seed_h_addr,

    output reg o_mat_vec_rd,
    output reg [`CLOG2(VEC_WEIGHT):0] o_vec_addr,
    input [8-1:0] i_vec,

    // input [PROC_SIZE-1:0] i_mat,
    
    
    input  [`CLOG2(MAT_ROW_SIZE/PROC_SIZE)-1:0] i_res_addr,
    input  i_res_en,
    output [PROC_SIZE-1:0] o_res,
    output o_done,

    input [`CLOG2(MAT_ROW_SIZE/PROC_SIZE)-1:0] i_vec_add_addr,
    input  i_vec_add_wen,
    output [PROC_SIZE-1:0] i_vec_add,

        // hash interface
    output   [32-1:0]                                   o_hash_data_in,
    input    [`CLOG2((SEED_SIZE)/32) -1:0]              i_hash_addr,
    input                                               i_hash_rd_en,

    input    wire [32-1:0]                              i_hash_data_out,
    input    wire                                       i_hash_data_out_valid,
    output   reg                                        o_hash_data_out_ready,

    output   wire  [32-1:0]                             o_hash_input_length, // in bits
    output   wire  [32-1:0]                             o_hash_output_length, // in bits

    output   reg                                        o_hash_start,
    input    wire                                       i_hash_force_done_ack,
    output   reg                                        o_hash_force_done



);


assign o_hash_input_length = SEED_SIZE;
assign o_hash_output_length = MAT_SIZE;

mem_single #(.WIDTH(32), .DEPTH(SEED_SIZE/32), .INIT(1))
SEED_H_MEM 
(
  .clock(i_clk),
  .data(i_seed_h),
  .address(i_seed_h_wr_en? i_seed_h_addr: i_hash_rd_en? i_hash_addr: 0),
  .wr_en(i_seed_h_wr_en),
  .q(o_hash_data_in)
);

//`assert(MAT_ROW_SIZE, VECTOR_SIZE)

wire [PROC_SIZE-1:0]    mul_out;




assign o_done = done_int;

reg [WIDTH-1:0] hash_in;

always@(posedge i_clk)
begin
    if (i_hash_data_out_valid) begin
        hash_in <= i_hash_data_out;
    end
end

reg start_dot_mul;
wire [N_GF-1:0] done_dot_mul;
genvar i;
generate
    for(i=0;i<N_GF;i=i+1) begin
        // if (FIELD == "P251") begin 
        //     p251_mul 
        //     P251_MULT 
        //     (
        //         .clk(i_clk), 
        //         .start(start_dot_mul), 
        //         .in_1(i_mat[PROC_SIZE-i*8-1 : PROC_SIZE-i*8-8]), 
        //         .in_2(i_vec),
        //         .done(done_dot_mul[i]), 
        //         .out(mul_out[PROC_SIZE-i*8-1 : PROC_SIZE-i*8-8]) 
        //     );
        // end
        // else begin 
            gf_mul 
            GF_MULT 
            (
                .clk(i_clk), 
                .start(start_dot_mul), 
                .in_1(i_hash_data_out[PROC_SIZE-i*8-1 : PROC_SIZE-i*8-8]), 
                .in_2(i_vec),
                .done(done_dot_mul[i]), 
                .out(mul_out[PROC_SIZE-i*8-1 : PROC_SIZE-i*8-8]) 
            );
        // end
    end
endgenerate

wire [PROC_SIZE-1:0] add_out;
wire [N_GF-1:0] done_add;
reg start_add;
// wire add_out_test;
// assign add_out_test = (add_out == (mul_out_reg ^ q_1));


genvar j;
generate
    for(j=0;j<N_GF;j=j+1) begin
        // if (FIELD == "P251") begin 
        //     p251_add 
        //     P251_ADD 
        //     (
        //        .clk(i_clk), 
        //        .start(done_dot_mul), 
        //         .in_1(mul_out_reg[PROC_SIZE-j*8-1 : PROC_SIZE-j*8-8]), 
        //         .in_2(q_1[PROC_SIZE-j*8-1 : PROC_SIZE-j*8-8]),
        //        .done(done_add[i]), 
        //         .out(add_out[PROC_SIZE-j*8-1 : PROC_SIZE-j*8-8]) 
        //     );
        // end
        // else begin 
            gf_add 
            GF_ADD 
            (
                .i_clk(i_clk), 
                .i_start(start_add), 
                .in_1(mul_out_reg[PROC_SIZE-j*8-1 : PROC_SIZE-j*8-8]), 
                .in_2(q_1[PROC_SIZE-j*8-1 : PROC_SIZE-j*8-8]),
                .o_done(done_add[j]), 
                .out(add_out[PROC_SIZE-j*8-1 : PROC_SIZE-j*8-8]) 
            );
        // end
    end
endgenerate


pipeline_reg_gen #(.WIDTH(`CLOG2(VEC_SIZE*8/PROC_SIZE)), .REG_STAGES(1))
REG_STATE_ADDR_PIPELINE
(
    .i_clk(i_clk),
    .i_data_in(addr_1),
    .o_data_out(addr_0)
   );

reg start_addr_0_en; 

always@(posedge i_clk)
begin
    if (start_addr_0_en) begin
       addr_1 <= 0;
    end
    else if (done_dot_mul[0]) begin
        if (addr_1 == MAT_ROW_SIZE/PROC_SIZE - 1) begin
            addr_1 <= 0;
        end
        else begin
            addr_1 <= addr_1 + 1;  
        end
    end
end

// always@(mul_out_reg, q_1)
always@(add_out)
begin
//    data_0 <= mul_out_reg ^ q_1;
    data_0 <= add_out;
end

always@(posedge i_clk)
begin
//   addr_0 <= addr_1;
  start_add <= done_dot_mul[0];
  mul_out_reg <= mul_out;
end

reg  [PROC_SIZE-1:0]    mul_out_reg; 
reg  [PROC_SIZE-1:0]    data_0;        
wire [PROC_SIZE-1:0]     data_1;        
wire [`CLOG2(VEC_SIZE*8/PROC_SIZE)-1:0] addr_0; 
reg [`CLOG2(VEC_SIZE*8/PROC_SIZE)-1:0] addr_1;
wire                    wren_0;        
wire                    wren_1;        
wire  [PROC_SIZE-1:0]     q_0;           
wire  [PROC_SIZE-1:0]     q_1;            


assign o_res = q_1;
assign wren_0 = done_add[0]; 

mem_dual #(.WIDTH(PROC_SIZE), .DEPTH(MAT_ROW_SIZE/PROC_SIZE), .FILE("SB_L1.mem"))
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
parameter s_start_hash      = 1;
parameter s_done_hash       = 2;
parameter s_update_vec_addr = 3;
parameter s_done            = 7;

reg [2:0] state = 0;
reg [7:0] vect_shift_count;
reg [`CLOG2(MAT_SIZE/PROC_SIZE):0] count_mat;
reg [`CLOG2(MAT_ROW_SIZE/PROC_SIZE):0] count;
reg done_int;

always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        o_vec_addr <= 0;
        done_int <= 0;
        count <= 0;
        count_mat <= 0;
        o_mat_vec_rd <= 0;
        o_hash_force_done <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            o_vec_addr <= 0;
            done_int <= 0;
            count <= 0;
            count_mat <= 0;
            o_hash_force_done <= 0;
            if (i_start) begin
                state <= s_start_hash;
                done_int <= 0;
                o_mat_vec_rd <= 1;
            end
            else begin
                o_mat_vec_rd <= 0;
            end
        end

        else if (state == s_start_hash) begin
            state <= s_done_hash;
        end

        else if (state == s_done_hash) begin
            if (count_mat == MAT_SIZE/PROC_SIZE - 1) begin
                state <= s_done;
            end
            else begin
                if (count == MAT_ROW_SIZE/PROC_SIZE - 2) begin
                    if (i_hash_data_out_valid) begin
                        count <= 0;
                        count_mat <= count_mat + 1;
                        state <= s_update_vec_addr;
                        o_vec_addr <= o_vec_addr + 1;
                    end
                end 
                else begin
                    if (i_hash_data_out_valid) begin
                        count <= count + 1;
                        count_mat <= count_mat + 1;
                        // state <= s_done;
                    end
                end 
            end
        end

        else if (state == s_update_vec_addr) begin
            if (count_mat == MAT_SIZE/PROC_SIZE - 1) begin
                state <= s_done;
            end
            else begin
                if (i_hash_data_out_valid) begin
                    // count <= count + 1;
                    count_mat <= count_mat + 1;
                    state <= s_done_hash;
                    o_mat_vec_rd <= 1;
                    // o_vec_addr <= o_vec_addr + 1;
                end
            end
        end
        
        else if (state == s_done) begin
            if (addr_0 == MAT_ROW_SIZE/PROC_SIZE - 1) begin
                state <= s_wait_start;
                done_int <= 1;
                o_mat_vec_rd <= 0;
                o_hash_force_done <= 1;
            end
            else begin
                done_int <= 0;
                o_hash_force_done <= 0;
            end
        end
       
    end
end

always@(*)
begin

    case(state)
        
    s_wait_start: begin
                    o_hash_start <= 0;
                    o_hash_data_out_ready <= 0;
                    if (i_start) begin
                        start_addr_0_en <= 1;
                        start_dot_mul <= 0;
                    end
                    else begin
                        start_addr_0_en <= 0;
                        start_dot_mul <= 0;
                    end
                  end
    
    s_start_hash: begin
        o_hash_start <= 1;
        o_hash_data_out_ready <= 1;
        start_addr_0_en <= 0;
    end

    s_done_hash: begin
        o_hash_start <= 0;
        start_addr_0_en <= 0;
        if (i_hash_data_out_valid) begin
            o_hash_data_out_ready <= 1;
            start_dot_mul <= 1;
        end
        else begin
            start_dot_mul <= 0;
        end
    end

    s_update_vec_addr: begin
        start_addr_0_en <= 0;
        if (i_hash_data_out_valid) begin
            o_hash_data_out_ready <= 1;
            start_dot_mul <= 1;
        end
        else begin
            start_dot_mul <= 0;
        end
    end
                
     s_done: begin
                start_addr_0_en <= 0;
                start_dot_mul <= 0;
                o_hash_start <= 0;
             end
     
     default: begin
                start_addr_0_en <= 0;
                start_dot_mul <= 0;
                o_hash_start <= 0;
               end
    
    endcase
    
end

endmodule