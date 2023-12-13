/*
 * This file is testbench for sign_online_sk module.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
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
    
    parameter FILE_MEM_INIT = "Y_L1.mem",

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

    parameter HASH_BRAM_DEPTH               = HASH_BITS_ADJ/32

    
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

wire [T*8-1:0]                                  o_r;
wire [`CLOG2(TAU*D_SPLIT)-1:0]                  i_r_addr;
wire                                            i_r_rd;

wire [T*8-1:0]                                  o_eps;
wire [`CLOG2(TAU*D_SPLIT)-1:0]                  i_eps_addr;
wire                                            i_eps_rd;
wire                                o_done;

reg [T*32-1:0]                                  i_minus_c;

wire   [32-1:0]                                    i_share;

reg [T*32-1:0]                                  i_a;
reg [T*32-1:0]                                  i_b;
reg [T*32-1:0]                                  i_r;
// wire [`CLOG2(TAU*D_SPLIT)-1:0]                  o_r_addr;
// wire                                            o_r_rd;

reg [T*32-1:0]                                  i_eps;

reg [T*32-1:0]                                  i_alpha_prime;
reg [T*32-1:0]                                  i_beta_prime;
// wire [`CLOG2(TAU*D_SPLIT)-1:0]                  o_eps_addr;
// wire                                            o_eps_rd;


wire [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0]             o_h_mat_addr;
wire [`CLOG2(M)-1:0]                              o_sa_addr;
wire [PROC_SIZE-1:0]                              i_h_mat;
wire [7:0]                                        i_sa;


// h2 signals
reg   [8-1:0]                                     i_msg;
reg                                               i_msg_valid;
reg   [`CLOG2(MAX_MSG_SIZE_BYTES)-1:0]            i_msg_size_in_bytes;


wire [31:0] i_salt;
wire [SALT_SIZE/32-1:0] o_salt_addr;
wire o_salt_rd;

wire [32*T*2-1:0] i_broad_plain;
wire [SALT_SIZE/32-1:0] o_broad_plain_addr;
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
wire                                i_hash_done;
wire                                i_hash_force_done_ack;
wire                                o_force_done_ack;


sign_online_sk #(.PARAMETER_SET(PARAMETER_SET), .FIELD(FIELD))
DUT 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(i_start),

.i_q(i_q),
.o_q_addr(o_q_addr),
.o_q_rd(o_q_rd),


.i_p(i_p),
.o_p_addr(o_p_addr),
.o_p_rd(o_p_rd),

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

.o_done(o_done),

//.o_h_mat_addr(o_h_mat_addr),
//.o_sa_addr(o_sa_addr),
//.i_h_mat(i_h_mat),
//.i_sa(i_sa),

// h2 signals
.i_msg(i_msg),
.i_msg_valid(i_msg_valid),
.o_msg_ready(),
.i_msg_size_in_bytes(i_msg_size_in_bytes),

.i_salt(i_salt),
.o_salt_addr(o_salt_addr),
.o_salt_rd(o_salt_rd),

.i_broad_plain(i_broad_plain),
.o_broad_plain_addr(o_broad_plain_addr),
.o_broad_plain_rd(o_broad_plain_rd),

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

integer start_time;
integer end_time;

initial 
begin
    i_rst <= 1;
    i_start <= 0;
    #100

    i_rst <= 0;
    i_start <= 1;
    start_time = $time;
    i_msg_size_in_bytes <= 16;
    #10
    i_start <= 0;
    #10
    i_msg <= 0; i_msg_valid <= 1; #10
    i_msg <= 1; i_msg_valid <= 1; #10
    i_msg <= 2; i_msg_valid <= 1; #10
    i_msg <= 3; i_msg_valid <= 1; #10
    i_msg <= 4; i_msg_valid <= 1; #10
    i_msg <= 5; i_msg_valid <= 1; #10
    i_msg <= 6; i_msg_valid <= 1; #10
    i_msg <= 7; i_msg_valid <= 1; #10
    i_msg <= 8; i_msg_valid <= 1; #10
    i_msg <= 9; i_msg_valid <= 1; #10
    i_msg <= 10; i_msg_valid <= 1;#10
    i_msg <= 11; i_msg_valid <= 1;#10
    i_msg <= 12; i_msg_valid <= 1;#10
    i_msg <= 13; i_msg_valid <= 1;#10
    i_msg <= 14; i_msg_valid <= 1;#10
    i_msg <= 15; i_msg_valid <= 1;#10
//    i_msg <= 0; i_msg_valid <= 1;#10
//    i_msg <= 1; i_msg_valid <= 1;#10
//    i_msg <= 2; i_msg_valid <= 1;#10

    i_start <= 0;
    i_msg_valid <= 0;
    
    @(posedge o_done)
    end_time = $time;

    $display("Clock Cycles taken for Party Computation =", (end_time-start_time-5)/10 );
    
    
    #100
    $finish;

end

//  always
//  begin
//      @(posedge o_done)
//     //  $writememb("HSA_L1.mem", DUT.MAT_VEC_MUL.RESULT_MEM.mem);
//  end

mem_single #(.WIDTH(8), .DEPTH(M), .FILE("S_L1.mem")) 
 Q_values
 (
 .clock(i_clk),
 .data(0),
 .address(o_q_addr),
 .wr_en(0),
 .q(i_q)
 );



 mem_single #(.WIDTH(8), .DEPTH(M), .FILE("S_L1.mem")) 
 P_values
 (
 .clock(i_clk),
 .data(0),
 .address(o_p_addr),
 .wr_en(0),
 .q(i_p)
 );


 mem_single #(.WIDTH(8), .DEPTH(M), .FILE("S_L1.mem")) 
 F_values
 (
 .clock(i_clk),
 .data(0),
 .address(o_f_addr),
 .wr_en(0),
 .q(i_f)
 );


 mem_single #(.WIDTH(PROC_SIZE), .DEPTH(MAT_SIZE/PROC_SIZE), .FILE("H_L1.mem")) 
 H_matrix_values
 (
 .clock(i_clk),
 .data(0),
 .address(o_h_mat_addr),
 .wr_en(0),
 .q(i_h_mat)
 );


  mem_single #(.WIDTH(8), .DEPTH(K), .FILE("S_L1.mem")) 
 Sa_values
 (
 .clock(i_clk),
 .data(0),
 .address(o_sa_addr),
 .wr_en(0),
 .q(i_sa)
 );


  mem_single #(.WIDTH(2*32*T), .DEPTH(TAU), .FILE("BROAD_PLAIN.mem")) 
 broad_plain_MEM
 (
 .clock(i_clk),
 .data(0),
 .address(o_broad_plain_rd? o_broad_plain_addr: 0),
 .wr_en(0),
 .q(i_broad_plain)
 );

  mem_single #(.WIDTH(32), .DEPTH(SALT_SIZE/32), .FILE("SALT.mem")) 
 SALT_MEM
 (
 .clock(i_clk),
 .data(0),
 .address(o_salt_rd? o_salt_addr: 0),
 .wr_en(0),
 .q(i_salt)
 );
 
always #5 i_clk = ! i_clk;

 

endmodule