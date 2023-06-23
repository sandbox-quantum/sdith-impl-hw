/*
 * This file is ComputeS which is part of SampleWitness.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module samplewitness 
#(

    parameter PARAMETER_SET = "L1",
    
    parameter LAMBDA =  (PARAMETER_SET == "L1")? 128:
                        (PARAMETER_SET == "L2")? 192:
                        (PARAMETER_SET == "L3")? 256:
                                                 128,
                                                    
    parameter M =  (PARAMETER_SET == "L1")? 230:
                        (PARAMETER_SET == "L2")? 352:
                        (PARAMETER_SET == "L3")? 480:
                                                 230,

    parameter WEIGHT =  (PARAMETER_SET == "L1")? 79:
                        (PARAMETER_SET == "L2")? 120:
                        (PARAMETER_SET == "L3")? 150:
                                                 79,

    parameter D =   (PARAMETER_SET == "L1")? 1:
                        (PARAMETER_SET == "L2")? 2:
                        (PARAMETER_SET == "L3")? 2:
                                                 1

)(
    input                                   i_clk,
    input                                   i_rst,
    input                                   i_start,

    input   [32-1:0]                        i_seed_wit,
    output  reg [`CLOG2(LAMBDA/32)-1:0]     i_seed_wit_addr,
    output  reg                             i_seed_wr_en,


    output  [7:0]                           o_q,
    input   [`CLOG2(WEIGHT/D + 1):0]        i_q_addr,
    input                                   i_q_rd,

    output  [7:0]                           o_s,
    input   [`CLOG2(M/D):0]                 i_s_addr,
    input                                   i_s_rd,

    output  [7:0]                           o_p,
    input   [`CLOG2(WEIGHT/D):0]            i_p_addr,
    input                                   i_p_rd,

    output   reg                            o_done
);



//==================X-mem======================

wire [7:0] q0_x, q1_x;
mem_dual #(.WIDTH(8), .DEPTH(M), .FILE("x_L1.mem")) 
 X_MEM
 (
 .clock(i_clk),
 .data_0(0),
 .data_1(0),
 .address_0(p_x_rd? p_x_addr: 0),
 .address_1(s_x_rd? s_x_addr: 0),
 .wren_0(0),
 .wren_1(0),
 .q_0(q0_x),
 .q_1(q1_x)
 );
//================================================



mem_single #(.WIDTH(8), .DEPTH(WEIGHT/D), .FILE("NON_ZERO_POS_L1.mem")) 
 NON_ZERO_POSITIONS
 (
 .clock(i_clk),
 .data(0),
 .address(q_non_zero_pos_rd? q_non_zero_pos_addr: 0),
 .wr_en(0),
 .q(q_non_zero_pos)
 );

//==================ComputeQ======================
reg start_q;
wire done_q;
wire [7:0] q_int;
wire   [`CLOG2(WEIGHT/D + 1):0] q_addr_int;
wire  [7:0]                   q_non_zero_pos;
wire  [`CLOG2(WEIGHT)-1:0]    q_non_zero_pos_addr;
wire                          q_non_zero_pos_rd;

compute_Q #(.PARAMETER_SET(PARAMETER_SET), .WEIGHT(WEIGHT), .D(D))
COMP_Q 
(
.i_clk(i_clk),      
.i_rst(i_rst),
.i_start(start_q),
.i_non_zero_pos(q_non_zero_pos),
.o_non_zero_pos_addr(q_non_zero_pos_addr),
.o_non_zero_pos_rd(q_non_zero_pos_rd),

.o_q(q_int),
.i_q_addr(q_addr_int),

.i_q_rd(i_q_rd || p_q_rd),
.o_done(done_q)
);

assign o_q = q_int;
assign q_addr_int = i_q_rd? i_q_addr:
                    p_q_rd? p_addr_q: 
                            p_addr_q;
//===================================================


//==================ComputeP=========================
wire start_p;
wire [7:0] p_x;
wire [`CLOG2(M)-1:0] p_x_addr;
wire p_x_rd;
wire [`CLOG2(WEIGHT/D + 1):0] p_addr_q;
wire p_q_rd;
wire done_p;

assign start_p = done_q;
assign p_x = q0_x;

compute_SP #(.PARAMETER_SET(PARAMETER_SET), .M(M), .WEIGHT(WEIGHT), .D(D), .TYPE("P"))
COMP_P 
(
.i_clk(i_clk),      
.i_rst(i_rst),
.i_start(start_p),

.i_x(p_x),
.o_x_addr(p_x_addr),
.o_x_rd(p_x_rd),

.i_q_fp(q_int),
.o_q_fp_addr(p_addr_q),
.o_q_fp_rd(p_q_rd),

.o_sp(o_p),
.i_sp_addr(i_p_addr),
.i_sp_rd(i_p_rd),


.o_done(done_p)
);
//===================================================


//==================ComputeS=========================
parameter FILE_FP = (PARAMETER_SET == "L1")?    "f_poly_L1.mem" :
                    (PARAMETER_SET == "L2")?    "f_poly_L1.mem" :
                    (PARAMETER_SET == "L3")?    "f_poly_L1.mem" :
                                                "f_poly_L1.mem";

wire [7:0] f_poly;

mem_single #(.WIDTH(8), .DEPTH(M/D+1), .FILE(FILE_FP)) 
 F_POLY_MEM
 (
 .clock(i_clk),
 .data(0),
 .address(s_addr_fp),
 .wr_en(0),
 .q(f_poly)
 );

reg start_s;
wire [7:0] s_x;
wire [`CLOG2(M)-1:0] s_x_addr;
wire p_x_rd;
wire [`CLOG2(WEIGHT/D + 1):0] s_addr_fp;
wire s_fp_rd;
wire done_s;

assign s_x = q1_x;

compute_SP #(.PARAMETER_SET(PARAMETER_SET), .M(M), .WEIGHT(WEIGHT), .D(D), .TYPE("S"))
COMP_S 
(
.i_clk(i_clk),      
.i_rst(i_rst),
.i_start(start_s),

.i_x(s_x),
.o_x_addr(s_x_addr),
.o_x_rd(s_x_rd),

.i_q_fp(f_poly),
.o_q_fp_addr(s_addr_fp),
.o_q_fp_rd(s_fp_rd),

.o_sp(o_s),
.i_sp_addr(i_s_addr),
.i_sp_rd(i_s_rd),


.o_done(done_s)
);
//===================================================

reg [3:0] state;
parameter s_wait_start      =0;
parameter s_sampling        =1;
parameter s_start_QSP       =2;
parameter s_done            =3;

always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        o_done <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            o_done <= 0;
            if (i_start) begin
                state <= s_sampling;
            end
        end

        else if (state == s_sampling) begin
            state <= s_start_QSP;
            o_done <= 0;
        end

        else if (state == s_start_QSP) begin
            o_done <= 0;
            if (done_s) begin
                state <= s_done;
            end
        end

        else if (state == s_done) begin
            state <= s_wait_start;
            o_done <= 1;

        end
    end
end

always@(state, i_start)
begin

    case(state)
        
    s_wait_start: begin
       start_s <= 0;
        start_q <= 0;
    end
    
    s_sampling: begin
        start_s <= 1;
        start_q <= 1;
    end

    s_start_QSP: begin
        start_s <= 0;
        start_q <= 0;
    end

    s_done: begin
        start_s <= 0;
        start_q <= 0;
    end
     
     default: begin
        start_s <= 0;
        start_q <= 0;
    end
    
    endcase
    
end

endmodule