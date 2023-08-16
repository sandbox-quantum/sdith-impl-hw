/*
 * This file is TREEPRG module which part of SDitH sign.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module treeprg 
#(
    parameter PARAMETER_SET = "L1",
    
    parameter LAMBDA =   (PARAMETER_SET == "L1")? 128:
                            (PARAMETER_SET == "L3")? 192:
                            (PARAMETER_SET == "L5")? 256:
                                                     128,



    parameter  K =  (PARAMETER_SET == "L1")? 126:
                    (PARAMETER_SET == "L3")? 193:
                    (PARAMETER_SET == "L5")? 278:
                                               1,


    parameter SEED_SIZE = LAMBDA,
    
    parameter D_HYPERCUBE = 8,
    
    parameter NUMBER_OF_SEED_BITS = (2**(D_HYPERCUBE)+1) * LAMBDA,
    
    parameter SALT_SIZE = 2*LAMBDA,
    
    
    parameter TREEPRG_SIZE = SEED_SIZE*(2**(D_HYPERCUBE+1)) + SEED_SIZE,
    parameter TREEPRG_DEPTH = (TREEPRG_SIZE)/32 

)(
    input                                               i_clk,
    input                                               i_rst,
    input                                               i_start,
    output reg                                          o_done,

    // input   [32-1:0]                                    i_salt,
    // input   [`CLOG2(SALT_SIZE/32)-1:0]                  i_salt_addr,
    // input                                               i_salt_wr_en,

    input   [32-1:0]                                    i_salt,
    output   [`CLOG2(SALT_SIZE/32)-1:0]                 o_salt_addr,
    output                                              o_salt_rd,

    input   [32-1:0]                                    i_seed,
    input   [`CLOG2(SEED_SIZE/32)-1:0]                  i_seed_addr,
    input                                               i_seed_wr_en,

    output   [32-1:0]                                   o_seed_e,
    input   [`CLOG2(TREEPRG_SIZE/32)-1:0]               i_seed_e_addr,
    input                                               i_seed_e_rd,

    output reg                                          o_treeprg_processing,        
    // hash interface
    output   [32-1:0]                                   o_hash_data_in,
    input    [`CLOG2((SEED_SIZE+SALT_SIZE)/32) -1:0]    i_hash_addr,
    input                                               i_hash_rd_en,

    input    wire [32-1:0]                              i_hash_data_out,
    input    wire                                       i_hash_data_out_valid,
    output   reg                                        o_hash_data_out_ready,

    output   wire  [32-1:0]                             o_hash_input_length, // in bits
    output   wire  [32-1:0]                             o_hash_output_length, // in bits

    output   reg                                        o_hash_start,
    input    wire                                       i_hash_force_done_ack,
    output   reg                                        o_hash_force_done

);


reg [`CLOG2((SEED_SIZE+SALT_SIZE)/32) -1:0]    hash_addr_reg;
always@(posedge i_clk)
begin
    hash_addr_reg <= i_hash_addr;
end

assign o_salt_addr = i_hash_rd_en? i_hash_addr : 0;
assign o_salt_rd = i_hash_rd_en;

assign o_hash_input_length = SALT_SIZE + SEED_SIZE;
assign o_hash_output_length = 2*SEED_SIZE;
assign o_hash_data_in = (hash_addr_reg < SALT_SIZE/32)? i_salt : seed;


// wire [31:0]salt;

// mem_single #(.WIDTH(32), .DEPTH(SALT_SIZE/32)) 
//  SALT_MEM
//  (
//  .clock(i_clk),
//  .data(i_salt),
//  .address(i_salt_wr_en? i_salt_addr : i_hash_rd_en? i_hash_addr : 0),
//  .wr_en(i_salt_wr_en),
//  .q(salt)
//  );

wire [31:0]seed;
wire [`CLOG2(TREEPRG_DEPTH)-1:0]  addr;
reg [`CLOG2(TREEPRG_DEPTH)-1:0]  addr_int = 0;
reg wren;

assign addr =   i_seed_wr_en? i_seed_addr: 
                i_seed_e_rd? i_seed_e_addr : 
                i_hash_rd_en? i_hash_addr + offset_addr:
                addr_int;

 mem_single #(.WIDTH(32), .DEPTH(TREEPRG_DEPTH)) 
 SEED_TREE_PRG
 (
 .clock(i_clk),
 .data(i_seed_wr_en? i_seed: i_hash_data_out),
 .address(addr),
 .wr_en(i_seed_wr_en || wren),
 .q(seed)
 );

assign o_seed_e = seed;

 reg [3:0] state = 0;

reg [`CLOG2(2**D_HYPERCUBE+1):0] count_seeds;
reg [`CLOG2(2*SEED_SIZE/32):0] count_hash = 0;
reg first;
reg [`CLOG2(TREEPRG_DEPTH)-1:0] offset_addr = 0;

parameter s_wait_start               = 0;
parameter s_wait_hash_first          = 1;
parameter s_check_count_seed         = 2;
parameter s_wait_hash_valid          = 3;
parameter s_wait_force_done_ack      = 4;
parameter s_done                    = 15;



always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        count_hash <= 0;
        count_seeds <= 0;
        addr_int <= LAMBDA/32;
        o_done <= 0;
        o_hash_force_done <= 0;
        offset_addr <= -SALT_SIZE/32;
    end
    else begin
        if (state == s_wait_start) begin
                count_hash <= 0;
                o_done <= 0;
                addr_int <= LAMBDA/32;
                count_seeds <= 0;
                o_hash_force_done <= 0;
                offset_addr <= -SALT_SIZE/32;
                if (i_start) begin
                    state <= s_wait_hash_first;
                end
        end 

        else if (state == s_wait_hash_first) begin
            if (count_hash == 2*SEED_SIZE/32) begin
                count_hash <= 0;
                state <= s_wait_force_done_ack;
                o_hash_force_done <= 1;
                count_seeds <= count_seeds + 2;
                offset_addr <= offset_addr + SEED_SIZE/32;
            end
            else begin
                if (i_hash_data_out_valid) begin
                    count_hash <= count_hash + 1;
                    addr_int <= addr_int+1;
                end
            end  
        end
        
        else if (state == s_check_count_seed) begin  
            o_hash_force_done <= 0;
            if (count_seeds <= 2**(D_HYPERCUBE+1) - 1) begin
                state <= s_wait_hash_valid;
            end
            else begin
               state <= s_done;
            end
        end

        else if (state == s_wait_hash_valid) begin
            if (count_hash == 2*SEED_SIZE/32) begin
                count_hash <= 0;
                state <= s_wait_force_done_ack;
                o_hash_force_done <= 1;
                count_seeds <= count_seeds + 2;
                offset_addr <= offset_addr + SEED_SIZE/32;
            end
            else begin
                if (i_hash_data_out_valid) begin
                    count_hash <= count_hash + 1;
                    addr_int <= addr_int+1;
                end
            end  
        end

        else if (state == s_wait_force_done_ack) begin
            o_hash_force_done <= 0;
            if (i_hash_force_done_ack) begin
                state <= s_check_count_seed;
            end
        end

        else if (state == s_done) begin
            state <= s_wait_start;
            o_done <= 1;
            o_hash_force_done <= 0;
            count_seeds <= 0;
        end

    end
end

always@(state, i_start, i_hash_data_out_valid, count_seeds, count_hash)
begin
    case(state)

    s_wait_start:begin
        wren <= 0;
        o_hash_data_out_ready <= 0;
        if (i_start) begin
            o_hash_start <= 1;
            o_treeprg_processing <= 1;
        end
        else begin
            o_hash_start <= 0;
            o_treeprg_processing <= 0;
        end
    end

    s_wait_hash_first: begin
        o_hash_start <= 0;
        o_treeprg_processing <= 1;
        if (i_hash_data_out_valid) begin
            o_hash_data_out_ready <= 1;
            wren <= 1;
        end
        else begin
            o_hash_data_out_ready <= 0;
            wren <= 0;
        end
    end

    s_check_count_seed: begin
        wren <= 0;
        o_hash_data_out_ready <= 0;
        o_treeprg_processing <= 1;
        if (count_seeds < 2**(D_HYPERCUBE+1) - 1) begin
            o_hash_start <= 1;
        end
        else begin
            o_hash_start <= 0;
        end
    end

    s_wait_hash_valid:begin
        o_hash_start <= 0;
        o_treeprg_processing <= 1;
        if (i_hash_data_out_valid) begin
            o_hash_data_out_ready <= 1;
            wren <= 1;
        end
        else begin
            o_hash_data_out_ready <= 0;
            wren <= 0;
        end
    end

    s_wait_force_done_ack: begin
        o_hash_data_out_ready <= 0;
        wren <= 0;
        o_hash_start <= 0;
        o_treeprg_processing <= 1;
    end

    s_done: begin
        o_hash_data_out_ready <= 0;
        wren <= 0;
        o_hash_start <= 0;
        o_treeprg_processing <= 0;
    end

    default:begin
        o_hash_data_out_ready <= 0;
        wren <= 0;
        o_hash_start <= 0;
        o_treeprg_processing <= 0;
    end

    endcase
end





endmodule