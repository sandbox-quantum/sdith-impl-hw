/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module sign_online
#(
   parameter WIDTH = 32,

   parameter FIELD = "GF256",
//     parameter FIELD = "P251",

    parameter PARAMETER_SET = "L1",
    
    parameter LAMBDA =   (PARAMETER_SET == "L1")? 128:
                            (PARAMETER_SET == "L3")? 192:
                            (PARAMETER_SET == "L5")? 256:
                                                     128,
                                                    
    parameter M =  (PARAMETER_SET == "L1")? 230:
                        (PARAMETER_SET == "L3")? 352:
                        (PARAMETER_SET == "L5")? 480:
                                                 230,

    parameter WEIGHT =  (PARAMETER_SET == "L1")? 79:
                        (PARAMETER_SET == "L3")? 120:
                        (PARAMETER_SET == "L5")? 150:
                                                 79,

    parameter D_SPLIT = (PARAMETER_SET == "L1")? 1:
                        (PARAMETER_SET == "L3")? 2:
                        (PARAMETER_SET == "L5")? 2:
                                                 1,
    //  k + 2w + t(2d + 1)η

    parameter  K =  (PARAMETER_SET == "L1")? 126:
                    (PARAMETER_SET == "L3")? 193:
                    (PARAMETER_SET == "L5")? 278:
                                               1,

    parameter  TAU =    (PARAMETER_SET == "L1")? 17:
                        (PARAMETER_SET == "L3")? 17: //check and update
                        (PARAMETER_SET == "L5")? 17: //check and update
                                               17,
    
    parameter D_HYPERCUBE = 8,
    parameter ETA = 4,

    parameter T =   (PARAMETER_SET == "L5")? 4:
                                             3, 

    parameter SEED_SIZE = LAMBDA,
    parameter SALT_SIZE = 2*LAMBDA,
    parameter NUMBER_OF_SEED_BITS = (2**D_HYPERCUBE) * SEED_SIZE,

    parameter HASH_INPUT_SIZE = LAMBDA + 2*LAMBDA,
    
    parameter HASH_OUTPUT_SIZE = 8*(K + 2*D_SPLIT*WEIGHT + T*D_SPLIT*3),
    parameter HO_SIZE_ADJ = HASH_OUTPUT_SIZE + (WIDTH - HASH_OUTPUT_SIZE%WIDTH)%WIDTH,
    
    parameter SK_SIZE = 8*(K + 2*D_SPLIT*WEIGHT),
    parameter SK_SIZE_ADJ = SK_SIZE + (WIDTH - SK_SIZE%WIDTH)%WIDTH,

    parameter Y_SIZE = (M-K)*8,
    parameter Y_SIZE_ADJ = Y_SIZE + (WIDTH - Y_SIZE%WIDTH)%WIDTH,

    parameter COMMIT_INPUT_SIZE = SALT_SIZE + SEED_SIZE + 32,
    parameter COMMIT_INPUT_SIZE_LAST = SALT_SIZE + SEED_SIZE + HASH_OUTPUT_SIZE + 32,
    parameter COMMIT_OUTPUT_SIZE = LAMBDA,
    parameter COMMIT_RAM_DEPTH = (COMMIT_OUTPUT_SIZE*(2**D_HYPERCUBE))/32,

    parameter HASH1_SIZE = 8 + SEED_SIZE + Y_SIZE + SALT_SIZE + COMMIT_OUTPUT_SIZE*(2**D_HYPERCUBE)*TAU,
    parameter HASH1_SIZE_ADJ = HASH1_SIZE + (WIDTH - HASH1_SIZE%WIDTH)%WIDTH, 

    

    parameter FILE_SK = ""
    

)(
    input                                               i_clk,
    input                                               i_rst,

    input                                               i_start,
    output reg                                          o_done,

    input   [32-1:0]                                    i_seed_h,
    input   [`CLOG2(SEED_SIZE/32)-1:0]                  i_seed_h_addr,
    input                                               i_seed_h_wr_en,

    input   [32-1:0]                                    i_salt,
    input   [`CLOG2(SALT_SIZE/32)-1:0]                  i_salt_addr,
    input                                               i_salt_wr_en,

    input   [32-1:0]                                    i_h1,
    input   [`CLOG2(2*SEED_SIZE/32)-1:0]                o_h1_addr,
    input                                               o_h1_rd_en,

    // input  [`CLOG2(D_HYPERCUBE)-1:0]                    o_input_mshare_sel,
    // input                                               o_input_mshare_rd,
    // input  [`CLOG2((TAU-1)*HO_SIZE_ADJ/32)-1:0]         o_input_mshare_addr,
    // output [WIDTH-1:0]                                  i_input_mshare,

    // hash interface
    output   [32-1:0]                                   o_hash_data_in,
    input    [`CLOG2(HASH1_SIZE_ADJ/32) -1:0]           i_hash_addr,
    input                                               i_hash_rd_en,

    input    wire [32-1:0]                              i_hash_data_out,
    input    wire                                       i_hash_data_out_valid,
    output   wire                                       o_hash_data_out_ready,

    output   wire  [32-1:0]                             o_hash_input_length, // in bits
    output   wire  [32-1:0]                             o_hash_output_length, // in bits

    output   wire                                       o_hash_start,
    input    wire                                       i_hash_force_done_ack,
    output   wire                                       o_hash_force_done

);

parameter H_GEN     = 0;
parameter MPC       = 1;
parameter EVC       = 2;
parameter GSSP      = 3;

reg [1:0] sel_hash_type;

assign o_hash_data_in        =  (sel_hash_type == H_GEN)?   hgen_o_hash_data_in:
                                (sel_hash_type == MPC)?     mpc_o_hash_data_in:
                                (sel_hash_type == EVC)?     evc_o_hash_data_in:
                                                            gssp_o_hash_data_in;


assign o_hash_data_out_ready =  (sel_hash_type == H_GEN)?   hgen_o_hash_data_out_ready:
                                (sel_hash_type == MPC)?     mpc_o_hash_data_out_ready:
                                (sel_hash_type == EVC)?     evc_o_hash_data_out_ready:
                                                            gssp_o_hash_data_out_ready;
                            

assign o_hash_input_length   =  (sel_hash_type == H_GEN)?   hgen_o_hash_input_length:
                                (sel_hash_type == MPC)?     mpc_o_hash_input_length:
                                (sel_hash_type == EVC)?     evc_o_hash_input_length:
                                                            gssp_o_hash_input_length; 

assign o_hash_output_length  =  (sel_hash_type == H_GEN)?   hgen_o_hash_output_length:
                                (sel_hash_type == MPC)?     mpc_o_hash_output_length:
                                (sel_hash_type == EVC)?     evc_o_hash_output_length:
                                                            gssp_o_hash_output_length; 


assign o_hash_start          =  (sel_hash_type == H_GEN)?   hgen_o_hash_start:
                                (sel_hash_type == MPC)?     mpc_o_hash_start:
                                (sel_hash_type == EVC)?     evc_o_hash_start: 
                                                            gssp_o_hash_start; 

assign o_hash_force_done     =  (sel_hash_type == H_GEN)?   hgen_o_hash_force_done:
                                (sel_hash_type == MPC)?     mpc_o_hash_force_done:
                                (sel_hash_type == EVC)?     evc_o_hash_force_done:
                                                            gssp_o_hash_force_done; 

// assign mpc_i_hash_addr       = i_hash_addr;                
// assign mpc_i_hash_rd_en      = i_hash_rd_en;             
// assign mpc_i_hash_data_out   = i_hash_data_out;     
// assign mpc_i_hash_data_out_valid = i_hash_data_out_valid;       
// assign mpc_i_hash_force_done_ack = i_hash_force_done_ack;

assign hgen_i_hash_addr       =      i_hash_addr;                
assign hgen_i_hash_rd_en      =      (sel_hash_type == H_GEN)? i_hash_rd_en : 0;             
assign hgen_i_hash_data_out   =      i_hash_data_out;     
assign hgen_i_hash_data_out_valid =  (sel_hash_type == H_GEN)? i_hash_data_out_valid : 0;       
assign hgen_i_hash_force_done_ack =  (sel_hash_type == H_GEN)? i_hash_force_done_ack : 0;

assign mpc_i_hash_addr       =      i_hash_addr;                
assign mpc_i_hash_rd_en      =      (sel_hash_type == MPC)? i_hash_rd_en : 0;             
assign mpc_i_hash_data_out   =      i_hash_data_out;     
assign mpc_i_hash_data_out_valid =  (sel_hash_type == MPC)? i_hash_data_out_valid : 0;       
assign mpc_i_hash_force_done_ack =  (sel_hash_type == MPC)? i_hash_force_done_ack : 0;

assign evc_i_hash_addr       =      i_hash_addr;                
assign evc_i_hash_rd_en      =      (sel_hash_type == EVC)? i_hash_rd_en : 0;             
assign evc_i_hash_data_out   =      i_hash_data_out;     
assign evc_i_hash_data_out_valid =  (sel_hash_type == EVC)? i_hash_data_out_valid : 0;       
assign evc_i_hash_force_done_ack =  (sel_hash_type == EVC)? i_hash_force_done_ack : 0;

assign gssp_i_hash_addr       =      i_hash_addr;                
assign gssp_i_hash_rd_en      =      (sel_hash_type == GSSP)? i_hash_rd_en : 0;             
assign gssp_i_hash_data_out   =      i_hash_data_out;     
assign gssp_i_hash_data_out_valid =  (sel_hash_type == GSSP)? i_hash_data_out_valid : 0;       
assign gssp_i_hash_force_done_ack =  (sel_hash_type == GSSP)? i_hash_force_done_ack : 0;


// ======================= H prime GEN ==========================
wire [32-1:0]                                   hgen_o_hash_data_in;
wire [`CLOG2((SALT_SIZE + SEED_SIZE)/32) -1:0]  hgen_i_hash_addr;
wire                                            hgen_i_hash_rd_en;
wire [32-1:0]                                   hgen_i_hash_data_out;
wire                                            hgen_i_hash_data_out_valid;
wire                                            hgen_o_hash_data_out_ready;
wire  [32-1:0]                                  hgen_o_hash_input_length; // in bits
wire  [32-1:0]                                  hgen_o_hash_output_length; // in bits
wire                                            hgen_o_hash_start;
wire                                            hgen_i_hash_done;
wire                                            hgen_i_hash_force_done_ack;
wire                                            hgen_o_hash_force_done;

// =============================================================

wire h1_rd_mpc;
wire [`CLOG2(2*SEED_SIZE/32)-1:0] h1_addr_mpc;
reg start_mpc_chal;
wire done_mpc_chal;

wire [32-1:0]                       mpc_o_hash_data_in;
wire [`CLOG2((2*SEED_SIZE)/32) -1:0]mpc_i_hash_addr;
wire                                mpc_i_hash_rd_en;
wire [32-1:0]                       mpc_i_hash_data_out;
wire                                mpc_i_hash_data_out_valid;
wire                                mpc_o_hash_data_out_ready;
wire  [32-1:0]                      mpc_o_hash_input_length; // in bits
wire  [32-1:0]                      mpc_o_hash_output_length; // in bits
wire                                mpc_o_hash_start;
wire                                mpc_i_hash_done;
wire                                mpc_i_hash_force_done_ack;
wire                                mpc_o_hash_force_done;


wire   [T*8-1:0]                                  r;
wire   [`CLOG2(TAU*D_SPLIT)-1:0]                   r_addr;
reg                                               r_rd;

wire   [T*8-1:0]                                  eps;
wire   [`CLOG2(TAU*D_SPLIT)-1:0]                   eps_addr;
reg                                               eps_rd;


   

assign r_addr = e_count;
assign eps_addr = e_count;

expand_mpc_challenge #(.PARAMETER_SET(PARAMETER_SET))
EXPAND_MPC_CHAL 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(start_mpc_chal),
.o_done(done_mpc_chal),


.o_h1_rd(o_h1_rd_en),
.o_h1_addr(o_h1_addr),
.i_h1(i_h1),

.o_r(r),
.i_r_addr(r_addr),
.i_r_rd(r_rd),

.o_eps(eps),
.i_eps_addr(eps_addr),
.i_eps_rd(eps_rd),


.o_hash_data_in          (mpc_o_hash_data_in       ),   
.i_hash_addr             (mpc_i_hash_addr          ),   
.i_hash_rd_en            (mpc_i_hash_rd_en         ),   
.i_hash_data_out         (mpc_i_hash_data_out      ),   
.i_hash_data_out_valid   (mpc_i_hash_data_out_valid),   
.o_hash_data_out_ready   (mpc_o_hash_data_out_ready),   
.o_hash_input_length     (mpc_o_hash_input_length  ),   
.o_hash_output_length    (mpc_o_hash_output_length ),   
.o_hash_start            (mpc_o_hash_start         ),   
.i_hash_force_done_ack   (mpc_i_hash_force_done_ack),   
.o_hash_force_done       (mpc_o_hash_force_done    )

);



reg start_comp_plain_broad;
wire done_comp_plain_broad;


wire o_start_mul;
wire [31:0] o_x_mul;
wire [31:0] o_y_mul;
wire  [31:0] i_o_mul;
wire  i_done_mul;

wire o_start_mul_gf8;
wire [32*T-1:0] o_in_1_mul_gf8;
wire [7:0] o_in_2_mul_gf8;
wire [32*T-1:0] i_out_mul_gf8;
wire [32*T/8 -1:0] i_done_mul_gf8;

wire o_start_add;
wire [32*T-1:0] o_in_1_add;
wire [32*T-1:0] o_in_2_add;
wire [32*T-1:0] i_add_out;
wire [T-1:0] i_done_add;


wire                                            o_start_evaluate;
wire  [7:0]                                     o_q_s;
wire [`CLOG2(M)-1:0]                            i_q_s_addr;
wire                                            i_q_s_rd;
wire [32*T-1:0]                                 o_r_eps;
wire [32*T-1:0]                                 i_evaluate_out;
wire                                            i_done_evaluate;

wire                                            o_start_mul32;
wire [31:0]                                     o_x_mul32;
wire [31:0]                                     o_y_mul32;
wire  [31:0]                                    i_o_mul32;
wire                                            i_done_mul32;

wire                                            o_start_add32;
wire [32*T-1:0]                                 o_in_1_add32;
wire [32*T-1:0]                                 o_in_2_add32;
wire [32*T-1:0]                                 i_add_out_add32;
wire                                            i_done_add32;

// Compute Plain Broadcast Signals
wire                                            cpb_o_start_evaluate;
wire  [7:0]                                     cpb_o_q_s;
// wire [`CLOG2(M)-1:0]                            i_q_s_addr;
// wire                                            i_q_s_rd;
wire [32*T-1:0]                                 cpb_o_r_eps;
// wire [32*T-1:0]                                 i_evaluate_out;
// wire                                            i_done_evaluate;

wire                                            cpb_o_start_mul32;
wire [31:0]                                     cpb_o_x_mul32;
wire [31:0]                                     cpb_o_y_mul32;
// wire  [31:0]                                    i_o_mul32;
// wire                                            i_done_mul32;

wire                                            cpb_o_start_add32;
wire [32*T-1:0]                                 cpb_o_in_1_add32;
wire [32*T-1:0]                                 cpb_o_in_2_add32;
// wire [32*T-1:0]                                 i_add_out_add32;
// wire                                            i_done_add32;

reg start_cpb;
wire done_cpb;
reg sel_pc;

assign o_start_evaluate = sel_pc?   pc_o_start_evaluate:
                                    cpb_o_start_evaluate;

assign o_q_s = sel_pc?  pc_o_qspf:
                        cpb_o_q_s;

assign o_r_eps = sel_pc?    pc_o_r_eps:
                            cpb_o_r_eps;

assign o_start_mul32 = sel_pc?  pc_o_start_mul32:
                                cpb_o_start_mul32;

assign o_x_mul32 = sel_pc?  pc_o_x_mul32:
                            cpb_o_x_mul32;

assign o_y_mul32 = sel_pc?  pc_o_y_mul32:
                            cpb_o_y_mul32;

assign o_start_add32 = sel_pc?  pc_o_start_add32:
                                cpb_o_start_add32;

assign o_in_1_add32 = sel_pc?   pc_o_in_1_add32:
                                cpb_o_in_1_add32;

assign o_in_2_add32 = sel_pc?   pc_o_in_2_add32:
                                cpb_o_in_2_add32;

// compute_plain_broadcast #(.PARAMETER_SET(PARAMETER_SET), .FILE_MEM_INIT(FILE_MEM_INIT))
compute_plain_broadcast #(.PARAMETER_SET(PARAMETER_SET))
COMP_PLAIN_BROAD 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(start_cpb),

.i_q(i_q),
.o_q_addr(o_q_addr),
.o_q_rd(o_q_rd),

.i_s(i_s),
.o_s_addr(o_s_addr),
.o_s_rd(o_s_rd),

.i_a(i_a),
.i_b(i_b),

.i_r(r),
// .o_r_addr(o_r_addr),
// .o_r_rd(o_r_rd),

.i_eps(eps),
// .o_eps_addr(o_eps_addr),
// .o_eps_rd(o_eps_rd),

.o_alpha(pc_i_alpha_prime),
.o_beta(pc_i_beta_prime),

.o_start_mul32(cpb_o_start_mul32),
.o_x_mul32(cpb_o_x_mul32),
.o_y_mul32(cpb_o_y_mul32),
.i_o_mul32(i_o_mul32),
.i_done_mul32(i_done_mul32),

.o_start_add32(cpb_o_start_add32),
.o_in_1_add32(cpb_o_in_1_add32),
.o_in_2_add32(cpb_o_in_2_add32),
.i_add_out_add32(i_add_out_add32),
.i_done_add32(i_done_add32),

.o_start_evaluate(cpb_o_start_evaluate),
.o_q_s(cpb_o_q_s),
.i_q_s_addr(i_q_s_addr),
.i_q_s_rd(i_q_s_rd),
.o_r_eps(cpb_o_r_eps),
.i_evaluate_out(i_evaluate_out),
.i_done_evaluate(i_done_evaluate),

.o_done(done_cpb)
);


// ======= PARTY COMPUTATION ===========

reg                                             start_pc;
wire                                            done_pc;

wire  [7:0]                                     pc_i_q;
wire [`CLOG2(M)-1:0]                            pc_o_q_addr;
wire                                            pc_o_q_rd;

wire  [7:0]                                     pc_i_s;
wire [`CLOG2(M)-1:0]                            pc_o_s_addr;
wire                                            pc_o_s_rd;

wire  [7:0]                                     pc_i_p;
wire [`CLOG2(M)-1:0]                            pc_o_p_addr;
wire                                            pc_o_p_rd;

wire  [7:0]                                     pc_i_f;
wire [`CLOG2(M)-1:0]                            pc_o_f_addr;
wire                                            pc_o_f_rd;

wire [T*8-1:0]                                  pc_o_r;
wire [`CLOG2(TAU*D_SPLIT)-1:0]                  pc_i_r_addr;
wire                                            pc_i_r_rd;

wire [T*8-1:0]                                  pc_o_eps;
wire [`CLOG2(TAU*D_SPLIT)-1:0]                  pc_i_eps_addr;
wire                                            pc_i_eps_rd;


reg [T*32-1:0]                                  pc_i_minus_c;

wire   [32-1:0]                                 pc_i_share;

reg [T*32-1:0]                                  pc_i_a;
reg [T*32-1:0]                                  pc_i_b;

reg [T*32-1:0]                                  pc_i_r;


reg [T*32-1:0]                                  pc_i_eps;

reg [T*32-1:0]                                  pc_i_alpha_prime;
reg [T*32-1:0]                                  pc_i_beta_prime;

wire                                            pc_o_start_evaluate;
wire  [7:0]                                     pc_o_qspf;
wire [`CLOG2(M)-1:0]                            pc_i_qspf_addr;
wire                                            pc_i_qspf_rd;
wire [32*T-1:0]                                 pc_o_r_eps;
wire [32*T-1:0]                                 pc_i_evaluate_out;
wire                                            pc_i_done_evaluate;

wire                                            pc_o_start_mul32;
wire [31:0]                                     pc_o_x_mul32;
wire [31:0]                                     pc_o_y_mul32;
wire  [31:0]                                    pc_i_o_mul32;
wire                                            pc_i_done_mul32;

wire                                            pc_o_start_add32;
wire [32*T-1:0]                                 pc_o_in_1_add32;
wire [32*T-1:0]                                 pc_o_in_2_add32;
wire [32*T-1:0]                                 pc_i_add_out_add32;
wire                                            pc_i_done_add32;

wire                                            pc_o_start_mul;
wire [31:0]                                     pc_o_x_mul;
wire [31:0]                                     pc_o_y_mul;
wire  [31:0]                                    pc_i_o_mul;
wire                                            pc_i_done_mul;

wire                                            pc_o_start_mul_gf8;
wire [32*T-1:0]                                 pc_o_in_1_mul_gf8;
wire [7:0]                                      pc_o_in_2_mul_gf8;
wire [32*T-1:0]                                 pc_i_out_mul_gf8;
wire [32*T/8 -1:0]                              pc_i_done_mul_gf8;

wire                                            pc_o_start_add;
wire [32*T-1:0]                                 pc_o_in_1_add;
wire [32*T-1:0]                                 pc_o_in_2_add;
wire [32*T-1:0]                                 pc_i_add_out;
wire [T-1:0]                                    pc_i_done_add;

// .o_start_evaluate(o_start_evaluate),
// .o_q_s(o_q_s),
// .i_q_s_addr(i_q_s_addr),
// .i_q_s_rd(i_q_s_rd),
// .o_r_eps(o_r_eps),
// .i_evaluate_out(i_evaluate_out),
// .i_done_evaluate(i_done_evaluate),


assign  pc_i_qspf_addr = sel_pc?    i_q_s_addr: 
                                    0;

assign  pc_i_qspf_rd = sel_pc?  i_q_s_rd:
                                0 ;

assign  pc_i_evaluate_out = sel_pc? i_evaluate_out:
                                    0;

assign  pc_i_done_evaluate = sel_pc?    i_done_evaluate:
                                        0;


assign pc_i_o_mul32 = sel_pc?   i_o_mul32:
                                0;
                                        
                                
assign pc_i_done_mul32 = sel_pc?    i_done_mul32:
                                    0;

assign pc_i_add_out_add32 = sel_pc? pc_i_add_out_add32:
                                    0;

assign pc_i_done_add32 = sel_pc?    i_done_add32:
                                    0;

// party_computation #(.PARAMETER_SET(PARAMETER_SET), .FILE_MEM_INIT(FILE_MEM_INIT))
party_computation #(.PARAMETER_SET(PARAMETER_SET), .FILE_MEM_INIT())
DUT 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(start_pc),

.i_q(pc_i_q),
.o_q_addr(pc_o_q_addr),
.o_q_rd(pc_o_q_rd),

.i_s(pc_i_s),
.o_s_addr(pc_o_s_addr),
.o_s_rd(pc_o_s_rd),

.i_p(pc_i_p),
.o_p_addr(pc_o_p_addr),
.o_p_rd(pc_o_p_rd),

.i_f(pc_i_f),
.o_f_addr(pc_o_f_addr),
.o_f_rd(pc_o_f_rd),

.i_a(pc_i_a),
.i_b(pc_i_b),

.i_minus_c(pc_i_minus_c),

.i_r(r),
// .o_r_addr(o_r_addr),
// .o_r_rd(o_r_rd),

.i_eps(eps),

.i_alpha_prime(pc_i_alpha_prime),
.i_beta_prime(pc_i_beta_prime),
// .o_eps_addr(o_eps_addr),
// .o_eps_rd(o_eps_rd),

.o_start_mul32(pc_o_start_mul32),
.o_x_mul32(pc_o_x_mul32),
.o_y_mul32(pc_o_y_mul32),
.i_o_mul32(pc_i_o_mul32),
.i_done_mul32(pc_i_done_mul32),

.o_start_add32(pc_o_start_add32),
.o_in_1_add32(pc_o_in_1_add32),
.o_in_2_add32(pc_o_in_2_add32),
.i_add_out_add32(pc_i_add_out_add32),
.i_done_add32(pc_i_done_add32),

.o_start_evaluate(pc_o_start_evaluate),
.o_qspf(pc_o_qspf),
.i_qspf_addr(pc_i_qspf_addr),
.i_qspf_rd(pc_i_qspf_rd),
.o_r_eps(pc_o_r_eps),
.i_evaluate_out(pc_i_evaluate_out),
.i_done_evaluate(pc_i_done_evaluate),

.o_done(done_pc)
);


// =====================================


evaluate
EVALUATE_QS
(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_r(o_r_eps),
    .i_q(o_q_s),
    .o_q_rd(i_q_s_rd),
    .o_q_addr(i_q_s_addr),
    .i_start(o_start_evaluate),
    .o_eval(i_evaluate_out),

    `ifdef GF32_MUL_SHARED
        .o_start_mul(o_start_mul),
        .o_x_mul(o_x_mul),
        .o_y_mul(o_y_mul),
        .i_o_mul(i_o_mul),
        .i_done_mul(i_done_mul),
    `endif 

    `ifdef GF8_MUL_SHARED
        .o_start_mul_gf8(o_start_mul_gf8),
        .o_in_1_mul_gf8(o_in_1_mul_gf8),
        .o_in_2_mul_gf8(o_in_2_mul_gf8),
        .i_out_mul_gf8(i_out_mul_gf8),
        .i_done_mul_gf8(i_done_mul_gf8),
    `endif 

    `ifdef GF32_ADD_SHARED
        .o_start_add(o_start_add),
        .o_in_1_add(o_in_1_add),
        .o_in_2_add(o_in_2_add),
        .i_add_out(i_add_out),
        .i_done_add(i_done_add),
    `endif 

    .o_done(i_done_evaluate)
);
 
assign i_o_mul32 = i_o_mul;
assign i_done_mul32 = i_done_mul;

`ifdef GF32_MUL_SHARED
    gf_mul_32
    GF32_MUL
    (
        .i_clk(i_clk),
        .i_x(o_start_mul32 ? o_x_mul32 : o_x_mul),
        .i_y(o_start_mul32 ? o_y_mul32 : o_y_mul),
        .i_start(o_start_mul | o_start_mul32),
        .o_o(i_o_mul),
        .o_done(i_done_mul)
    );
`endif 

    wire o_start_mul_gf8;
    wire [32*T-1:0] o_in_1_mul_gf8;
    wire [32*T-1:0] o_in_2_mul_gf8;
    wire [32*T-1:0] i_out_mul_gf8;
    wire [32*T/8 -1:0] i_done_mul_gf8;

`ifdef GF8_MUL_SHARED
    genvar j;
    generate
        for(j=0; j< 32*T/8; j=j+1) begin
            gf_mul 
            #(
                .REG_IN(1),
                .REG_OUT(1)
            )
            GF_MUL_GF8
            (
                .clk(i_clk),
                .start(o_start_mul_gf8),
                .in_1(o_in_1_mul_gf8[32*T-8*j-1:32*T-8*j-8]),
                .in_2(o_in_2_mul_gf8),
                .out(i_out_mul_gf8[32*T-8*j-1:32*T-8*j-8]),
                .done(i_done_mul_gf8)
            );
                end
    endgenerate
`endif 


assign i_add_out_add32 = i_add_out;
assign i_done_add32 = i_done_add[0];

`ifdef GF32_ADD_SHARED
    genvar k;
    generate
        for(k=0; k<T; k=k+1) begin
            gf_add 
            #(
                .WIDTH(32),
                .REG_IN(1),
                .REG_OUT(1)
            )
            GF32_ADD 
            (
                .i_clk(i_clk), 
                .i_start(o_start_add32 | o_start_add), 
                .in_1(o_start_add32 ? o_in_1_add32[32*k+32-1:32*k] : o_in_1_add[32*k+32-1:32*k]), 
                .in_2(o_start_add32 ? o_in_2_add32[32*k+32-1:32*k] : o_in_2_add[32*k+32-1:32*k]),
                .o_done(i_done_add[k]), 
                .out(i_add_out[32*k+32-1:32*k]) 
            );
        end
    endgenerate
`endif

// =============== Expand View Challenge ===============
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

reg start_evc;
wire done_evc;
wire [`CLOG2(TAU)-1:0]               i_star_addr;
reg                                 i_star_rd;

assign i_star_addr = e_count;

expand_view_challenge #(.PARAMETER_SET(PARAMETER_SET))
ExpandViewChallenge 
(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_start(start_evc),
    .o_done(done_evc),


    .i_h2_wr_en(0),
    .i_h2_rd_en(0),
    .i_h2_addr(i_h2_addr),
    .i_h2(i_h2),
    .o_h2(o_h2),

    .o_i_star(i_star),
    .i_i_star_addr(i_star_addr),
    .i_i_star_rd_en(0),

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
// ===============      ===============     ===============

// =============== Get Seed Sibling Path ===============
wire [32-1:0]                       gssp_o_hash_data_in;
wire [`CLOG2((SALT_SIZE + SEED_SIZE)/32) -1:0]       gssp_i_hash_addr;
wire                                gssp_i_hash_rd_en;
wire [32-1:0]                       gssp_i_hash_data_out;
wire                                gssp_i_hash_data_out_valid;
wire                                gssp_o_hash_data_out_ready;
wire  [32-1:0]                      gssp_o_hash_input_length; // in bits
wire  [32-1:0]                      gssp_o_hash_output_length; // in bits
wire                                gssp_o_hash_start;
wire                                gssp_i_hash_done;
wire                                gssp_i_hash_force_done_ack;
wire                                gssp_o_hash_force_done;

reg start_gssp;
wire done_gssp;
wire [7:0] i_star;

get_seed_sibling_path #(.PARAMETER_SET(PARAMETER_SET))
GetSeedSiblingPath 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(start_gssp),
.o_done(done_gssp),

.i_i_star(i_star),

.i_salt_seed_wen(0),
.i_salt_seed_addr(0),
.i_salt_seed(0),


.o_hash_data_in          (gssp_o_hash_data_in       ),   
.i_hash_addr             (gssp_i_hash_addr          ),   
.i_hash_rd_en            (gssp_i_hash_rd_en         ),   
.i_hash_data_out         (gssp_i_hash_data_out      ),   
.i_hash_data_out_valid   (gssp_i_hash_data_out_valid),   
.o_hash_data_out_ready   (gssp_o_hash_data_out_ready),   
.o_hash_input_length     (gssp_o_hash_input_length  ),   
.o_hash_output_length    (gssp_o_hash_output_length ),   
.o_hash_start            (gssp_o_hash_start         ),   
.i_hash_force_done_ack   (gssp_i_hash_force_done_ack),   
.o_hash_force_done       (gssp_o_hash_force_done    )

);
// ===============      ===============     ===============

reg [`CLOG2(TAU)-1:0] e_count;
reg [`CLOG2(8):0] p_count;
reg [3:0] state;
parameter s_wait_start      = 0;
parameter s_start_mpc_chal  = 1;
parameter s_done_mpc_chal   = 2;

parameter s_for_loop_e      = 3;
parameter s_for_loop_p      = 4;

parameter s_start_cpb       = 5;
parameter s_done_cpb        = 6;

parameter s_start_pc       = 7;
parameter s_done_pc        = 8;

parameter s_start_evc       = 9;
parameter s_done_evc        = 10;

parameter s_for_loop_e_gssp  = 11;
parameter s_start_gssp       = 12;
parameter s_done_gssp        = 13;

parameter s_done            = 14;

always@(posedge i_clk)
begin
    if (i_rst) begin
        o_done <= 0;
        state <= s_wait_start;
        e_count <= 0;
        p_count <= 0;
        sel_hash_type <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            o_done <= 0;
            e_count <= 0;
            p_count <= 0;
            sel_hash_type <= 1;
            if (i_start) begin
                state <= s_start_mpc_chal;
            end
        end

        else if (state == s_start_mpc_chal) begin
            state <= s_done_mpc_chal;
        end

        else if (state == s_done_mpc_chal) begin
            if (done_mpc_chal) begin
                state <= s_for_loop_e;
                sel_hash_type <= 2;
            end
        end

        else if (state == s_for_loop_e) begin
            if (e_count == TAU) begin
            // if (e_count == 1) begin
                state <= s_start_evc;
                e_count <= 0;
            end
            else begin
                state <= s_start_cpb;
            end
        end

        else if (state == s_for_loop_p) begin
            if (p_count == D_HYPERCUBE) begin
                state <= s_for_loop_e;
                p_count <= 0;
                e_count <= e_count + 1;
            end
            else begin
                state <= s_start_pc;
            end
        end

        else if (state == s_start_cpb) begin
            state <= s_done_cpb;
        end

        else if (state == s_done_cpb) begin
            if (done_cpb) begin
                state <= s_start_pc;
                // e_count <= e_count + 1;
            end
        end

        else if (state == s_start_pc) begin
            state <= s_done_pc;
        end

        else if (state == s_done_pc) begin
            if (done_pc) begin
                state <= s_for_loop_p;
                // state <= s_for_loop_e;
                // e_count <= e_count + 1;
                p_count <= p_count + 1;
            end
        end

        else if (state == s_start_evc) begin
            state <= s_done_evc;
        end

        else if (state == s_done_evc) begin
            if (done_evc) begin
                state <= s_for_loop_e_gssp;
                sel_hash_type <= 3;
            end
        end

        else if (state == s_for_loop_e_gssp) begin
            if (e_count == TAU) begin
            // if (e_count == 1) begin
                state <= s_done;
                e_count <= 0;
            end
            else begin
                state <= s_start_gssp;
            end
        end

        else if (state == s_start_gssp) begin
            state <= s_done_gssp;
        end

        else if (state == s_done_gssp) begin
            if (done_gssp) begin
                state <= s_for_loop_e_gssp;
                e_count <= e_count+1;
            end
        end

        else if (state == s_done) begin
            o_done <= 1;
        end
    end
end

always@(*)
begin
    case(state)

    s_wait_start:begin
        start_mpc_chal <= 0;
        start_cpb <= 0;
        r_rd <= 0;
        eps_rd <= 0;
        sel_pc <= 0;
        start_pc <= 0;
        start_evc <= 0;
        start_gssp <= 0;
        i_star_rd <= 0;
    end

    s_start_mpc_chal:begin
        start_mpc_chal <= 1;
        start_cpb <= 0;
        r_rd <= 0;
        eps_rd <= 0;
        sel_pc <= 0;
        start_pc <= 0;
        start_evc <= 0;
        start_gssp <= 0;
        i_star_rd <= 0;
    end

    s_done_mpc_chal:begin
        start_mpc_chal <= 0;
        start_cpb <= 0;
        sel_pc <= 0;
        start_pc <= 0;
        start_evc <= 0;
        start_gssp <= 0;
        i_star_rd <= 0;
        if (done_mpc_chal) begin
            r_rd <= 1;
            eps_rd <= 1;
        end
        else begin
            r_rd <= 0;
            eps_rd <= 0;
        end
    end

    s_for_loop_e:begin
        start_mpc_chal <= 0;
        start_cpb <= 0;
        r_rd <= 1;
        eps_rd <= 1;
        sel_pc <= 0;
        start_pc <= 0;
        start_evc <= 0;
        start_gssp <= 0;
        i_star_rd <= 0;
    end

    s_start_cpb: begin
        start_mpc_chal <= 0;
        start_cpb <= 1;
        r_rd <= 1;
        eps_rd <= 1;
        sel_pc <= 0;
        start_pc <= 0;
        start_evc <= 0;
        start_gssp <= 0;
        i_star_rd <= 0;
    end

    s_done_cpb: begin
        start_mpc_chal <= 0;
        start_cpb <= 0;
        r_rd <= 0;
        eps_rd <= 0;
        sel_pc <= 0;
        start_pc <= 0;
        start_evc <= 0;
        start_gssp <= 0;
        i_star_rd <= 0;
    end

    s_start_pc: begin
        start_mpc_chal <= 0;
        start_cpb <= 1;
        r_rd <= 1;
        eps_rd <= 1;
        sel_pc <= 1;
        start_pc <= 1;
        start_evc <= 0;
        start_gssp <= 0;
        i_star_rd <= 0;
    end

    s_done_pc: begin
        start_mpc_chal <= 0;
        start_cpb <= 0;
        r_rd <= 0;
        eps_rd <= 0;
        sel_pc <= 1;
        start_pc <= 0;
        start_evc <= 0;
        start_gssp <= 0;
        i_star_rd <= 0;
    end

    

    s_start_evc: begin
        start_mpc_chal <= 0;
        start_cpb <= 0;
        r_rd <= 0;
        eps_rd <= 0;
        sel_pc <= 0;
        start_pc <= 0;
        start_evc <= 1;
        start_gssp <= 0;
        i_star_rd <= 0;
    end

    s_done_evc: begin
        start_mpc_chal <= 0;
        start_cpb <= 0;
        r_rd <= 0;
        eps_rd <= 0;
        sel_pc <= 0;
        start_pc <= 0;
        start_evc <= 0;
        start_gssp <= 0;
        i_star_rd <= 0;
    end

    s_for_loop_e_gssp: begin
        start_mpc_chal <= 0;
        start_cpb <= 0;
        r_rd <= 0;
        eps_rd <= 0;
        sel_pc <= 0;
        start_pc <= 0;
        start_evc <= 0;
        start_gssp <= 0;
        i_star_rd <= 1;
    end

    s_start_gssp: begin
        start_mpc_chal <= 0;
        start_cpb <= 0;
        r_rd <= 0;
        eps_rd <= 0;
        sel_pc <= 0;
        start_pc <= 0;
        start_evc <= 0;
        start_gssp <= 1;
        i_star_rd <= 1;
    end

    s_done_gssp: begin
        start_mpc_chal <= 0;
        start_cpb <= 0;
        r_rd <= 0;
        eps_rd <= 0;
        sel_pc <= 0;
        start_pc <= 0;
        start_evc <= 0;
        start_gssp <= 0;
        i_star_rd <= 1;
    end

    s_done: begin
        start_mpc_chal <= 0;
        start_cpb <= 0;
        r_rd <= 0;
        eps_rd <= 0;
        sel_pc <= 0;
        start_pc <= 0;
        start_evc <= 0;
        start_gssp <= 0;
    end

    default: begin
        start_mpc_chal <= 0;
        start_cpb <= 0;
        r_rd <= 0;
        eps_rd <= 0;
        sel_pc <= 0;
        start_pc <= 0;
        start_evc <= 0;
        start_gssp <= 0;
        i_star_rd <= 0;
    end
    endcase
end

endmodule