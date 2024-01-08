/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/


module p251_add
#(
   parameter REG_IN = 1,
   parameter REG_OUT = 1
)
(
    input i_clk, // for potential regs we may add later
    input i_start,
    input [7:0] in_1,
    input [7:0] in_2,
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

assign a_reg = in_1_reg + in_2_reg;


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

assign out = c_final[7:0];
// assign o_done = i_start;
 
endmodule

