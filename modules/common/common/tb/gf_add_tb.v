/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module gf_add_tb(

    );
    
reg clk = 0;
reg start = 0;
reg [7:0] in_1;
reg [7:0] in_2;
wire [7:0] out;
wire done;


gf_add
#(
.WIDTH(8),
.REG_IN(0),
.REG_OUT(0)
)
DUT
(
    .i_clk(clk),
    .in_1(in_1),
    .in_2(in_2),
    .i_start(start),
    .out(out),
    .o_done(done)
);
 
 initial
 begin
     start <= 0;
     in_1 <= 0;
     in_2 <= 0;
     #100
     start <= 1;
     in_1  <= 8'he9;
     in_2  <= 8'h05;
     
     #10 
     start <= 0;
 
 end
 
 always #5 clk = ~clk;
 
endmodule
