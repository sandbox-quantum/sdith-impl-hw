`timescale 1ns / 1ps
/*
 * 
 *
 * Copyright (C) 2022
 * Author: Sanjay Deshpande <sanjay.deshpande@yale.edu>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
*/

//`include "clog2.v"

module gf251_add_32
# (
    A_WIDTH = 32,
    B_WIDTH = 32,
    MAX_AB = (A_WIDTH > B_WIDTH)? A_WIDTH : B_WIDTH
    )
    (
    input  i_clk,
    input  i_start,
    output o_done,
    
//    input  [32-1:0] i_x,
//    input  [32-1:0] i_y,
    
    input  [32-1:0] in_1,
    input  [32-1:0] in_2,
    output [32-1:0] out
    
//    output [32-1:0] o_o
    );
    

reg [32:0] add_out_33;
reg done_add_out_33;

always@(posedge i_clk)
begin
	add_out_33 <= in_1 + in_2;
	done_add_out_33 <= i_start;
end

//REDUCTION LOGIC STARTS HERE

//1. t <-- a*m>>k
//2. c <-- a - t*N
//3. if (c <0 )
//4. c <-- c+N
//5. end if
//6. return c

wire [64+33-1:0] a_mul_m;
wire done_a_mul_m;

karatsuba_mul
#(
.A_WIDTH(64),
.B_WIDTH(64)
)
A_MUL_M
(
    .i_clk(i_clk),
    .i_x({31'h00000000,add_out_33}),
    .i_y(64'h0000000115041c34),
    .i_start(done_add_out_33),
    .o_o(a_mul_m),
    .o_done(done_a_mul_m)
);

wire [32:0] t;
assign t[32:0] = a_mul_m[96:64];


wire [63:0] t_mul_N;
wire done_t_mul_N;
karatsuba_mul
#(
.A_WIDTH(64),
.B_WIDTH(64)
)
T_MUL_N
(
    .i_clk(i_clk),
    .i_x({31'h00000000,t}),
    .i_y(64'h00000000ec940e71),
    .i_start(done_a_mul_m),
    .o_o(t_mul_N),
    .o_done(done_t_mul_N)
);

wire [32:0] a_reg;
pipeline_reg_gen #(.WIDTH(33), .REG_STAGES(8))
A_REG
(
    .i_clk(i_clk),
    .i_data_in(add_out_33),
    .o_data_out(a_reg)
);

wire [32:0] c, c_reg, c_reg_reg;
wire done_c;
assign c = a_reg - t_mul_N;

pipeline_reg_gen #(.WIDTH(33), .REG_STAGES(1))
C_REG
(
    .i_clk(i_clk),
    .i_data_in(c),
    .o_data_out(c_reg)
);

pipeline_reg_gen #(.WIDTH(1), .REG_STAGES(1))
DONE_C
(
    .i_clk(i_clk),
    .i_data_in(done_t_mul_N),
    .o_data_out(done_c)
);

wire [32:0] c_plus_n, c_plus_n_reg;
wire done_c_plus_n
;
assign c_plus_n = c_reg + 32'hec940e71;

pipeline_reg_gen #(.WIDTH(33), .REG_STAGES(1))
C_PLUS_N_REG
(
    .i_clk(i_clk),
    .i_data_in(c_plus_n),
    .o_data_out(c_plus_n_reg)
);

pipeline_reg_gen #(.WIDTH(33), .REG_STAGES(1))
C_REG_REG
(
    .i_clk(i_clk),
    .i_data_in(c_reg),
    .o_data_out(c_reg_reg)
);

pipeline_reg_gen #(.WIDTH(1), .REG_STAGES(1))
DONE_C_PLUS_N
(
    .i_clk(i_clk),
    .i_data_in(done_c),
    .o_data_out(done_c_plus_n)
);

assign out = c_reg_reg[32]? c_plus_n_reg : c_reg_reg;
assign o_done = done_c_plus_n;

endmodule


