/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module gf_mul_p251_mul_cycle_tb(

    );
    
reg clk = 0;
reg start = 0;
reg [7:0] in_1;
reg [7:0] in_2;
wire [7:0] out;
wire done;


wire [7:0] p251_out;
wire p251_done;

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

p251_mul
DUT_P251
(
    .clk(clk),
    .in_1(in_1),
    .in_2(in_2),
    .start(start),
    .out(p251_out),
    .done(p251_done)
);
 
 initial
 begin
     start <= 0;
     in_1 <= 0;
     in_2 <= 0;
     #100
     start <= 1;
     in_1  <= 1;
     in_2  <= 20;
     
     #10 
     start <= 0;
 
 end
 
 always #5 clk = ~clk;
 
endmodule
