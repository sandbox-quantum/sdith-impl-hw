/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module sign_online_sk 
#(
    parameter PARAMETER_SET = "L1",

    parameter FIELD = "P251",
//    parameter FIELD = "GF256",
    
    parameter LAMBDA =      (PARAMETER_SET == "L1")? 128:
                            (PARAMETER_SET == "L3")? 192:
                            (PARAMETER_SET == "L5")? 256:
                                                     128,



    parameter D_SPLIT = (PARAMETER_SET == "L1")? 1:
                        (PARAMETER_SET == "L3")? 2:
                        (PARAMETER_SET == "L5")? 2:
                                                 1,
    parameter M  =  (PARAMETER_SET == "L1")? 230:
                    (PARAMETER_SET == "L3")? 352:
                    (PARAMETER_SET == "L5")? 480:
                                             230,

    parameter  K =  (PARAMETER_SET == "L1")? 126:
                    (PARAMETER_SET == "L3")? 193:
                    (PARAMETER_SET == "L5")? 278:
                                               1,

    parameter TAU = (PARAMETER_SET == "L1")? 17:
                    (PARAMETER_SET == "L3")? 26:
                    (PARAMETER_SET == "L5")? 34:
                                             17,
    
    parameter T =   (PARAMETER_SET == "L5")? 4:
                                             3, 

    parameter MAT_ROW_SIZE_BYTES = (PARAMETER_SET == "L1")? 104:
                                   (PARAMETER_SET == "L3")? 159:
                                   (PARAMETER_SET == "L5")? 202:
                                                            104,
                                                            
    parameter MAT_COL_SIZE_BYTES  =(PARAMETER_SET == "L1")? 126:
                                   (PARAMETER_SET == "L3")? 193:
                                   (PARAMETER_SET == "L5")? 278:
                                                            126,



    parameter VEC_S_WEIGHT =    (PARAMETER_SET == "L1")? 126:
                                (PARAMETER_SET == "L3")? 193:
                                (PARAMETER_SET == "L5")? 278:
                                                         8,

    parameter VEC_SIZE_BYTES = (PARAMETER_SET == "L1")? 126:
                               (PARAMETER_SET == "L3")? 193:
                               (PARAMETER_SET == "L5")? 278:
                                                        8,
                                                        
    parameter MAT_SIZE_BYTES = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES,
    

    parameter MRS_BITS = MAT_ROW_SIZE_BYTES*8,
    parameter MCS_BITS = MAT_COL_SIZE_BYTES*8,
    
    parameter MAT_ROW_SIZE = MRS_BITS + (PROC_SIZE - MRS_BITS%PROC_SIZE)%PROC_SIZE,
    parameter MAT_COL_SIZE = MCS_BITS + (PROC_SIZE - MCS_BITS%PROC_SIZE)%PROC_SIZE,
    parameter MAT_SIZE = MAT_ROW_SIZE*MAT_COL_SIZE_BYTES,
    
    parameter D_HYPERCUBE = 8,
    
    parameter N_GF = 4,
    parameter PROC_SIZE = N_GF*8,
    parameter WIDTH = PROC_SIZE,
    
    parameter Y_SIZE = (M-K)*8,
    parameter Y_SIZE_ADJ = Y_SIZE + (WIDTH - Y_SIZE%WIDTH)%WIDTH,

    parameter SIZE_OF_R     = TAU*T*D_SPLIT*8,
    parameter SIZE_OF_EPS   = TAU*T*D_SPLIT*8,

    // HASH_2 parameters
    parameter SALT_SIZE                     = 2*LAMBDA,
    parameter BROAD_PLAIN_SIZE              = 32*T*2,
    parameter BROAD_SHARE_SIZE              = 32*T*3,
    parameter MAX_MSG_SIZE_BITS             = 1024,
    
    parameter BROAD_PLAIN_SIZE_BYTES        = BROAD_PLAIN_SIZE/8,
    parameter BROAD_SHARE_SIZE_BYTES        = BROAD_SHARE_SIZE/8,
    parameter MAX_MSG_SIZE_BYTES            = MAX_MSG_SIZE_BITS/8,
    
    parameter HASH_BITS                     = 8 + MAX_MSG_SIZE_BITS + SALT_SIZE + TAU*BROAD_PLAIN_SIZE + TAU*D_HYPERCUBE*BROAD_SHARE_SIZE,
    parameter HASH_BITS_ADJ                 = HASH_BITS + (32 - HASH_BITS%32)%32,
    parameter HASH_BITS_NO_MSG              = HASH_BITS - MAX_MSG_SIZE_BITS,

    parameter HASH_BRAM_DEPTH               = HASH_BITS_ADJ/32,
    parameter HASH_OUTPUT_SIZE              = 2*LAMBDA,
    
    parameter FILE_MEM_INIT = ""
    

)(
    input                                               i_clk,
    input                                               i_rst,

    input                                               i_start,


    input  [7:0]                                        i_y,
    input [`CLOG2(Y_SIZE_ADJ/32)-1:0]                   i_y_addr,
    input                                               i_y_wr_en,
    
    input  [7:0]                                        i_q,
    output [`CLOG2(M)-1:0]                              o_q_addr,
    output                                              o_q_rd,

    input  [7:0]                                        i_p,
    output [`CLOG2(M)-1:0]                              o_p_addr,
    output                                              o_p_rd,

    input  [7:0]                                        i_f,
    output [`CLOG2(M)-1:0]                              o_f_addr,
    output                                              o_f_rd,

    input [T*32-1:0]                                    i_alpha_prime,
    input [T*32-1:0]                                    i_beta_prime,
    input [T*32-1:0]                                    i_r,
    input [T*32-1:0]                                    i_eps,


    output[`CLOG2(TAU*D_HYPERCUBE)-1:0]                 o_abc_addr,
    output reg                                          o_abc_rd,
    input [T*32-1:0]                                    i_minus_c,
    input [32*T-1:0]                                    i_a,
    input [32*T-1:0]                                    i_b,

    output   [`CLOG2(TAU)-1:0]                          o_a_b_r_e_c_addr,
    output  reg                                         o_a_b_r_e_c_rd,


    output                                              o_h_mat_sa_rd,
    output [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0]             o_h_mat_addr,
    output [`CLOG2(M)-1:0]                              o_sa_addr,
    input [PROC_SIZE-1:0]                               i_h_mat,
    input [7:0]                                         i_sa,

    // output  [32*T-1:0]                                  o_alpha,
    // output  [32*T-1:0]                                  o_beta,
    // output  [32*T-1:0]                                  o_v,

    output reg                                          o_done,
    
    
    input [7:0]                                         i_msg,
    input                                               i_msg_valid,
    output                                              o_msg_ready,
    input [`CLOG2(MAX_MSG_SIZE_BYTES)-1:0]              i_msg_size_in_bytes,


    output [`CLOG2(SALT_SIZE/32)-1:0]                   o_salt_addr,  
    output                                              o_salt_rd,  
    input  [31:0]                                       i_salt,

    // output [`CLOG2(TAU):0]                              o_broad_plain_h2_addr,  
    // output                                              o_broad_plain_h2_rd,  
    // input  [BROAD_PLAIN_SIZE-1:0]                       i_broad_plain_h2,

    output [`CLOG2(TAU):0]                              o_broad_plain_addr,  
    output                                              o_broad_plain_rd,  
    input  [BROAD_PLAIN_SIZE-1:0]                       i_broad_plain,

    input  [31:0]                                       i_rseed,
    output reg [`CLOG2(TAU*LAMBDA/32)-1:0]              o_rseed_addr,
    output reg                                          o_rseed_rd,

    input                                               i_view_rd_en,
    input [`CLOG2(TAU)-1:0]                             i_view_sel,
    input [`CLOG2((8*LAMBDA/32)) -1:0]                  i_view_addr,
    output [31:0]                                       o_view,
    
    input                                               i_i_star_rd_en,
    input [`CLOG2(TAU)-1:0]                             i_i_star_addr,
    input [7:0]                                         o_i_star,

    output reg [2:0]                                    o_status_reg,
    
//    input                                               i_broad_share_valid,
//    output reg                                          o_broad_share_ready,
//    input  [BROAD_SHARE_SIZE-1:0]                       i_broad_share,

//    input                                               i_start,
//    output reg                                          o_done,
    
   input  [`CLOG2(2*LAMBDA/32)-1:0]                     i_h2_addr,
   input                                                i_h2_rd_en,
   output  [31:0]                                       o_h2,
    
        // hash interface
    output   [32-1:0]                                   o_hash_data_in,
    input    [`CLOG2(HASH_BRAM_DEPTH) -1:0]             i_hash_addr,
    input                                               i_hash_rd_en,

    input    [32-1:0]                                   i_hash_data_out,
    input                                               i_hash_data_out_valid,
    output                                              o_hash_data_out_ready,

    output   [32-1:0]                                   o_hash_input_length, // in bits
    output   [32-1:0]                                   o_hash_output_length, // in bits

    output                                              o_hash_start,
    input                                               i_hash_force_done_ack,
    output                                              o_hash_force_done


);

reg [1:0] sel_hash;

assign o_hash_data_in           = (sel_hash == 1)? evc_o_hash_data_in:
                                (sel_hash == 2)? gssb_o_hash_data_in:
                                                    h2_o_hash_data_in;    

assign o_hash_data_out_ready    = (sel_hash == 1)? evc_o_hash_data_out_ready:
                                (sel_hash == 2)? gssb_o_hash_data_out_ready:
                                                    h2_o_hash_data_out_ready;

assign o_hash_input_length      = (sel_hash == 1)? evc_o_hash_input_length:
                                  (sel_hash == 2)? gssb_o_hash_input_length:
                                                    h2_o_hash_input_length;  

assign o_hash_output_length     = (sel_hash == 1)? evc_o_hash_output_length:
                                    (sel_hash == 2)? gssb_o_hash_output_length:
                                                    h2_o_hash_output_length; 

assign o_hash_start             = (sel_hash == 1)? evc_o_hash_start:
                                    (sel_hash == 2)? gssb_o_hash_start:     
                                                    h2_o_hash_start;

assign o_hash_force_done        = (sel_hash == 1)? evc_o_hash_force_done:
                                    (sel_hash == 2)? gssb_o_hash_force_done:    
                                                    h2_o_hash_force_done;    
      
assign h2_i_hash_addr           = i_hash_addr;          
assign h2_i_hash_rd_en          = i_hash_rd_en;         
assign h2_i_hash_data_out       = i_hash_data_out;      
assign h2_i_hash_data_out_valid = i_hash_data_out_valid & (sel_hash == 0);        
assign h2_i_hash_force_done_ack = i_hash_force_done_ack & (sel_hash == 0);
   

wire broad_share_valid;
wire broad_share_ready;
wire [BROAD_SHARE_SIZE-1:0]  broad_share;

wire [32*T-1:0] pc_alpha_out;
wire [32*T-1:0] pc_beta_out;
wire [32*T-1:0] pc_v_out;


    
 party_computation_top #(.PARAMETER_SET(PARAMETER_SET), .FIELD(FIELD))
 PARTY_COMP_TOP 
 (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_start(start_pc),

    .i_q(i_q),
    .o_q_addr(o_q_addr),
    .o_q_rd(o_q_rd),

    .i_p(i_p),
    .o_p_addr(o_p_addr),
    .o_p_rd(o_p_rd),

//    .o_h_mat_addr(o_h_mat_addr),
//    .o_sa_addr(o_sa_addr),
//    .i_h_mat(i_h_mat),
//    .i_sa(i_sa),

    .i_f(i_f),
    .o_f_addr(o_f_addr),
    .o_f_rd(o_f_rd),

    .i_a(i_a),
    .i_b(i_b),
    .i_minus_c(i_minus_c),
    .i_r(i_r),
    .i_eps(i_eps),
    .i_alpha_prime(i_alpha_prime),
    .i_beta_prime(i_beta_prime),

    .o_h_mat_addr(o_h_mat_addr),
    .o_sa_addr(o_sa_addr),
    .o_h_mat_sa_rd(o_h_mat_sa_rd),
    .i_h_mat(i_h_mat),
    .i_sa(i_sa),


    .o_alpha(pc_alpha_out),
    .o_beta(pc_beta_out),
    .o_v(pc_v_out),

    .o_done(done_pc)
 );


//dummy_pc 
// #( 
//     .FIELD(FIELD),
//     .PARAMETER_SET(PARAMETER_SET),
//     .T(T)
////     .CLOCK_CYCLE_COUNT(37163)
//     )
//DUMMY_PC 
//(
//.i_clk(i_clk),
//.i_rst(i_rst),
//.i_start(start_pc),
//.o_done(done_pc),

//.o_alpha(pc_alpha_out),
//.o_beta(pc_beta_out),
//.o_v(pc_v_out)

//);

assign broad_share = {pc_alpha_out, pc_beta_out, pc_v_out};
assign broad_share_valid = done_pc;

wire [32-1:0]                              h2_o_hash_data_in;
wire [`CLOG2(HASH_BRAM_DEPTH) -1:0]        h2_i_hash_addr;
wire                                       h2_i_hash_rd_en;
wire [32-1:0]                              h2_i_hash_data_out;
wire                                       h2_i_hash_data_out_valid;
wire                                       h2_o_hash_data_out_ready;
wire  [32-1:0]                             h2_o_hash_input_length; // in bits
wire  [32-1:0]                             h2_o_hash_output_length; // in bits
wire                                       h2_o_hash_start;
wire                                       h2_i_hash_force_done_ack;
wire                                       h2_o_hash_force_done;

//wire  [`CLOG2(HASH_OUTPUT_SIZE/32)-1:0]   h2_addr;
wire    h2_rd;
//wire  [31:0] h2;
wire h2_done;

hash_2 #(
    .SALT_SIZE(SALT_SIZE),
    .T(T),
    .TAU(TAU),
    .MAX_MSG_SIZE_BITS(1024),
    .HASH_OUTPUT_SIZE(HASH_OUTPUT_SIZE)
    )
HASH2 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(i_start),
.o_done(h2_done),

.i_msg(i_msg),
.i_msg_valid(i_msg_valid),
.o_msg_ready(o_msg_ready),
.i_msg_size_in_bytes(i_msg_size_in_bytes),

.i_salt(i_salt),
.o_salt_addr(o_salt_addr),
.o_salt_rd(o_salt_rd),

.i_broad_plain(i_broad_plain),
.o_broad_plain_addr(o_broad_plain_addr),
.o_broad_plain_rd(o_broad_plain_rd),

.i_broad_share_valid(broad_share_valid),
.o_broad_share_ready(broad_share_ready),
.i_broad_share(broad_share),

.i_h2_addr(0),
.i_h2_rd(0),
.o_h2(),

.o_hash_data_in          (h2_o_hash_data_in       ),   
.i_hash_addr             (h2_i_hash_addr          ),   
.i_hash_rd_en            (h2_i_hash_rd_en         ),   
.i_hash_data_out         (h2_i_hash_data_out      ),   
.i_hash_data_out_valid   (h2_i_hash_data_out_valid),   
.o_hash_data_out_ready   (h2_o_hash_data_out_ready),   
.o_hash_input_length     (h2_o_hash_input_length  ),   
.o_hash_output_length    (h2_o_hash_output_length ),   
.o_hash_start            (h2_o_hash_start         ),   
.i_hash_force_done_ack   (h2_i_hash_force_done_ack),   
.o_hash_force_done       (h2_o_hash_force_done    )

);



wire [32-1:0]                              evc_o_hash_data_in;
wire [`CLOG2(HASH_BRAM_DEPTH) -1:0]        evc_i_hash_addr;
wire                                       evc_i_hash_rd_en;
wire [32-1:0]                              evc_i_hash_data_out;
wire                                       evc_i_hash_data_out_valid;
wire                                       evc_o_hash_data_out_ready;
wire  [32-1:0]                             evc_o_hash_input_length; // in bits
wire  [32-1:0]                             evc_o_hash_output_length; // in bits
wire                                       evc_o_hash_start;
wire                                       evc_i_hash_force_done_ack;
wire                                       evc_o_hash_force_done;

wire [31:0] h2;
wire h2_wr_en;
reg  [`CLOG2(2*LAMBDA/32)-1:0] h2_addr;


wire  [7:0]                                       i_star_int;
wire  [`CLOG2(TAU)-1:0]                           i_star_addr_int;
wire                                              i_star_rd_en_int;
reg                                               i_star_rd_en;

assign h2 = i_hash_data_out;
assign h2_wr_en = i_hash_data_out_valid & (sel_hash == 0);


always@(posedge i_clk)
begin
    if (i_rst | i_start) begin
        h2_addr <= 0;
    end
    else begin
        if (h2_wr_en) begin
            h2_addr <= h2_addr + 1;
        end
    end
end

assign evc_i_hash_addr           = i_hash_addr;          
assign evc_i_hash_rd_en          = i_hash_rd_en & (sel_hash == 1);         
assign evc_i_hash_data_out       = i_hash_data_out;      
assign evc_i_hash_data_out_valid = i_hash_data_out_valid & (sel_hash == 1);        
assign evc_i_hash_force_done_ack = i_hash_force_done_ack & (sel_hash == 1);

expand_view_challenge #(.PARAMETER_SET(PARAMETER_SET))
ExpandViewChallenge 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(start_evc),
.o_done(done_evc),


.i_h2_wr_en(h2_wr_en),
.i_h2_rd_en(i_h2_rd_en),
.i_h2_addr(i_h2_rd_en? i_h2_addr :h2_addr),
.i_h2(h2),
.o_h2(o_h2),

.o_i_star(i_star_int),
.i_i_star_addr(i_star_addr_int),
.i_i_star_rd_en(i_star_rd_en_int),

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

assign o_i_star = i_star_int;
assign i_star_addr_int = i_i_star_rd_en? i_star_int: count_tau;
assign i_star_rd_en_int = i_i_star_rd_en | i_star_rd_en;

wire [32-1:0]                              gssb_o_hash_data_in;
wire [`CLOG2(HASH_BRAM_DEPTH) -1:0]        gssb_i_hash_addr;
wire                                       gssb_i_hash_rd_en;
wire [32-1:0]                              gssb_i_hash_data_out;
wire                                       gssb_i_hash_data_out_valid;
wire                                       gssb_o_hash_data_out_ready;
wire  [32-1:0]                             gssb_o_hash_input_length; // in bits
wire  [32-1:0]                             gssb_o_hash_output_length; // in bits
wire                                       gssb_o_hash_start;
wire                                       gssb_i_hash_force_done_ack;
wire                                       gssb_o_hash_force_done;


assign gssb_i_hash_addr           = i_hash_addr;          
assign gssb_i_hash_rd_en          = i_hash_rd_en & (sel_hash == 2);         
assign gssb_i_hash_data_out       = i_hash_data_out;      
assign gssb_i_hash_data_out_valid = i_hash_data_out_valid & (sel_hash == 2);        
assign gssb_i_hash_force_done_ack = i_hash_force_done_ack & (sel_hash == 2);

wire salt_seed_wen;
wire [`CLOG2((LAMBDA+SALT_SIZE)/32)-1:0] salt_seed_addr_mux;
reg salt_wen, seed_wen;
reg [`CLOG2((LAMBDA+SALT_SIZE)/32)-1:0] salt_addr, seed_addr;
wire [31:0] salt_seed;

always@(posedge i_clk)
begin
    salt_wen <= o_salt_rd;
    salt_addr <= o_salt_addr;
    seed_wen <= o_rseed_rd;
    seed_addr <= SALT_SIZE/32 + rseed_count;
end

assign salt_seed = (salt_wen)? i_salt: i_rseed;
assign salt_seed_addr_mux = (salt_wen)? salt_addr: seed_addr;
assign salt_seed_wen = salt_wen | seed_wen;

reg start_gssb;
wire done_gssb;

get_seed_sibling_path #(.PARAMETER_SET(PARAMETER_SET))
DUT 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(start_gssb),
.o_done(done_gssb),

.i_i_star(i_star_int),

.i_salt_seed_wen(salt_seed_wen),
.i_salt_seed_addr(salt_seed_addr_mux),
.i_salt_seed(salt_seed),

.o_tree_seed(tree_seed),
.o_tree_seed_valid(tree_seed_valid),
.o_tree_seed_addr(tree_seed_addr),

.o_hash_data_in          (gssb_o_hash_data_in       ),   
.i_hash_addr             (gssb_i_hash_addr          ),   
.i_hash_rd_en            (gssb_i_hash_rd_en         ),   
.i_hash_data_out         (gssb_i_hash_data_out      ),   
.i_hash_data_out_valid   (gssb_i_hash_data_out_valid),   
.o_hash_data_out_ready   (gssb_o_hash_data_out_ready),   
.o_hash_input_length     (gssb_o_hash_input_length  ),   
.o_hash_output_length    (gssb_o_hash_output_length ),   
.o_hash_start            (gssb_o_hash_start         ),   
.i_hash_force_done_ack   (gssb_i_hash_force_done_ack),   
.o_hash_force_done       (gssb_o_hash_force_done    )

);

wire [31:0]                                 tree_seed;
wire                                        tree_seed_valid;
wire [`CLOG2((8*LAMBDA/32)) -1:0]        tree_seed_addr;

wire [TAU-1:0] view_sel;
wire [32-1:0] view [TAU-1:0];

assign view_sel =   ((count_tau == 0 ) && tree_seed_valid)?   17'b00000000000000001:
                    ((count_tau == 1 ) && tree_seed_valid)?   17'b00000000000000010:
                    ((count_tau == 2 ) && tree_seed_valid)?   17'b00000000000000100:
                    ((count_tau == 3 ) && tree_seed_valid)?   17'b00000000000001000:
                    ((count_tau == 4 ) && tree_seed_valid)?   17'b00000000000010000:
                    ((count_tau == 5 ) && tree_seed_valid)?   17'b00000000000100000:
                    ((count_tau == 6 ) && tree_seed_valid)?   17'b00000000001000000:
                    ((count_tau == 7 ) && tree_seed_valid)?   17'b00000000010000000:
                    ((count_tau == 8 ) && tree_seed_valid)?   17'b00000000100000000:
                    ((count_tau == 9 ) && tree_seed_valid)?   17'b00000001000000000:
                    ((count_tau == 10) && tree_seed_valid)?   17'b00000010000000000:
                    ((count_tau == 11) && tree_seed_valid)?   17'b00000100000000000:
                    ((count_tau == 12) && tree_seed_valid)?   17'b00001000000000000:
                    ((count_tau == 13) && tree_seed_valid)?   17'b00010000000000000:
                    ((count_tau == 14) && tree_seed_valid)?   17'b00100000000000000:
                    ((count_tau == 15) && tree_seed_valid)?   17'b01000000000000000:
                    ((count_tau == 16) && tree_seed_valid)?   17'b10000000000000000:
                                                              17'b00000000000000000;

assign o_view = (i_view_sel == 0)?   view[0]:
                (i_view_sel == 1)?   view[1]:
                (i_view_sel == 2)?   view[2]:
                (i_view_sel == 3)?   view[3]:
                (i_view_sel == 4)?   view[4]:
                (i_view_sel == 5)?   view[5]:
                (i_view_sel == 6)?   view[6]:
                (i_view_sel == 7)?   view[7]:
                (i_view_sel == 8)?   view[8]:
                (i_view_sel == 9)?   view[9]:
                (i_view_sel == 10)?  view[10]:
                (i_view_sel == 11)?  view[11]:
                (i_view_sel == 12)?  view[12]:
                (i_view_sel == 13)?  view[13]:
                (i_view_sel == 14)?  view[14]:
                (i_view_sel == 15)?  view[15]:
                (i_view_sel == 16)?  view[16]:
                                    0;





generate
    begin
        genvar i;
        for (i=0; i<TAU; i=i+1) begin
            mem_single #(.WIDTH(32), .DEPTH(8*LAMBDA/32), .INIT(1)) 
            VIEW_MEM
            (
            .clock(i_clk),
            .data(tree_seed),
            .address(i_view_rd_en? i_view_addr: tree_seed_addr),
            .wr_en(view_sel[i]),
            .q(view[i])
            );
        end
    end
endgenerate



reg [3:0] l_state;
parameter l_wait_start          =0;
parameter l_loop_tau            =1;
parameter l_loop_D              =2;
parameter l_pc_done             =3;
parameter l_loop_check_tau      =4;
parameter l_wait_for_hash2_done =5;
// parameter l_wait_for_h         =6;
parameter l_loop_D_done         =7;

parameter l_start_evc          =8;
parameter l_done_evc           =9;

parameter l_load_rseed          =10;
parameter l_start_gssb          =11;
parameter l_done_gssb           =12;
parameter l_check_gssb_count    =13;

reg [`CLOG2(D_HYPERCUBE):0] count_D = 0;
reg [`CLOG2(TAU)-1:0] count_tau = 0;

reg [`CLOG2(TAU*D_HYPERCUBE)-1:0] mshare_count = 0;

reg start_pc;
wire done_pc;

reg start_evc;
wire done_evc;

reg [`CLOG2(LAMBDA/32):0] rseed_count;

assign o_abc_addr = mshare_count;
//assign o_broad_plain_addr = count_tau;
assign o_a_b_r_e_c_addr = count_tau;

always@(posedge i_clk)
begin
    if (i_rst) begin
        l_state <= l_wait_start;
        o_done <= 0;
        rseed_count <= 0;
        o_status_reg <= 0;
    end
    else begin
        if  (l_state == l_wait_start) begin
            count_D <= 0;
            count_tau <= 0;
            mshare_count <= 0;
            o_done <= 0;
            o_rseed_addr <= 0;
            rseed_count <= 0;
            o_status_reg <= 0;
            if (i_start) begin
                l_state <= l_loop_D;
            end
        end
        
        else if (l_state == l_loop_D)  begin
            o_status_reg <= 1;
            if (count_D == D_HYPERCUBE) begin
//                l_state <= l_loop_D_done;
                l_state <= l_loop_check_tau;
                count_D <= 0;
                count_tau <= count_tau + 1;
            end
            else begin
                l_state <= l_pc_done;
            end 
        end 
        
        else if (l_state == l_pc_done) begin
            if (done_pc) begin
                count_D <=count_D + 1;
                l_state <= l_loop_D;
                mshare_count <= mshare_count + 1;
            end
        end

        else if (l_state == l_loop_check_tau) begin
           if (count_tau == TAU) begin
              l_state <= l_wait_for_hash2_done;  
              count_tau <= 0;
              o_status_reg <= 2;
           end
           else begin 
              l_state <= l_loop_D; 
           end
        end

        else if (l_state == l_wait_for_hash2_done) begin
           if (h2_done) begin
              l_state <= l_loop_D_done;
              o_status_reg <= 2;
           end
        end
        
        else if (l_state == l_loop_D_done) begin
            if (i_hash_force_done_ack) begin
                l_state <= l_start_evc;
                mshare_count <= 0;
            end 
        end

        else if (l_state == l_start_evc) begin
                l_state <= l_done_evc;
                o_status_reg <= 3;
        end

        else if (l_state == l_done_evc) begin
            if (done_evc) begin
                l_state <= l_load_rseed;
                o_status_reg <= 4;
            end  
        end
        
          else if (l_state == l_load_rseed) begin
            if (rseed_count < 4) begin
                rseed_count <= rseed_count + 1;
                o_rseed_addr <= o_rseed_addr + 1;
            end
            else begin
                l_state <= l_start_gssb;
                 rseed_count <= 0;
            end   
        end


         else if (l_state == l_start_gssb) begin
                l_state <= l_done_gssb;  
                 
        end

        else if (l_state == l_done_gssb) begin
            if (done_gssb) begin
                l_state <= l_check_gssb_count;
                count_tau <= count_tau + 1;
            end   
        end

        else if (l_state == l_check_gssb_count) begin
            if (count_tau == TAU) begin
                l_state <= l_wait_start;
                count_tau <= 0;
                o_done <= 1;
                o_status_reg <= 0;
            end    
            else begin  
                l_state <= l_load_rseed;
            end
        end


    end
end

always@(*)
begin
    case(l_state)
        l_wait_start: begin
           start_pc <= 0; 
           sel_hash <= 0;
           start_evc <= 0;
           o_rseed_rd <= 0;
           start_gssb <= 0;
           i_star_rd_en <= 0;
           if (i_start) begin
              o_abc_rd <= 1;
              o_a_b_r_e_c_rd <= 1;
           end
           else begin
              o_abc_rd <= 0;
              o_a_b_r_e_c_rd <= 0;
           end
        end

        l_loop_D: begin
            o_abc_rd <= 1;
            o_a_b_r_e_c_rd <= 1;
            sel_hash <= 0;
            start_evc <= 0;
            o_rseed_rd <= 0;
            start_gssb <= 0;
            i_star_rd_en <= 0;
            if (count_D < D_HYPERCUBE) begin
                start_pc <= 1;
            end
            else begin
                start_pc <= 0;
            end
        end
        
        l_pc_done: begin
            start_pc <= 0;
            o_a_b_r_e_c_rd <= 1;
            o_abc_rd <= 1;
            sel_hash <= 0;
            start_evc <= 0;
            o_rseed_rd <= 0;
            start_gssb <= 0;
            i_star_rd_en <= 0;
        end
        
        l_loop_check_tau: begin
            start_pc <= 0;
            o_abc_rd <= 1;
            o_a_b_r_e_c_rd <= 1;
            sel_hash <= 0;
            start_evc <= 0;
            o_rseed_rd <= 0;
            start_gssb <= 0;
            i_star_rd_en <= 0;
        end
        
        l_wait_for_hash2_done: begin
            start_pc <= 0;
            o_abc_rd <= 0;
            o_a_b_r_e_c_rd <= 0;
            sel_hash <= 0;
            start_evc <= 0;
            o_rseed_rd <= 0;
            start_gssb <= 0;
            i_star_rd_en <= 0;
        end

        l_loop_D_done: begin
            start_pc <= 0;
            o_abc_rd <= 0;
            o_a_b_r_e_c_rd <= 0;
            sel_hash <= 0;
            start_evc <= 0;
            o_rseed_rd <= 0;
            start_gssb <= 0;
            i_star_rd_en <= 0;
        end   

        l_start_evc: begin
            start_pc <= 0;
            o_abc_rd <= 0;
            o_a_b_r_e_c_rd <= 0;
            sel_hash <= 1;
            start_evc <= 1;
            o_rseed_rd <= 0;
            start_gssb <= 0;
            i_star_rd_en <= 0;
        end   

        l_done_evc: begin
            start_pc <= 0;
            o_abc_rd <= 0;
            o_a_b_r_e_c_rd <= 0;
            sel_hash <= 1;
            start_evc <= 0;
            start_gssb <= 0;
            o_rseed_rd <= 0;
            i_star_rd_en <= 0;
        end  
        
        l_load_rseed: begin
            start_pc <= 0;
            o_abc_rd <= 0;
            o_a_b_r_e_c_rd <= 0;
            sel_hash <= 1;
            start_evc <= 0;
            start_gssb <= 0;
            i_star_rd_en <= 1;
            if (rseed_count < 4) begin
                o_rseed_rd <= 1;
            end
            else begin
                o_rseed_rd <= 0;
            end
        
        end
        
        l_start_gssb: begin
            start_pc <= 0;
            o_abc_rd <= 0;
            o_a_b_r_e_c_rd <= 0;
            sel_hash <= 2;
            start_evc <= 0;
            o_rseed_rd <= 0;
            start_gssb <= 1;
            i_star_rd_en <= 1;
        end

        l_done_gssb: begin
            start_pc <= 0;
            o_abc_rd <= 0;
            o_a_b_r_e_c_rd <= 0;
            sel_hash <= 2;
            start_evc <= 0;
            o_rseed_rd <= 0;
            start_gssb <= 0;
            i_star_rd_en <= 1;
        end

        l_check_gssb_count: begin
            start_pc <= 0;
            o_abc_rd <= 0;
            o_a_b_r_e_c_rd <= 0;
            sel_hash <= 2;
            start_evc <= 0;
            start_gssb <= 0;
             o_rseed_rd <= 0;
             i_star_rd_en <= 1;
        end


        default: begin
            start_pc = 0;
            o_abc_rd <= 0;
            o_a_b_r_e_c_rd <= 0;
            sel_hash <= 0;
            o_rseed_rd <= 0;
            start_gssb <= 0;
            i_star_rd_en <= 0;
        end
    endcase
end

endmodule