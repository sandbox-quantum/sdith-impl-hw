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
   parameter WIDTH = 8,
   parameter REG_IN = 1,
   parameter REG_OUT = 1
)
(
    input i_clk, // for potential regs we may add later
    input i_start,
    input [WIDTH-1:0] in_1,
    input [WIDTH-1:0] in_2,
    output reg [WIDTH-1:0] out,
    output reg o_done
    );
  
reg [WIDTH-1:0] in_1_reg, in_2_reg;
wire [WIDTH-1:0] out_reg;
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


assign out_reg = in_1_reg ^ in_2_reg;
 
generate
    if (REG_OUT) begin
        always@(posedge i_clk)
        begin
            out <= out_reg;
            o_done <= done_reg;

        end
    end
    else begin
        always@(*)
        begin
            out <= out_reg;
            o_done <= done_reg;
        end
    end
endgenerate

endmodule

