/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module dummy_pc_tb
#(

    parameter PARAMETER_SET = "L1",    
    parameter T =   (PARAMETER_SET == "L5")? 4:
                                             3, 
    parameter CLOCK_CYCLE_COUNT = 49463


    
)(

);

reg                                               i_clk = 0;
reg                                               i_rst;
reg                                               i_start;
wire                                              o_done;

wire [32*T-1:0]                              o_alpha;
wire [32*T-1:0]                              o_beta;
wire [32*T-1:0]                              o_v;

dummy_pc #(
    .PARAMETER_SET(PARAMETER_SET),
    .T(T),
    .CLOCK_CYCLE_COUNT(CLOCK_CYCLE_COUNT)
    )
DUT 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(i_start),
.o_done(o_done),

.o_alpha(o_alpha),
.o_beta(o_beta),
.o_v(o_v)

);




integer start_time, end_time;

initial 
begin
    i_rst <= 1;
    i_start <= 0;
    #100

    i_rst <= 0;
    i_start <= 1;
    start_time = $time;
    #10
    i_start <= 0;

    @(posedge o_done)
    end_time = $time;

    $display("Time taken by Dummy PC =", (end_time-start_time-5)/10 );
    
    
    #100
    $finish;

end


always #5 i_clk = ! i_clk;

 

endmodule