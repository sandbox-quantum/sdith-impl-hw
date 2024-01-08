/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module sign_online_sk_tb
#(
    
    parameter FIELD = "GF256",
    
    parameter PARAMETER_SET = "L1",
    
    parameter LAMBDA =   (PARAMETER_SET == "L1")? 128:
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
    
    // H2 parameters
    parameter SALT_SIZE                     = 256,
    parameter BROAD_PLAIN_SIZE              = 32*T*2,
    parameter BROAD_SHARE_SIZE              = 32*T*3,
    parameter MAX_MSG_SIZE_BITS             = 1024,
    parameter HASH_OUTPUT_SIZE              = 256,

    parameter BROAD_PLAIN_SIZE_BYTES        = BROAD_PLAIN_SIZE/8,
    parameter BROAD_SHARE_SIZE_BYTES        = BROAD_SHARE_SIZE/8,
    parameter MAX_MSG_SIZE_BYTES            = MAX_MSG_SIZE_BITS/8,
    
    parameter HASH_BITS                     = 8 + MAX_MSG_SIZE_BITS + SALT_SIZE + TAU*BROAD_PLAIN_SIZE + TAU*D_HYPERCUBE*BROAD_SHARE_SIZE,
    parameter HASH_BITS_ADJ                 = HASH_BITS + (32 - HASH_BITS%32)%32,
    parameter HASH_BITS_NO_MSG              = HASH_BITS - MAX_MSG_SIZE_BITS,

    parameter HASH_BRAM_DEPTH               = HASH_BITS_ADJ/32,
    
    parameter TEST_SET = 2

    
)(

);

reg                                 i_clk = 0;
reg                                 i_rst;
reg                                 i_start;

wire  [7:0]                                       i_q;
wire [`CLOG2(M)-1:0]                              o_q_addr;
wire                                              o_q_rd;

//wire  [7:0]                                       i_s;
//wire [`CLOG2(M)-1:0]                              o_s_addr;
//wire                                              o_s_rd;

wire  [7:0]                                       i_p;
wire [`CLOG2(M)-1:0]                              o_p_addr;
wire                                              o_p_rd;

wire  [7:0]                                       i_f;
wire [`CLOG2(M)-1:0]                              o_f_addr;
wire                                              o_f_rd;

wire                                o_done;

wire [T*32-1:0]                                  i_minus_c;
wire [T*32-1:0]                                  i_a;
wire [T*32-1:0]                                  i_b;


wire [T*32-1:0]                                 i_r;
wire [T*32-1:0]                                 i_eps;
//wire [T*32-1:0]                                 i_alpha_prime;
//wire [T*32-1:0]                                 i_beta_prime;

//wire [`CLOG2(TAU)-1:0]                          o_alpha_beta_prime_addr;
//wire                                            o_alpha_beta_prime_rd;

// wire [`CLOG2(TAU*D_SPLIT)-1:0]                  o_eps_addr;
// wire                                            o_eps_rd;

wire   [`CLOG2(TAU)-1:0]                        o_a_b_r_e_c_addr;
wire                                            o_a_b_r_e_c_rd;

wire   [`CLOG2(TAU*D_HYPERCUBE)-1:0]            o_abc_addr;
wire                                            o_abc_rd;


wire                                              o_h_mat_sa_rd;
wire [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0]             o_h_mat_addr;
wire [`CLOG2(M)-1:0]                              o_sa_addr;
wire [PROC_SIZE-1:0]                              i_h_mat;
wire [7:0]                                        i_sa;

wire [31:0]                                        i_y;
reg                                                i_y_wr_en;
reg [`CLOG2(Y_SIZE_ADJ/32)-1:0]                    i_y_addr;
reg [`CLOG2(Y_SIZE_ADJ/32)-1:0]                   y_addr;


// h2 signals
reg   [8-1:0]                                     i_msg;
reg                                               i_msg_valid;
//wire                                              o_msg_ready;
reg   [`CLOG2(MAX_MSG_SIZE_BYTES)-1:0]            i_msg_size_in_bytes;


wire [31:0] i_salt;
wire [`CLOG2(SALT_SIZE/32)-1:0] o_salt_addr;
wire o_salt_rd;

wire [32*T*2-1:0] i_broad_plain;
wire [`CLOG2(TAU)-1:0] o_broad_plain_addr;
wire o_broad_plain_rd;

wire [32-1:0]                       o_hash_data_in;
wire [`CLOG2(HASH_BRAM_DEPTH) -1:0]       i_hash_addr;
wire                                i_hash_rd_en;
wire [32-1:0]                       i_hash_data_out;
wire                                i_hash_data_out_valid;
wire                                o_hash_data_out_ready;
wire  [32-1:0]                      o_hash_input_length; // in bits
wire  [32-1:0]                      o_hash_output_length; // in bits
wire                                o_hash_start;
wire                                i_hash_force_done_ack;

reg  [`CLOG2(2*LAMBDA/32)-1:0]      i_h2_addr;
reg                                 i_h2_rd_en;
wire [31:0]                         o_h2;

 wire o_rseed_rd;
 wire [`CLOG2(TAU*LAMBDA/32)-1:0] o_rseed_addr;
 wire [31:0] i_rseed;

reg                                          i_view_rd_en;
reg [`CLOG2(TAU)-1:0]                        i_view_sel;
reg [`CLOG2((8*LAMBDA/32)) -1:0]             i_view_addr;
wire [31:0]                                  o_view;


reg                                               i_i_star_rd_en;
reg [`CLOG2(TAU)-1:0]                             i_i_star_addr;
wire [7:0]                                        o_i_star;

wire [2:0] o_status_reg;

sign_online_sk #(.PARAMETER_SET(PARAMETER_SET), .FIELD(FIELD))
DUT 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(i_start),

.i_q(i_q),
.o_q_addr(o_q_addr),
.o_q_rd(o_q_rd),


.i_y(i_y),
.i_y_addr(i_y_addr),
.i_y_wr_en(i_y_wr_en),

.i_p(i_p),
.o_p_addr(o_p_addr),
.o_p_rd(o_p_rd),

.i_f(i_f),
.o_f_addr(o_f_addr),
.o_f_rd(o_f_rd),

.o_a_b_r_e_c_addr(o_a_b_r_e_c_addr),
.o_a_b_r_e_c_rd(o_a_b_r_e_c_rd),  


.o_abc_rd(o_abc_rd),  
.o_abc_addr(o_abc_addr),  


.i_a(i_a),
.i_b(i_b),
.i_minus_c(i_minus_c),

.i_r(i_r),
.i_eps(i_eps),

// .o_alpha_beta_prime_rd(o_alpha_beta_prime_rd),
// .o_alpha_beta_prime_addr(o_alpha_beta_prime_addr),
.i_alpha_prime(broad_plain[2*32*T-1:32*T]),
.i_beta_prime(broad_plain[32*T-1:0]),

.o_done(o_done),

.o_h_mat_sa_rd(o_h_mat_sa_rd),
.o_h_mat_addr(o_h_mat_addr),
.o_sa_addr(o_sa_addr),
.i_h_mat(i_h_mat),
.i_sa(i_sa),

// h2 signals
.i_msg(i_msg),
.i_msg_valid(i_msg_valid),
//.o_msg_ready(o_msg_ready),
.i_msg_size_in_bytes(i_msg_size_in_bytes),

.i_salt(i_salt),
.o_salt_addr(o_salt_addr),
.o_salt_rd(o_salt_rd),

.i_h2_addr(i_h2_addr),
.i_h2_rd_en(i_h2_rd_en),
.o_h2(o_h2),

 .o_rseed_rd(o_rseed_rd),
 .o_rseed_addr(o_rseed_addr),
 .i_rseed(i_rseed),

.i_broad_plain(i_broad_plain),
.o_broad_plain_addr(o_broad_plain_addr),
.o_broad_plain_rd(o_broad_plain_rd),

.i_view_rd_en(i_view_rd_en),
.i_view_sel(i_view_sel),
.i_view_addr(i_view_addr),
.o_view(o_view),

.i_i_star_rd_en(i_i_star_rd_en),
.i_i_star_addr(i_i_star_addr),
.o_i_star(o_i_star),

.o_status_reg(o_status_reg),

// hash interface
.o_hash_data_in          (o_hash_data_in       ),   
.i_hash_addr             (i_hash_addr          ),   
.i_hash_rd_en            (i_hash_rd_en         ),   
.i_hash_data_out         (i_hash_data_out      ),   
.i_hash_data_out_valid   (i_hash_data_out_valid),   
.o_hash_data_out_ready   (o_hash_data_out_ready),   
.o_hash_input_length     (o_hash_input_length  ),   
.o_hash_output_length    (o_hash_output_length ),   
.o_hash_start            (o_hash_start         ),   
.i_hash_force_done_ack   (i_hash_force_done_ack),   
.o_hash_force_done       (o_hash_force_done    )


);


hash_mem_interface #(.IO_WIDTH(32), .MAX_RAM_DEPTH(HASH_BRAM_DEPTH), .PARAMETER_SET(PARAMETER_SET))
  HASH_INTERFACE
   (
    .clk                (i_clk                   ),
    .rst                (i_rst                   ),
    .i_data_in          (o_hash_data_in          ),
    .o_addr             (i_hash_addr             ),            
    .o_rd_en            (i_hash_rd_en            ),
    .o_data_out         (i_hash_data_out         ),
    .o_data_out_valid   (i_hash_data_out_valid   ),
    .i_data_out_ready   (o_hash_data_out_ready   ), 
    .i_input_length     (o_hash_input_length     ),
    .i_output_length    (o_hash_output_length    ),                 
    .i_start            (o_hash_start            ),
    .o_force_done_ack   (i_hash_force_done_ack   ),
    .i_force_done       (o_hash_force_done       )  
    );

wire [255:0] MESSAGE;

assign MESSAGE = (TEST_SET == 0)? "Hi! How are you?":
                 (TEST_SET == 1)? "__ Happy New Year! __":
                                  "####### IACR CHES 2024 #######";

parameter MESSAGE_SIZE = (TEST_SET == 0)? 16:
                         (TEST_SET == 1)? 24:
                                          32;

parameter VCD_NAME = (TEST_SET == 0)? "sign_online_0.vcd":
                     (TEST_SET == 1)? "sign_online_1.vcd":
                                      "sign_online_2.vcd";

integer start_time;
integer end_time;
integer i;
initial 
begin
    i_rst <= 1;
    i_start <= 0;
    i_h2_addr <= 0;
    i_h2_rd_en <= 0;
    i_y_wr_en <= 0;
    i_y_addr <= 0;
    y_addr <= 0;
    i_msg_size_in_bytes <= 0;
    i_msg <= 0;
    i_msg_valid <= 0;
    i_view_rd_en <= 0;
    i_view_sel <= 0;
    i_view_addr <= 0;
    i_i_star_rd_en <= 0;
    i_i_star_addr <= 0;

    $dumpfile(VCD_NAME);
    $dumpvars(1, sign_online_sk_tb);

    #100
    
    for(i = 0; i < (M-K)*8/32; i= i+1)
    begin
        y_addr <= i; #10
        i_y_addr <= y_addr; i_y_wr_en <= 1;
    end
    
    #10
    i_y_wr_en <= 0;
    
    #100
    i_rst <= 0;
    i_start <= 1;
    start_time = $time;
    i_msg_size_in_bytes <= MESSAGE_SIZE;
    #10
    i_start <= 0;
    #10
    i_msg <= MESSAGE[8*0+8-1:8*0]; i_msg_valid <= 1; #10
    i_msg <= MESSAGE[8*1+8-1:8*1]; i_msg_valid <= 1; #10
    i_msg <= MESSAGE[8*2+8-1:8*2]; i_msg_valid <= 1; #10
    i_msg <= MESSAGE[8*3+8-1:8*3]; i_msg_valid <= 1; #10
    i_msg <= MESSAGE[8*4+8-1:8*4]; i_msg_valid <= 1; #10
    i_msg <= MESSAGE[8*5+8-1:8*5]; i_msg_valid <= 1; #10
    i_msg <= MESSAGE[8*6+8-1:8*6]; i_msg_valid <= 1; #10
    i_msg <= MESSAGE[8*7+8-1:8*7]; i_msg_valid <= 1; #10
    i_msg <= MESSAGE[8*8+8-1:8*8]; i_msg_valid <= 1; #10
    i_msg <= MESSAGE[8*9+8-1:8*9]; i_msg_valid <= 1; #10
    i_msg <= MESSAGE[8*10+8-1:8*10];  i_msg_valid <= 1;#10
    i_msg <= MESSAGE[8*11+8-1:8*11];  i_msg_valid <= 1;#10
    i_msg <= MESSAGE[8*12+8-1:8*12];  i_msg_valid <= 1;#10
    i_msg <= MESSAGE[8*13+8-1:8*13];  i_msg_valid <= 1;#10
    i_msg <= MESSAGE[8*14+8-1:8*14];  i_msg_valid <= 1;#10
    i_msg <= MESSAGE[8*15+8-1:8*15];  i_msg_valid <= 1;#10
    
    if (TEST_SET == 1 || TEST_SET == 2) begin
         i_msg <= MESSAGE[8*16+8-1:8*16];  i_msg_valid <= 1; #10
         i_msg <= MESSAGE[8*17+8-1:8*17];  i_msg_valid <= 1; #10
         i_msg <= MESSAGE[8*18+8-1:8*18];  i_msg_valid <= 1; #10
         i_msg <= MESSAGE[8*19+8-1:8*19];  i_msg_valid <= 1; #10
         i_msg <= MESSAGE[8*20+8-1:8*20];  i_msg_valid <= 1; #10
         i_msg <= MESSAGE[8*21+8-1:8*21];  i_msg_valid <= 1; #10
         i_msg <= MESSAGE[8*22+8-1:8*22];  i_msg_valid <= 1; #10
         i_msg <= MESSAGE[8*23+8-1:8*23];  i_msg_valid <= 1; #10;
    end
    
     if (TEST_SET == 2) begin
         i_msg <= MESSAGE[8*24+8-1:8*24];  i_msg_valid <= 1; #10
         i_msg <= MESSAGE[8*25+8-1:8*25];  i_msg_valid <= 1; #10
         i_msg <= MESSAGE[8*26+8-1:8*26];  i_msg_valid <= 1;#10
         i_msg <= MESSAGE[8*27+8-1:8*27];  i_msg_valid <= 1;#10
         i_msg <= MESSAGE[8*28+8-1:8*28];  i_msg_valid <= 1;#10
         i_msg <= MESSAGE[8*29+8-1:8*29];  i_msg_valid <= 1;#10
         i_msg <= MESSAGE[8*30+8-1:8*30];  i_msg_valid <= 1;#10
         i_msg <= MESSAGE[8*31+8-1:8*31];  i_msg_valid <= 1;#10;
    end
//    i_msg <= 0; i_msg_valid <= 1;#10
//    i_msg <= 1; i_msg_valid <= 1;#10
//    i_msg <= 2; i_msg_valid <= 1;#10

    i_start <= 0;
    i_msg_valid <= 0;
    
    @(posedge o_done)
//    @(posedge DUT.done_pc)
//    @(posedge DUT.done_pc)
    end_time = $time;

    $display("Clock Cycles taken for Party Computation =", (end_time-start_time-5)/10 );

    for(i = 0; i < 2*LAMBDA/32; i= i+1)
    begin
        i_h2_addr <= i; i_h2_rd_en <= 1; #10;
    end    
    
    #100
    $finish;

end


wire [255:0] status_msg_ascii;


assign status_msg_ascii = (o_status_reg == 0)? "Waiting to Start":
                          (o_status_reg == 1)? "Party Computation Loop":
                          (o_status_reg == 2)? "Hash2 Processing":
                          (o_status_reg == 3)? "ExpandViewChallenge":
                          (o_status_reg == 4)? "GetSeedSiblingPath and Gen View":
                                                "Waiting to Start";

//  always
//  begin
//      @(posedge o_done)
//     //  $writememb("HSA_L1.mem", DUT.MAT_VEC_MUL.RESULT_MEM.mem);
//  end




// ================== SALT ===================
parameter FILE_SALT = (TEST_SET == 0)? "SALT_SEED_0.in":
                      (TEST_SET == 1)? "SALT_SEED_1.in":
                                       "SALT_SEED_2.in";

mem_single #(.WIDTH(32), .DEPTH(SALT_SIZE/32), .FILE(FILE_SALT)) 
 SALT_MEM
 (
 .clock(i_clk),
 .data(0),
 .address(o_salt_rd? o_salt_addr: 0),
 .wr_en(0),
 .q(i_salt)
 );


// ================== F ===================
parameter FILE_F = (TEST_SET == 0)? "F_L1_0.in":
                      (TEST_SET == 1)? "F_L1_1.in":
                                       "F_L1_2.in";

 mem_single #(.WIDTH(8), .DEPTH(M), .FILE(FILE_F)) 
 F_values
 (
 .clock(i_clk),
 .data(0),
 .address(o_f_addr%M),
 .wr_en(0),
 .q(i_f)
 );


// ================== H matrix ===================

parameter FILE_H =  (TEST_SET == 0)? "H_L1.mem":
                    (TEST_SET == 1)? "H_L1.mem":
                                     "H_L1.mem";

 mem_single #(.WIDTH(PROC_SIZE), .DEPTH(MAT_SIZE/PROC_SIZE), .FILE(FILE_H)) 
 H_matrix_values
 (
 .clock(i_clk),
 .data(0),
 .address(o_h_mat_addr),
 .wr_en(0),
 .q(i_h_mat)
 );
 
 parameter FILE_Y = (TEST_SET == 0)? "Y_0_0.in":
                    (TEST_SET == 1)? "Y_0_1.in":
                                     "Y_0_2.in";



mem_single #(.WIDTH(32), .DEPTH(Y_SIZE_ADJ/32), .FILE(FILE_Y)) 
 Y_values
 (
 .clock(i_clk),
 .data(0),
 .address(y_addr),
 .wr_en(0),
 .q(i_y)
 );

// =============== Sa, Q, P ===================
parameter FILE_S =  (TEST_SET == 0)? "Sa_L1_0.in":
                    (TEST_SET == 1)? "Sa_L1_1.in":
                                     "Sa_L1_2.in";

mem_single #(.WIDTH(8), .DEPTH(M), .FILE(FILE_S)) 
 Sa_values
 (
 .clock(i_clk),
 .data(0),
 .address(o_sa_addr%(M)),
 .wr_en(0),
 .q(i_sa)
 );


parameter FILE_Q = (TEST_SET == 0)? "Q_L1_0.in":
                   (TEST_SET == 1)? "Q_L1_1.in":
                                    "Q_L1_2.in";

mem_single #(.WIDTH(8), .DEPTH(M), .FILE(FILE_Q)) 
 Q_values
 (
 .clock(i_clk),
 .data(0),
 .address(o_q_addr%(M)),
 .wr_en(0),
 .q(i_q)
 );

parameter FILE_P = (TEST_SET == 0)? "P_L1_0.in":
                   (TEST_SET == 1)? "P_L1_1.in":
                                    "P_L1_2.in";

 mem_single #(.WIDTH(8), .DEPTH(M), .FILE(FILE_P)) 
 P_values
 (
 .clock(i_clk),
 .data(0),
 .address(o_p_addr%(M)),
 .wr_en(0),
 .q(i_p)
 );



//===============BROAD PLAIN===================
wire [2*32*T-1:0] broad_plain;
parameter FILE_BROAD_PLAIN = (TEST_SET == 0)? "BROAD_PLAIN_0.in":
                             (TEST_SET == 1)? "BROAD_PLAIN_1.in":
                                              "BROAD_PLAIN_2.in";

mem_dual #(.WIDTH(2*32*T), .DEPTH(TAU), .FILE(FILE_BROAD_PLAIN)) 
 broad_plain_MEM
 (
 .clock(i_clk),
 .data_0(0),
 .data_1(0),
 .address_0(o_broad_plain_rd? o_broad_plain_addr%TAU: 0),
 .address_1(o_a_b_r_e_c_rd? o_a_b_r_e_c_addr: 0),
 .wren_0(0),
 .wren_1(0),
 .q_0(i_broad_plain),
 .q_1(broad_plain)
 );



//===============BROAD SHARE===================
parameter FILE_BEAV_A_MSHARE = (TEST_SET == 0)? "BEAV_A_MSHARE_0.in":
                               (TEST_SET == 1)? "BEAV_A_MSHARE_1.in":
                                                "BEAV_A_MSHARE_2.in";

 mem_single #(.WIDTH(32*T), .DEPTH(TAU*D_HYPERCUBE), .FILE(FILE_BEAV_A_MSHARE)) 
 BEAV_A_MSHARE
 (
 .clock(i_clk),
 .data(0),
 .address(o_abc_rd? o_abc_addr: 0),
 .wr_en(0),
 .q(i_a)
 );

parameter FILE_BEAV_B_MSHARE = (TEST_SET == 0)? "BEAV_B_MSHARE_0.in":
                               (TEST_SET == 1)? "BEAV_B_MSHARE_1.in":
                                                "BEAV_B_MSHARE_2.in";

mem_single #(.WIDTH(32*T), .DEPTH(TAU*D_HYPERCUBE), .FILE(FILE_BEAV_B_MSHARE)) 
 BEAV_B_MSHARE
 (
 .clock(i_clk),
 .data(0),
 .address(o_abc_rd? o_abc_addr: 0),
 .wr_en(0),
 .q(i_b)
 );


 parameter FILE_BEAV_C_MSHARE = (TEST_SET == 0)?"BEAV_MINUS_C_MSHARE_0.in":
                                (TEST_SET == 1)?"BEAV_MINUS_C_MSHARE_1.in":
                                                "BEAV_MINUS_C_MSHARE_2.in";

mem_single #(.WIDTH(32*T), .DEPTH(TAU*D_HYPERCUBE), .FILE(FILE_BEAV_C_MSHARE)) 
 BEAV_C_MSHARE
 (
 .clock(i_clk),
 .data(0),
 .address(o_abc_rd? o_abc_addr: 0),
 .wr_en(0),
 .q(i_minus_c)
 );

//===============MPC CHALLENGE===================
parameter FILE_R =  (TEST_SET == 0)?"R_L1_0.in":
                    (TEST_SET == 1)?"R_L1_1.in":
                                    "R_L1_2.in";

mem_single #(.WIDTH(32*T), .DEPTH(TAU), .FILE(FILE_R)) 
 R_MEM
 (
 .clock(i_clk),
 .data(0),
 .address(o_a_b_r_e_c_rd? o_a_b_r_e_c_addr: 0),
 .wr_en(0),
 .q(i_r)
 );


parameter FILE_EPS =(TEST_SET == 0)?"EPS_L1_0.in":
                    (TEST_SET == 1)?"EPS_L1_1.in":
                                    "EPS_L1_2.in";

 mem_single #(.WIDTH(32*T), .DEPTH(TAU), .FILE(FILE_EPS)) 
 EPS_MEM
 (
 .clock(i_clk),
 .data(0),
 .address(o_a_b_r_e_c_rd? o_a_b_r_e_c_addr: 0),
 .wr_en(0),
 .q(i_eps)
 );


 //===============RSEED===================
parameter FILE_RSEED =  (TEST_SET == 0)?"RSEED_L1_0.in":
                    (TEST_SET == 1)?"RSEED_L1_1.in":
                                    "RSEED_L1_2.in";

mem_single #(.WIDTH(32), .DEPTH(TAU*LAMBDA/32), .FILE(FILE_RSEED)) 
 RSEED_MEM
 (
 .clock(i_clk),
 .data(0),
 .address(o_rseed_rd? o_rseed_addr: 0),
 .wr_en(0),
 .q(i_rseed)
 );
 


always #5 i_clk = ! i_clk;

 

endmodule