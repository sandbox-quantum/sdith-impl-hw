/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/


/*
 * This file is the r^i module which works 3 r values simultaneously.
 *
 *

 Algorithm: Square-and-multiply
Require: x ∈ {0,..., N − 1} and K = (k−1,..., k0)2
1: r �? 1
2: for i from  l − 1 downto 0 do
3:      r �? r^2 mod N
4:      if ki = 1 then
5:          r �? r × x mod N
6:      end if
7: end for
8: return r          
*/

module evaluate
#(
    
     parameter FIELD = "P251",
//    parameter FIELD = "GF256",
    
    
    parameter PARAMETER_SET = "L5",
    parameter D_SPLIT = (PARAMETER_SET == "L1")? 1:
                                                    2,
    
    parameter M  =  (PARAMETER_SET == "L1")? 230/D_SPLIT:
                    (PARAMETER_SET == "L3")? 352/D_SPLIT:
                    (PARAMETER_SET == "L5")? 480/D_SPLIT:
                                             230/D_SPLIT,
    parameter T =   (PARAMETER_SET == "L5")? 4:
                                             3
    
    
)(
    input                   i_clk,
    input                   i_rst,

    input                   i_start,

    input  [7:0]            i_q,
    output [`CLOG2(M)-1:0]  o_q_addr,
    output reg              o_q_rd,

    input [32*T-1:0]        i_r,

    output [32*T-1:0]       o_eval,

    `ifdef GF32_MUL_SHARED
        output o_start_mul,
        output [31:0] o_x_mul,
        output [31:0] o_y_mul,
        input  [31:0] i_o_mul,
        input  i_done_mul,
    `endif 

    `ifdef GF8_MUL_SHARED
        output o_start_mul_gf8,
        output [32*T-1:0] o_in_1_mul_gf8,
        output [7:0] o_in_2_mul_gf8,
        input  [32*T-1:0] i_out_mul_gf8,
        input  [32*T/8 -1:0] i_done_mul_gf8,
    `endif 

    `ifdef GF32_ADD_SHARED
        output o_start_add,
        output [32*T-1:0] o_in_1_add,
        output [32*T-1:0] o_in_2_add,
        input  [32*T-1:0] i_add_out,
        input  [T-1:0] i_done_add,
    `endif 

    output reg              o_done

);


reg start_exp;
wire done_exp;

assign o_q_addr = i_reg;

wire [32*T-1:0]        r_pow_i;
r_pow_i_x_t
#(
    .PARAMETER_SET(PARAMETER_SET),
    .FIELD(FIELD),
    .T(T),
    .M(M)
)
MOD_EXPONENT
(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_r(i_r),
    .i_exp(i_reg),
    .i_start(start_exp),
    .o_r_pow_exp(r_pow_i),

    `ifdef GF32_MUL_SHARED
        .o_start_mul(o_start_mul),
        .o_x_mul(o_x_mul),
        .o_y_mul(o_y_mul),
        .o_o_mul(i_o_mul),
        .i_done_mul(i_done_mul),
    `endif 

    .o_done(done_exp)
);


reg [7:0] q_reg;
always@(posedge i_clk)
begin
    if (start_exp) begin
        q_reg <= i_q;
    end
end

wire [32*T/8 - 1:0] done_gf8;
wire [32*T-1:0]     q_r_pow_i;

`ifndef GF8_MUL_SHARED
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
                    .start(done_exp),
                    .in_1(r_pow_i[32*T-8*j-1:32*T-8*j-8]),
                    .in_2(q_reg),
                    .out(q_r_pow_i[32*T-8*j-1:32*T-8*j-8]),
                    .done(done_gf8[j])
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
                    .start(done_exp),
                    .in_1(r_pow_i[32*T-8*j-1:32*T-8*j-8]),
                    .in_2(q_reg),
                    .out(q_r_pow_i[32*T-8*j-1:32*T-8*j-8]),
                    .done(done_gf8[j])
                );
            end
         end
    endgenerate
`endif 



`ifdef GF8_MUL_SHARED
        assign o_start_mul_gf8 = done_exp;
        assign o_in_1_mul_gf8 = r_pow_i;
        assign o_in_2_mul_gf8 = q_reg;
        assign q_r_pow_i = i_out_mul_gf8;
        assign done_gf8 = i_done_mul_gf8;
`endif 

wire [T-1:0]    done_add;
wire [32*T-1:0] add_q_r_pow_i;

`ifndef GF32_ADD_SHARED
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
                .i_start(done_gf8[0]), 
                .in_1(q_r_pow_i[32*k+32-1:32*k]), 
                .in_2(sum_q_r_pow_i[32*k+32-1:32*k]),
                .o_done(done_add[k]), 
                .out(add_q_r_pow_i[32*k+32-1:32*k]) 
            );
        end
        else begin
            gf251_add_32 
            GF32_ADD 
            (
                .i_clk(i_clk), 
                .i_start(done_gf8[0]), 
                .in_1(q_r_pow_i[32*k+32-1:32*k]), 
                .in_2(sum_q_r_pow_i[32*k+32-1:32*k]),
                .o_done(done_add[k]), 
                .out(add_q_r_pow_i[32*k+32-1:32*k]) 
            );        
        end
    end
endgenerate
`endif 

`ifdef GF32_ADD_SHARED
       assign   o_start_add = done_gf8[0];
       assign   o_in_1_add = q_r_pow_i;
       assign   o_in_2_add = sum_q_r_pow_i;
       assign   add_q_r_pow_i = i_add_out;
       assign   done_add = i_done_add;
`endif 

reg [32*T-1:0]     sum_q_r_pow_i;

always@(posedge i_clk)
begin
    if (i_start) begin
        sum_q_r_pow_i <= 0;
    end
    else if (done_add[0]) begin
        sum_q_r_pow_i <= add_q_r_pow_i;
    end

end

assign o_eval = sum_q_r_pow_i;


reg [3:0] state;
parameter s_wait_start          = 0;
parameter s_start_mod_exp       = 1;
parameter s_done_mod_exp        = 2;
parameter s_done                = 3;


reg [`CLOG2(M):0] i_reg;


always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        o_done <= 0;
        i_reg <= 0;
    end
    else begin
        
        if (state == s_wait_start) begin
            o_done <= 0;
            i_reg <= 0;
            if (i_start) begin
                state <= s_start_mod_exp;
            end
        end

        else if (state == s_start_mod_exp) begin
            if (i_reg == M) begin
                state <= s_done;
            end
            else begin
                state <= s_done_mod_exp;
                i_reg <= i_reg + 1;
            end
        end
        
        else if (state == s_done_mod_exp) begin 
            if (done_exp) begin
                state <= s_start_mod_exp;
            end
        end

        else if (state == s_done) begin 
            if (done_add[0]) begin
                state <= s_wait_start;
                o_done <= 1;
            end
            else begin
                o_done <= 0;
            end
        end
       
    end
end

always@(*)
begin

    case(state)
        
        s_wait_start: begin
            start_exp <= 0;
            if (i_start) begin
                o_q_rd <= 1;
            end
            else begin
                o_q_rd <= 0;
            end
        end

        s_start_mod_exp:begin
            if (i_reg == M) begin
                start_exp <= 0;
                o_q_rd <= 0;
            end
            else begin
                start_exp <= 1;
                o_q_rd <= 1;
            end
        end

                    
        s_done_mod_exp: begin
            start_exp <= 0;
            o_q_rd <= 1;
        end

        s_done: begin
            o_q_rd <= 0;
            start_exp <= 0;
        end        
        
        default: begin
            start_exp <= 0;
        end
    
    endcase
    
end

endmodule