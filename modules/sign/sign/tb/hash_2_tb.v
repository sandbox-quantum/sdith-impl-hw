/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module hash_2_tb
#(
    parameter PARAMETER_SET                 = "L1",
    parameter LAMBDA =   (PARAMETER_SET == "L1")? 128:
                    (PARAMETER_SET == "L3")? 192:
                    (PARAMETER_SET == "L5")? 256:
                                                 128,
    parameter SALT_SIZE                     = 2*LAMBDA,
    parameter T                             = 3,
    parameter TAU                           =   (PARAMETER_SET == "L1")? 17:
                                                (PARAMETER_SET == "L3")? 26:
                                                (PARAMETER_SET == "L5")? 34:
                                                                         17,
    parameter D_HYPERCUBE                   = 8,
    parameter BROAD_PLAIN_SIZE              = 32*T*2,
    parameter BROAD_SHARE_SIZE              = 32*T*3,
    parameter MAX_MSG_SIZE_BITS             = 1024,
    parameter HASH_OUTPUT_SIZE              = 2*LAMBDA,

    parameter BROAD_PLAIN_SIZE_BYTES        = BROAD_PLAIN_SIZE/8,
    parameter BROAD_SHARE_SIZE_BYTES        = BROAD_SHARE_SIZE/8,
    parameter MAX_MSG_SIZE_BYTES            = MAX_MSG_SIZE_BITS/8,
    
    parameter HASH_BITS                     = 8 + MAX_MSG_SIZE_BITS + SALT_SIZE + TAU*BROAD_PLAIN_SIZE + TAU*D_HYPERCUBE*BROAD_SHARE_SIZE,
    parameter HASH_BITS_ADJ                 = HASH_BITS + (32 - HASH_BITS%32)%32,
    parameter HASH_BITS_NO_MSG              = HASH_BITS - MAX_MSG_SIZE_BITS,

    parameter HASH_BRAM_DEPTH               = HASH_BITS_ADJ/32,
    
   parameter TEST_SET = 0



    
)(

);

reg                                               i_clk = 0;
reg                                               i_rst;
reg                                               i_start;
wire                                              o_done;

reg   [8-1:0]                                     i_msg;
reg                                               i_msg_valid;
reg   [`CLOG2(MAX_MSG_SIZE_BYTES)-1:0]            i_msg_size_in_bytes;


wire [31:0] i_salt;
wire [`CLOG2(SALT_SIZE/32)-1 :0] o_salt_addr;
wire o_salt_rd;

wire [32*T*2-1:0] i_broad_plain;
wire [`CLOG2(TAU)-1:0] o_broad_plain_addr;
wire o_broad_plain_rd;

reg     i_broad_share_valid;
wire   o_broad_share_ready;
reg [32*T*3-1:0]    i_broad_share = 0;


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

hash_2 #(
    .PARAMETER_SET(PARAMETER_SET),
    .SALT_SIZE(SALT_SIZE),
    .T(T),
    .TAU(TAU),
    .MAX_MSG_SIZE_BITS(MAX_MSG_SIZE_BITS),
    .HASH_OUTPUT_SIZE(HASH_OUTPUT_SIZE)
    )
DUT 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(i_start),
.o_done(o_done),

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

.i_broad_share_valid(i_broad_share_valid),
.o_broad_share_ready(o_broad_share_ready),
.i_broad_share(i_broad_share),

.i_h2_addr(0),
.i_h2_rd(0),
.o_h2(),

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



parameter msg = (TEST_SET == 0)? 128'hbfe40ee61d73ab85d3b0cf5596d6e8d5:
                (TEST_SET == 1)? 128'h75cfa61bccb6802504350ac9c8e08839:
                                128'h6dcfa9974e9b522f027f43f40ddd6630;
                
parameter VCD_NAME = (TEST_SET == 0)? "hash2_0.vcd":
                     (TEST_SET == 1)? "hash2_1.vcd":
                                      "hash2_2.vcd";
                                      
integer i;
integer start_time, end_time;

initial 
begin
    i_rst <= 1;
    i_start <= 0;
    i_broad_share_valid <= 0;
    
    $dumpfile(VCD_NAME);
    $dumpvars(1, hash_2_tb);
    
    #100

    i_rst <= 0;
    i_start <= 1;
    start_time = $time;
    i_msg_size_in_bytes <= 16;
    #10
    i_start <= 0;
    #10
//    i_msg <= 0; i_msg_valid <= 1; #10
//    i_msg <= 1; i_msg_valid <= 1; #10
//    i_msg <= 2; i_msg_valid <= 1; #10
//    i_msg <= 3; i_msg_valid <= 1; #10
//    i_msg <= 4; i_msg_valid <= 1; #10
//    i_msg <= 5; i_msg_valid <= 1; #10
//    i_msg <= 6; i_msg_valid <= 1; #10
//    i_msg <= 7; i_msg_valid <= 1; #10
//    i_msg <= 8; i_msg_valid <= 1; #10
//    i_msg <= 9; i_msg_valid <= 1; #10
//    i_msg <= 10; i_msg_valid <= 1;#10
//    i_msg <= 11; i_msg_valid <= 1;#10
//    i_msg <= 12; i_msg_valid <= 1;#10
//    i_msg <= 13; i_msg_valid <= 1;#10
//    i_msg <= 14; i_msg_valid <= 1;#10
//    i_msg <= 15; i_msg_valid <= 1;#10
    
    i_msg <= msg[8+8*0 -1:8*0];		i_msg_valid <= 1; #10
    i_msg <= msg[8+8*1 -1:8*1];     i_msg_valid <= 1; #10
    i_msg <= msg[8+8*2 -1:8*2];     i_msg_valid <= 1; #10
    i_msg <= msg[8+8*3 -1:8*3];     i_msg_valid <= 1; #10
    i_msg <= msg[8+8*4 -1:8*4];     i_msg_valid <= 1; #10
    i_msg <= msg[8+8*5 -1:8*5];     i_msg_valid <= 1; #10
    i_msg <= msg[8+8*6 -1:8*6];     i_msg_valid <= 1; #10
    i_msg <= msg[8+8*7 -1:8*7];     i_msg_valid <= 1; #10
    i_msg <= msg[8+8*8 -1:8*8];     i_msg_valid <= 1; #10
    i_msg <= msg[8+8*9 -1:8*9];     i_msg_valid <= 1; #10
    i_msg <= msg[8+8*10 -1:8*10];   i_msg_valid <= 1; #10
    i_msg <= msg[8+8*11 -1:8*11];   i_msg_valid <= 1; #10
    i_msg <= msg[8+8*12 -1:8*12];   i_msg_valid <= 1; #10
    i_msg <= msg[8+8*13 -1:8*13];   i_msg_valid <= 1; #10
    i_msg <= msg[8+8*14 -1:8*14];   i_msg_valid <= 1; #10
    i_msg <= msg[8+8*15 -1:8*15];   i_msg_valid <= 1; #10
//    i_msg <= 0; i_msg_valid <= 1;#10
//    i_msg <= 1; i_msg_valid <= 1;#10
//    i_msg <= 2; i_msg_valid <= 1;#10
    i_start <= 0;
    i_msg_valid <= 0;
    

    // for (i = 0; i < 2; i = i + 1) begin
    for (i = 0; i < TAU*D_HYPERCUBE; i = i + 1) begin

        @(posedge o_broad_share_ready)
        #90;
        i_broad_share_valid <= 1;
//        i_broad_share <= 288'h03040506ff00010203040506ff00010203040506ff00010203040506ff000102030405ee; #10
        i_broad_share <= {$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom} ; #10
        #10
        i_broad_share_valid <= 0;
        
    end 
    // @(posedge o_broad_share_ready)

    // i_broad_share_valid <= 1;
    // i_broad_share <= 288'hff00010203040506ff00010203040506ff00010203040506ff00010203040506ff000102; #10
    // #10
    
    i_broad_share_valid <= 0;
    @(posedge o_done)
//    end_time = $time;

//    $display("Time taken by Hash2 =", (end_time-start_time-5)/10 );
    
    
    #100
    $finish;

end

always
begin
    
    @(posedge o_hash_start)
    start_time = $time;
    
    @(posedge o_done)
    end_time = $time;

    $display("Time taken by Hash2 =", (end_time-start_time-5)/10 );
end

parameter FILE_SS = (TEST_SET == 0)? "SALT_SEED_0.in":
                    (TEST_SET == 1)? "SALT_SEED_1.in":
                                     "SALT_SEED_2.in";

 mem_single #(.WIDTH(32), .DEPTH(SALT_SIZE/32), .FILE(FILE_SS)) 
 SALT_MEM
 (
 .clock(i_clk),
 .data(0),
 .address(o_salt_rd? o_salt_addr: 0),
 .wr_en(0),
 .q(i_salt)
 );


parameter FILE_BP = (TEST_SET == 0)? "BROAD_PLAIN_0.in":
                    (TEST_SET == 1)? "BROAD_PLAIN_1.in":
                                     "BROAD_PLAIN_2.in";

  mem_single #(.WIDTH(2*32*T), .DEPTH(TAU), .FILE(FILE_BP)) 
 broad_plain_MEM
 (
 .clock(i_clk),
 .data(0),
 .address(o_broad_plain_rd? o_broad_plain_addr: 0),
 .wr_en(0),
 .q(i_broad_plain)
 );

//   mem_single #(.WIDTH(OUT_WIDTH), .DEPTH(DESTINATION_BRAM_DEPTH), .FILE()) 
//  SOURCE_MEM
//  (
//  .clock(i_clk),
//  .data(o_narrow_out),
//  .address(o_narrow_out_en? o_narrow_out_addr: 0),
//  .wr_en(o_narrow_out_en),
//  .q()
//  );


always #5 i_clk = ! i_clk;

 

endmodule