`timescale 1ns / 1ps
/*
 * This file is the AES-CTR PRNG testbench
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module aes_ctr_prng_tb
#(
   parameter SEED_SIZE = 192
)(

    );
   

    reg i_clk = 0;
    reg i_rst;
    reg i_start;
    
    reg [SEED_SIZE-1:0] i_seed; 
    wire o_seed_ready; 
    
    reg i_reset_seed = 0;

    reg [15:0] i_no_of_bits;
    
    reg i_prng_out_ready;
    wire o_prng_out_valid;
    wire [128-1:0] o_prng_out;

aes_ctr_prng #(.SEED_SIZE(SEED_SIZE)) uut
    (
        .i_rst(i_rst),
        .i_clk(i_clk),
        .i_start(i_start),
        .i_seed(i_seed),
        .o_seed_ready(o_seed_ready),
        .i_reset_seed(i_reset_seed),
        .i_no_of_bits(i_no_of_bits),
        .i_prng_out_ready(i_prng_out_ready),
        .o_prng_out_valid(o_prng_out_valid),
        .o_prng_out(o_prng_out)
    );

initial
begin
    i_rst <= 1;
    i_seed <= 0;
    i_start <= 0;
    i_prng_out_ready <= 0;
    i_reset_seed <= 0;
    #100

    i_rst <= 0;
    #10
    i_start <= 1;
    i_no_of_bits <= 2560;
    // i_prng_out_ready <= 1;
    #10
    i_start <= 0;

    // @(posedge o_prng_out_valid)
    // #10
    // @(posedge o_prng_out_valid)
    // #100
    
    // i_reset_seed <= 1;
    // #10
    // i_reset_seed <= 0;
    // #100

    // i_seed <= 1;
    // i_start <= 1;
    // i_no_of_bits <= 127;
    // #10
    // i_start <= 0;

    // @(posedge o_prng_out_valid)
    #10


    $finish; 
    
end

always #5 i_clk = !i_clk;

endmodule
