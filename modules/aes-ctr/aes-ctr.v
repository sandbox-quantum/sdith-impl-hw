// Copyright (c) SandboxAQ. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// This file is the PRNG module using AES-CTR mode

module aes_ctr_prng
#(
   parameter SEED_SIZE = 256
)
(
    input i_clk,
    input i_rst,
    input i_start,
    input [SEED_SIZE-1:0] i_seed, 
    output reg o_seed_ready, 
    
    input i_reset_seed,

    input [15:0] i_no_of_bits,
    
    input i_prng_out_ready,
    output reg o_prng_out_valid,
    output [128-1:0] o_prng_out

);


reg start_aes;
wire ready_aes;
reg init_aes;
wire done_aes;
wire done_init_aes;

reg [127:0] ctr;
wire [127:0] aes_out;

reg ctr_init, ctr_update;

always@(posedge i_clk)
begin
    if (ctr_init) begin
        ctr <= 0;
    end
    else if (ctr_update) begin
        ctr <= ctr + 1;
    end
end

assign o_prng_out = aes_out;
AES_Enc
AES_ENCRYPT
    (
        .rst(i_rst),
        .clk(i_clk),
        .start(start_aes),
        .ready(ready_aes),
        .init(init_aes),
        .done(done_aes),
        .done_init(done_init_aes),
        .din(ctr),
        .dout(aes_out),
        .key(i_seed)
    );

reg  [3:0] state = 0;    
parameter s_wait_start      = 0;
parameter s_wait_aes_init   = 1;
parameter s_start_enc       = 2;
parameter s_wait_out_ready  = 3;
parameter s_no_key_update   = 4;

reg [8:0] no_of_blocks;

always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        o_prng_out_valid <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            o_prng_out_valid <= 0;
            if (i_start) begin
                no_of_blocks <= i_no_of_bits[15:7];
                state <= s_wait_aes_init;
                o_seed_ready <= 0;
            end
            else begin
                no_of_blocks <= 0;
                o_seed_ready <= 1;
            end
        end

        else if (state == s_wait_aes_init) begin
            o_prng_out_valid <= 0;
            if (i_reset_seed) begin
                state <= s_wait_start;
                o_seed_ready <= 1;
            end
            else begin
                if (ready_aes) begin
                    state <= s_start_enc;
                    o_seed_ready <= 0;
                end
            end
        end

        else if (state == s_start_enc) begin
            if (i_reset_seed) begin
                state <= s_wait_start;
                o_prng_out_valid <= 0;
                o_seed_ready <= 1;
            end
            else begin
                o_seed_ready <= 0;
                if (done_aes) begin
                    o_prng_out_valid <= 1;
                    state <= s_wait_out_ready;
                    if (no_of_blocks != 0) begin
                        no_of_blocks <= no_of_blocks - 1;
                    end 
                end
                else begin
                    o_prng_out_valid <= 0;
                end
            end
        end

        else if (state == s_wait_out_ready) begin
            if (i_reset_seed) begin
                state <= s_wait_start;
                o_prng_out_valid <= 0;
                o_seed_ready <= 1;
            end
            else begin
                o_seed_ready <= 0;
                if (i_prng_out_ready) begin
                    o_prng_out_valid <= 0;
                    if (no_of_blocks == 0) begin
                        state <= s_no_key_update;
                    end
                    else begin
                    state <= s_start_enc; 
                    end
                end
                else begin
                    o_prng_out_valid <= 1;
                end
            end
        end

        else if (state == s_no_key_update) begin
            if (i_reset_seed) begin
                state <= s_wait_start;
                o_prng_out_valid <= 0;
                o_seed_ready <= 1;
            end
            else begin
                o_seed_ready <= 0;
                if (i_start) begin
                    if (ready_aes) begin
                        state <= s_start_enc;
                        o_seed_ready <= 0;
                    end
                end 
            end
        end
    end
end

always@(state, i_start, ready_aes, i_prng_out_ready, no_of_blocks)
begin
    case(state)

    s_wait_start: begin
        ctr_init <= 1;
        ctr_update <= 0;
        if (i_start) begin
            init_aes <= 1;
        end
        else begin
            init_aes <= 0;
        end
    end

    s_wait_aes_init: begin
        init_aes <= 0;
        ctr_init <= 0;
        ctr_update <= 0;
        if (ready_aes) begin
            start_aes <= 1;
        end
        else begin
            start_aes <= 0;
        end
    end

    s_start_enc: begin
        start_aes <= 0;
        init_aes <= 0;
        ctr_init <= 0;
        if (done_aes) begin
            ctr_update <= 1;
        end
    end

    s_wait_out_ready: begin
        init_aes <= 0;
        ctr_init <= 0;
        ctr_update <= 0;
        if (i_prng_out_ready) begin
            if (no_of_blocks > 0) begin
                start_aes <= 1;
            end
            else begin
                start_aes <= 0;
            end
        end
        else begin
            start_aes <= 0;
        end
    end

    s_no_key_update: begin
        init_aes <= 0;
        ctr_init <= 0;
        ctr_update <= 0;
        if (i_start) begin
            if (ready_aes) begin
                start_aes <= 1;
            end
            else begin
                start_aes <= 0;
            end
        end
    end

    default: begin
        start_aes <= 0;
        init_aes <= 0;
        ctr_init <= 0;
        ctr_update <= 0;
    end
    endcase

end


endmodule
