`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/26/2023 02:51:47 PM
// Design Name: 
// Module Name: gf_mul_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module evaluation_tb
#(
    
     parameter FIELD = "P251",
//    parameter FIELD = "GF256",
    
    
    parameter PARAMETER_SET = "L5",
    parameter M  =  (PARAMETER_SET == "L1")? 230:
                    (PARAMETER_SET == "L3")? 352:
                    (PARAMETER_SET == "L5")? 480:
                                             230,
    parameter T =   (PARAMETER_SET == "L5")? 4:
                                             3,
                                             
    parameter D_SPLIT =   (PARAMETER_SET == "L1")? 1:
                                                    2                                        
    
    
)(

    );
    
reg i_clk = 0;
reg i_rst = 0;
reg i_start = 0;
reg [32*T-1:0] i_r;
wire [7:0] i_q;
wire [`CLOG2(M)-1:0] o_q_addr;
wire [32*T-1:0] o_eval;
wire o_done;

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

evaluate
#(
.FIELD(FIELD),
.PARAMETER_SET(PARAMETER_SET),
.M(M/D_SPLIT),
.T(T)
)
DUT
(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_r(i_r),
    .i_q(i_q),
    .o_q_addr(o_q_addr),
    .i_start(i_start),
    .o_eval(o_eval),

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

    .o_done(o_done)
);
 
`ifdef GF32_MUL_SHARED
    if (FIELD == "GF256") begin
        gf_mul_32
        GF32_MUL
        (
            .i_clk(i_clk),
            .i_x(o_x_mul),
            .i_y(o_y_mul),
            .i_start(o_start_mul),
            .o_o(i_o_mul),
            .o_done(i_done_mul)
        );
    end
    else begin
        gf251_mul_32
        GF32_MUL
        (
            .i_clk(i_clk),
            .i_x(o_x_mul),
            .i_y(o_y_mul),
            .i_start(o_start_mul),
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
                    .i_start(o_start_add), 
                    .in_1(o_in_1_add[32*k+32-1:32*k]), 
                    .in_2(o_in_2_add[32*k+32-1:32*k]),
                    .o_done(i_done_add[k]), 
                    .out(i_add_out[32*k+32-1:32*k]) 
                );
             end
             else begin
                gf251_add_32 
                GF32_ADD 
                (
                    .i_clk(i_clk), 
                    .i_start(o_start_add), 
                    .in_1(o_in_1_add[32*k+32-1:32*k]), 
                    .in_2(o_in_2_add[32*k+32-1:32*k]),
                    .o_done(i_done_add[k]), 
                    .out(i_add_out[32*k+32-1:32*k]) 
                );
             end
        end
    endgenerate
`endif


 integer start_time;
 initial
 begin
 
     i_rst <= 1;
    
     #100
        
     i_rst <= 0;
     i_start <= 0;
     i_r <= 0;
     #100
     i_start <= 1;
     start_time = $time;
     i_r  <= {32'h12345678, 32'h33223322, 32'h22222222};
     
     #10 
     i_start <= 0;

     @(posedge o_done)
     $display("Total Clock Cycles taken for Evaluation =", ($time-start_time-5)/10);
     #100
     
     $finish;
 
 end
 
 always #5 i_clk = ~i_clk;


mem_single #(.WIDTH(8), .DEPTH(M), .FILE("S_L1.mem")) 
 Q_values
 (
 .clock(i_clk),
 .data(0),
 .address(o_q_addr),
 .wr_en(0),
 .q(i_q)
 );
 
endmodule
