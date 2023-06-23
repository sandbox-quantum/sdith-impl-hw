/*
 * This file is testbench for samplewitness module.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module seed_wit_expansion_tb
#(

    parameter PARAMETER_SET = "L1",
    
    parameter LAMBDA =  (PARAMETER_SET == "L1")? 128:
                        (PARAMETER_SET == "L2")? 192:
                        (PARAMETER_SET == "L3")? 256:
                                                 128,
                                                    
    parameter M =  (PARAMETER_SET == "L1")? 230:
                        (PARAMETER_SET == "L2")? 352:
                        (PARAMETER_SET == "L3")? 480:
                                                 230,

    parameter WEIGHT =  (PARAMETER_SET == "L1")? 79:
                        (PARAMETER_SET == "L2")? 120:
                        (PARAMETER_SET == "L3")? 150:
                                                 79,

    parameter D =   (PARAMETER_SET == "L1")? 1:
                        (PARAMETER_SET == "L2")? 2:
                        (PARAMETER_SET == "L3")? 2:
                                                 1
    
    
)(

);

reg                                i_clk = 0;
reg                                i_rst;
reg                                i_start;
reg   [32-1:0]                     i_seed;
reg  [`CLOG2(LAMBDA/32)-1:0]       i_seed_addr;
reg                                i_seed_wr_en;

wire [32-1:0]                       o_hash_data_in;
wire [`CLOG2(LAMBDA/32) -1:0]       i_hash_addr;
wire                                 i_hash_rd_en;
wire [32-1:0]                       i_hash_data_out;
wire                                i_hash_data_out_valid;
wire                                o_hash_data_out_ready;
wire  [32-1:0]                      o_hash_input_length; // in bits
wire  [32-1:0]                      o_hash_output_length; // in bits
wire                                o_hash_start;
wire                                i_hash_done;
wire                                o_hash_force_done;
  


reg [`CLOG2(WEIGHT/D)-1:0]       i_pos_addr = 0;
reg                              i_pos_rd = 0;
wire [7:0]                       o_pos;

reg [`CLOG2(WEIGHT/D)-1:0]       i_val_addr = 0;
reg                              i_val_rd = 0;
wire [7:0]                       o_val;

reg [`CLOG2(WEIGHT/D)-1:0]       i_x_addr = 0;
reg                              i_x_rd = 0;
wire [7:0]                       o_x;



seed_wit_expansion #(.PARAMETER_SET(PARAMETER_SET))
SEED_WIT_EXP 
(
.i_clk                  (i_clk                 ),
.i_rst                  (i_rst                 ),
.i_start                (i_start               ),
.i_seed_wit             (i_seed                ),
.i_seed_wit_addr        (i_seed_addr           ),
.i_seed_wit_wr_en       (i_seed_wr_en          ),

.o_hash_data_in          (o_hash_data_in       ),   
.i_hash_addr             (i_hash_addr          ),   
.i_hash_rd_en            (i_hash_rd_en         ),   
.i_hash_data_out         (i_hash_data_out      ),   
.i_hash_data_out_valid   (i_hash_data_out_valid),   
.o_hash_data_out_ready   (o_hash_data_out_ready),   
.o_hash_input_length     (o_hash_input_length  ),   
.o_hash_output_length    (o_hash_output_length ),   
.o_hash_start            (o_hash_start         ),   
.o_hash_force_done       (o_hash_force_done    ), 

.i_pos_addr             (i_pos_addr            ), 
.i_pos_rd               (i_pos_rd              ), 
.o_pos                  (o_pos                 ), 

.i_val_addr             (i_val_addr            ), 
.i_val_rd               (i_val_rd              ), 
.o_val                  (o_val                 ), 

.i_x_addr               (i_x_addr               ), 
.i_x_rd                 (i_x_rd                 ), 
.o_x                    (o_x                    ), 

.o_done_xv(o_done)
);


hash_mem_interface #(.IO_WIDTH(32), .MAX_RAM_DEPTH(LAMBDA/32))
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
    .i_force_done       (o_hash_force_done       ) 
    
    );


integer start_time, end_time;
initial 
begin
    i_rst <= 1;
    i_start <= 0;

    #100


    i_rst <= 0;

    i_seed <= 0;
    i_seed_wr_en <= 1;
    i_seed_addr <= 0; #10  
    i_seed_addr <= 1; #10  
    i_seed_addr <= 2; #10  
    i_seed_addr <= 3; #10
    i_seed_wr_en <= 0;

    
    #10
    i_start <= 1;
    start_time = $time;
    #10
    i_start <= 0;

    #100



    @(posedge o_done)
    end_time = $time;

    $display("Time taken to SeedExpansion =", (end_time-start_time-5)/10 );
    
    
    #100
    $finish;

end

always #5 i_clk = ! i_clk;

 

endmodule