/*
 * This file is testbench for H matrix generation.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module compute_Q_tb
#(

    parameter PARAMETER_SET = "L1",
    
                                                    
    parameter WEIGHT =  (PARAMETER_SET == "L1")? 79:
                        (PARAMETER_SET == "L3")? 120:
                        (PARAMETER_SET == "L5")? 150:
                                                 32,
                                                            
    parameter D =   (PARAMETER_SET == "L1")? 1:
                    (PARAMETER_SET == "L3")? 2:
                    (PARAMETER_SET == "L5")? 2:
                                            1,
    parameter DEPTH_OF_Q = WEIGHT/D 
    
    
)(

);



reg                           i_clk = 0;
reg                           i_rst;
reg                           i_start;
wire  [7:0]                   i_non_zero_pos;
wire  [`CLOG2(WEIGHT)-1:0]    o_non_zero_pos_addr;
wire                         o_non_zero_pos_rd;


wire  [7:0]                     o_q ;
reg   [`CLOG2(DEPTH_OF_Q)-1:0]  i_q_addr = 0;
reg                           i_q_rd = 0;

wire                         o_done;

compute_Q #(.PARAMETER_SET(PARAMETER_SET), .WEIGHT(WEIGHT), .D(D))
COMP_Q 
(
.i_clk(i_clk),      
.i_rst(i_rst),
.i_start(i_start),
.i_non_zero_pos(i_non_zero_pos),
.o_non_zero_pos_addr(o_non_zero_pos_addr),
.o_non_zero_pos_rd(o_non_zero_pos_rd),

.o_q(o_q),
.i_q_addr(i_q_addr),

.i_q_rd(i_q_rd),
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

    $display("Time taken to Compute Q =", (end_time-start_time-5)/10 );
    
    #100
    i_q_rd <= 1;
    i_q_addr <= 1;
    #100
    $finish;

end

always #5 i_clk = ! i_clk;


mem_single #(.WIDTH(8), .DEPTH(DEPTH_OF_Q), .FILE("NON_ZERO_POS_L1.mem")) 
 NON_ZERO_POSITIONS
 (
 .clock(i_clk),
 .data(0),
 .address(o_non_zero_pos_rd? o_non_zero_pos_addr: 0),
 .wr_en(0),
 .q(i_non_zero_pos)
 );

endmodule