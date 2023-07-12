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
 *
*/
module p251_mul_red
#(
//    parameter REG_IN = 1,
//    parameter REG_OUT = 1
)
(
    input i_clk, // for potential regs we may add later
    input i_start,
    input [15:0] i_a,
    output [7:0] o_c,
    output o_done
    );
  
wire [15:0] a_reg;  
wire [15+8:0] a_mul_256;
wire [15+2:0] a_mul_4;
wire [15+1:0] a_mul_2;

wire [15+8+2:0] a_mul_262;

wire [9:0] a_s16;

wire [9+8:0] a_s16_mul_256;
wire [9+2:0] a_s16_mul_4;

wire [9+8:0] a_s16_mul_251;

wire [8:0] c_temp;

//always@(posedge i_clk) 
//begin
//     a_reg <= i_a;
//end

assign a_reg = i_a;

assign a_mul_256 = {a_reg,8'h00};
assign a_mul_4 = {a_reg,2'b00};
assign a_mul_2 = {a_reg,1'b0};

assign a_mul_262 = a_mul_256 + a_mul_4 + a_mul_2;

assign a_s16 = a_mul_262[15+8+2:16];

assign a_s16_mul_256 = {a_s16,8'h00};
assign a_s16_mul_4 = {a_s16,2'b00};

assign a_s16_mul_251 = a_s16_mul_256 - a_s16_mul_4 - a_s16;

assign c_temp = a_reg - a_s16_mul_251;


assign o_c = (c_temp[8] == 1)? c_temp + 251 : c_temp;

assign o_done = i_start;
 
endmodule

