/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module compute_plain_broadcast_top_tb
#(
//    parameter FIELD         = "P251",
    parameter FIELD         = "GF256",
    parameter PARAMETER_SET = "L1",
    
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
    
    parameter TEST_SET = 2

    
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

//wire [T*8-1:0]                                  o_r;
//wire [`CLOG2(TAU*D_SPLIT)-1:0]                  i_r_addr;
//wire                                            i_r_rd;

//wire [T*8-1:0]                                  o_eps;
//wire [`CLOG2(TAU*D_SPLIT)-1:0]                  i_eps_addr;
//wire                                            i_eps_rd;
wire                                o_done;


//wire   [32-1:0]                                    i_share;

reg [T*32-1:0]                                  i_a;
reg [T*32-1:0]                                  i_b;
reg [T*32-1:0]                                  i_r;
// wire [`CLOG2(TAU*D_SPLIT)-1:0]                  o_r_addr;
// wire                                            o_r_rd;

reg [T*32-1:0]                                  i_eps;
// wire [`CLOG2(TAU*D_SPLIT)-1:0]                  o_eps_addr;
// wire                                            o_eps_rd;

wire [32*T-1:0]                                 o_alpha;
wire [32*T-1:0]                                 o_beta;

compute_plain_broadcast_top #(.PARAMETER_SET(PARAMETER_SET), .FIELD(FIELD))
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


.o_alpha(o_alpha),
.o_beta(o_beta),

// .o_eps_addr(o_eps_addr),
// .o_eps_rd(o_eps_rd),


.o_done(o_done)
);



parameter VCD_NAME = (TEST_SET == 0)? "compute_plain_broadcast_0.vcd":
                     (TEST_SET == 1)? "compute_plain_broadcast_1.vcd":
                                      "compute_plain_broadcast_2.vcd";

parameter INPUT_NAME = (TEST_SET == 0)? "compute_plain_broadcast_in_0.txt":
                     (TEST_SET == 1)? "compute_plain_broadcast_in_1.txt":
                                      "compute_plain_broadcast_in_2.txt";

integer start_time;
integer end_time;
integer f;

initial 
begin
    i_rst <= 1;
    i_start <= 0;
    
    $dumpfile(VCD_NAME);
    $dumpvars(1, compute_plain_broadcast_top_tb);
    
    #100

    i_rst <= 0;

    
    #10
    i_start <= 1;
//    i_r <= {32'h12345678, 32'h33223322, 32'h22222222};
//    i_eps <= {32'h00000001, 32'h00000002, 32'h00000003};
//    i_a <= {32'h00000001, 32'h00000001, 32'h00000001};
//    i_b <= {32'h00000001, 32'h00000001, 32'h00000001};
    
    if (TEST_SET == 0) begin
        i_r     <= 96'hb37ca38928989129b37d09fb;
        i_eps   <= 96'hcbbe2529faf8883d4ec90832;
        i_a     <= 96'h6c9696f432cd96d394298cf5;
        i_b     <= 96'hc45476ecc8d39d96850866cb;
    end
    else if (TEST_SET == 1) begin
        i_r     <= 96'h781590a220fe140e71c6da13;
        i_eps   <= 96'h77d856186bde44c3ba8504d5;
        i_a     <= 96'h288c1b347fade6d354a78ac8;
        i_b     <= 96'hf9000696f4625eca57a82c4b;
    end
    else begin
        i_r     <= 96'h01ac0e4b72e51961d2bb6fe5;
        i_eps   <= 96'h4562e7cb2e57ace77b41949f;
        i_a     <= 96'h711c27247a711d0abd8c81b3;
        i_b     <= 96'h53f9d79dbe40013312cd10f5;
    end
    
    start_time = $time;
    #10
    i_start <= 0;

    #100
    
    @(posedge o_done)
    end_time = $time;

    $display("Clock Cycles taken for compute plain broadcast =", (end_time-start_time-5)/10 );
    
    f = $fopen(INPUT_NAME, "w");
    $fwrite(f, "\n i_r  =", i_r);
    $fwrite(f, "\n i_eps =", i_eps);
    $fwrite(f, "\n i_a  =", i_a);
    $fwrite(f, "\n i_b  =", i_b);
    $fclose(f);
    
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
 .address(o_q_addr%M),
 .wr_en(0),
 .q(i_q)
 );

 mem_single #(.WIDTH(8), .DEPTH(M), .FILE("S_L1.mem")) 
 S_values
 (
 .clock(i_clk),
 .data(0),
 .address(o_s_addr%M),
 .wr_en(0),
 .q(i_s)
 );



always #5 i_clk = ! i_clk;

 

endmodule