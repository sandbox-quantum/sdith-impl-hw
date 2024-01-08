/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module sign_offline_tb
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
                        (PARAMETER_SET == "L3")? 26: //check and update
                        (PARAMETER_SET == "L5")? 34: //check and update
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

    parameter WIT_PLAIN_SIZE = 8*(K + WEIGHT + 1 + WEIGHT),
    parameter WIT_PLAIN_SIZE_ADJ = WIT_PLAIN_SIZE + (32 - WIT_PLAIN_SIZE%32)%32,

    parameter HASH1_SIZE = 8 + SEED_SIZE + Y_SIZE + SALT_SIZE + COMMIT_OUTPUT_SIZE*(2**D_HYPERCUBE)*TAU,
    parameter HASH1_SIZE_ADJ = HASH1_SIZE + (WIDTH - HASH1_SIZE%WIDTH)%WIDTH, 

    parameter N_GF = 8,

    parameter MAT_ROW_SIZE_BYTES = M-K,                                                            
    parameter MAT_COL_SIZE_BYTES  =K,

    //ExpandH
    parameter MAT_SIZE_BYTES = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES,
    parameter PROC_SIZE = N_GF*8,
    parameter MRS_BITS = MAT_ROW_SIZE_BYTES*8,
    parameter MCS_BITS = MAT_COL_SIZE_BYTES*8,
    parameter MAT_ROW_SIZE = MRS_BITS + (PROC_SIZE - MRS_BITS%PROC_SIZE)%PROC_SIZE,
    parameter MAT_COL_SIZE = MCS_BITS + (PROC_SIZE - MCS_BITS%PROC_SIZE)%PROC_SIZE,
    parameter MAT_SIZE = MAT_ROW_SIZE*MAT_COL_SIZE_BYTES,
    parameter MS = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES*8,
    parameter H_SHAKE_SQUEEZE = 2*(MS + (32-MS%32)%32),

    parameter TEST_SET = 0
    
)(

);

// Secret Key

reg                                               i_clk = 0;
reg                                               i_rst;

reg                                               i_start;

reg   [32-1:0]                                    i_salt;
reg  [`CLOG2(SALT_SIZE/32)-1:0]                   i_salt_addr;
reg                                               i_salt_wr_en;

reg   [32-1:0]                                    i_seed_h;
reg  [`CLOG2(SEED_SIZE/32)-1:0]                   i_seed_h_addr;
reg                                               i_seed_h_wr_en;

reg   [32-1:0]                                    i_mseed;
reg  [`CLOG2(SEED_SIZE/32)-1:0]                   i_mseed_addr;
reg                                               i_mseed_wr_en;

reg   [32-1:0]                                    i_seed_h;
reg  [`CLOG2(SEED_SIZE/32)-1:0]                   i_seed_h_addr;
reg                                               i_seed_h_wr_en;

wire   [32-1:0]                                   i_y;
reg   [`CLOG2(Y_SIZE_ADJ/32)-1:0]                 i_y_addr;
reg                                               i_y_wr_en;

wire  [32-1:0]                                    i_wit_plain;
reg   [`CLOG2(HO_SIZE_ADJ/32)-1:0]                i_wit_plain_addr;
reg                                               i_wit_plain_wr_en;

// output
reg  [`CLOG2(D_HYPERCUBE)-1:0]                    i_input_mshare_sel;
reg                                               i_input_mshare_rd_en;
reg  [`CLOG2((TAU-1)*HO_SIZE_ADJ/32)-1:0]         i_input_mshare_addr;
wire [WIDTH-1:0]                                  o_input_mshare;

reg                                               i_h1_rd_en;
reg  [`CLOG2(2*SEED_SIZE/32)-1:0]                 i_h1_addr;
wire [32-1:0]                                     o_h1;

wire   [32-1:0]                                   o_com;
reg   [`CLOG2(HASH1_SIZE_ADJ/WIDTH)-1:0]          i_com_addr;
reg                                               i_com_rd_en;

wire [32*T-1:0]                                   o_alpha;
reg [`CLOG2(TAU)-1:0]                             i_alpha_addr;
reg                                               i_alpha_rd_en;

wire [32*T-1:0]                                   o_beta;
reg [`CLOG2(TAU)-1:0]                             i_beta_addr;
reg                                               i_beta_rd_en;


wire                                              o_done;

wire [32-1:0]                                     o_hash_data_in;
wire [`CLOG2(HASH1_SIZE_ADJ/32) -1:0]             i_hash_addr;
wire                                              i_hash_rd_en;
wire [32-1:0]                                     i_hash_data_out;
wire                                              i_hash_data_out_valid;
wire                                              o_hash_data_out_ready;
wire  [32-1:0]                                    o_hash_input_length; // in bits
wire  [32-1:0]                                    o_hash_output_length; // in bits
wire                                              o_hash_start;
wire                                              i_hash_force_done_ack;

wire [2:0] o_status_reg;

// sign_offline #(.FIELD(FIELD), .PARAMETER_SET(PARAMETER_SET), .FILE_SK("SK_POLY_L1.MEM"))
sign_offline #(.FIELD(FIELD), .PARAMETER_SET(PARAMETER_SET), .N_GF(N_GF), .TEST_SET(TEST_SET))
DUT 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(i_start),

.i_mseed(i_mseed),
.i_mseed_addr(i_mseed_addr),
.i_mseed_wr_en(i_mseed_wr_en),

.i_salt(i_salt),
.i_salt_addr(i_salt_addr),
.i_salt_wr_en(i_salt_wr_en),


.i_seed_h(i_seed_h),
.i_seed_h_addr(i_seed_h_addr),
.i_seed_h_wr_en(i_seed_h_wr_en),

.i_y(i_y),
.i_y_addr(i_y_addr),
.i_y_wr_en(i_y_wr_en),

.i_wit_plain(i_wit_plain),
.i_wit_plain_addr(i_wit_plain_addr),
.i_wit_plain_wr_en(i_wit_plain_wr_en),

.i_input_mshare_sel(i_input_mshare_sel),
.i_input_mshare_rd_en(i_input_mshare_rd_en),
.i_input_mshare_addr(i_input_mshare_addr),
.o_input_mshare(o_input_mshare),


.o_done          (o_done),

.i_com_rd_en (i_com_rd_en),
.i_com_addr (i_com_addr),
.o_com (o_com),

.i_h1_rd_en (i_h1_rd_en),
.i_h1_addr (i_h1_addr),
.o_h1 (o_h1),

.i_alpha_rd_en (i_alpha_rd_en),
.i_alpha_addr (i_alpha_addr),
.o_alpha (o_alpha),

.i_beta_rd_en (i_beta_rd_en),
.i_beta_addr (i_beta_addr),
.o_beta (o_beta),

.o_status_reg(o_status_reg),

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


hash_mem_interface #(.IO_WIDTH(32), .MAX_RAM_DEPTH(HASH1_SIZE_ADJ/32), .PARAMETER_SET(PARAMETER_SET))
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


parameter MSEED = (TEST_SET == 0)? 128'h3c3f361a42e1fe0420fc38395aa2e32f:
                  (TEST_SET == 1)? 128'h8ba3c36996f73bdf7f60e3511f5d3fd9:
                                   128'h8a52f0e4d5b487deed3c736a246c94b7;

parameter SALT = (TEST_SET == 0)? 256'hac9ce51f417b947e23de8a3699de25682f31f71407305a249573b7214a042ce6:
                 (TEST_SET == 1)? 256'h4c6902f7942d8d350cd02a52d9df88884023d2ae3edfd39d8072a41dd6e8fe9f:
                                  256'hc4f04b15d319e4df9e732c809793e92c228ace18e7f6612b5e6f5fdb69b01bc2;

parameter SEED_H = (TEST_SET == 0)? 128'hd442599af24583e69b7b34d134861289:
                   (TEST_SET == 1)? 128'h95e1ec7708cc61f2bf8908235e7042c9:
                                    128'h1f1f0cd89dfae0e72a349671f8cecf0f;

parameter VCD_NAME = (TEST_SET == 0)? "sign_offline_0.vcd":
                     (TEST_SET == 1)? "sign_offline_1.vcd":
                                      "sign_offline_2.vcd";

integer start_time, end_time;
integer i;
initial 
begin
    i_rst <= 1;
    i_start <= 0;
    i_mseed <= 0;
    i_mseed_addr <= 0;
    i_mseed_wr_en <= 0;
    i_salt <= 0;
    i_salt_addr <= 0;
    i_salt_wr_en <= 0;
    i_seed_h <= 0;
    i_seed_h_addr <= 0;
    i_seed_h_wr_en <= 0;
    i_y_addr <= 0;
    i_y_wr_en <= 0;
    i_wit_plain_addr <= 0;
    i_wit_plain_wr_en <= 0;
    i_input_mshare_sel <= 0;
    i_input_mshare_rd_en <= 0;
    i_input_mshare_addr <= 0;
    i_h1_rd_en <= 0;
    i_h1_addr <= 0;
    i_com_rd_en <= 0;
    i_com_addr <= 0;
    i_alpha_rd_en <= 0;
    i_alpha_addr <= 0;
    i_beta_rd_en <= 0;
    i_beta_addr <= 0;

    $dumpfile(VCD_NAME);
    $dumpvars(1, sign_offline_tb);
    
    i_salt_wr_en <= 0;
    i_mseed_wr_en <= 0;
    i_seed_h_wr_en <= 0;
    
    
    #100

    i_rst <= 0;

   i_mseed_wr_en <= 1;
   i_mseed <= MSEED[32*3+32-1:32*3];    i_mseed_addr <= 0; #10  
   i_mseed <= MSEED[32*2+32-1:32*2];    i_mseed_addr <= 1; #10  
   i_mseed <= MSEED[32*1+32-1:32*1];    i_mseed_addr <= 2; #10  
   i_mseed <= MSEED[32*0+32-1:32*0];    i_mseed_addr <= 3; #10
   i_mseed <= 0;i_mseed_wr_en <= 0;

   i_salt_wr_en <= 1;
   i_salt <= SALT[32*7+32-1:32*7];      i_salt_addr <= 0; #10  
   i_salt <= SALT[32*6+32-1:32*6];      i_salt_addr <= 1; #10  
   i_salt <= SALT[32*5+32-1:32*5];      i_salt_addr <= 2; #10  
   i_salt <= SALT[32*4+32-1:32*4];      i_salt_addr <= 3; #10
   i_salt <= SALT[32*3+32-1:32*3];      i_salt_addr <= 4; #10
   i_salt <= SALT[32*2+32-1:32*2];      i_salt_addr <= 5; #10
   i_salt <= SALT[32*1+32-1:32*1];      i_salt_addr <= 6; #10
   i_salt <= SALT[32*0+32-1:32*0];      i_salt_addr <= 7; #10
   i_salt_wr_en <= 0;
   
   i_seed_h_wr_en <= 1;
   i_seed_h <= SEED_H[32*3+32-1:32*3];       i_seed_h_addr <= 0; #10  
   i_seed_h <= SEED_H[32*2+32-1:32*2];       i_seed_h_addr <= 1; #10  
   i_seed_h <= SEED_H[32*1+32-1:32*1];       i_seed_h_addr <= 2; #10  
   i_seed_h <= SEED_H[32*0+32-1:32*0];       i_seed_h_addr <= 3; #10
   i_seed_h_wr_en <= 0;


   for (i=0; i<Y_SIZE_ADJ/32; i=i+1) begin
       y_addr <= i; #10
       i_y_wr_en <= 1;
       i_y_addr <= y_addr;
   end

    #10
    i_y_wr_en <= 0;

    for (i=0; i<WIT_PLAIN_SIZE_ADJ/32; i=i+1) begin
       wit_plain_addr <= i; #10
       i_wit_plain_wr_en <= 1;
       i_wit_plain_addr <= wit_plain_addr;
   end

    #10
    i_wit_plain_wr_en <= 0;

//    i_seed_root <= 0;i_seed_root_addr <= 4; #10  
//    i_seed_root <= 0;i_seed_root_addr <= 5; #10  
//    i_seed_root <= 0;i_seed_root_addr <= 6; #10  
//    i_seed_root <= 0;i_seed_root_addr <= 7; #10
//    i_seed_root <= 0;i_seed_root_addr <= 8; #10  
//    i_seed_root <= 0;i_seed_root_addr <= 9; #10  
//    i_seed_root <= 0;i_seed_root_addr <= 10; #10  
//    i_seed_root <= 0;i_seed_root_addr <= 11; #10
    
    // if (PARAMETER_SET == "L3") begin
    //     i_seed_root <= 0;i_seed_root_addr <= 4; #10  
    //     i_seed_root <= 0;i_seed_root_addr <= 5; #10;
    // end
   
    // if (PARAMETER_SET == "L5") begin
    //     i_seed_root <= 0;i_seed_root_addr <= 4; #10  
    //     i_seed_root <= 0;i_seed_root_addr <= 5; #10  
    //     i_seed_root <= 0;i_seed_root_addr <= 6; #10  
    //     i_seed_root <= 0;i_seed_root_addr <= 7; #10; 
    // end
    
//    i_mseed_wr_en <= 0;
    
    #10
    i_start <= 1;
    start_time = $time;
    #10
    i_start <= 0;

    #100
    


    @(posedge o_done)
    end_time = $time;

    $display("Time taken for Offline Sign =", (end_time-start_time-5)/10 );
    
    i_input_mshare_rd_en <= 1;

    for (i=0; i<2*SEED_SIZE/32; i=i+1) begin
       i_h1_addr <= i; 
       i_h1_rd_en <= 1; #10;
    end
    
    i_h1_rd_en <= 0;
    
    #100
    $finish;

end

wire [255:0] status_msg_ascii;


assign status_msg_ascii = (o_status_reg == 0)? "Waiting to Start":
                          (o_status_reg == 1)? "RSEED Generation":
                          (o_status_reg == 2)? "TreePRG, Sampling and Commit":
                          (o_status_reg == 3)? "Hash1 processing":
                          (o_status_reg == 4)? "ExpandMPCChallenge":
                          (o_status_reg == 5 || o_status_reg == 6)? "ComputePlainBroadcast":
                                                "Waiting to Start";


// integer start_time_rseed;
// always
// begin
//      @(posedge i_start)
//     start_time_rseed = $time;

//     @(posedge DUT.hash_force_done_exp_seed)
//     $display("Time taken for RSEED generation =", ($time-start_time_rseed-5)/10 );
// end

// integer start_time_commit_block;
// integer start_time_commit_hash;
// integer doneprg_time;
// always
// begin
//      @(posedge DUT.start_commit)
//     start_time_commit_block = $time;
    
//     @(posedge DUT.COMMIT_BLOCK.done_treeprg)
//     doneprg_time = $time;
// //    $display("Time taken for each treeprg =", ($time-start_time_commit_block-5)/10 );
    
//     @(posedge DUT.COMMIT_BLOCK.i_hash_force_done_ack)
//     start_time_commit_hash = $time;
//     $display("Time taken for each Sampling inside Commit Block =", ($time-doneprg_time-5)/10 );
    
//     @(posedge DUT.done_commit)
//     $display("Time taken for each commit hash =", ($time-start_time_commit_hash-5)/10 );
// end

// integer start_time_treeprg;
// always
// begin
//      @(posedge DUT.start_commit)
//     start_time_treeprg = $time;

//     @(posedge DUT.COMMIT_BLOCK.done_treeprg)
//     $display("Time taken for each treeprg =", ($time-start_time_treeprg-5)/10 );
// end


// integer start_time_h1;
// always
// begin
//      @(DUT.e_count == TAU + 1)
//     start_time_h1 = $time;

//     @(posedge DUT.i_hash_force_done_ack)
//     $display("Time taken for Hash1 =", ($time-start_time_h1-5)/10 );
// end

// always
// begin
//    @(posedge o_done)
// //    $writememh("FULL_COMMIT_MEM.txt", DUT.FULL_COMMIT_MEM.mem);
// end

// reg [31:0] hash_count;
// always@(posedge i_clk)
// begin
//     if (i_start) begin
//         hash_count <= 0;
//     end
//     else if (o_hash_start) begin
//        hash_count <= hash_count + 1; 
//     end
// end

parameter FILE_Y = (TEST_SET == 0)? "Y_0_0.in":
                   (TEST_SET == 1)? "Y_0_1.in":
                                    "Y_0_2.in";

reg   [`CLOG2(Y_SIZE_ADJ/32)-1:0]    y_addr;
mem_single #(.WIDTH(32), .DEPTH(Y_SIZE_ADJ/32), .INIT(0), .FILE(FILE_Y)) 
 Y_MEM
 (
    .clock(i_clk),
    .data(0),
    .address(y_addr),
    .wr_en(0),
    .q(i_y)
 );

parameter FILE_WIT_PLAIN = (TEST_SET == 0)? "WIT_PLAIN_0_0.in":
                           (TEST_SET == 1)? "WIT_PLAIN_0_1.in":
                                            "WIT_PLAIN_0_2.in";

reg   [`CLOG2(WIT_PLAIN_SIZE_ADJ/32)-1:0]    wit_plain_addr;

mem_single #(.WIDTH(32), .DEPTH(WIT_PLAIN_SIZE_ADJ/32), .INIT(0), .FILE(FILE_WIT_PLAIN)) 
 WIT_PLAIN_MEM
 (
    .clock(i_clk),
    .data(0),
    .address(wit_plain_addr),
    .wr_en(0),
    .q(i_wit_plain)
 );


always #5 i_clk = ! i_clk;





endmodule