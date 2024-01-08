/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module gf_mul_tb(

    );
    
reg clk = 0;
reg start = 0;
reg [7:0] in_1;
reg [7:0] in_2;
wire [7:0] out;
wire done;


gf_mul
DUT
(
    .clk(clk),
    .in_1(in_1),
    .in_2(in_2),
    .start(start),
    .out(out),
    .done(done)
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
