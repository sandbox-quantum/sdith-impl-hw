/*
 * This file is testbench for KeyGen module.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module compute_plain_broadcast_tb
#(
    parameter FIELD         = "P251",
//    parameter FIELD         = "GF256",
    parameter PARAMETER_SET = "L5",
    
    parameter LAMBDA =   (PARAMETER_SET == "L1")? 128:
                            (PARAMETER_SET == "L3")? 192:
                            (PARAMETER_SET == "L5")? 256:
                                                     128,



    parameter D_SPLIT = (PARAMETER_SET == "L1")? 1:
                        (PARAMETER_SET == "L3")? 2:
                        (PARAMETER_SET == "L5")? 2:
                                                 1,

    parameter M  =  (PARAMETER_SET == "L1")? 230:
                    (PARAMETER_SET == "L3")? 352:
                    (PARAMETER_SET == "L5")? 480:
                                             230,
                                             
    parameter  K =  (PARAMETER_SET == "L1")? 126:
                    (PARAMETER_SET == "L3")? 193:
                    (PARAMETER_SET == "L5")? 278:
                                               1,

    parameter TAU = (PARAMETER_SET == "L1")? 17:
                    (PARAMETER_SET == "L3")? 17:
                    (PARAMETER_SET == "L5")? 17:
                                             17,
    
    parameter T =   (PARAMETER_SET == "L5")? 4:
                                             3, 

    parameter MAT_ROW_SIZE_BYTES = (PARAMETER_SET == "L1")? 104:
                                   (PARAMETER_SET == "L3")? 159:
                                   (PARAMETER_SET == "L5")? 202:
                                                            104,
                                                            
    parameter MAT_COL_SIZE_BYTES  =(PARAMETER_SET == "L1")? 126:
                                   (PARAMETER_SET == "L3")? 193:
                                   (PARAMETER_SET == "L5")? 278:
                                                            126,



    parameter VEC_S_WEIGHT =    (PARAMETER_SET == "L1")? 126:
                                (PARAMETER_SET == "L3")? 193:
                                (PARAMETER_SET == "L5")? 278:
                                                         8,

    parameter VEC_SIZE_BYTES = (PARAMETER_SET == "L1")? 126:
                               (PARAMETER_SET == "L3")? 193:
                               (PARAMETER_SET == "L5")? 278:
                                                        8,
                                                        
    parameter MAT_SIZE_BYTES = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES,
    

    parameter MRS_BITS = MAT_ROW_SIZE_BYTES*8,
    parameter MCS_BITS = MAT_COL_SIZE_BYTES*8,
    
    parameter MAT_ROW_SIZE = MRS_BITS + (PROC_SIZE - MRS_BITS%PROC_SIZE)%PROC_SIZE,
    parameter MAT_COL_SIZE = MCS_BITS + (PROC_SIZE - MCS_BITS%PROC_SIZE)%PROC_SIZE,
    parameter MAT_SIZE = MAT_ROW_SIZE*MAT_COL_SIZE_BYTES,
    
    parameter D_HYPERCUBE = 8,
    
    parameter N_GF = 4,
    parameter PROC_SIZE = N_GF*8,
    parameter WIDTH = PROC_SIZE,
    
    parameter Y_SIZE = (M-K)*8,
    parameter Y_SIZE_ADJ = Y_SIZE + (WIDTH - Y_SIZE%WIDTH)%WIDTH,

    parameter SIZE_OF_R     = TAU*T*D_SPLIT*8,
    parameter SIZE_OF_EPS   = TAU*T*D_SPLIT*8,
    
    parameter FILE_MEM_INIT = "Y_L1.mem"

    
)(

);

reg                                 i_clk = 0;
reg                                 i_rst;
reg                                 i_start;

wire  [7:0]                                       i_q;
wire [`CLOG2(M)-1:0]                              o_q_addr;
wire                                              o_q_rd;

wire  [7:0]                                       i_s;
wire [`CLOG2(M)-1:0]                              o_s_addr;
wire                                              o_s_rd;

wire [T*8-1:0]                                  o_r;
wire [`CLOG2(TAU*D_SPLIT)-1:0]                  i_r_addr;
wire                                            i_r_rd;

wire [T*8-1:0]                                  o_eps;
wire [`CLOG2(TAU*D_SPLIT)-1:0]                  i_eps_addr;
wire                                            i_eps_rd;
wire                                o_done;


wire   [32-1:0]                                    i_share;

reg [T*32-1:0]                                  i_a;
reg [T*32-1:0]                                  i_b;
reg [T*32-1:0]                                  i_r;
// wire [`CLOG2(TAU*D_SPLIT)-1:0]                  o_r_addr;
// wire                                            o_r_rd;

reg [T*32-1:0]                                  i_eps;
// wire [`CLOG2(TAU*D_SPLIT)-1:0]                  o_eps_addr;
// wire                                            o_eps_rd;

wire                                            o_start_evaluate;
wire  [7:0]                                     o_q_s;
wire [`CLOG2(M)-1:0]                            i_q_s_addr;
wire                                            i_q_s_rd;
wire [32*T-1:0]                                 o_r_eps;
wire [32*T-1:0]                                 i_evaluate_out;
wire                                            i_done_evaluate;

wire                                            o_start_mul32;
wire [31:0]                                     o_x_mul32;
wire [31:0]                                     o_y_mul32;
wire  [31:0]                                    i_o_mul32;
wire                                            i_done_mul32;

wire                                            o_start_add32;
wire [32*T-1:0]                                 o_in_1_add32;
wire [32*T-1:0]                                 o_in_2_add32;
wire [32*T-1:0]                                 i_add_out_add32;
wire                                            i_done_add32;

`ifdef GF32_MUL_SHARED
    wire o_start_mul;
    wire [31:0] o_x_mul;
    wire [31:0] o_y_mul;
    wire  [31:0] i_o_mul;
    wire  i_done_mul;
`endif 

`ifdef GF8_MUL_SHARED
    wire o_start_mul_gf8;
    wire [32*T-1:0] o_in_1_mul_gf8;
    wire [7:0] o_in_2_mul_gf8;
    wire [32*T-1:0] i_out_mul_gf8;
    wire [32*T/8 -1:0] i_done_mul_gf8;
`endif 

`ifdef GF32_ADD_SHARED
    wire o_start_add;
    wire [32*T-1:0] o_in_1_add;
    wire [32*T-1:0] o_in_2_add;
    wire [32*T-1:0] i_add_out;
    wire [T-1:0] i_done_add;
`endif 


compute_plain_broadcast #(.PARAMETER_SET(PARAMETER_SET), .FIELD(FIELD), .FILE_MEM_INIT(FILE_MEM_INIT))
DUT 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(i_start),

.i_q(i_q),
.o_q_addr(o_q_addr),
.o_q_rd(o_q_rd),

.i_s(i_s),
.o_s_addr(o_s_addr),
.o_s_rd(o_s_rd),

.i_a(i_a),
.i_b(i_b),

.i_r(i_r),
// .o_r_addr(o_r_addr),
// .o_r_rd(o_r_rd),

.i_eps(i_eps),
// .o_eps_addr(o_eps_addr),
// .o_eps_rd(o_eps_rd),

.o_start_mul32(o_start_mul32),
.o_x_mul32(o_x_mul32),
.o_y_mul32(o_y_mul32),
.i_o_mul32(i_o_mul32),
.i_done_mul32(i_done_mul32),

.o_start_add32(o_start_add32),
.o_in_1_add32(o_in_1_add32),
.o_in_2_add32(o_in_2_add32),
.i_add_out_add32(i_add_out_add32),
.i_done_add32(i_done_add32),

.o_start_evaluate(o_start_evaluate),
.o_q_s(o_q_s),
.i_q_s_addr(i_q_s_addr),
.i_q_s_rd(i_q_s_rd),
.o_r_eps(o_r_eps),
.i_evaluate_out(i_evaluate_out),
.i_done_evaluate(i_done_evaluate),

.o_done(o_done)
);



evaluate
#(
.FIELD(FIELD),
.PARAMETER_SET(PARAMETER_SET),
.M(M/D_SPLIT),
.T(T)
)
EVALUATE_QS
(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_r(o_r_eps),
    .i_q(o_q_s),
    .o_q_rd(i_q_s_rd),
    .o_q_addr(i_q_s_addr),
    .i_start(o_start_evaluate),
    .o_eval(i_evaluate_out),

    `ifdef GF32_MUL_SHARED
        .o_start_mul(o_start_mul),
        .o_x_mul(o_x_mul),
        .o_y_mul(o_y_mul),
        .i_o_mul(i_o_mul),
        .i_done_mul(i_done_mul),
    `endif 

    `ifdef GF8_MUL_SHARED
        .o_start_mul_gf8(o_start_mul_gf8),
        .o_in_1_mul_gf8(o_in_1_mul_gf8),
        .o_in_2_mul_gf8(o_in_2_mul_gf8),
        .i_out_mul_gf8(i_out_mul_gf8),
        .i_done_mul_gf8(i_done_mul_gf8),
    `endif 

    `ifdef GF32_ADD_SHARED
        .o_start_add(o_start_add),
        .o_in_1_add(o_in_1_add),
        .o_in_2_add(o_in_2_add),
        .i_add_out(i_add_out),
        .i_done_add(i_done_add),
    `endif 

    .o_done(i_done_evaluate)
);
 
assign i_o_mul32 = i_o_mul;
assign i_done_mul32 = i_done_mul;

`ifdef GF32_MUL_SHARED
    if (FIELD == "GF256") begin
        gf_mul_32
        GF32_MUL
        (
            .i_clk(i_clk),
            .i_x(o_start_mul32 ? o_x_mul32 : o_x_mul),
            .i_y(o_start_mul32 ? o_y_mul32 : o_y_mul),
            .i_start(o_start_mul | o_start_mul32),
            .o_o(i_o_mul),
            .o_done(i_done_mul)
        );
    end
    else begin
        gf251_mul_32
        GF32_MUL
        (
            .i_clk(i_clk),
            .i_x(o_start_mul32 ? o_x_mul32 : o_x_mul),
            .i_y(o_start_mul32 ? o_y_mul32 : o_y_mul),
            .i_start(o_start_mul | o_start_mul32),
            .o_o(i_o_mul),
            .o_done(i_done_mul)
        );
    end
`endif 

    wire o_start_mul_gf8;
    wire [32*T-1:0] o_in_1_mul_gf8;
    wire [32*T-1:0] o_in_2_mul_gf8;
    wire [32*T-1:0] i_out_mul_gf8;
    wire [32*T/8 -1:0] i_done_mul_gf8;

`ifdef GF8_MUL_SHARED
    genvar j;
    generate
        for(j=0; j< 32*T/8; j=j+1) begin
            if (FIELD == "GF256") begin
                gf_mul 
                #(
                    .REG_IN(1),
                    .REG_OUT(1)
                )
                GF_MUL_GF8
                (
                    .clk(i_clk),
                    .start(o_start_mul_gf8),
                    .in_1(o_in_1_mul_gf8[32*T-8*j-1:32*T-8*j-8]),
                    .in_2(o_in_2_mul_gf8),
                    .out(i_out_mul_gf8[32*T-8*j-1:32*T-8*j-8]),
                    .done(i_done_mul_gf8)
                );
            end
            else begin
                gf251_mul 
                #(
                    .REG_IN(0),
                    .REG_OUT(1)
                )
                GF_MUL_GF8
                (
                    .clk(i_clk),
                    .start(o_start_mul_gf8),
                    .in_1(o_in_1_mul_gf8[32*T-8*j-1:32*T-8*j-8]),
                    .in_2(o_in_2_mul_gf8),
                    .out(i_out_mul_gf8[32*T-8*j-1:32*T-8*j-8]),
                    .done(i_done_mul_gf8)
                );
            end
        end
    endgenerate
`endif 


assign i_add_out_add32 = i_add_out;
assign i_done_add32 = i_done_add[0];

`ifdef GF32_ADD_SHARED
    genvar k;
    generate
        for(k=0; k<T; k=k+1) begin
            if (FIELD == "GF256") begin
                gf_add 
                #(
                    .WIDTH(32),
                    .REG_IN(1),
                    .REG_OUT(1)
                )
                GF32_ADD 
                (
                    .i_clk(i_clk), 
                    .i_start(o_start_add32 | o_start_add), 
                    .in_1(o_start_add32 ? o_in_1_add32[32*k+32-1:32*k] : o_in_1_add[32*k+32-1:32*k]), 
                    .in_2(o_start_add32 ? o_in_2_add32[32*k+32-1:32*k] : o_in_2_add[32*k+32-1:32*k]),
                    .o_done(i_done_add[k]), 
                    .out(i_add_out[32*k+32-1:32*k]) 
                );
             end
             else begin
               gf251_add_32 
                GF32_ADD 
                (
                    .i_clk(i_clk), 
                    .i_start(o_start_add32 | o_start_add), 
                    .in_1(o_start_add32 ? o_in_1_add32[32*k+32-1:32*k] : o_in_1_add[32*k+32-1:32*k]), 
                    .in_2(o_start_add32 ? o_in_2_add32[32*k+32-1:32*k] : o_in_2_add[32*k+32-1:32*k]),
                    .o_done(i_done_add[k]), 
                    .out(i_add_out[32*k+32-1:32*k]) 
                );
             end
        end
    endgenerate
`endif

integer start_time;
integer end_time;

initial 
begin
    i_rst <= 1;
    i_start <= 0;

    #100

    i_rst <= 0;

    
    #10
    i_start <= 1;
    i_r <= {32'h12345678, 32'h33223322, 32'h22222222};
    i_eps <= {32'h00000001, 32'h00000002, 32'h00000003};
    i_a <= {32'h00000001, 32'h00000001, 32'h00000001};
    i_b <= {32'h00000001, 32'h00000001, 32'h00000001};
    start_time = $time;
    #10
    i_start <= 0;

    #100
    
    @(posedge o_done)
    end_time = $time;

    $display("Clock Cycles taken for compute plain broadcast =", (end_time-start_time-5)/10 );
    
    
    #100
    $finish;

end

//  always
//  begin
//      @(posedge o_done)
//     //  $writememb("HSA_L1.mem", DUT.MAT_VEC_MUL.RESULT_MEM.mem);
//  end

mem_single #(.WIDTH(8), .DEPTH(M), .FILE("S_L1.mem")) 
 Q_values
 (
 .clock(i_clk),
 .data(0),
 .address(o_q_addr),
 .wr_en(0),
 .q(i_q)
 );

 mem_single #(.WIDTH(8), .DEPTH(M), .FILE("S_L1.mem")) 
 S_values
 (
 .clock(i_clk),
 .data(0),
 .address(o_s_addr),
 .wr_en(0),
 .q(i_s)
 );



always #5 i_clk = ! i_clk;

 

endmodule