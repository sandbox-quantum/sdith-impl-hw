/*
 * This file is compute plain broad cast module which part of SDitH sign.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module compute_plain_broadcast 
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

    parameter FILE_MEM_INIT = ""
    

)(
    input                                               i_clk,
    input                                               i_rst,

    input                                               i_start,


    input  [7:0]                                        i_q,
    output [`CLOG2(M)-1:0]                              o_q_addr,
    output                                              o_q_rd,

    input  [7:0]                                        i_s,
    output [`CLOG2(M)-1:0]                              o_s_addr,
    output                                              o_s_rd,

    input    [T*32-1:0]                                 i_r,

    input    [T*32-1:0]                                 i_eps,


    input [32*T-1:0]                                   i_a,
    input [32*T-1:0]                                   i_b,

    output reg [32*T-1:0]                              o_alpha,
    output reg [32*T-1:0]                              o_beta,

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
    output  [7:0]                                       o_q_s,
    input [`CLOG2(M)-1:0]                               i_q_s_addr,
    input                                               i_q_s_rd,
    output [32*T-1:0]                                   o_r_eps,
    input [32*T-1:0]                                    i_evaluate_out,
    input                                               i_done_evaluate,
    output reg                                          o_done

);


reg sel_r_eps; // = 0 selects r and = 1 selects eps 
reg sel_qs;

assign o_q_s = sel_qs? i_q : i_s;
assign o_q_addr = i_q_s_addr;
assign o_s_addr = i_q_s_addr;
assign o_q_rd = i_q_s_rd;
assign o_s_rd = i_q_s_rd;

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


// GF32 MUL
assign o_x_mul32 = alpha_beta_reg[32*T-1:32*T-32];
assign o_y_mul32 = ab_reg[32*T-1:32*T-32];

//GF32 ADD
reg sel_b;
assign o_in_1_add32 = alpha_beta_reg;
assign o_in_2_add32 = sel_b? i_b : i_a;


reg [3:0] state = 0;
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
parameter s_done                = 11;

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
        if (i_done_add32) begin
            beta_en <= 1;
        end
        else begin
            beta_en <= 0;
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
    end

    endcase
end

endmodule