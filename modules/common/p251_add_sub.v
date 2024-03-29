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
module p251_add_sub
#(
   parameter REG_IN = 0,
   parameter REG_MID = 0,
   parameter REG_OUT = 0
)
(
    input i_clk, // for potential regs we may add later
    input i_start,
    input [7:0] in_1,
    input [7:0] in_2,
    input i_add_sub,
    output [7:0] out,
    output reg o_done
    );
  
reg [8:0] a;
wire [8+2:0]a_mul_3;
wire [8+2-9:0]t;
wire [8:0] c_init; 
wire [8:0] c_final;


reg [7:0] in_1_reg, in_2_reg;
wire [8:0] a_reg;
reg done_reg;

generate
    if (REG_IN) begin
        always@(posedge i_clk)
        begin
            in_1_reg <= in_1;
            in_2_reg <= in_2;
            done_reg <= i_start;
        end
    end
    else begin
        always@(*)
        begin
            in_1_reg <= in_1;
            in_2_reg <= in_2;
            done_reg <= i_start;
        end
    end
endgenerate

assign a_reg = (i_add_sub == 1)? in_1_reg - in_2_reg : in_1_reg + in_2_reg;


generate
    if (REG_OUT) begin
        always@(posedge i_clk)
        begin
            a <= a_reg;
            o_done <= done_reg;
        end
    end
    else begin
        always@(*)
        begin
            a <= a_reg;
            o_done <= done_reg;
        end
    end
endgenerate


assign a_mul_3 = {a,1'b0} + a;
assign t = a_mul_3[10:9];
assign c_init = a - ({t,8'h00} - {t,2'b00} - t);


assign c_final = (c_init[8] == 1)? c_init + 251 : c_init;

wire [7:0] c_final_sub;

assign c_final_sub = (a[8] == 1)? a + 251 : a;


assign out = (i_add_sub == 1)?  c_final_sub :c_final[7:0];



// assign o_done = i_start;
 
endmodule

