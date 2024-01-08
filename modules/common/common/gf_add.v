/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
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
//    output [WIDTH-1:0] out,
    output reg o_done
    );
  
reg [WIDTH-1:0] in_1_reg, in_2_reg;
wire [WIDTH-1:0] out_reg;
reg done_reg;

generate
    if (REG_IN == 1) begin
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
    if (REG_OUT == 1) begin
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

//always@(in_1,in_2)
//begin
//    out <= in_1 ^ in_2;
//end
//assign out = in_1 ^ in_2;
endmodule

