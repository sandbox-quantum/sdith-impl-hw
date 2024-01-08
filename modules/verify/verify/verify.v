/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/


`include "clog2.v"

module verify 
#(
    parameter FIELD = "GF256",
//    parameter FIELD = "P251",
    parameter PARAMETER_SET = "L1",
    parameter N_GF = 8, 
    
    parameter LAMBDA =      (PARAMETER_SET == "L1")? 128:
                            (PARAMETER_SET == "L3")? 192:
                            (PARAMETER_SET == "L5")? 256:
                                                     128,


                                                    
    parameter M  =  (PARAMETER_SET == "L1")? 230:
                    (PARAMETER_SET == "L3")? 352:
                    (PARAMETER_SET == "L5")? 480:
                                             8,

    parameter D_SPLIT = (PARAMETER_SET == "L1")? 1:
                        (PARAMETER_SET == "L3")? 2:
                        (PARAMETER_SET == "L5")? 2:
                                                 1,

    parameter  K =  (PARAMETER_SET == "L1")? 126:
                    (PARAMETER_SET == "L3")? 193:
                    (PARAMETER_SET == "L5")? 278:
                                               1,

    parameter TAU = (PARAMETER_SET == "L1")? 17:
                    (PARAMETER_SET == "L3")? 17:
                    (PARAMETER_SET == "L5")? 17:
                                             17,
    
    parameter T =   (PARAMETER_SET == "L5")? 4:
                                             3, 
    parameter SEED_SIZE = LAMBDA,
    parameter SALT_SIZE = 2*LAMBDA,
    
    parameter D_HYPERCUBE = 8,
    
    parameter NUMBER_OF_SEED_BITS = (2**(D_HYPERCUBE)+1) * LAMBDA,

    parameter SIZE_OF_R     = TAU*T*D_SPLIT*8,
    parameter SIZE_OF_EPS   = TAU*T*D_SPLIT*8,
    
    
    
    // H matrix size
    parameter MAT_ROW_SIZE_BYTES = (PARAMETER_SET == "L1")? 104:
                                   (PARAMETER_SET == "L3")? 159:
                                   (PARAMETER_SET == "L5")? 202:
                                                            8,
                                                            
    parameter MAT_COL_SIZE_BYTES  =(PARAMETER_SET == "L1")? 126:
                                   (PARAMETER_SET == "L3")? 193:
                                   (PARAMETER_SET == "L5")? 278:
                                                            8,
    
    parameter VEC_S_WEIGHT =  (PARAMETER_SET == "L1")? 126:
                            (PARAMETER_SET == "L3")? 193:
                            (PARAMETER_SET == "L5")? 278:
                                                     8,

    parameter VEC_SIZE_BYTES = (PARAMETER_SET == "L1")? 126:
                               (PARAMETER_SET == "L3")? 193:
                               (PARAMETER_SET == "L5")? 278:
                                                        8,

    parameter MAT_SIZE_BYTES = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES,
    
    parameter PROC_SIZE = N_GF*8,
    
    parameter MRS_BITS = MAT_ROW_SIZE_BYTES*8,
    parameter MCS_BITS = MAT_COL_SIZE_BYTES*8,
    
    parameter MAT_ROW_SIZE = MRS_BITS + (PROC_SIZE - MRS_BITS%PROC_SIZE)%PROC_SIZE,
    parameter MAT_COL_SIZE = MCS_BITS + (PROC_SIZE - MCS_BITS%PROC_SIZE)%PROC_SIZE,


    
    parameter MAT_SIZE = MAT_ROW_SIZE*MAT_COL_SIZE_BYTES,
    
    parameter MS = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES*8,
    parameter SHAKE_SQUEEZE_H = 2*(MS + (32-MS%32)%32)
    

)(
    input                                               i_clk,
    input                                               i_rst,

    input                                               i_start,
    output reg                                          o_done,

    input  [7:0]                                        i_i_star,

    input [`CLOG2(SEED_SIZE)-1:0]                       i_seed_h_addr,             
    input                                               i_seed_h_wr_en,
    input [31:0]                                        i_seed_h, 

    input                                               i_h2_wr_en,
    input [`CLOG2(2*SEED_SIZE/32)-1:0]                  i_h2_addr,
    input [31:0]                                        i_h2,

    // hash interface
    output   wire [32-1:0]                                      o_hash_data_in,
    input    wire [`CLOG2((SALT_SIZE+SEED_SIZE)/32) -1:0]       i_hash_addr,
    input    wire                                               i_hash_rd_en,

    input    wire [32-1:0]                                      i_hash_data_out,
    input    wire                                               i_hash_data_out_valid,
    output   wire                                               o_hash_data_out_ready,

    output   wire  [32-1:0]                                     o_hash_input_length, // in bits
    output   wire  [32-1:0]                                     o_hash_output_length, // in bits

    output   wire                                               o_hash_start,
    input    wire                                               i_hash_force_done_ack,
    output   wire                                               o_hash_force_done

);


parameter EXPAND_H = 3'b000;
parameter EXPAND_VIEW_CHALLENGE = 3'b001;

reg [2:0]sel_hash;

assign o_hash_data_in           =     (sel_hash == EXPAND_VIEW_CHALLENGE) ? evc_o_hash_data_in:
                                                                            o_hash_data_in_h;

assign o_hash_data_out_ready    =      (sel_hash == EXPAND_VIEW_CHALLENGE) ? evc_o_hash_data_out_ready:
                                                                            o_hash_data_out_ready_h;

assign o_hash_input_length      =      (sel_hash == EXPAND_VIEW_CHALLENGE) ? evc_o_hash_input_length:
                                                                            SEED_SIZE; 

assign o_hash_output_length     =      (sel_hash == EXPAND_VIEW_CHALLENGE) ? evc_o_hash_output_length:
                                                                            SHAKE_SQUEEZE_H;

assign o_hash_start             =      (sel_hash == EXPAND_VIEW_CHALLENGE) ? evc_o_hash_start:
                                                                            o_hash_start_h;

assign o_hash_force_done        =      (sel_hash == EXPAND_VIEW_CHALLENGE) ? evc_o_hash_force_done:
                                                                            o_hash_force_done_h;

assign i_hash_addr_h            =      i_hash_addr;
assign i_hash_rd_en_h           =      (sel_hash == EXPAND_H) ? i_hash_rd_en: 0;
assign i_hash_data_out_h        =      i_hash_data_out;
assign i_hash_data_out_valid_h  =      (sel_hash == EXPAND_H) ? i_hash_data_out_valid : 0;
assign i_hash_force_done_ack_h  =      (sel_hash == EXPAND_VIEW_CHALLENGE) ? i_hash_force_done_ack : 0;


assign evc_i_hash_addr            =     i_hash_addr;
assign evc_i_hash_rd_en           =    (sel_hash == EXPAND_VIEW_CHALLENGE) ?  i_hash_rd_en : 0;
assign evc_i_hash_data_out        =     i_hash_data_out;
assign evc_i_hash_data_out_valid  =    (sel_hash == EXPAND_VIEW_CHALLENGE) ?  i_hash_data_out_valid : 0;
assign evc_i_hash_force_done_ack  =    (sel_hash == EXPAND_VIEW_CHALLENGE) ?  i_hash_force_done_ack : 0;

reg start_gen_h;

wire [32-1:0]                       o_hash_data_in_h;
wire                                o_hash_data_out_ready_h;
wire  [32-1:0]                      o_hash_input_length_h; // in bits
wire  [32-1:0]                      o_hash_output_length_h; // in bits
wire                                o_hash_start_h;
wire                                o_hash_force_done_h;

wire [`CLOG2((SEED_SIZE)/32) -1:0]  i_hash_addr_h;
wire                                i_hash_rd_en_h;
wire [32-1:0]                       i_hash_data_out_h;
wire                                i_hash_data_out_valid_h;
wire                                i_hash_done_h;
wire                                i_hash_force_done_ack_h;

gen_H_seq #(.FIELD(FIELD), .PARAMETER_SET(PARAMETER_SET), .N_GF(N_GF))
H_Matrix_Gen 
(
.i_clk(i_clk),      
.i_rst(i_rst),
.i_start(start_gen_h),

.i_seed_h(i_seed_h),
.i_seed_h_addr(i_seed_h_addr),
.i_seed_wr_en(i_seed_h_wr_en),

// .o_start_h_proc(o_hash_start_h),
.o_seed_h_prng(o_hash_data_in_h),

.o_start_prng(o_hash_start_h),

.i_prng_rd(i_hash_rd_en_h),
.i_prng_addr(i_hash_rd_en_h? i_hash_addr_h : 0),

.i_prng_out(i_hash_data_out_h),
.i_prng_out_valid(i_hash_data_out_valid_h),
.o_prng_out_ready(o_hash_data_out_ready_h),

.o_prng_force_done(o_hash_force_done_h),

.i_h_out_en(o_mat_vec_rd),
.i_h_out_addr(h_mat_addr),
.o_h_out(h_mat),

.o_done(done_gen_h)
);



// =============== Expand View Challenge ===============

wire [7:0] i_star;
wire [`CLOG2(TAU)-1:0] i_star_addr;
reg i_star_rd_en = 0;
reg start_evc;
wire done_evc;

wire [32-1:0]                                   evc_o_hash_data_in;
wire [`CLOG2((SALT_SIZE + SEED_SIZE)/32) -1:0]  evc_i_hash_addr;
wire                                            evc_i_hash_rd_en;
wire [32-1:0]                                   evc_i_hash_data_out;
wire                                            evc_i_hash_data_out_valid;
wire                                            evc_o_hash_data_out_ready;
wire  [32-1:0]                                  evc_o_hash_input_length; // in bits
wire  [32-1:0]                                  evc_o_hash_output_length; // in bits
wire                                            evc_o_hash_start;
wire                                            evc_i_hash_done;
wire                                            evc_i_hash_force_done_ack;
wire                                            evc_o_hash_force_done;

expand_view_challenge #(.PARAMETER_SET(PARAMETER_SET))
ExpandViewChallenge 
(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_start(start_evc),
    .o_done(done_evc),


    .i_h2_rd_en(0),
    .i_h2_wr_en(i_h2_wr_en),
    .i_h2_addr(i_h2_addr),
    .i_h2(i_h2),

    .o_i_star(i_star),
    .i_i_star_addr(i_star_addr),
    .i_i_star_rd_en(i_star_rd_en),

    .o_hash_data_in          (evc_o_hash_data_in       ),   
    .i_hash_addr             (evc_i_hash_addr          ),   
    .i_hash_rd_en            (evc_i_hash_rd_en         ),   
    .i_hash_data_out         (evc_i_hash_data_out      ),   
    .i_hash_data_out_valid   (evc_i_hash_data_out_valid),   
    .o_hash_data_out_ready   (evc_o_hash_data_out_ready),   
    .o_hash_input_length     (evc_o_hash_input_length  ),   
    .o_hash_output_length    (evc_o_hash_output_length ),   
    .o_hash_start            (evc_o_hash_start         ),   
    .i_hash_force_done_ack   (evc_i_hash_force_done_ack),   
    .o_hash_force_done       (evc_o_hash_force_done    )

);

reg [4:0] state;

parameter s_wait_start                  = 0;
parameter s_done_h                      = 1;
parameter s_wait_force_done_ack_0       = 2;
parameter s_done_evc                    = 3;
parameter s_done                        = 31;


always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
    end
    else begin
        if (state == s_wait_start) begin
            if (i_start) begin
                state <= s_done_h;
            end
        end
        
        else if (state == s_done_h) begin
            if (done_gen_h) begin
                state <= s_wait_force_done_ack_0;
            end
        end

        else if (state == s_wait_force_done_ack_0) begin
            if (i_hash_force_done_ack) begin
                state <= s_done_evc;
            end
        end

        else if (state == s_done_evc) begin
            if (done_evc) begin
                state <= s_done;
            end
        end
            
        else if (state == s_done) begin
            state <= s_wait_start;
        end
    end
end


always@(*)
begin
    case(state)

        s_wait_start: begin
            o_done <= 0;
            start_evc = 0;
            sel_hash <= EXPAND_H;
            if (i_start) begin
                start_gen_h = 1;
            end 
            else begin
                start_gen_h = 0;
            end
        end

        s_done_h: begin
            start_gen_h = 0;
            o_done <= 0;
            sel_hash <= EXPAND_H;
            start_evc = 0;
        end

        s_wait_force_done_ack_0: begin
            start_gen_h = 0;
            o_done <= 0;
            start_evc = 0;
            sel_hash <= EXPAND_VIEW_CHALLENGE;
            if (i_hash_force_done_ack) begin
                start_evc = 1;
            end
            else begin
                start_evc = 0;
            end
        end

        s_done_evc: begin
            start_gen_h = 0;
            o_done <= 0;
            start_evc = 0;
            sel_hash <= EXPAND_VIEW_CHALLENGE;
        end

        s_done: begin
            start_gen_h = 0;
            o_done <= 1;
            start_evc = 0;
            sel_hash <= EXPAND_H;
        end

        default: begin
            start_gen_h = 0;
            o_done <= 0;
            start_evc = 0;
            sel_hash <= EXPAND_H;
        end
    
    endcase
end


endmodule