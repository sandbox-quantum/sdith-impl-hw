/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module party_computation 
#(
    parameter PARAMETER_SET = "L1",

    parameter FIELD = "GF256",
    
    parameter LAMBDA =      (PARAMETER_SET == "L1")? 128:
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
    
    parameter M_BY_D_SPLIT = M/D_SPLIT,

    parameter FILE_MEM_INIT = ""
    

)(
    input                                               i_clk,
    input                                               i_rst,

    input                                               i_start,


    input  [7:0]                                        i_q,
    output [`CLOG2(M)-1:0]                              o_q_addr,
    output                                              o_q_rd,

    // input  [7:0]                                        i_s,
    // output [`CLOG2(M)-1:0]                              o_s_addr,
    // output                                              o_s_rd,

    input  [7:0]                                        i_p,
    output [`CLOG2(M)-1:0]                              o_p_addr,
    output                                              o_p_rd,

    input  [7:0]                                        i_f,
    output [`CLOG2(M)-1:0]                              o_f_addr,
    output                                              o_f_rd,

    input    [T*32-1:0]                                 i_alpha_prime,
    input    [T*32-1:0]                                 i_beta_prime,

    input    [T*32-1:0]                                 i_r,
    input    [T*32-1:0]                                 i_eps,
    input    [T*32-1:0]                                 i_minus_c,


    input [32*T-1:0]                                   i_a,
    input [32*T-1:0]                                   i_b,

    output reg [32*T-1:0]                              o_alpha,
    output reg [32*T-1:0]                              o_beta,
    output wire [32*T-1:0]                             o_v,

    // H.Sa Matrix Vector Multiplication Ports

    output [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0]             o_h_mat_addr,
    output [`CLOG2(M)-1:0]                              o_sa_addr,
    output                                              o_h_mat_sa_rd,
    input [PROC_SIZE-1:0]                               i_h_mat,
    input [7:0]                                         i_sa,


    // GF32 MUL PORTS
    output reg                                          o_start_mul32,
    output [31:0]                                       o_x_mul32,
    output [31:0]                                       o_y_mul32,
    input  [31:0]                                       i_o_mul32,
    input                                               i_done_mul32,

    // GF32 ADD PORTS
    output reg                                          o_start_add32,
    output [32*T-1:0]                                   o_in_1_add32,
    output [32*T-1:0]                                   o_in_2_add32,
    input  [32*T-1:0]                                   i_add_out_add32,
    input                                               i_done_add32,

    // evaluate ports
    output  reg                                         o_start_evaluate,
    output  [7:0]                                       o_qspf,
    input [`CLOG2(M)-1:0]                               i_qspf_addr,
    input                                               i_qspf_rd,
    output [32*T-1:0]                                   o_r_eps,
    input [32*T-1:0]                                    i_evaluate_out,
    input                                               i_done_evaluate,
    output reg                                          o_done

);

// ===================== H.SA ========================= 
reg start_mat_vec_mul;
wire done_mat_vec_mul;
wire [PROC_SIZE-1:0] vec_res;
// // wire [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0] o_h_mat_addr;
// // wire [`CLOG2(M)-1:0] o_sa_addr;
// reg [`CLOG2(M)-1:0] s_vec_addr_reg;
// // wire [PROC_SIZE-1:0] i_h_mat;
// // wire [`CLOG2(M)+7:0] i_sa;
// wire [7:0] s_out;
// // wire o_mat_vec_rd;



 mat_vec_mul_ser
 #(
 .FIELD(FIELD),
 .PARAMETER_SET(PARAMETER_SET),
 .MAT_ROW_SIZE_BYTES(MAT_ROW_SIZE_BYTES),
 .MAT_COL_SIZE_BYTES(MAT_COL_SIZE_BYTES),
 .VEC_SIZE_BYTES(VEC_SIZE_BYTES),
 .VEC_WEIGHT(VEC_S_WEIGHT),
 .N_GF(N_GF)
 )
 MAT_VEC_MUL
 (
     .i_clk(i_clk),
     .i_rst(i_rst),
     .i_start(start_mat_vec_mul),
     .o_mat_addr(o_h_mat_addr),
     .o_vec_addr(o_sa_addr),
     .o_mat_vec_rd(o_h_mat_sa_rd),
     .i_mat(i_h_mat),
     .i_vec(i_sa),

     .o_res(data_parser_wide_in),
     .i_res_en(data_parser_wide_in_rd),
     .i_res_addr(data_parser_wide_in_addr),
     .o_done(done_mat_vec_mul),

     .i_vec_add_addr(0),
     .i_vec_add_wen(0)
    //  .i_vec_add(0)
 );

reg [`CLOG2(M)-1:0] sa_addr_reg;

always@(posedge i_clk)
begin
    sa_addr_reg <= o_sa_addr;
end

wire start_data_parser;
wire done_data_parser;
wire data_parser_wide_in_rd;
wire [PROC_SIZE-1:0] data_parser_wide_in;
wire [`CLOG2(M-K)-1:0] data_parser_wide_in_addr;
wire [7:0] data_parser_byte;
wire [`CLOG2(MAT_ROW_SIZE_BYTES)-1:0] data_parser_byte_addr;

wire data_parser_byte_en;

assign start_data_parser = done_mat_vec_mul;

 data_parser #(
    .IN_WIDTH(PROC_SIZE),
    .OUT_WIDTH(8),
    .SOURCE_BRAM_DEPTH(MAT_ROW_SIZE/PROC_SIZE),
    .DESTINATION_BRAM_DEPTH(MAT_ROW_SIZE_BYTES)
    )
Sa_DATA_PARSER 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(start_data_parser),
.o_done(done_data_parser),

.i_wide_in(data_parser_wide_in),
.o_wide_in_addr(data_parser_wide_in_addr),
.o_wide_in_rd(data_parser_wide_in_rd),

.o_narrow_out(data_parser_byte),
.o_narrow_out_addr(data_parser_byte_addr),
.o_narrow_out_en(data_parser_byte_en)
);

wire [7:0] s;
wire [`CLOG2(M)-1:0] s_in_addr;
wire [`CLOG2(M)-1:0] s_addr;
wire                 s_rd;

assign s_in_addr =  (s_eval_en && s_rd)?    s_addr : 
                    data_parser_byte_en?    data_parser_byte_addr + K : 
                                            sa_addr_reg;

mem_single #(.WIDTH(8), .DEPTH(M), .FILE("Sa_L1_0.in")) 
 Sa_MEM
 (
    .clock(i_clk),
    .data(data_parser_byte_en? data_parser_byte: i_sa),
    .address(s_in_addr),
    // .wr_en(data_parser_byte_en? data_parser_byte_en: o_h_mat_sa_rd),
    .wr_en(0), //Replace this 
    .q(s)
 );
// ============================================== 



reg sel_r_eps; // = 0 selects r and = 1 selects eps 
reg [1:0] sel_qs;

assign o_qspf = (sel_qs == 2'b01)? i_q : 
                (sel_qs == 2'b10)? i_p :
                (sel_qs == 2'b11)? i_f :
                                   s;

assign o_q_addr = i_qspf_addr;
assign s_addr   = i_qspf_addr;
assign o_p_addr = i_qspf_addr;
assign o_f_addr = i_qspf_addr;

assign o_q_rd = i_qspf_rd;
assign s_rd = i_qspf_rd;
assign o_p_rd = i_qspf_rd;
assign o_f_rd = i_qspf_rd;

assign o_r_eps = i_r;


reg [32*T-1:0] ab_reg;
reg en_a;
reg en_b;
reg en_shift_ab;

always@(posedge i_clk)
begin
    if (en_a) begin
        ab_reg <= i_eps;
    end
    else if (alpha_en) begin
        ab_reg <= i_add_out_add32;
    end
    else if (en_shift_ab) begin
        ab_reg <= {ab_reg[32*T-32-1:0], ab_reg[32*T-1:32*T-32]};
    end
end


reg [32*T-1:0] alpha_beta_reg;
reg [`CLOG2(T*D_SPLIT)-1:0] alpha_beta_addr;
reg alpha_mem_wen;
reg ab_en;
reg done_shift_gf32mul;

always@(posedge i_clk)
begin
    if (ab_en) begin
        alpha_beta_reg <= i_evaluate_out;
    end
    else if (beta_en) begin
        alpha_beta_reg <= i_add_out_add32;
    end
    else if (en_shift_ab) begin
        alpha_beta_reg <= {alpha_beta_reg[32*T-32-1:0], alpha_beta_reg[32*T-1:32*T-32]};
    end
    else if (done_shift_gf32mul) begin
        alpha_beta_reg <= {alpha_beta_reg[32*T-32-1:0], i_o_mul32};
    end
end

reg alpha_en;
reg beta_en;

always@(*)
begin
    o_alpha <= ab_reg;
end

always@(*)
begin
    o_beta <= alpha_beta_reg;
end


reg en_pr;
reg shift_pf;
reg [32*T-1:0] eval_pr;
reg done_shift_gf32mul_pf;

always@(posedge i_clk)
begin
    if (en_pr) begin
        eval_pr <= i_evaluate_out;
    end
    else if (shift_pf) begin
        eval_pr <= {eval_pr[32*T-32-1:0], eval_pr[32*T-1:32*T-32]};
    end
    else if (done_shift_gf32mul_pf) begin
        eval_pr <= {eval_pr[32*T-32-1:0], i_o_mul32};
    end
end

reg en_fr;
reg [32*T-1:0] eval_fr;

always@(posedge i_clk)
begin
    if (en_fr) begin
        eval_fr <= i_evaluate_out;
    end
    else if (shift_pf && sel_gf_mul == 1) begin
        eval_fr <= {eval_fr[32*T-32-1:0], eval_fr[32*T-1:32*T-32]};
    end
end

reg [32*T-1:0] eps_reg;
always@(posedge i_clk)
begin
    if (i_start) begin
        eps_reg <= i_eps;
    end
    else if (shift_pf && sel_gf_mul == 2) begin
        eps_reg <= {eps_reg[32*T-32-1:0], eps_reg[32*T-1:32*T-32]};
    end
end

reg [2:0] sel_gf_mul;

// GF32 MUL
assign o_x_mul32 =  (sel_gf_mul==1 || sel_gf_mul==2 )?  eval_pr[32*T-1:32*T-32] :
                    (sel_gf_mul==3)?                    beta_prime_reg[32*T-1:32*T-32] :
                    (sel_gf_mul==4)?                    alpha_prime_reg[32*T-1:32*T-32] :
                                                        alpha_beta_reg[32*T-1:32*T-32];

assign o_y_mul32 =  (sel_gf_mul==1)? eval_fr[32*T-1:32*T-32] :
                    (sel_gf_mul==2)? eps_reg[32*T-1:32*T-32]:
                    (sel_gf_mul==3)? a_reg[32*T-1:32*T-32] :
                    (sel_gf_mul==4)? b_reg[32*T-1:32*T-32] :
                                     ab_reg[32*T-1:32*T-32];


reg [1:0] sel_gf_add;
reg v_reg_en;


//GF32 ADD
reg sel_b;
assign o_in_1_add32 = (sel_gf_add == 1 || sel_gf_add == 2 || sel_gf_add == 3)?  v_reg :
                                                                                alpha_beta_reg;

assign o_in_2_add32 =   (sel_gf_add == 1)?          eval_pr :
                        (sel_gf_add == 2)?          alpha_prime_reg :
                        (sel_gf_add == 3)?          beta_prime_reg :
                        (sel_gf_add == 0 && sel_b)? b_reg : 
                                                    a_reg;

reg [32*T-1:0] v_reg;

always@(posedge i_clk)
begin
    if (i_start) begin
        v_reg <= i_minus_c;
    end
    else if (v_reg_en) begin
        v_reg <= i_add_out_add32;
    end
end

assign o_v = v_reg;

reg [32*T-1:0] a_reg;
reg shift_a_reg;
always@(posedge i_clk)
begin
    if (i_start) begin
        a_reg <= i_a;
    end
    else if (shift_a_reg) begin
        a_reg <= {a_reg[32*T-32-1:0], a_reg[32*T-1:32*T-32]};
    end
end

reg [32*T-1:0] b_reg;
reg shift_b_reg;
always@(posedge i_clk)
begin
    if (i_start) begin
        b_reg <= i_b;
    end
    else if (shift_a_reg) begin
        b_reg <= {b_reg[32*T-32-1:0], b_reg[32*T-1:32*T-32]};
    end
end

reg [32*T-1:0] alpha_prime_reg;
reg done_shift_gfmul_alphap;
always@(posedge i_clk)
begin
    if (i_start) begin
        alpha_prime_reg <= i_alpha_prime;
    end
    else if (shift_b_reg) begin
        alpha_prime_reg <= {alpha_prime_reg[32*T-32-1:0], alpha_prime_reg[32*T-1:32*T-32]};
    end
    else if (done_shift_gfmul_alphap) begin
        alpha_prime_reg <= {alpha_prime_reg[32*T-32-1:0], i_o_mul32};
    end
end

reg [32*T-1:0] beta_prime_reg;
reg done_shift_gfmul_betap;
always@(posedge i_clk)
begin
    if (i_start) begin
        beta_prime_reg <= i_beta_prime;
    end
    else if (shift_a_reg) begin
        beta_prime_reg <= {beta_prime_reg[32*T-32-1:0], beta_prime_reg[32*T-1:32*T-32]};
    end
    else if (done_shift_gfmul_betap) begin
        beta_prime_reg <= {beta_prime_reg[32*T-32-1:0], i_o_mul32};
    end
end

reg s_eval_en;

reg [4:0] state = 0;
parameter s_wait_start          = 0;
parameter s_start_r_eval        = 1;
parameter s_done_r_eval         = 2;
parameter s_r_eval_mul_eps      = 3;
parameter s_r_eval_mul_eps_done = 4;
parameter s_alpha_add_a         = 5;
parameter s_alpha_add_done      = 6;
parameter s_start_rs_eval       = 7;
parameter s_done_rs_eval        = 8;
parameter s_beta_add_b          = 9;
parameter s_beta_add_done       = 10;
parameter s_start_p_eval        = 11;
parameter s_done_p_eval         = 12;
parameter s_start_f_eval        = 13;
parameter s_done_f_eval         = 14;    
parameter s_p_eval_mul_f_eval   = 15;
parameter s_p_eval_mul_f_eval_done = 16;

parameter s_pf_eval_mul_eps         = 17;
parameter s_pf_eval_mul_eps_done    = 18;

parameter s_eps_eval_add            = 19;
parameter s_eps_eval_add_done       = 20;

parameter s_betap_mul_a             = 21;
parameter s_betap_mul_a_done        = 22;

parameter s_alphap_mul_b            = 23;
parameter s_alphap_mul_b_done       = 24;

parameter s_v_alphap_add            = 25;
parameter s_v_alphap_add_done       = 26;

parameter s_v_betap_add             = 27;
parameter s_v_betap_add_done        = 28;

parameter s_done                    = 31;

reg [`CLOG2(T)-1:0] count_shift = 0;
always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        o_done <= 0;
        count_shift <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            o_done <= 0;
            count_shift <= 0;
            if (i_start) begin
                state <= s_start_r_eval;
            end
        end

        else if (state == s_start_r_eval) begin
                state <= s_done_r_eval;
        end

        else if (state == s_done_r_eval) begin
            if (i_done_evaluate) begin
                state <= s_r_eval_mul_eps;
            end
        end

        else if (state == s_r_eval_mul_eps) begin
            if (count_shift == T - 1) begin
                count_shift <= 0;
                state <= s_r_eval_mul_eps_done;
            end
            else begin 
                count_shift <= count_shift + 1;
            end
        end

        else if (state == s_r_eval_mul_eps_done) begin
            if (count_shift == T - 1) begin
                count_shift <= 0;
                state <= s_alpha_add_a;
            end
            else begin 
                if (i_done_mul32) begin
                    count_shift <= count_shift + 1;
                end
            end                    
        end

        else if (state == s_alpha_add_a) begin
            state <= s_alpha_add_done;
        end

        else if (state == s_alpha_add_done) begin
            if (i_done_add32) begin
                state <= s_start_rs_eval;
            end
        end

        else if (state == s_start_rs_eval) begin
            state <= s_done_rs_eval;
        end
        
        else if (state == s_done_rs_eval) begin
            if (i_done_evaluate) begin
                state <= s_beta_add_b;
            end
        end

        else if (state == s_beta_add_b) begin
            state <= s_beta_add_done;
        end

        else if (state == s_beta_add_done) begin
            if (i_done_add32) begin
                state <= s_start_p_eval;
            end
        end

        else if (state == s_start_p_eval) begin
            state <= s_done_p_eval;
        end
        
        else if (state == s_done_p_eval) begin
            if (i_done_evaluate) begin
                state <= s_start_f_eval;
            end
        end

        else if (state == s_start_f_eval) begin
            state <= s_done_f_eval;
        end
        
        else if (state == s_done_f_eval) begin
            if (i_done_evaluate) begin
                state <= s_p_eval_mul_f_eval;
            end
        end

        else if (state == s_p_eval_mul_f_eval) begin
            if (count_shift == T - 1) begin
                count_shift <= 0;
                state <= s_p_eval_mul_f_eval_done;
            end
            else begin 
                count_shift <= count_shift + 1;
            end
        end

        else if (state == s_p_eval_mul_f_eval_done) begin
            if (count_shift == T - 1) begin
                count_shift <= 0;
                state <= s_pf_eval_mul_eps;
            end
            else begin 
                if (i_done_mul32) begin
                    count_shift <= count_shift + 1;
                end
            end                    
        end

        else if (state == s_pf_eval_mul_eps) begin
            if (count_shift == T - 1) begin
                count_shift <= 0;
                state <= s_pf_eval_mul_eps_done;
            end
            else begin 
                count_shift <= count_shift + 1;
            end
        end

        else if (state == s_pf_eval_mul_eps_done) begin
            if (count_shift == T - 1) begin
                count_shift <= 0;
                state <= s_eps_eval_add;
            end
            else begin 
                if (i_done_mul32) begin
                    count_shift <= count_shift + 1;
                end
            end                    
        end

        else if (state == s_eps_eval_add) begin
            state <= s_eps_eval_add_done;
        end

        else if (state == s_eps_eval_add_done) begin
            if (i_done_add32) begin
                state <= s_betap_mul_a;
            end
        end

        else if (state == s_betap_mul_a) begin
            if (count_shift == T - 1) begin
                count_shift <= 0;
                state <= s_betap_mul_a_done;
            end
            else begin 
                count_shift <= count_shift + 1;
            end
        end

        else if (state == s_betap_mul_a_done) begin
            if (count_shift == T - 1) begin
                count_shift <= 0;
                state <= s_alphap_mul_b;
            end
            else begin 
                if (i_done_mul32) begin
                    count_shift <= count_shift + 1;
                end
            end                    
        end

        else if (state == s_alphap_mul_b) begin
            if (count_shift == T - 1) begin
                count_shift <= 0;
                state <= s_alphap_mul_b_done;
            end
            else begin 
                count_shift <= count_shift + 1;
            end
        end

        else if (state == s_alphap_mul_b_done) begin
            if (count_shift == T - 1) begin
                count_shift <= 0;
                state <= s_v_alphap_add;
            end
            else begin 
                if (i_done_mul32) begin
                    count_shift <= count_shift + 1;
                end
            end                    
        end

        else if (state == s_v_alphap_add) begin
            state <= s_v_alphap_add_done;
        end

        else if (state == s_v_alphap_add_done) begin
            if (i_done_add32) begin
                state <= s_v_betap_add;
            end
        end

        else if (state == s_v_betap_add) begin
            state <= s_v_betap_add_done;
        end

        else if (state == s_v_betap_add_done) begin
            if (i_done_add32) begin
                state <= s_done;
            end
        end
        
        else if (state == s_done) begin
            state <= s_wait_start;
            o_done <= 1;
        end

    end

end

always@(*)
begin
    case(state)

    s_wait_start: begin
        o_start_evaluate <= 0;
        sel_r_eps <= 0;
        sel_qs <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        en_shift_ab <= 0;
        done_shift_gf32mul <= 0;
        o_start_add32 <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 0;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
    end

    s_start_r_eval: begin
        sel_r_eps <= 0;
        sel_qs <= 1;
        o_start_evaluate <= 1;
        ab_en<= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        en_shift_ab <= 0;
        done_shift_gf32mul <= 0;
        o_start_add32 <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 0;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 1;
        s_eval_en <= 0;
    end

    s_done_r_eval: begin
        sel_r_eps <= 0;
        sel_qs <= 1;
        o_start_evaluate <= 0;
        o_start_mul32 <= 0;
        en_shift_ab <= 0;
        done_shift_gf32mul <= 0;
        o_start_add32 <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 0;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
        if (i_done_evaluate) begin
            ab_en <= 1;
            en_a <= 1;
        end
        else begin
            ab_en <= 0;
            en_a <= 0;
        end
    end

    s_r_eval_mul_eps: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 1;
        en_a <= 0;
        en_shift_ab <= 1;
        done_shift_gf32mul <= 0;
        o_start_add32 <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 0;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
    end

    s_r_eval_mul_eps_done: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        en_shift_ab <= 0;
        o_start_add32 <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 0;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
        if (i_done_mul32) begin
            done_shift_gf32mul <= 1;
        end
        else begin
            done_shift_gf32mul <= 0;
        end
    end

    s_alpha_add_a: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        o_start_add32 <= 1;
        alpha_en <= 0;
        sel_b <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 0;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
    end

    s_alpha_add_done: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        o_start_add32 <= 0;
        sel_b <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 0;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
        if (i_done_add32) begin
            alpha_en <= 1;
        end
        else begin
            alpha_en <= 0;
        end
    end

    s_start_rs_eval: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 1;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        o_start_add32 <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 0;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 1;
    end

    s_done_rs_eval: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        o_start_add32 <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 0;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 1;
        if (i_done_evaluate) begin
            ab_en <= 1;
        end
        else begin
            ab_en <= 0;
        end
    end

    s_beta_add_b: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        o_start_add32 <= 1;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 0;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
    end

    s_beta_add_done: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        o_start_add32 <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 0;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
        if (i_done_add32) begin
            beta_en <= 1;
        end
        else begin
            beta_en <= 0;
        end
    end

    s_start_p_eval: begin
        sel_r_eps <= 0;
        sel_qs <= 2;
        o_start_evaluate <= 1;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 0;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
    end

    s_done_p_eval: begin
        sel_r_eps <= 0;
        sel_qs <= 2;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        beta_en <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 0;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
        if (i_done_evaluate) begin
            en_pr <= 1;
        end
        else begin
            en_pr <= 0;
        end
    end

    s_start_f_eval: begin
        sel_r_eps <= 0;
        sel_qs <= 2;
        o_start_evaluate <= 1;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 0;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
    end

    s_done_f_eval: begin
        sel_r_eps <= 0;
        sel_qs <= 2;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        beta_en <= 0;
        shift_pf <= 0;
        en_pr <= 0;
        sel_gf_mul <= 0;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
        if (i_done_evaluate) begin
            en_fr <= 1;
        end
        else begin
            en_fr <= 0;
        end
    end

    s_p_eval_mul_f_eval: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 1;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 1;
        en_fr <= 0;
        sel_gf_mul <= 1;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
    end

    s_p_eval_mul_f_eval_done: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 1;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
        if (i_done_mul32) begin
            done_shift_gf32mul_pf <= 1;
        end
        else begin
            done_shift_gf32mul_pf <= 0;
        end
    end

    s_pf_eval_mul_eps: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 1;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 1;
        en_fr <= 0;
        sel_gf_mul <= 2;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
    end

    s_pf_eval_mul_eps_done: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 2;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
        if (i_done_mul32) begin
            done_shift_gf32mul_pf <= 1;
        end
        else begin
            done_shift_gf32mul_pf <= 0;
        end
    end

   s_eps_eval_add: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        o_start_add32 <= 1;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 0;
        sel_gf_add <= 1;
        v_reg_en <= 0;
        done_shift_gf32mul_pf <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
    end

    s_eps_eval_add_done: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        o_start_add32 <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        beta_en <= 0;
        sel_gf_mul <= 0;
        sel_gf_add <= 0;
        done_shift_gf32mul_pf <= 0; 
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
        if (i_done_add32) begin
            v_reg_en <= 1;
        end
        else begin
            v_reg_en <= 0;
        end
    end

    s_betap_mul_a: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 1;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 3;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 1;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
    end

    s_betap_mul_a_done: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 3;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gf32mul_pf <= 0;
        done_shift_gfmul_alphap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
        if (i_done_mul32) begin
            done_shift_gfmul_betap <= 1;
        end
        else begin
            done_shift_gfmul_betap <= 0;
        end
    end

    s_alphap_mul_b: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 1;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 4;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 1;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
    end

    s_alphap_mul_b_done: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 4;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gf32mul_pf <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
        if (i_done_mul32) begin
            done_shift_gfmul_alphap <= 1;
        end
        else begin
            done_shift_gfmul_alphap <= 0;
        end
    end

    s_v_alphap_add: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        o_start_add32 <= 1;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 0;
        sel_gf_add <= 2;
        v_reg_en <= 0;
        done_shift_gf32mul_pf <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
    end

    s_v_alphap_add_done: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        o_start_add32 <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        beta_en <= 0;
        sel_gf_mul <= 0;
        sel_gf_add <= 0;
        done_shift_gf32mul_pf <= 0; 
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
        if (i_done_add32) begin
            v_reg_en <= 1;
        end
        else begin
            v_reg_en <= 0;
        end
    end

    s_v_betap_add: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        o_start_add32 <= 1;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 0;
        sel_gf_add <= 3;
        v_reg_en <= 0;
        done_shift_gf32mul_pf <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
    end

    s_v_betap_add_done: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        o_start_add32 <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        beta_en <= 0;
        sel_gf_mul <= 0;
        sel_gf_add <= 0;
        done_shift_gf32mul_pf <= 0; 
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
        if (i_done_add32) begin
            v_reg_en <= 1;
        end
        else begin
            v_reg_en <= 0;
        end
    end

    s_done: begin
        sel_r_eps <= 0;
        sel_qs <= 0;
        o_start_evaluate <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        done_shift_gf32mul <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 0;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
    end

    default: begin
        o_start_evaluate <= 0;
        sel_r_eps <= 0;
        sel_qs <= 0;
        ab_en <= 0;
        o_start_mul32 <= 0;
        en_a <= 0;
        en_shift_ab <= 0;
        done_shift_gf32mul <= 0;
        o_start_add32 <= 0;
        alpha_en <= 0;
        sel_b <= 0;
        beta_en <= 0;
        en_pr <= 0;
        shift_pf <= 0;
        en_fr <= 0;
        sel_gf_mul <= 0;
        done_shift_gf32mul_pf <= 0;
        v_reg_en <= 0;
        sel_gf_add <= 0;
        done_shift_gfmul_alphap <= 0;
        done_shift_gfmul_betap <= 0;
        shift_a_reg <= 0;
        shift_b_reg <= 0;
        start_mat_vec_mul <= 0;
        s_eval_en <= 0;
    end

    endcase
end

endmodule