/*
 * This file is testbench for H matrix generation.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module compute_SP_tb
#(

    parameter PARAMETER_SET = "L1",
    
    parameter TYPE = "S",

    parameter M  =  (PARAMETER_SET == "L1")? 230:
                    (PARAMETER_SET == "L2")? 352:
                    (PARAMETER_SET == "L3")? 480:
                                             8,

    parameter WEIGHT =  (PARAMETER_SET == "L1")? 79:
                        (PARAMETER_SET == "L2")? 120:
                        (PARAMETER_SET == "L3")? 150:
                                                    8,
                                                            
    parameter D =   (PARAMETER_SET == "L1")? 1:
                    (PARAMETER_SET == "L2")? 2:
                    (PARAMETER_SET == "L3")? 2:
                                            1,
    parameter DEPTH_Q_FP = (TYPE == "S")? M/D : WEIGHT/D 

    
    // parameter PAR_WD = W*8/D, 
    // parameter PAR_MD = M*8/D, 

    // parameter N_GF = 4,
    // parameter WIDTH = 8*N_GF,


    // parameter PAR_WD_WIDTH =  PAR_WD + (WIDTH - PAR_WD%WIDTH)%WIDTH,
    // parameter PAR_MD_WIDTH =  PAR_MD + (WIDTH - PAR_MD%WIDTH)%WIDTH
    
    
)(

);



reg                                   i_clk = 0;
reg                                   i_rst;
reg                                   i_start;

wire   [8-1:0]                         i_x;
wire  [`CLOG2(M)-1:0]         o_x_addr;
wire                               o_x_rd;

wire   [8-1:0]                         i_q_fp;
wire   [`CLOG2(DEPTH_Q_FP+1)-1:0]    o_q_fp_addr;
wire                               o_q_fp_rd;


wire  [8-1:0]                     o_sp;
reg   [`CLOG2(M):0]       i_sp_addr;
reg                                   i_sp_rd = 0;



wire                         o_done;

compute_SP #(.PARAMETER_SET(PARAMETER_SET), .WEIGHT(WEIGHT), .D(D), .TYPE(TYPE))
COMP_SP 
(
.i_clk(i_clk),      
.i_rst(i_rst),
.i_start(i_start),

.i_x(i_x),
.o_x_addr(o_x_addr),
.o_x_rd(o_x_rd),

.i_q_fp(i_q_fp),
.o_q_fp_addr(o_q_fp_addr),
.o_q_fp_rd(o_q_fp_rd),

.o_sp(o_sp),
.i_sp_addr(i_sp_addr),
.i_sp_rd(i_sp_rd),


.o_done(o_done)
);


integer start_time, end_time;
initial 
begin
    i_rst <= 1;
    i_start <= 0;

    #100

    i_rst <= 0;
    
    #10
    i_start <= 1;
    start_time = $time;
    #10
    i_start <= 0;

    #100



    @(posedge o_done)
    end_time = $time;

    $display("Time taken to Compute SV =", (end_time-start_time-5)/10 );
    
    
    #100
    $finish;

end

always #5 i_clk = ! i_clk;


mem_single #(.WIDTH(8), .DEPTH(M), .FILE("x_L1.mem")) 
 X_val
 (
 .clock(i_clk),
 .data(0),
 .address(o_x_rd? o_x_addr: 0),
 .wr_en(0),
 .q(i_x)
 );

parameter FILE_SQ = (TYPE == "S")? "f_poly_L1.mem" : "Q_L1.mem";

mem_single #(.WIDTH(8), .DEPTH(DEPTH_Q_FP+1), .FILE(FILE_SQ)) 
 Q_val
 (
 .clock(i_clk),
 .data(0),
 .address(o_q_fp_rd? o_q_fp_addr: 0),
 .wr_en(0),
 .q(i_q_fp)
 );
 
// mem_single #(.WIDTH(8), .DEPTH(M+1), .FILE("f_poly_L1.mem"))
// F_POLY_MEM 
// (
//   .clock(i_clk),
//   .data(0),
//   .address(o_q_rd? o_q_addr: 0),
//   .wr_en(0),
//   .q(i_q)

// );

endmodule