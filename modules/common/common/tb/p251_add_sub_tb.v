/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module p251_add_sub_tb(

    );
    
reg clk = 0;
reg start = 0;
reg [7:0] in_1;
reg [7:0] in_2;
wire [7:0] out;
reg i_add_sub = 1;
wire done;


p251_add_sub
DUT
(
    .i_clk(clk),
    .in_1(in_1),
    .in_2(in_2),
    .i_start(start),
    .i_add_sub(i_add_sub),
    .out(out),
    .o_done(done)
);
 
integer i;
 
 initial
 begin
     start <= 0;
     in_1 <= 0;
     in_2 <= 0;
     #100
     for (i =0; i < 256; i=i+1) 
     begin
        start <= 1;
        in_1 <= i;
        in_2 <= 250;
        #10;
     end
     
     start <= 1;
     in_1  <= 1;
     in_2  <= 20;
     
     #10 
     start <= 1;
     in_1  <= 2;
     in_2  <= 31;
     
     #10 
     start <= 1;
     in_1  <= 3;
     in_2  <= 85;
     
      #10 
     start <= 1;
     in_1  <= 6;
     in_2  <= 165;
     
     
     #10 
     start <= 0;
     $finish;
 
 end
 
 always #5 clk = ~clk;
 
endmodule
