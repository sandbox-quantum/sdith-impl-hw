/*
 * This file is SDitH KeyGen module.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/

(* use_dsp = "no" *) module p251_mul
#(
    parameter REG_IN = 1,
    parameter REG_OUT = 1
)
(
    input clk,
    input start,
    input [7:0] in_1,
    input [7:0] in_2,
    output [7:0] out,
    output done
    );


reg done_reg_1, done_reg_2;

// reg [7:0] in_1_reg;
// reg [7:0] in_2_reg;
// generate
// if (REG_IN == 1) begin
//     always@(posedge clk)
//     begin
//         in_1_reg <= in_1;
//         in_2_reg <= in_2;
//         done_reg_1 <= start;
//     end
// end
// else begin
//     always@(in_1, in_2, start)
//     begin
//         in_1_reg <= in_1;
//         in_2_reg <= in_2;
//         done_reg_1 <= start;
//     end
// end
// endgenerate

wire [15:0] mul;
assign mul = in_1 * in_2;

reg [15:0] mul_reg;
generate
if (REG_IN == 1) begin
    always@(posedge clk)
    begin
        mul_reg <= mul;
        done_reg_1 <= start;
    end
end
else begin
    always@(mul, start)
    begin
        mul_reg <= mul;
        done_reg_1 <= start;
    end
end
endgenerate

wire [7:0] red;
wire red_done;
p251_mul_red
RED
(
    .i_clk(i_clk),
    .i_a(mul_reg),
    .i_start(done_reg_1),
    .o_c(red),
    .o_done(red_done)
);

reg [7:0] red_reg;
generate
if (REG_OUT == 1) begin
    always@(posedge clk)
    begin
        red_reg <= red;
        done_reg_2 <= red_done;
    end
end
else begin
    always@(red, red_done)
    begin
        red_reg <= red;
        done_reg_2 <= red_done;
    end
end
endgenerate

assign out = red_reg;
assign done = done_reg_2;

endmodule

