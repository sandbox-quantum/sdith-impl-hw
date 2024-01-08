/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module expand_mpc_challenge_tb
#(

    parameter PARAMETER_SET = "L1",
    
    parameter LAMBDA =   (PARAMETER_SET == "L1")? 128:
                            (PARAMETER_SET == "L3")? 192:
                            (PARAMETER_SET == "L5")? 256:
                                                     128,


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
    
    parameter D_HYPERCUBE = 8,
    
    parameter NUMBER_OF_SEED_BITS = (2**(D_HYPERCUBE)+1) * LAMBDA,

    parameter SIZE_OF_R     = TAU*T*D_SPLIT*8,
    parameter SIZE_OF_EPS   = TAU*T*D_SPLIT*8,
    
    parameter TEST_SET = 2

    
)(

);

reg                                 i_clk = 0;
reg                                 i_rst;
reg                                 i_start;


wire   [32-1:0]                                    i_h1;
wire   [`CLOG2(2*SEED_SIZE/32)-1:0]                o_h1_addr;
wire                                               o_h1_rd;

wire [T*32-1:0]                                  o_r;
wire [`CLOG2(TAU*D_SPLIT)-1:0]                  i_r_addr = 0;
wire                                            i_r_rd  = 0;

wire [T*32-1:0]                                  o_eps;
wire [`CLOG2(TAU*D_SPLIT)-1:0]                  i_eps_addr  = 0;
wire                                            i_eps_rd  = 0;


wire                                o_done;

wire [32-1:0]                       o_hash_data_in;
wire [`CLOG2((2*SEED_SIZE)/32) -1:0]       i_hash_addr;
wire                                i_hash_rd_en;
wire [32-1:0]                       i_hash_data_out;
wire                                i_hash_data_out_valid;
wire                                o_hash_data_out_ready;
wire  [32-1:0]                      o_hash_input_length; // in bits
wire  [32-1:0]                      o_hash_output_length; // in bits
wire                                o_hash_start;
//wire                                i_hash_done;
wire                                i_hash_force_done_ack;
//wire                                o_force_done_ack;

expand_mpc_challenge #(.PARAMETER_SET(PARAMETER_SET))
DUT 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(i_start),
.o_done(o_done),


.o_h1_rd(o_h1_rd),
.o_h1_addr(o_h1_addr),
.i_h1(i_h1),

.o_r(o_r),
.i_r_addr(0),
.i_r_rd(0),

.o_eps(o_eps),
.i_eps_addr(0),
.i_eps_rd(0),


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


hash_mem_interface #(.IO_WIDTH(32), .MAX_RAM_DEPTH((2*SEED_SIZE)/32), .PARAMETER_SET(PARAMETER_SET))
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

parameter VCD_NAME = (TEST_SET == 0)? "expand_mpc_challenge_0.vcd":
                     (TEST_SET == 1)? "expand_mpc_challenge_1.vcd":
                                      "expand_mpc_challenge_2.vcd";

integer start_time, end_time;
//integer mult_start_time;
//integer gen_h_start_time;
initial 
begin
    i_rst <= 1;
    i_start <= 0;

    $dumpfile(VCD_NAME);
    $dumpvars(1, expand_mpc_challenge_tb);

    #100

    i_rst <= 0;

    
    #10
    i_start <= 1;
    start_time = $time;
    #10
    i_start <= 0;

    #100
    
    @(posedge o_done)
    end_time = $time;

    $display("Time taken for expand mpc challenge =", (end_time-start_time-5)/10 );
    
    
    #100
    $finish;

end

//  always
//  begin
//      @(posedge o_done)
//     //  $writememb("HSA_L1.mem", DUT.MAT_VEC_MUL.RESULT_MEM.mem);
//  end

parameter H1_FILE = (TEST_SET == 0)? "H1_0.in":
                    (TEST_SET == 1)? "H1_1.in":
                                     "H1_2.in";

 mem_single #(.WIDTH(32), .DEPTH(2*SEED_SIZE/32), .FILE(H1_FILE)) 
 H1_MEM
 (
 .clock(i_clk),
 .data(0),
 .address(o_h1_rd? o_h1_addr: 0),
 .wr_en(0),
 .q(i_h1)
 );



always #5 i_clk = ! i_clk;

 

endmodule