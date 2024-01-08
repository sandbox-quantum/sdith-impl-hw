/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



//`include "clog2.v"

module karatsuba_mul
# (
    A_WIDTH = 32,
    B_WIDTH = 32,
    MAX_AB = (A_WIDTH > B_WIDTH)? A_WIDTH : B_WIDTH
    )
    (
    input  i_clk,
    input  i_start,
    output reg o_done,
    
    input  [A_WIDTH-1:0] i_x,
    input  [B_WIDTH-1:0] i_y,

    output reg [A_WIDTH+B_WIDTH-1:0] o_o
    );
    



//karatsuba
reg  [A_WIDTH-1:0]a_in_reg, a_in_reg_reg, a_in_reg_reg_reg;
wire [A_WIDTH+B_WIDTH-1:0] ab;
wire [A_WIDTH/2 - 1:0] a0, a1;
wire [B_WIDTH/2 - 1:0] b0, b1;


reg [(A_WIDTH + B_WIDTH)/2 - 1:0] a0b0, a1b1;
reg [MAX_AB/2:0] add_a0a1, add_b0b1;
reg [(A_WIDTH + B_WIDTH)/2 - 1:0] a0b0_reg, a1b1_reg;
reg [(A_WIDTH + B_WIDTH)/2 - 1:0] a0b0_reg_reg, a1b1_reg_reg;

reg [(A_WIDTH + B_WIDTH)/2:0] add_a0b0_a1b1;

reg [(A_WIDTH + B_WIDTH)/2 + 1:0] mul_a0a1_b0b1;
reg [(A_WIDTH + B_WIDTH)/2 + 1:0] sub_mul_ab_add_ab;

reg done_reg_0;
reg done_reg_1;
reg done_reg_2;

assign a0 = i_x[A_WIDTH/2 - 1:0];
assign a1 = i_x[A_WIDTH - 1:A_WIDTH/2];
assign b0 = i_y[B_WIDTH/2 - 1:0];
assign b1 = i_y[B_WIDTH - 1:B_WIDTH/2];


always@(posedge i_clk)
begin
    a0b0 <= a0*b0;
    a1b1 <= a1*b1;
    add_a0a1 <= a0 + a1;
    add_b0b1 <= b0 + b1;
    done_reg_0 <= i_start;
end


always@(posedge i_clk)
begin
    a0b0_reg <= a0b0;
    a1b1_reg <= a1b1;
    add_a0b0_a1b1 <= a0b0 + a1b1;
    mul_a0a1_b0b1 <= add_a0a1 * add_b0b1;
    done_reg_1 <= done_reg_0;
end

always@(posedge i_clk)
begin
    a0b0_reg_reg <= a0b0_reg;
    a1b1_reg_reg <= a1b1_reg;
    sub_mul_ab_add_ab <= mul_a0a1_b0b1 - add_a0b0_a1b1;
    done_reg_2 <= done_reg_1;
end

always@(posedge i_clk)
begin
 o_o <= a0b0_reg_reg + {sub_mul_ab_add_ab, {{MAX_AB/2}{1'b0}}} + {a1b1_reg_reg, {{MAX_AB}{1'b0}}};
 o_done <= done_reg_2;
end
  
endmodule


