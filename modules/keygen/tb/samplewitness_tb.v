/*
 * This file is testbench for samplewitness module.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module samplewitness_tb
#(

    parameter PARAMETER_SET = "L3",
    
    parameter LAMBDA =  (PARAMETER_SET == "L1")? 128:
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

    parameter D =   (PARAMETER_SET == "L1")? 1:
                        (PARAMETER_SET == "L3")? 2:
                        (PARAMETER_SET == "L5")? 2:
                                                 1,

    parameter FILE_SEED = (PARAMETER_SET == "L1")? "SEED_SAMPLE.mem":
                    (PARAMETER_SET == "L3")? "SEED_SAMPLE_L3.mem":
                    (PARAMETER_SET == "L5")? "SEED_SAMPLE_L5.mem":
                                                "SEED_SAMPLE.mem"

    
    
)(

);

reg                                 i_clk = 0;
reg                                 i_rst;
reg                                 i_start;
reg   [32-1:0]                     i_seed_wit;
reg  [`CLOG2(LAMBDA/32)-1:0]       i_seed_wit_addr;
reg                                i_seed_wit_wr_en;

    wire  [8-1:0]                       o_q;
    reg   [`CLOG2(M):0]                 i_q_addr;
    reg                                 i_q_rd = 0;
    wire  [8-1:0]                       o_p;
    reg   [`CLOG2(M):0]                 i_p_addr;
    reg                                 i_p_rd = 0;
    wire  [8-1:0]                       o_s;
    reg   [`CLOG2(M):0]                 i_s_addr;
    reg                                 i_s_rd = 0;

`ifdef TWO_SHARES
    wire  [8-1:0]                       o_q_0;
    reg   [`CLOG2(M):0]                 i_q_0_addr;
    reg                                 i_q_0_rd = 0;
    wire  [8-1:0]                       o_p_0;
    reg   [`CLOG2(M):0]                 i_p_0_addr;
    reg                                 i_p_0_rd = 0;
//    wire  [8-1:0]                       o_s_0;
//    reg   [`CLOG2(M):0]                 i_s_0_addr;
//    reg                                 i_s_0_rd = 0;
`endif 

wire                                o_done;



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

samplewitness #(.PARAMETER_SET(PARAMETER_SET), .FILE_SEED(FILE_SEED))
DUT 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(i_start),
.i_seed_wit(i_seed_wit),
.i_seed_wit_addr(i_seed_wit_addr),
.i_seed_wit_wr_en(i_seed_wit_wr_en),
.o_q(o_q),
.i_q_addr(i_q_addr),
.i_q_rd(i_q_rd),
.o_p(o_p),
.i_p_addr(i_p_addr),
.i_p_rd(i_p_rd),
.o_s(o_s),
.i_s_addr(i_s_addr),
.i_s_rd (i_s_rd ),

`ifdef TWO_SHARES
    .o_q_0(o_q_0),
    .i_q_0_addr(i_q_0_addr),
    .i_q_0_rd(i_q_0_rd),
    .o_p_0(o_p_0),
    .i_p_0_addr(i_p_0_addr),
    .i_p_0_rd(i_p_0_rd),
//    .o_s_0(o_s_0),
//    .i_s_0_addr(i_s_0_addr),
//    .i_s_0_rd (i_s_0_rd ),
`endif 

.o_done(o_done),

.o_hash_data_in          (o_hash_data_in       ),   
.i_hash_addr             (i_hash_addr          ),   
.i_hash_rd_en            (i_hash_rd_en         ),   
.i_hash_data_out         (i_hash_data_out      ),   
.i_hash_data_out_valid   (i_hash_data_out_valid),   
.o_hash_data_out_ready   (o_hash_data_out_ready),   
.o_hash_input_length     (o_hash_input_length  ),   
.o_hash_output_length    (o_hash_output_length ),   
.o_hash_start            (o_hash_start         ),   
.o_hash_force_done       (o_hash_force_done    )

);


hash_mem_interface #(.PARAMETER_SET(PARAMETER_SET), .IO_WIDTH(32), .MAX_RAM_DEPTH(LAMBDA/32))
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

    i_seed_wit <= 0;
    i_seed_wit_wr_en <= 1;
//    i_seed_wit_addr <= 0; #10  
//    i_seed_wit_addr <= 1; #10  
//    i_seed_wit_addr <= 2; #10  
//    i_seed_wit_addr <= 3; #10
    i_seed_wit_wr_en <= 0;
    
    #10
    i_start <= 1;
    start_time = $time;
    #10
    i_start <= 0;

    #100



    @(posedge o_done)
    end_time = $time;

    $display("Time taken to SampleWitness =", (end_time-start_time-5)/10 );
    
    
    #100
    $finish;

end

always
begin
    @(posedge o_done)
    $writememb("X_L1_gen.mem", DUT.SEED_WIT_EXP.X_MEM.mem);
end

always #5 i_clk = ! i_clk;

 

endmodule