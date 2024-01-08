/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module get_seed_sibling_path_tb
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
    parameter SALT_SIZE = 2*LAMBDA,
    
    parameter D_HYPERCUBE = 8,
    
    parameter NUMBER_OF_SEED_BITS = (2**(D_HYPERCUBE)+1) * LAMBDA,

    parameter SIZE_OF_R     = TAU*T*D_SPLIT*8,
    parameter SIZE_OF_EPS   = TAU*T*D_SPLIT*8,
  
    parameter TEST_SET = 1

    
)(

);

reg                                 i_clk = 0;
reg                                 i_rst;
reg                                 i_start;



reg  [7:0]                         i_i_star;

wire                                o_done;

wire [32-1:0]                       o_hash_data_in;
wire [`CLOG2((SALT_SIZE + SEED_SIZE)/32) -1:0]       i_hash_addr;
wire                                i_hash_rd_en;
wire [32-1:0]                       i_hash_data_out;
wire                                i_hash_data_out_valid;
wire                                o_hash_data_out_ready;
wire  [32-1:0]                      o_hash_input_length; // in bits
wire  [32-1:0]                      o_hash_output_length; // in bits
wire                                o_hash_start;
wire                                i_hash_force_done_ack;
wire                                o_hash_force_done;

wire [31:0]                          o_tree_seed;
wire                                 o_tree_seed_valid;
wire [`CLOG2((8*SEED_SIZE/32)) -1:0] o_tree_seed_addr;

parameter FILE_SS = (TEST_SET == 0)? "SALT_SEED_0.in":
                    (TEST_SET == 1)? "SALT_SEED_1.in":
                                     "SALT_SEED_2.in";

get_seed_sibling_path #(.PARAMETER_SET(PARAMETER_SET), .FILE_SS(FILE_SS))
DUT 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(i_start),
.o_done(o_done),

.i_i_star(i_i_star),
.i_salt_seed_wen(0),
.i_salt_seed_addr(0),
.i_salt_seed(0),

.o_tree_seed(o_tree_seed),
.o_tree_seed_valid(o_tree_seed_valid),
.o_tree_seed_addr(o_tree_seed_addr),

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


hash_mem_interface #(.IO_WIDTH(32), .MAX_RAM_DEPTH((SALT_SIZE+SEED_SIZE)/32), .PARAMETER_SET(PARAMETER_SET))
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

parameter VCD_NAME = (TEST_SET == 0)? "get_seed_sibling_path_0.vcd":
                     (TEST_SET == 1)? "get_seed_sibling_path_1.vcd":
                                      "get_seed_sibling_path_2.vcd";

integer start_time, end_time;

initial 
begin
    i_rst <= 1;
    i_start <= 0;
    
    $dumpfile(VCD_NAME);
    $dumpvars(1, get_seed_sibling_path_tb);

    #100

    i_rst <= 0;

    
    #10
    i_start <= 1;
//    i_i_star <= 255;
//    i_i_star <= 126;

 if (TEST_SET == 0) begin
        i_i_star <= 255;
    end
    else if (TEST_SET == 1) begin
        i_i_star <= 126;
    end
    else begin
        i_i_star <= 8;
    end
    
    start_time = $time;
    #10
    i_start <= 0;

    #100
    
    @(posedge o_done)
    end_time = $time;

    $display("Time taken for Get Seed Sibling Path =", (end_time-start_time-5)/10 );
    
    
    #100
    $finish;

end




always #5 i_clk = ! i_clk;

 

endmodule