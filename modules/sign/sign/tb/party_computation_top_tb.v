/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module party_computation_top_tb
#(

    parameter FIELD = "GF256",
//    parameter FIELD = "P251",
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
    
    parameter TEST_SET = 0
    
)(

);

reg                                 i_clk = 0;
reg                                 i_rst;
reg                                 i_start;

wire  [7:0]                                       i_q;
wire [`CLOG2(M)-1:0]                              o_q_addr;
wire                                              o_q_rd;

//wire  [7:0]                                       i_s;
//wire [`CLOG2(M)-1:0]                              o_s_addr;
//wire                                              o_s_rd;

wire  [7:0]                                       i_p;
wire [`CLOG2(M)-1:0]                              o_p_addr;
wire                                              o_p_rd;

wire  [7:0]                                       i_f;
wire [`CLOG2(M)-1:0]                              o_f_addr;
wire                                              o_f_rd;




wire                                o_done;

reg [T*32-1:0]                                  i_minus_c;


reg [T*32-1:0]                                  i_a;
reg [T*32-1:0]                                  i_b;
reg [T*32-1:0]                                  i_r;
// wire [`CLOG2(TAU*D_SPLIT)-1:0]                  o_r_addr;
// wire                                            o_r_rd;

reg [T*32-1:0]                                  i_eps;

reg [T*32-1:0]                                  i_alpha_prime;
reg [T*32-1:0]                                  i_beta_prime;


wire [T*32-1:0]                                  o_alpha;
wire [T*32-1:0]                                  o_beta;
wire [T*32-1:0]                                  o_v;
// wire [`CLOG2(TAU*D_SPLIT)-1:0]                  o_eps_addr;
// wire                                            o_eps_rd;


wire [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0]             o_h_mat_addr;
wire [`CLOG2(M)-1:0]                              o_sa_addr;
wire [PROC_SIZE-1:0]                              i_h_mat;
wire [7:0]                                        i_sa;


party_computation_top 
#(
.FIELD(FIELD),
.PARAMETER_SET(PARAMETER_SET),
.M(M),
.T(T)
)
DUT 
(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_start(i_start),

    .i_q(i_q),
    .o_q_addr(o_q_addr),
    .o_q_rd(o_q_rd),

    //.i_s(i_s),
    //.o_s_addr(o_s_addr),
    //.o_s_rd(o_s_rd),

    .i_p(i_p),
    .o_p_addr(o_p_addr),
    .o_p_rd(o_p_rd),

    .i_f(i_f),
    .o_f_addr(o_f_addr),
    .o_f_rd(o_f_rd),

    .i_a(i_a),
    .i_b(i_b),

    .i_minus_c(i_minus_c),

    .i_r(i_r),
    // .o_r_addr(o_r_addr),
    // .o_r_rd(o_r_rd),

    .i_eps(i_eps),

    .i_alpha_prime(i_alpha_prime),
    .i_beta_prime(i_beta_prime),
    
    .o_alpha(o_alpha),
    .o_beta(o_beta),
    .o_v(o_v),
    // .o_eps_addr(o_eps_addr),
    // .o_eps_rd(o_eps_rd),


    .o_h_mat_addr(o_h_mat_addr),
    .o_sa_addr(o_sa_addr),
    .i_h_mat(i_h_mat),
    .i_sa(i_sa),


    .o_done(o_done)
);


parameter VCD_NAME = (TEST_SET == 0)? "party_computation_0.vcd":
                     (TEST_SET == 1)? "party_computation_1.vcd":
                                      "party_computation_2.vcd";


integer start_time;
integer end_time;

initial 
begin
    i_rst <= 1;
    i_start <= 0;

    $dumpfile(VCD_NAME);
    $dumpvars(1, party_computation_top_tb);
    
    #100

    i_rst <= 0;

    
    #10
    i_start <= 1;
    // i_r <= {32'h12345678, 32'h33223322, 32'h22222222};
    // i_eps <= {32'h00000001, 32'h00000002, 32'h00000003};
    // i_a <= {32'h00000001, 32'h00000001, 32'h00000001};
    // i_b <= {32'h00000001, 32'h00000001, 32'h00000001};
    // i_minus_c <= {32'h00000001, 32'h00000001, 32'h00000001};
    // i_alpha_prime <= {32'h00000003, 32'h00000002, 32'h00000001};
    // i_beta_prime <= {32'h00000003, 32'h00000002, 32'h00000001};

    if (TEST_SET == 0) begin
        i_r             <= 96'h461cad0d0097feb39e138972;
        i_eps           <= 96'hff09845ae7476fd0dcc13183;
        i_a             <= 96'h14f72b095d77526a7e8604c2;
        i_b             <= 96'heb613d8b85ee7fa8b44406eb;
        i_minus_c       <= 96'h4ca604b2b4a7e768ac1d813f;
        i_alpha_prime   <= 96'h0c74cc8c47af5a6b2743cc9d;
        i_beta_prime    <= 96'hac5318e63e69ab351e689529;
    end
    else if (TEST_SET == 1) begin
        i_r             <= 96'h488356462e986a376ded5a2b;
        i_eps           <= 96'he4b2bb33141ac6e900d407b4;
        i_a             <= 96'h427922ea18d8b371f424f9a4;
        i_b             <= 96'h84d53e7531d89984bcd21f18;
        i_minus_c       <= 96'hc6c71792726fe4ce0273473f;
        i_alpha_prime   <= 96'h4eb73bc1ebd5c7dee1415147;
        i_beta_prime    <= 96'hf49300c966e4b911cd7b3cb0;
    end
    else begin
        i_r             <= 96'h8f3640b57d7191e9e9916b6a;
        i_eps           <= 96'h3f7c6d1670a4f0f95a5e260e;
        i_a             <= 96'hc2023628b175c840295ae49a;
        i_b             <= 96'h451438dea601caf68b2fd932;
        i_minus_c       <= 96'he95a6ce908db84d611b557c8;
        i_alpha_prime   <= 96'hedf5d641a2beb4e944a96629;
        i_beta_prime    <= 96'he7484b59173b043a682684e3;
    end

    start_time = $time;
    #10
    i_start <= 0;

    #100
    
    @(posedge o_done)
    end_time = $time;

    $display("Clock Cycles taken for Party Computation =", (end_time-start_time-5)/10 );
    
    
    #100
    $finish;

end


parameter Q_FILE =   (TEST_SET == 0)? "Q_L1_0.in":
                     (TEST_SET == 1)? "Q_L1_1.in":
                                      "Q_L1_2.in";
//  always
//  begin
//      @(posedge o_done)
//     //  $writememb("HSA_L1.mem", DUT.MAT_VEC_MUL.RESULT_MEM.mem);
//  end

mem_single #(.WIDTH(8), .DEPTH(M), .FILE(Q_FILE)) 
 Q_values
 (
 .clock(i_clk),
 .data(0),
 .address(o_q_addr%M),
 .wr_en(0),
 .q(i_q)
 );

// mem_single #(.WIDTH(8), .DEPTH(M), .FILE("S_L1.mem")) 
// S_values
// (
// .clock(i_clk),
// .data(0),
// .address(o_s_addr),
// .wr_en(0),
// .q(i_s)
// );

parameter P_FILE =   (TEST_SET == 0)? "P_L1_0.in":
                     (TEST_SET == 1)? "P_L1_1.in":
                                      "P_L1_2.in";

 mem_single #(.WIDTH(8), .DEPTH(M), .FILE(P_FILE)) 
 P_values
 (
 .clock(i_clk),
 .data(0),
 .address(o_p_addr%M),
 .wr_en(0),
 .q(i_p)
 );


parameter F_FILE =   (TEST_SET == 0)? "F_L1_0.in":
                     (TEST_SET == 1)? "F_L1_1.in":
                                      "F_L1_2.in";
                                      
 mem_single #(.WIDTH(8), .DEPTH(M), .FILE(F_FILE)) 
 F_values
 (
 .clock(i_clk),
 .data(0),
 .address(o_f_addr%M),
 .wr_en(0),
 .q(i_f)
 );


 mem_single #(.WIDTH(PROC_SIZE), .DEPTH(MAT_SIZE/PROC_SIZE), .FILE("H_L1.mem")) 
 H_matrix_values
 (
 .clock(i_clk),
 .data(0),
 .address(o_h_mat_addr%(MAT_SIZE/PROC_SIZE)),
 .wr_en(0),
 .q(i_h_mat)
 );

parameter Sa_FILE =   (TEST_SET == 0)?"Sa_L1_0.in":
                     (TEST_SET == 1)? "Sa_L1_1.in":
                                      "Sa_L1_2.in";

  mem_single #(.WIDTH(8), .DEPTH(K), .FILE(Sa_FILE)) 
 Sa_values
 (
 .clock(i_clk),
 .data(0),
 .address(o_sa_addr%M),
 .wr_en(0),
 .q(i_sa)
 );

always #5 i_clk = ! i_clk;

 

endmodule