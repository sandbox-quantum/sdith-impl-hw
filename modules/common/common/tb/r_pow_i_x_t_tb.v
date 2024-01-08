/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module r_pow_i_x_t_tb
#(
    
    // parameter FIELD = "P251",
    parameter FIELD = "GF256",
    
    
    parameter PARAMETER_SET = "L1",
    parameter M = 230,
    parameter T = 3
    
    
)(

    );
    
reg i_clk = 0;
reg i_rst = 0;
reg i_start = 0;
reg [32*T-1:0] i_r;
reg [`CLOG2(M)-1:0] i_exp;
wire [32*T-1:0] o_r_pow_exp;
wire o_done;

`ifdef GF32_MUL_SHARED
    wire o_start_mul;
    wire [31:0] o_x_mul;
    wire [31:0] o_y_mul;
    wire  [31:0] o_o_mul;
    wire  i_done_mul;
`endif 

r_pow_i_x_t
DUT
(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_r(i_r),
    .i_exp(i_exp),
    .i_start(i_start),
    .o_r_pow_exp(o_r_pow_exp),

   `ifdef GF32_MUL_SHARED
        .o_start_mul(o_start_mul),
        .o_x_mul(o_x_mul),
        .o_y_mul(o_y_mul),
        .o_o_mul(o_o_mul),
        .i_done_mul(i_done_mul),
    `endif 

    .o_done(o_done)
);


`ifdef GF32_MUL_SHARED
    gf_mul_32
    GF32_MUL
    (
        .i_clk(i_clk),
        .i_x(o_x_mul),
        .i_y(o_y_mul),
        .i_start(o_start_mul),
        .o_o(o_o_mul),
        .o_done(i_done_mul)
    );
`endif 
 
 integer start_time;
 initial
 begin
 
     i_rst <= 1;
    
     #100
        
     i_rst <= 0;
     i_start <= 0;
     i_r <= 0;
     i_exp <= 0;
     #100
     i_start <= 1;
     start_time = $time;
     i_r  <= {32'h12345678, 32'h33223322, 32'h22222222};
     i_exp  <= 8'h87;
     
     #10 
     i_start <= 0;

     @(posedge o_done)
     $display("Total Clock Cycles taken for exponentiation =", ($time-start_time-5)/10);
     #100
     
     $finish;
 
 end
 
 always #5 i_clk = ~i_clk;
 
endmodule
