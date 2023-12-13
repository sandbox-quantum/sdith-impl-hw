/*
 * This file is sign_online_sk module which part of SDitH sign.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
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


    input  [7:0]                                        i_q,
    output [`CLOG2(M)-1:0]                              o_q_addr,
    output                                              o_q_rd,

    input  [7:0]                                        i_p,
    output [`CLOG2(M)-1:0]                              o_p_addr,
    output                                              o_p_rd,

    input  [7:0]                                        i_f,
    output [`CLOG2(M)-1:0]                              o_f_addr,
    output                                              o_f_rd,

    input    [T*32-1:0]                                 i_alpha_prime,
    input    [T*32-1:0]                                 i_beta_prime,
    input    [T*32-1:0]                                 i_r,
    input    [T*32-1:0]                                 i_eps,
    input    [T*32-1:0]                                 i_minus_c,
    input [32*T-1:0]                                    i_a,
    input [32*T-1:0]                                    i_b,

    output   [`CLOG2(TAU)-1:0]                          o_a_b_r_e_c_addr,
    output                                              o_a_b_r_e_c_rd,


    output  [32*T-1:0]                                  o_alpha,
    output  [32*T-1:0]                                  o_beta,
    output  [32*T-1:0]                                  o_v,

    output reg                                          o_done,
    
    
    input [7:0]                                         i_msg,
    input                                               i_msg_valid,
    output                                              o_msg_ready,
    input [`CLOG2(MAX_MSG_SIZE_BYTES)-1:0]              i_msg_size_in_bytes,


    output [`CLOG2(SALT_SIZE/32):0]                     o_salt_addr,  
    output                                              o_salt_rd,  
    input  [31:0]                                       i_salt,

    output [`CLOG2(TAU):0]                              o_broad_plain_addr,  
    output                                              o_broad_plain_rd,  
    input  [BROAD_PLAIN_SIZE-1:0]                       i_broad_plain,

//    input                                               i_broad_share_valid,
//    output reg                                          o_broad_share_ready,
//    input  [BROAD_SHARE_SIZE-1:0]                       i_broad_share,

//    input                                               i_start,
//    output reg                                          o_done,
    
//    input  [`CLOG2(HASH_OUTPUT_SIZE/32)-1:0]            i_h2_addr,
//    input                                               i_h2_rd,
//    output  [31:0]                                      o_h2,
    
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


assign o_hash_data_in           = h2_o_hash_data_in;      
assign o_hash_data_out_ready    = h2_o_hash_data_out_ready;
assign o_hash_input_length      = h2_o_hash_input_length;  
assign o_hash_output_length     = h2_o_hash_output_length; 
assign o_hash_start             = h2_o_hash_start;         
assign o_hash_force_done        = h2_o_hash_force_done;    
      
assign h2_i_hash_addr           = i_hash_addr;          
assign h2_i_hash_rd_en          = i_hash_rd_en;         
assign h2_i_hash_data_out       = i_hash_data_out;      
assign h2_i_hash_data_out_valid = i_hash_data_out_valid;        
assign h2_i_hash_force_done_ack = i_hash_force_done_ack;
   




wire broad_share_valid;
wire broad_share_ready;
wire [BROAD_SHARE_SIZE-1:0]  broad_share;

wire [32*T-1:0] pc_alpha_out;
wire [32*T-1:0] pc_beta_out;
wire [32*T-1:0] pc_v_out;

// party_computation_top #(.PARAMETER_SET(PARAMETER_SET), .FILE_MEM_INIT(FILE_MEM_INIT))
// DUT 
// (
// .i_clk(i_clk),
// .i_rst(i_rst),
// .i_start(start_pc),

// .i_q(i_q),
// .o_q_addr(o_q_addr),
// .o_q_rd(o_q_rd),

// .i_p(i_p),
// .o_p_addr(o_p_addr),
// .o_p_rd(o_p_rd),

// .i_f(i_f),
// .o_f_addr(o_f_addr),
// .o_f_rd(o_f_rd),

// .i_a(i_a),
// .i_b(i_b),
// .i_minus_c(i_minus_c),
// .i_r(i_r),
// .i_eps(i_eps),
// .i_alpha_prime(i_alpha_prime),
// .i_beta_prime(i_beta_prime),

// .o_h_mat_addr(o_h_mat_addr),
// .o_sa_addr(o_sa_addr),
// .o_h_mat_sa_rd(o_h_mat_sa_rd),
// .i_h_mat(i_h_mat),
// .i_sa(i_sa),


// .o_alpha(pc_alpha_out),
// .o_beta(pc_beta_out),
// .o_v(pc_v_out),

// .o_done(done_pc)
// );


dummy_pc 
 #( 
     .FIELD(FIELD),
     .PARAMETER_SET(PARAMETER_SET),
     .T(T)
//     .CLOCK_CYCLE_COUNT(37163)
     )
DUMMY_PC 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(start_pc),
.o_done(done_pc),

.o_alpha(pc_alpha_out),
.o_beta(pc_beta_out),
.o_v(pc_v_out)

);

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

wire  [`CLOG2(HASH_OUTPUT_SIZE/32)-1:0]   h2_addr;
wire    h2_rd;
wire  [31:0] h2;
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


reg [3:0] l_state;
parameter l_wait_start          =0;
parameter l_loop_tau            =1;
parameter l_loop_D              =2;
parameter l_pc_done             =3;
parameter l_loop_check_tau      =4;
parameter l_wait_for_hash2_done =5;
// parameter l_wait_for_h         =6;
parameter l_loop_D_done         =7;

reg [`CLOG2(D_HYPERCUBE):0] count_D = 0;
reg [`CLOG2(TAU)-1:0] count_tau = 0;
reg start_pc;
wire done_pc;

always@(posedge i_clk)
begin
    if (i_rst) begin
        l_state <= l_wait_start;
    end
    else begin
        if  (l_state == l_wait_start) begin
            count_D <= 0;
            count_tau <= 0;
            if (i_start) begin
                l_state <= l_loop_D;
            end
        end
        
        else if (l_state == l_loop_D)  begin
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
            end
        end

        else if (l_state == l_loop_check_tau) begin
           if (count_tau == TAU) begin
              l_state <= l_wait_for_hash2_done;  
              count_tau <= 0;
           end
           else begin 
              l_state <= l_loop_D; 
           end
        end

        else if (l_state == l_wait_for_hash2_done) begin
           if (h2_done) begin
              l_state <= l_loop_D_done;
           end
        end
        
        else if (l_state == l_loop_D_done) begin
           l_state <= l_wait_start;
           o_done <= 1;
        end
    end
end

always@(*)
begin
    case(l_state)
        l_wait_start: begin
           start_pc <= 0; 
        end

        l_loop_D: begin
            if (count_D < D_HYPERCUBE) begin
                start_pc <= 1;
            end
            else begin
                start_pc <= 0;
            end
        end
        
        l_pc_done: begin
            start_pc <= 0;
        end
        
        l_loop_check_tau: begin
            start_pc <= 0;
        end
        
        l_wait_for_hash2_done: begin
            start_pc <= 0;
        end

        l_loop_D_done: begin
            start_pc <= 0;
        end        

        default: begin
            start_pc = 0;
        end
    endcase
end

endmodule