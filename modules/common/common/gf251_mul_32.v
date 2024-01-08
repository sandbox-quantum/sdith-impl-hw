/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/

//module gf251_mul_32
//#(
//    parameter REG_IN = 1,
//    parameter REG_OUT = 1
//)
//(
//    input i_clk,
//    input i_start,
//    input [31:0] i_x,
//    input [31:0] i_y,
//    output [31:0] o_o,
//    output o_done
//    );


//wire [15:0] x0;
//wire [15:0] x1;
//wire [15:0] y0;
//wire [15:0] y1;


//assign x0 = i_x[15:0];
//assign x1 = i_x[31:16];

//assign y0 = i_y[15:0];
//assign y1 = i_y[31:16];

//wire [31:0] x0y0;
//wire [31:0] x1y0;
//wire [16:0] x0plusy1;
//wire [16:0] x1plusy0;

//assign x0y0 = x0*y0;
//assign x1y1 = x1*y1;
//assign x0plusy1 = x0 + y1;
//assign x1plusy0 = x1 + y0;



//wire [31:0] x0y0_reg;
//wire [31:0] x1y1_reg;
//wire [16:0] x0plusy1_reg;
//wire [16:0] x1plusy0_reg;

//pipeline_reg_gen #(.WIDTH(32), .REG_STAGES(1))
//X0Y0_REG
//(
//    .i_clk(i_clk),
//    .i_data_in(x0y0),
//    .o_data_out(x0y0_reg)
//);

//pipeline_reg_gen #(.WIDTH(32), .REG_STAGES(1))
//X1Y1_REG
//(
//    .i_clk(i_clk),
//    .i_data_in(x1y1),
//    .o_data_out(x1y1_reg)
//);

//pipeline_reg_gen #(.WIDTH(17), .REG_STAGES(1))
//X1plusY0_REG
//(
//    .i_clk(i_clk),
//    .i_data_in(x0plusy1),
//    .o_data_out(x0plusy1_reg)
//);

//pipeline_reg_gen #(.WIDTH(17), .REG_STAGES(1))
//X0plusY1_REG
//(
//    .i_clk(i_clk),
//    .i_data_in(x1plusy0),
//    .o_data_out(x1plusy0_reg)
//);

//wire [33:0] x0plusy1_x_x1plusy0;
//wire [32:0] x0y0_plus_x1y1;

//assign x0plusy1_x_x1plusy0 = x0plusy1_reg*x1plusy0_reg;
//assign x0y0_plus_x1y1 = x0y0_reg + x1y1_reg;



//wire [31:0] x0y0_reg_reg;
//wire [31:0] x1y1_reg_reg;
//wire [16*2-1:0] x0plusy1_x_x1plusy0_reg;
//wire [32:0] x0y0_plus_x1y1_reg;

//pipeline_reg_gen #(.WIDTH(32), .REG_STAGES(1))
//X0Y0_REG_REG
//(
//    .i_clk(i_clk),
//    .i_data_in(x0y0_reg),
//    .o_data_out(x0y0_reg_reg)
//);

//pipeline_reg_gen #(.WIDTH(32), .REG_STAGES(1))
//X1Y1_REG_REG
//(
//    .i_clk(i_clk),
//    .i_data_in(x1y1_reg),
//    .o_data_out(x1y1_reg_reg)
//);

//pipeline_reg_gen #(.WIDTH(34), .REG_STAGES(1))
//X1plusY0_REG
//(
//    .i_clk(i_clk),
//    .i_data_in(x0plusy1_x_x1plusy0),
//    .o_data_out(x0plusy1_x_x1plusy0_reg)
//);

//pipeline_reg_gen #(.WIDTH(33), .REG_STAGES(1))
//X0plusY1_REG
//(
//    .i_clk(i_clk),
//    .i_data_in(x1plusy0),
//    .o_data_out(x0y0_plus_x1y1_reg)
//);


//endmodule



/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/


//`include "clog2.v"

module gf251_mul_32
# (
    A_WIDTH = 32,
    B_WIDTH = 32,
    MAX_AB = (A_WIDTH > B_WIDTH)? A_WIDTH : B_WIDTH
    )
    (
    input  i_clk,
    input  i_start,
    output o_done,
    
    input  [32-1:0] i_x,
    input  [32-1:0] i_y,

    output [32-1:0] o_o
    );
    

wire [63:0] mul_out_64;
wire done_mul_out_64;

karatsuba_mul
#(
.A_WIDTH(32),
.B_WIDTH(32)
)
MAIN_MULT
(
    .i_clk(i_clk),
    .i_x(i_x),
    .i_y(i_y),
    .i_start(i_start),
    .o_o(mul_out_64),
    .o_done(done_mul_out_64)
);


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
    .i_x(mul_out_64),
    .i_y(64'h0000000115041c34),
    .i_start(done_mul_out_64),
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

wire [63:0] a_reg;
pipeline_reg_gen #(.WIDTH(64), .REG_STAGES(8))
A_REG
(
    .i_clk(i_clk),
    .i_data_in(mul_out_64),
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

assign o_o = c_reg_reg[32]? c_plus_n_reg : c_reg_reg;
assign o_done = done_c_plus_n;

endmodule


