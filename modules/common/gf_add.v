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
module gf_add
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
  
assign out = in_1 ^ in_2;
 
endmodule

