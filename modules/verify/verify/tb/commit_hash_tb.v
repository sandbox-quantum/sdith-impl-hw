/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/


`include "clog2.v"

module commit_hash_tb
#(

    parameter PARAMETER_SET = "L1",
    parameter DATA_WIDTH    = 32,
    parameter LAMBDA =      (PARAMETER_SET == "L1")? 128:
                            (PARAMETER_SET == "L3")? 192:
                            (PARAMETER_SET == "L5")? 256:
                                                     128,
    parameter M  =  (PARAMETER_SET == "L1")? 230:
                    (PARAMETER_SET == "L3")? 352:
                    (PARAMETER_SET == "L5")? 480:
                                             8,
    parameter SEED_SIZE = LAMBDA,
    parameter SALT_SIZE = 2*LAMBDA,
    parameter RHO_SIZE = LAMBDA/8,
    parameter AUX_SIZE = 256,
    parameter HASH_IN_SIZE = 8+SEED_SIZE + SALT_SIZE + 32 + AUX_SIZE,
    parameter HASH_IN_SIZE_32 = HASH_IN_SIZE + (32-HASH_IN_SIZE%32)%32
    
)(

);

reg                                 i_clk = 0;
reg                                 i_rst;
reg                                 i_start;

wire  [31:0]                                       i_salt;
wire  [`CLOG2(SALT_SIZE/32)-1:0]               o_salt_addr;
wire                                              o_salt_rd;

wire  [31:0]                                       i_leaf_seed;
wire [`CLOG2(SALT_SIZE/32)-1:0]                   o_leaf_seed_addr;
wire                                              o_leaf_seed_rd;

reg  [15:0]                                       i_iteration;
reg  [15:0]                                       i_leaf_idx;
// reg  [15:0]                                       i_leaf_rho;

wire  [31:0]                                      i_aux;
wire [`CLOG2(AUX_SIZE/32)-1:0]                   o_aux_addr;
wire                                             o_aux_rd;
wire [31:0]                                       o_hash_in;
wire [`CLOG2(HASH_IN_SIZE/32)-1:0]            o_hash_addr;
wire                                           o_hash_wen;

wire                                o_done;

wire [32-1:0]                       o_hash_data_in;
wire [`CLOG2((HASH_IN_SIZE_32)/32) -1:0]       i_hash_addr;
wire                                i_hash_rd_en;
wire [32-1:0]                       i_hash_data_out;
wire                                i_hash_data_out_valid;
wire                                o_hash_data_out_ready;
wire  [32-1:0]                      o_hash_input_length_32; // in bits
wire  [32-1:0]                      o_hash_input_length; // in bits
wire  [32-1:0]                      o_hash_output_length; // in bits
wire                                o_hash_start;
wire                                i_hash_done;
wire                                i_hash_force_done_ack;
wire                                o_hash_force_done;

commit_hash #(
    .PARAMETER_SET(PARAMETER_SET),
    .DATA_WIDTH(DATA_WIDTH),
    .LAMBDA(LAMBDA),
    .M(M),
    .SEED_SIZE(SEED_SIZE),
    .SALT_SIZE(SALT_SIZE),
    .RHO_SIZE(RHO_SIZE),
    .AUX_SIZE(AUX_SIZE),
    .HASH_IN_SIZE(HASH_IN_SIZE)
    )
DUT 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(i_start),
.o_done(o_done),


.i_salt(i_salt),
.o_salt_addr(o_salt_addr),
.o_salt_rd(o_salt_rd),

.i_leaf_seed(i_leaf_seed),
.o_leaf_seed_addr(o_leaf_seed_addr),
.o_leaf_seed_rd(o_leaf_seed_rd),

.i_iteration(i_iteration),
.i_leaf_idx(i_leaf_idx),
// .i_leaf_rho(i_leaf_rho),

.i_aux(i_aux),
.o_aux_addr(o_aux_addr),
.o_aux_rd(o_aux_rd),

.o_hash_in(o_hash_in),
.o_hash_addr(o_hash_addr),
.o_hash_wen(o_hash_wen),



// .o_hash_data_in          (o_hash_data_in       ),   
// .i_hash_addr             (i_hash_addr          ),   
// .i_hash_rd_en            (i_hash_rd_en         ),   
.i_hash_data_out         (i_hash_data_out      ),   
.i_hash_data_out_valid   (i_hash_data_out_valid),   
.o_hash_data_out_ready   (o_hash_data_out_ready),   
.o_hash_input_length_32  (o_hash_input_length_32  ),   
.o_hash_input_length     (o_hash_input_length  ),   
.o_hash_output_length    (o_hash_output_length ),   
.o_hash_start            (o_hash_start         ),   
.i_hash_force_done_ack   (i_hash_force_done_ack),   
.o_hash_force_done       (o_hash_force_done    )

);


hash_mem_interface #(.IO_WIDTH(32), .MAX_RAM_DEPTH((HASH_IN_SIZE_32)/32), .PARAMETER_SET(PARAMETER_SET))
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
    .i_input_length_32  (o_hash_input_length_32  ),
    .i_input_length     (o_hash_input_length     ),
    .i_output_length    (o_hash_output_length    ),                 
    .i_start            (o_hash_start            ),
    .o_force_done_ack   (i_hash_force_done_ack   ),
    .i_force_done       (o_hash_force_done       ) 
    
    );

integer start_time, end_time;
integer mult_start_time;
integer gen_h_start_time;
initial 
begin
    i_rst <= 1;
    i_start <= 0;


    #100

    i_rst <= 0;

    
    #10

    i_iteration <= 63;
    i_leaf_idx <= 44;
    // i_leaf_rho <= 0;

    i_start <= 1;
    

    start_time = $time;
    #10
    i_start <= 0;

    #100
    
    @(posedge o_done)


    
    end_time = $time;

    $display("Time taken for Commit Hash =", (end_time-start_time-5)/10 );
    
    
    #100
    $finish;

end




always #5 i_clk = ! i_clk;

 

 mem_single #(.WIDTH(32), .DEPTH(SALT_SIZE/32), .INIT(0), .FILE("SALT.mem")) 
 SALT_MEM
 (
 .clock(i_clk),
 .data(0),
 .address(o_salt_rd? o_salt_addr: 0),
 .wr_en(),
 .q(i_salt)
 );

mem_single #(.WIDTH(32), .DEPTH(SEED_SIZE/32), .INIT(0), .FILE("LEAF_SEED.mem")) 
 SEED_MEM
 (
 .clock(i_clk),
 .data(0),
 .address(o_leaf_seed_rd? o_leaf_seed_addr: 0),
 .wr_en(),
 .q(i_leaf_seed)
 );

mem_single #(.WIDTH(32), .DEPTH(AUX_SIZE/32), .INIT(0), .FILE("AUX_IN.mem"))
    AUX_MEM
    (
    .clock(i_clk),
    .data(0),
    .address(o_aux_rd? o_aux_addr: 0),
    .wr_en(),
    .q(i_aux)
    );


mem_single #(.WIDTH(32), .DEPTH(HASH_IN_SIZE_32/32), .INIT(0))
    HASH_MEM
    (
    .clock(i_clk),
    .data(o_hash_in),
    .address(o_hash_wen? o_hash_addr: i_hash_addr),
    .wr_en(o_hash_wen),
    .q(o_hash_data_in)
    );

endmodule