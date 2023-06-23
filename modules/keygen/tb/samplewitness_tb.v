/*
 * This file is testbench for samplewitness module.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module samplewitness_tb
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

reg                                 i_clk = 0;
reg                                 i_rst;
reg                                 i_start;
wire   [32-1:0]                     i_seed_wit;
wire  [`CLOG2(LAMBDA/32)-1:0]       i_seed_wit_addr;
wire                                i_seed_wr_en;
wire  [8-1:0]                       o_q;
reg   [`CLOG2(M):0]                 i_q_addr;
reg                                 i_q_rd = 0;
wire  [8-1:0]                       o_p;
reg   [`CLOG2(M):0]                 i_p_addr;
reg                                 i_p_rd = 0;
wire  [8-1:0]                       o_s;
reg   [`CLOG2(M):0]                 i_s_addr;
reg                                 i_s_rd = 0;
wire                                o_done;



samplewitness #(.PARAMETER_SET(PARAMETER_SET))
COMP_SP 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(i_start),
.i_seed_wit(i_seed_wit),
.i_seed_wit_addr(i_seed_wit_addr),
.i_seed_wr_en(i_seed_wr_en),
.o_q(o_q),
.i_q_addr(i_q_addr),
.i_q_rd(i_q_rd),
.o_p(o_p),
.i_p_addr(i_p_addr),
.i_p_rd(i_p_rd),
.o_s(o_s),
.i_s_addr(i_s_addr),
.i_s_rd (i_s_rd ),
.o_done(o_done)
);


integer start_time, end_time;
initial 
begin
    i_rst <= 1;
    i_start <= 0;

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

    $display("Time taken to SampleWitness =", (end_time-start_time-5)/10 );
    
    
    #100
    $finish;

end

always #5 i_clk = ! i_clk;

 

endmodule