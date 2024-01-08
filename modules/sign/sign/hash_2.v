/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module hash_2 
#(
    parameter PARAMETER_SET                 = "L5",
    parameter LAMBDA =   (PARAMETER_SET == "L1")? 128:
                        (PARAMETER_SET == "L3")? 192:
                        (PARAMETER_SET == "L5")? 256:
                                                 128,
    parameter SALT_SIZE                     = 2*LAMBDA,
    parameter T                             = 3,
    parameter TAU                           =   (PARAMETER_SET == "L1")? 17:
                                                (PARAMETER_SET == "L3")? 26:
                                                (PARAMETER_SET == "L5")? 34:
                                                                         17,
    parameter D_HYPERCUBE                   = 8,
    parameter BROAD_PLAIN_SIZE              = 32*T*2,
    parameter BROAD_SHARE_SIZE              = 32*T*3,
    parameter MAX_MSG_SIZE_BITS             = 1024,
    parameter HASH_OUTPUT_SIZE              = 2*LAMBDA,

    parameter BROAD_PLAIN_SIZE_BYTES        = BROAD_PLAIN_SIZE/8,
    parameter BROAD_SHARE_SIZE_BYTES        = BROAD_SHARE_SIZE/8,
    parameter MAX_MSG_SIZE_BYTES            = MAX_MSG_SIZE_BITS/8,
    
    parameter HASH_BITS                     = 8 + MAX_MSG_SIZE_BITS + SALT_SIZE + TAU*BROAD_PLAIN_SIZE + TAU*D_HYPERCUBE*BROAD_SHARE_SIZE,
    parameter HASH_BITS_ADJ                 = HASH_BITS + (32 - HASH_BITS%32)%32,
    parameter HASH_BITS_NO_MSG              = HASH_BITS - MAX_MSG_SIZE_BITS,

    parameter HASH_BRAM_DEPTH               = HASH_BITS_ADJ/32

)(
    input                                               i_clk,
    input                                               i_rst,

    input [7:0]                                         i_msg,
    input                                               i_msg_valid,
    output                                              o_msg_ready,
    input [`CLOG2(MAX_MSG_SIZE_BYTES)-1:0]              i_msg_size_in_bytes,


    output reg [`CLOG2(SALT_SIZE/32):0]                 o_salt_addr,  
    output reg                                          o_salt_rd,  
    input  [31:0]                                       i_salt,

    output reg [`CLOG2(TAU):0]                          o_broad_plain_addr,  
    output reg                                          o_broad_plain_rd,  
    input  [BROAD_PLAIN_SIZE-1:0]                       i_broad_plain,

    input                                               i_broad_share_valid,
    output reg                                          o_broad_share_ready,
    input  [BROAD_SHARE_SIZE-1:0]                       i_broad_share,

    input                                               i_start,
    output reg                                          o_done,
    
    input  [`CLOG2(HASH_OUTPUT_SIZE/32)-1:0]            i_h2_addr,
    input                                               i_h2_rd,
    output  [31:0]                                      o_h2,
    
        // hash interface
    output   [32-1:0]                                   o_hash_data_in,
    input    [`CLOG2(HASH_BRAM_DEPTH) -1:0]             i_hash_addr,
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


assign o_hash_input_length = hash_input_size;
assign o_hash_output_length = HASH_OUTPUT_SIZE;
assign o_hash_data_in = bram_out;


reg shift;
reg load;
reg init;

reg [32-1:0] in_reg;


reg  data_type;
wire [7:0] data;
wire [7:0] salt_byte;
wire [7:0] broad_plain_byte;
wire [7:0] broad_share_byte;

reg [3*32*T-1:0] big_shift_reg;

reg load_salt;
reg load_broad_plain;
reg load_broad_share;

always@(posedge i_clk)
begin
    if (load_salt) begin
        big_shift_reg <= {i_salt, {(3*32*T-32){1'b0}}};
    end
    else if (load_broad_plain) begin
        big_shift_reg <= {i_broad_plain, {(32*3*T-32*2*T){1'b0}}};
    end
    else if (load_broad_share) begin
        big_shift_reg <= {i_broad_share};
    end
    else if (shift) begin
        big_shift_reg <= {big_shift_reg[3*32*T-8-1:0], 8'b0};
    end
end

assign data = (data_type == 0)? i_msg : 
                                big_shift_reg[3*32*T-1:3*32*T-8];

always@(posedge i_clk)
begin
    if (init) begin
        in_reg <= 32'h00000002;
    end
    else if (shift) begin
        in_reg <= {in_reg[23:0], data};
    end
end

reg [`CLOG2(HASH_BRAM_DEPTH)-1:0] addr;
always@(posedge i_clk)
begin
    if (i_start || o_done) begin
        addr <= 0;
    end
    else if (wr_en) begin
        addr <= addr + 1;
    end
end

wire [31:0] bram_in_from_reg;
wire [31:0] bram_in;
wire [31:0] bram_out;

assign bram_in_from_reg =   (last_block && count == 1) ? {in_reg[7:0], 24'h000000} :
                            (last_block && count == 2) ? {in_reg[15:0], 16'h0000} :
                            (last_block && count == 3) ? {in_reg[23:0], 8'h00} :
                                                         in_reg;

assign bram_in = (h2_wr_en)? i_hash_data_out: bram_in_from_reg;

mem_single #(.WIDTH(32), .DEPTH(HASH_BRAM_DEPTH)) 
HASH2_IN_BRAM
 (
 .clock(i_clk),
 .data(bram_in),
 .address(i_h2_rd? {0,i_h2_addr} :h2_wr_en? {0,h2_addr}: i_hash_rd_en? i_hash_addr: wr_en? addr: addr),
 .wr_en(wr_en || h2_wr_en),
 .q(bram_out)
 );

assign o_h2 = bram_out;

reg h2_wr_en;
reg [`CLOG2(HASH_OUTPUT_SIZE/32)-1:0] h2_addr;

// mem_single #(.WIDTH(32), .DEPTH(HASH_OUTPUT_SIZE/32)) 
//HASH2_OUT_BRAM
// (
// .clock(i_clk),
// .data(i_hash_data_out),
// .address(h2_wr_en? h2_addr :0 ),
// .wr_en(h2_wr_en),
// .q()
// );

reg [3:0] state =0;
reg [4:0] count =0;
parameter s_wait_start                  = 0;
parameter s_load_msg                    = 1;
parameter s_load_salt                   = 2;
parameter s_shift_salt                  = 3;
parameter s_load_broad_plain            = 4;
parameter s_shift_broad_plain           = 5;
parameter s_wait_for_broad_share_done   = 6;
parameter s_shift_broad_share           = 7;
parameter s_last_block                  = 8;
parameter s_hash_start                  = 9;
parameter s_hash_done                   = 10;
parameter s_done                        = 11;

reg [`CLOG2(HASH_BITS):0] hash_input_size = 0;

reg last_block;
reg [`CLOG2(3*32*T/8):0] count_salt = 0;


// reg [`CLOG2(3*T):0] count_salt = 0;

reg [`CLOG2(MAX_MSG_SIZE_BYTES)-1:0] count_msg_bytes = 0;
reg [`CLOG2(TAU*D_HYPERCUBE):0] count_broad_share_blocks = 0;
reg [`CLOG2(MAX_MSG_SIZE_BYTES)-1:0] msg_bytes;
reg wr_en = 0;
always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        count <= 1;
        count_msg_bytes <= 0;
        o_done <= 0;
        msg_bytes <= 0;
        o_salt_addr <= 0;
        count_salt <= 0;
        o_broad_plain_addr <= 0;
        count_broad_share_blocks <= 0;
        o_broad_share_ready <= 0;
        h2_addr <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            o_salt_addr <= 0;
            count_salt <= 0;
            o_broad_plain_addr <= 0;
            count_broad_share_blocks <= 0;
            o_broad_share_ready <= 0;
            h2_addr <= 0;
            if (i_start) begin
                state <= s_load_msg;
                count <= 1;
                count_msg_bytes <= 0;
                o_done <= 0;
                msg_bytes <= i_msg_size_in_bytes;
                hash_input_size <= {i_msg_size_in_bytes, 3'b000} + HASH_BITS_NO_MSG;
            end
        end 

        else if (state == s_load_msg) begin
           if (count_msg_bytes == msg_bytes) begin 
                state <= s_shift_salt;
                count_msg_bytes <= 0; 
           end 
           else begin
                if (i_msg_valid) begin
                    state <= s_load_msg;
                    count_msg_bytes <= count_msg_bytes + 1;
                    if (count == 3) begin
                        count <= 0;
                    end
                    else begin
                        count <= count + 1;
                    end
                end
           end
        end

        else if (state == s_load_salt) begin
            if (o_salt_addr == SALT_SIZE/32) begin
                state <= s_shift_broad_plain;
            end
            else begin
                state <= s_shift_salt;
            end

            if (count == 3) begin
                count <= 0;
            end
            else begin
                count <= count + 1;
            end

            if (count_salt == 3) begin
                count_salt <= 0;
            end
            else begin
                count_salt <= count_salt + 1;
            end
        end

        else if (state == s_shift_salt) begin
            // state <= s_shift;
            if (count_salt == 2) begin
                state <= s_load_salt;
            end

            if (count_salt == 3) begin
                count_salt <= 0;
            end
            else begin
                count_salt <= count_salt + 1;
            end

            if (count == 3) begin
                count <= 0;
            end
            else begin
                count <= count + 1;
            end

            if (count_salt == 1) begin
                o_salt_addr <= o_salt_addr + 1;
            end

        end

        else if (state == s_load_broad_plain) begin
            if (o_broad_plain_addr == TAU) begin
                state <= s_wait_for_broad_share_done;
            end
            else begin
                state <= s_shift_broad_plain;
            end

            if (count == 3) begin
                count <= 0;
            end
            else begin
                count <= count + 1;
            end

            if (count_salt == BROAD_PLAIN_SIZE_BYTES - 1) begin
                count_salt <= 0;
            end
            else begin
                count_salt <= count_salt + 1;
            end 
        end

        else if (state == s_shift_broad_plain) begin
            if (count_salt == BROAD_PLAIN_SIZE_BYTES - 2) begin
                state <= s_load_broad_plain;
            end

            if (count_salt == BROAD_PLAIN_SIZE_BYTES - 1) begin
                count_salt <= 0;
            end
            else begin
                count_salt <= count_salt + 1;
            end

            if (count == 3) begin
                count <= 0;
            end
            else begin
                count <= count + 1;
            end

            if (count_salt == BROAD_PLAIN_SIZE_BYTES - 3) begin
                o_broad_plain_addr <= o_broad_plain_addr + 1;
            end
        end

        else if (state == s_wait_for_broad_share_done) begin
            if (count_broad_share_blocks == TAU*D_HYPERCUBE) begin
                state <= s_last_block; 
                o_broad_share_ready <= 0;
            end
            else begin
                if (i_broad_share_valid) begin
                    state <= s_shift_broad_share;
                    count_broad_share_blocks <= count_broad_share_blocks + 1;
                    o_broad_share_ready <= 0;
                end
                else begin
                    o_broad_share_ready <= 1;
                end
            end
        end

        else if (state == s_shift_broad_share) begin
            if (count_salt == BROAD_SHARE_SIZE_BYTES - 1) begin
                state <= s_wait_for_broad_share_done;
            end

            if (count_salt == BROAD_SHARE_SIZE_BYTES - 1) begin
                count_salt <= 0;
            end
            else begin
                count_salt <= count_salt + 1;
            end

            if (count == 3) begin
                count <= 0;
            end
            else begin
                count <= count + 1;
            end

        end

        else if (state == s_last_block) begin
            state <= s_hash_start;
        end

        else if (state == s_hash_start) begin
           state <= s_hash_done; 
        end

        else if (state == s_hash_done) begin
            if (h2_addr == HASH_OUTPUT_SIZE/32 - 1) begin
                state <= s_done;
                h2_addr <= 0;
            end
            else begin
                if (i_hash_data_out_valid) begin
                    h2_addr <= h2_addr + 1;
                end
            end
        end

        else if (state == s_done) begin
            state <= s_wait_start;
            o_done <= 1;
            count <= 0;
        end

    end
end

always@(*)
begin
    case(state)

    s_wait_start:begin
        shift <= 0;
        data_type <= 0;
        wr_en <= 0;
        load_salt <= 0;
        o_salt_rd <= 0;
        load_broad_plain <= 0;
        o_broad_plain_rd <= 0;
        load_broad_share <= 0;
        last_block <= 0;
        o_hash_start <= 0;
        h2_wr_en <= 0;
        o_hash_force_done <= 0;
        o_hash_data_out_ready <= 0;
        if (i_start) begin
            init <= 1;
        end
        else begin
            init <= 0;
            wr_en <= 0;
        end
    end
     
    s_load_msg:begin
        if (count_msg_bytes == msg_bytes) begin
            data_type <= 1;
            load_salt <= 1;
             o_salt_rd <= 1;
        end
        else begin 
            data_type <= 0;
            load_salt <= 0;
            o_salt_rd <= 0;
        end
        
        if (i_msg_valid) begin
            shift <= 1;
        end
        else begin
            shift <= 0;
        end

        init <= 0;
        
        if (count == 0) begin
            wr_en <= 1;
        end
        else begin
            wr_en <= 0;
        end

        load_broad_plain <= 0;
        o_broad_plain_rd <= 0;
        load_broad_share <= 0;
        last_block <= 0;
        o_hash_start <= 0;
        h2_wr_en <= 0;
        o_hash_data_out_ready <= 0;
        o_hash_force_done <= 0;
    end

    s_load_salt: begin
        if (o_salt_addr < SALT_SIZE/32) begin
            load_salt <= 1;
            o_salt_rd <= 1;
            load_broad_plain <= 0;
        end
        else begin
            load_salt <= 0;
            o_salt_rd <= 0;
            load_broad_plain <= 1;
        end

        shift <= 1;
        data_type <= 1;

        if (count == 0) begin
            wr_en <= 1;
        end
        else begin
            wr_en <= 0;
        end
        o_broad_plain_rd <= 1;
        load_broad_share <= 0;
        last_block <= 0;
        o_hash_start <= 0;
        h2_wr_en <= 0;
        o_hash_data_out_ready <= 0;
        o_hash_force_done <= 0;
    end

    s_shift_salt: begin
        data_type <= 1;
        shift <= 1;
        load_salt <= 0;
        last_block <= 0;
        o_hash_start <= 0;
        if (count == 0) begin
            wr_en <= 1;
        end
        else begin
            wr_en <= 0;
        end

        o_broad_plain_rd <= 1;
        load_broad_share <= 0;
        last_block <= 0;
        o_hash_start <= 0;
        h2_wr_en <= 0;
        o_hash_data_out_ready <= 0;
        o_hash_force_done <= 0;
    end

    s_load_broad_plain: begin
        if (o_broad_plain_addr < TAU) begin
            load_broad_plain <= 1;
            o_broad_plain_rd <= 1;
        end
        else begin
            load_broad_plain <= 0;
            o_broad_plain_rd <= 0;
        end

        shift <= 1;
        data_type <= 1;
        load_salt <= 0;
        o_salt_rd <= 0;
        load_broad_share <= 0;
        last_block <= 0;
        o_hash_start <= 0;
        h2_wr_en <= 0;
        o_hash_data_out_ready <= 0;
        o_hash_force_done <= 0;
        if (count == 0) begin
            wr_en <= 1;
        end
        else begin
            wr_en <= 0;
        end
    end

    s_shift_broad_plain: begin
        data_type <= 1;
        shift <= 1;
        load_salt <= 0;
        load_broad_plain <= 0;
        o_broad_plain_rd <= 1;
        load_broad_share <= 0;
        last_block <= 0;
        o_hash_start <= 0;
        h2_wr_en <= 0;
        o_hash_data_out_ready <= 0;
        o_hash_force_done <= 0;
        if (count == 0) begin
            wr_en <= 1;
        end 
        else begin
            wr_en <= 0;
        end
    end
    
    s_wait_for_broad_share_done: begin
        data_type <= 1;
        shift <= 0;
        load_salt <= 0;
        load_broad_plain <= 0;
        o_broad_plain_rd <= 0;
        wr_en <= 0;
        last_block <= 0;
        o_hash_start <= 0;
        h2_wr_en <= 0;
        o_hash_data_out_ready <= 0;
        o_hash_force_done <= 0;
        if (i_broad_share_valid) begin
            load_broad_share <= 1;
        end
        else begin
            load_broad_share <= 0;
        end
    end

    s_shift_broad_share: begin
        data_type <= 1;
        shift <= 1;
        load_salt <= 0;
        load_broad_plain <= 0;
        o_broad_plain_rd <= 0;
        load_broad_share <= 0;
        last_block <= 0;
        o_hash_start <= 0;
        h2_wr_en <= 0;
        o_hash_data_out_ready <= 0;
        o_hash_force_done <= 0;
        if (count == 0) begin
            wr_en <= 1;
        end 
        else begin
            wr_en <= 0;
        end
    end

    s_last_block: begin
        last_block <= 1;
        // if (count == 0) begin
        //     wr_en <= 0;
        // end
        // else begin
        wr_en <= 1;
        // end
        data_type <= 1;
        shift <= 0;
        load_salt <= 0;
        load_broad_share <= 0;
        load_broad_plain <= 0;
        o_hash_start <= 0;
        h2_wr_en <= 0;
        o_hash_data_out_ready <= 0;
        o_hash_force_done <= 0;
    end
    
    s_hash_start: begin
        last_block <= 0;
        wr_en <= 0;
        data_type <= 0;
        shift <= 0;
        load_salt <= 0;
        load_broad_share <= 0;
        load_broad_plain <= 0;
        o_hash_start <= 1;
        h2_wr_en <= 0;
        o_hash_data_out_ready <= 0;
        o_hash_force_done <= 0;
    end

    s_hash_done: begin
        last_block <= 0;
        wr_en <= 0;
        data_type <= 0;
        shift <= 0;
        load_salt <= 0;
        load_broad_share <= 0;
        load_broad_plain <= 0;
        o_hash_start <= 0;
        o_hash_data_out_ready <= 1;
        o_hash_force_done <= 0;
        if (i_hash_data_out_valid) begin
            h2_wr_en <= 1;
        end
        else begin
            h2_wr_en <= 0;
        end
    end

    s_done: begin
        data_type <= 0;
        wr_en <= 0;
        shift <= 0;
        load_salt <= 0;
        load_broad_share <= 0;
        load_broad_plain <= 0;
        last_block <= 0;
        o_hash_start <= 0;
        h2_wr_en <= 0;
        o_hash_data_out_ready <= 0;
        o_hash_force_done <= 1;
    end

    default:begin
        data_type <= 0;
        init <= 0;
        shift <= 0;
        wr_en <= 0;
        load_salt <= 0;
        load_broad_plain <= 0;
        load_broad_share <= 0;
        last_block <= 0;
        o_hash_start <= 0;
        h2_wr_en <= 0;
        o_hash_data_out_ready <= 0;
        o_hash_force_done <= 0;
    end

    endcase
end





endmodule