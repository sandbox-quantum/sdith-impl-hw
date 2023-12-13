/*
 * This file is GetLeavesFromSiblingPath module which part of SDitH verify.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/

`include "clog2.v"

module commit_hash 
#(
    parameter PARAMETER_SET = "L1",
    
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
    
    parameter D_HYPERCUBE = 8,
    
    parameter NUMBER_OF_SEED_BITS = (2**(D_HYPERCUBE)+1) * LAMBDA,

    parameter SIZE_OF_R     = TAU*T*D_SPLIT*8,
    parameter SIZE_OF_EPS   = TAU*T*D_SPLIT*8
    

)(
    input                                               i_clk,
    input                                               i_rst,

    input                                               i_start,
    output reg                                          o_done,

    input  [31:0]                                       i_salt,
    output [`CLOG2(SALT_SIZE/32)-1:0]                   o_salt_addr,
    output                                              o_salt_rd,

    input  [31:0]                                       i_leaf_seed,
    output [`CLOG2(SALT_SIZE/32)-1:0]                   o_leaf_seed_addr,
    output                                              o_leaf_seed_rd,

    input  [15:0]                                       i_iteration,
    input  [15:0]                                       i_leaf_idx,

    input  [15:0]                                       i_leaf_rho,

    input  [31:0]                                       i_aux,
    output [`CLOG2(SALT_SIZE/32)-1:0]                   o_aux_addr,
    output                                              o_aux_rd


    // hash interface
    // output   [32-1:0]                                   o_hash_data_in,
    // input    [`CLOG2((SALT_SIZE+SEED_SIZE)/32) -1:0]            i_hash_addr,
    // input                                               i_hash_rd_en,

    // input    wire [32-1:0]                              i_hash_data_out,
    // input    wire                                        i_hash_data_out_valid,
    // output   reg                                        o_hash_data_out_ready,

    // output   wire  [32-1:0]                             o_hash_input_length, // in bits
    // output   wire  [32-1:0]                             o_hash_output_length, // in bits

    // output   reg                                        o_hash_start,
    // input    wire                                       i_hash_force_done_ack,
    // output   reg                                        o_hash_force_done

);






reg [3:0] state;



always@(posedge i_clk) begin
    if(i_rst) begin
        o_done <= 1'b0;
    end
    else begin
        if(i_start) begin
            o_done <= 1'b0;
        end
        else begin
            o_done <= 1'b1;
        end
    end
end



endmodule