/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/


`include "clog2.v"
module commit_hash
#(
    parameter PARAMETER_SET = "L1",
    parameter DATA_WIDTH    = 32,
    parameter LAMBDA =      (PARAMETER_SET == "L1")? 128:
                            (PARAMETER_SET == "L3")? 192:
                            (PARAMETER_SET == "L5")? 256:
                                                     128,
    parameter M  =  (PARAMETER_SET == "L1")? 230:
                    (PARAMETER_SET == "L3")? 352:
                    (PARAMETER_SET == "L5")? 480:
                                             8,
    parameter SEED_SIZE = LAMBDA,
    parameter SALT_SIZE = 2*LAMBDA,
    parameter RHO_SIZE = LAMBDA/8,
    parameter AUX_SIZE = 256,
    parameter COMMIT_SIZE = LAMBDA,
    parameter HASH_IN_SIZE = 8+SEED_SIZE + SALT_SIZE + 32 + AUX_SIZE,
    parameter HASH_IN_SIZE_32 = HASH_IN_SIZE + (32-HASH_IN_SIZE%32)%32

)(
    input                                               i_clk,
    input                                               i_rst,

    input                                               i_start,
    output reg                                          o_done,
    
    input  [31:0]                                       i_salt,
    output reg [`CLOG2(SALT_SIZE/32)-1:0]               o_salt_addr,
    output reg                                          o_salt_rd,
    
    input  [31:0]                                       i_leaf_seed,
    output reg [`CLOG2(SALT_SIZE/32)-1:0]               o_leaf_seed_addr,
    output reg                                          o_leaf_seed_rd,
    
    input  [15:0]                                       i_iteration,
    input  [15:0]                                       i_leaf_idx,
    // input  [15:0]                                       i_leaf_rho,
    
    input  [31:0]                                       i_aux,
    output reg [`CLOG2(AUX_SIZE/32)-1:0]                o_aux_addr,
    output reg                                          o_aux_rd,
   
    output [31:0]                                       o_hash_in,
    output reg [`CLOG2(HASH_IN_SIZE_32/32)-1:0]            o_hash_addr,
    output reg                                          o_hash_wen,

    input                                              i_last_commit,   
    
    output [31:0]                                       o_commit,
    output [31:0]                                       o_commit_valid,
    output reg [`CLOG2(COMMIT_SIZE/32)-1:0]                 o_commit_addr,
    // hash interface
    // output   [32-1:0]                                   o_hash_data_in,
    // input    [`CLOG2((SALT_SIZE+SEED_SIZE)/32) -1:0]            i_hash_addr,
    // input                                               i_hash_rd_en,
    input    wire [32-1:0]                              i_hash_data_out,
    input    wire                                        i_hash_data_out_valid,
    output   reg                                        o_hash_data_out_ready,
    output   wire  [32-1:0]                             o_hash_input_length_32, // in bits
    output   wire  [32-1:0]                             o_hash_input_length, // in bits
    output   wire  [32-1:0]                             o_hash_output_length, // in bits
    output   reg                                        o_hash_start,
    input    wire                                       i_hash_force_done_ack,
    output   reg                                        o_hash_force_done
);

wire [31:0] hash_out;
reg [31:0] hash_out_reg;
reg [1:0] sel_hash;
reg first_block;
reg sel_leaf_idx;
reg sel_iteration;
reg sel_leaf_rho;

assign o_hash_input_length_32 = HASH_IN_SIZE_32;
assign o_hash_input_length = HASH_IN_SIZE;
assign o_hash_output_length = COMMIT_SIZE;

assign o_commit = i_hash_data_out;
assign o_commit_valid = i_hash_data_out_valid;

always@(posedge i_clk)
begin
    hash_out_reg <= hash_out;    
end


assign hash_out =   (sel_hash == 0)?   i_salt:
                    (sel_hash == 1)?   {i_leaf_idx[15:0], i_iteration[15:0]}:
                    (sel_hash == 2)?   i_leaf_seed:
                    (sel_hash == 3)?   i_aux:
                                        0;
                    // (PARAMETER_SET == "L1" && sel_hash == 1)?   {i_leaf_idx[15:0], i_iteration[15:0]}:
                    // (PARAMETER_SET == "L1" && sel_hash == 2)?   i_leaf_seed:
                    // (PARAMETER_SET == "L1" && sel_hash == 3)?   i_aux:
                    //                                             0;

assign o_hash_in = (o_hash_addr == 0)? {8'h00, hash_out[31:8]}:
                   (o_hash_addr == HASH_IN_SIZE_32/32 - 1)? {hash_out_reg[7:0], 24'h000000}: 
                                                        {hash_out_reg[7:0], hash_out[31:8]};

reg [3:0] state;
parameter s_wait_start              = 0;
parameter s_move_salt               = 1;
parameter s_move_leaf_id            = 2;
parameter s_move_rho                = 3;
parameter s_leaf_idx                = 4;
parameter s_move_aux                = 5;
parameter s_move_leaf_seed          = 6;
parameter s_move_last_block         = 7;
parameter s_done_move               = 8;
parameter s_start_hash              = 9;
parameter s_wait_hash_done          = 10;

always@(posedge i_clk) begin
    if(i_rst) begin
        o_done <= 1'b0;
        state <= s_wait_start;
        o_salt_addr <= 0;
        o_leaf_seed_addr <= 0;
        o_aux_addr <= 0;
        o_hash_addr <= 0;
        o_done <= 1'b0;
        sel_hash <= 0; 
        o_commit_addr <= 0;
        o_hash_data_out_ready <= 0;
        o_hash_force_done <= 0;
    end
    else begin
        if(state ==s_wait_start) begin
            o_done <= 1'b0;
            o_salt_addr <= 0;
            o_leaf_seed_addr <= 0;
            o_aux_addr <= 0;
            o_hash_addr <= 0;
            o_done <= 1'b0;
            sel_hash <= 0; 
            o_commit_addr <= 0;
            o_hash_data_out_ready <= 0;
            o_hash_force_done <= 0;
            if (i_start) begin
                state <= s_move_salt;
                o_salt_addr <= o_salt_addr + 1;
            end
            else begin
                state <= s_wait_start;
                o_salt_addr <= 0;
            end
        end
        else if (state == s_move_salt) begin
            if (o_salt_addr == SALT_SIZE/32 - 1) begin
                o_salt_addr <= 0;
                state <= s_move_leaf_id;
                o_hash_addr <= o_hash_addr + 1;
            end
            else begin
                o_salt_addr <= o_salt_addr + 1;
                o_hash_addr <= o_hash_addr + 1;
            end
        end

        else if (state == s_move_leaf_id) begin
            state <= s_move_leaf_seed;
            sel_hash <= 1; 
            o_hash_addr <= o_hash_addr + 1;
        end
        
        // else if (state == s_move_rho) begin
        //     state <= s_move_leaf_seed;
        // end

        else if (state == s_move_leaf_seed) begin
            sel_hash <= 2; 
            o_hash_addr <= o_hash_addr + 1;
            if (o_leaf_seed_addr == SEED_SIZE/32 - 1) begin
                o_leaf_seed_addr <= 0;
                state <= s_move_aux;
            end
            else begin
                o_leaf_seed_addr <= o_leaf_seed_addr + 1;
            end
        end

        else if (state == s_move_aux) begin
            sel_hash <= 3; 
            o_hash_addr <= o_hash_addr + 1;
            if (o_aux_addr == AUX_SIZE/32 - 1) begin
                o_aux_addr <= 0;
                state <= s_move_last_block;
            end
            else begin
                o_aux_addr <= o_aux_addr + 1;
            end
        end

        else if (state == s_move_last_block) begin
            state <= s_done_move;
            o_hash_addr <= o_hash_addr + 1;
        end

        else if  (state == s_done_move) begin
            o_done <= 1'b0;
            state <= s_start_hash;
        end

        else if (state == s_start_hash) begin
            state <= s_wait_hash_done;
            o_hash_data_out_ready <= 1'b1;
        end

        else if (state == s_wait_hash_done) begin
            if (o_commit_addr == COMMIT_SIZE/32 - 1) begin
                state <= s_wait_start;
                o_done <= 1'b1;
                o_hash_data_out_ready <= 1'b0;
                o_hash_force_done <= 1'b1;
            end
            else begin
                if (i_hash_data_out_valid) begin
                    o_commit_addr <= o_commit_addr + 1;
                end
            end
        end
    end
end


always@(*)
begin
    case(state)
        s_wait_start: begin
            // sel_hash <= 0;
            // first_block <= 0;
            o_hash_wen <= 0;
            o_leaf_seed_rd <= 0;
            o_aux_rd <= 0;
            o_hash_start <= 1'b0;
            if (i_start) begin
                o_salt_rd <= 1;
            end
            else begin
                o_salt_rd <= 0;
            end
        end

        s_move_salt: begin
            // sel_hash <= 0;
            o_salt_rd <= 1;
            o_leaf_seed_rd <= 0;
            o_aux_rd <= 0;
            o_hash_start <= 1'b0;
            // if (o_salt_addr == 1) begin
            //     first_block <= 1;
            // end
            // else begin
            //     first_block <= 0;
            // end
            if (o_salt_addr > 0) begin
                o_hash_wen <= 1;
            end
            else begin
                o_hash_wen <= 1;
            end
        end

        s_move_leaf_id: begin
            // sel_hash <= 0;
            // first_block <= 0;
            o_salt_rd <= 0;
            o_hash_wen <= 1;
            o_aux_rd <= 0;
            o_hash_start <= 1'b0;
        end

        // s_move_rho: begin
        //     sel_hash <= 0;
        //     first_block <= 0;
        //     o_hash_wen <= 1;
        // end

        s_move_leaf_seed: begin
            // sel_hash <= 1;
            // first_block <= 0;
            o_leaf_seed_rd <= 1;
            o_salt_rd <= 0;
            o_aux_rd <= 0;
            o_hash_wen <= 1;
            o_hash_start <= 1'b0;
        end

        s_move_aux: begin
            // sel_hash <= 2;
            // first_block <= 0;
            o_leaf_seed_rd <= 0;
            o_salt_rd <= 0;
            o_aux_rd <= 1;
            o_hash_wen <= 1;
            o_hash_start <= 1'b0;
        end

         s_move_last_block: begin
            // sel_hash <= 2;
            // first_block <= 0;
            o_leaf_seed_rd <= 0;
            o_salt_rd <= 0;
            o_aux_rd <= 0;
            o_hash_wen <= 1;
            o_hash_start <= 1'b0;
        end


        s_done_move: begin
            // sel_hash <= 0;
            // first_block <= 0;
            o_hash_wen <= 1;
            o_leaf_seed_rd <= 0;
            o_salt_rd <= 0;
            o_aux_rd <= 0;
            o_hash_start <= 1'b0;
        end

        s_start_hash: begin
            // sel_hash <= 0;
            // first_block <= 0;
            o_hash_wen <= 0;
            o_leaf_seed_rd <= 0;
            o_salt_rd <= 0;
            o_aux_rd <= 0;
            o_hash_start <= 1'b1;
        end

        s_wait_hash_done: begin
            // sel_hash <= 0;
            // first_block <= 0;
            o_hash_wen <= 0;
            o_leaf_seed_rd <= 0;
            o_salt_rd <= 0;
            o_aux_rd <= 0;
            o_hash_start <= 1'b0;
        end
        
        default: begin
            // sel_hash <= 0;
            // first_block <= 0;
            o_hash_wen <= 0;
            o_aux_rd <= 0;
            o_leaf_seed_rd <= 0;
            o_salt_rd <= 0;
            o_hash_start <= 1'b0;
        end
    endcase
end

endmodule