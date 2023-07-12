`timescale 1ns / 1ps
/*
 *
 *
Copyright (C) 2023
Author: Sanjay Deshpande
 *
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.
 *
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
 *
You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software Foundation,
Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA

Input: in_1, in_2 and m = floor(2^9/251)+1   //m = 3, 9 represents output width on adding two 8-bit numbers
Output: c  = (in_1 + in_2) mod 251
0: a = in_1 + in_2
1: t <- a*3 >> 9
2: c <- a - t*251
3: if (c<0)
4: 	c <- c+251
5: end if
6: return c

 *
*/
module p251_add
#(
//    parameter REG_IN = 1,
//    parameter REG_OUT = 1
)
(
    input i_clk, // for potential regs we may add later
    input i_start,
    input [7:0] in_1,
    input [7:0] in_2,
    output [7:0] out,
    output o_done
    );
  
wire [8:0] a;
wire [8+2:0]a_mul_3;
wire [8+2-9:0]t;
wire [8:0] c_init; 
wire [8:0] c_final;

assign a = in_1 + in_2;
assign a_mul_3 = {a,1'b0} + a;
assign t = a_mul_3[10:9];
assign c_init = a - ({t,8'h00} - {t,2'b00} - t);

assign c_final = (c_init[8] == 1)? c_init + 251 : c_init;

assign out = c_final[7:0];
assign o_done = i_start;
 
endmodule

