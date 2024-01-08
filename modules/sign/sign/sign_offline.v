/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module sign_offline 
#(
   parameter WIDTH = 32,

   parameter FIELD = "GF256",
//     parameter FIELD = "P251",

    parameter PARAMETER_SET = "L5",
    
    parameter LAMBDA =   (PARAMETER_SET == "L1")? 128:
                            (PARAMETER_SET == "L3")? 192:
                            (PARAMETER_SET == "L5")? 256:
                                                     128,
                                                    
    parameter M =  (PARAMETER_SET == "L1")? 230:
                        (PARAMETER_SET == "L3")? 352:
                        (PARAMETER_SET == "L5")? 480:
                                                 230,

    parameter WEIGHT =  (PARAMETER_SET == "L1")? 79:
                        (PARAMETER_SET == "L3")? 120:
                        (PARAMETER_SET == "L5")? 150:
                                                 79,

    parameter D_SPLIT = (PARAMETER_SET == "L1")? 1:
                        (PARAMETER_SET == "L3")? 2:
                        (PARAMETER_SET == "L5")? 2:
                                                 1,
    //  k + 2w + t(2d + 1)η

    parameter  K =  (PARAMETER_SET == "L1")? 126:
                    (PARAMETER_SET == "L3")? 193:
                    (PARAMETER_SET == "L5")? 278:
                                               1,

    parameter  TAU =    (PARAMETER_SET == "L1")? 17:
                        (PARAMETER_SET == "L3")? 26: //check and update
                        (PARAMETER_SET == "L5")? 34: //check and update
                                               17,
    
    parameter D_HYPERCUBE = 8,
    parameter ETA = 4,

    parameter T =   (PARAMETER_SET == "L5")? 4:
                                             3, 

    parameter SEED_SIZE = LAMBDA,
    parameter SALT_SIZE = 2*LAMBDA,
    parameter NUMBER_OF_SEED_BITS = (2**D_HYPERCUBE) * SEED_SIZE,

    parameter HASH_INPUT_SIZE = LAMBDA + 2*LAMBDA,
    
    parameter HASH_OUTPUT_SIZE = 8*(K + 2*D_SPLIT*WEIGHT + T*D_SPLIT*3),
    parameter HO_SIZE_ADJ = HASH_OUTPUT_SIZE + (WIDTH - HASH_OUTPUT_SIZE%WIDTH)%WIDTH,
    
    parameter SK_SIZE = 8*(K + 2*D_SPLIT*WEIGHT),
    parameter SK_SIZE_ADJ = SK_SIZE + (WIDTH - SK_SIZE%WIDTH)%WIDTH,

    parameter Y_SIZE = (M-K)*8,
    parameter Y_SIZE_ADJ = Y_SIZE + (WIDTH - Y_SIZE%WIDTH)%WIDTH,

    parameter COMMIT_INPUT_SIZE = SALT_SIZE + SEED_SIZE + 32,
    parameter COMMIT_INPUT_SIZE_LAST = SALT_SIZE + SEED_SIZE + HASH_OUTPUT_SIZE + 32,
    parameter COMMIT_OUTPUT_SIZE = LAMBDA,
    parameter COMMIT_RAM_DEPTH = (COMMIT_OUTPUT_SIZE*(2**D_HYPERCUBE))/32,

    parameter HASH1_SIZE = 8 + SEED_SIZE + Y_SIZE + SALT_SIZE + COMMIT_OUTPUT_SIZE*(2**D_HYPERCUBE)*TAU,
    parameter HASH1_SIZE_ADJ = HASH1_SIZE + (WIDTH - HASH1_SIZE%WIDTH)%WIDTH, 

    parameter N_GF = 4,

    parameter MAT_ROW_SIZE_BYTES = M-K,                                                            
    parameter MAT_COL_SIZE_BYTES  =K,

    //ExpandH
    parameter MAT_SIZE_BYTES = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES,
    parameter PROC_SIZE = N_GF*8,
    parameter MRS_BITS = MAT_ROW_SIZE_BYTES*8,
    parameter MCS_BITS = MAT_COL_SIZE_BYTES*8,
    parameter MAT_ROW_SIZE = MRS_BITS + (PROC_SIZE - MRS_BITS%PROC_SIZE)%PROC_SIZE,
    parameter MAT_COL_SIZE = MCS_BITS + (PROC_SIZE - MCS_BITS%PROC_SIZE)%PROC_SIZE,
    parameter MAT_SIZE = MAT_ROW_SIZE*MAT_COL_SIZE_BYTES,
    parameter MS = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES*8,
    parameter H_SHAKE_SQUEEZE = 2*(MS + (32-MS%32)%32),

    parameter TEST_SET = 0
    

)(
    input                                               i_clk,
    input                                               i_rst,

    input                                               i_start,

    

    input   [32-1:0]                                    i_mseed,
    input   [`CLOG2(SEED_SIZE/32)-1:0]                  i_mseed_addr,
    input                                               i_mseed_wr_en,

    input   [32-1:0]                                    i_salt,
    input   [`CLOG2(SALT_SIZE/32)-1:0]                  i_salt_addr,
    input                                               i_salt_wr_en,

    
    

    output   [32-1:0]                                   o_com,
    input   [`CLOG2(HASH1_SIZE_ADJ/WIDTH)-1:0]          i_com_addr,
    input                                               i_com_rd_en,

    output  [32*T-1:0]                                  o_alpha,
    input   [`CLOG2(TAU)-1:0]                           i_alpha_addr,
    input                                               i_alpha_rd_en,

    output  [32*T-1:0]                                  o_beta,
    input   [`CLOG2(TAU)-1:0]                           i_beta_addr,
    input                                               i_beta_rd_en,

    output reg                                          o_done,

    
    // Secret Key
    input   [32-1:0]                                    i_seed_h,
    input   [`CLOG2(SEED_SIZE/32)-1:0]                  i_seed_h_addr,
    input                                               i_seed_h_wr_en,

    input   [32-1:0]                                    i_y,
    input   [`CLOG2(Y_SIZE_ADJ/32)-1:0]                 i_y_addr,
    input                                               i_y_wr_en,

    input   [32-1:0]                                    i_wit_plain,
    input   [`CLOG2(HO_SIZE_ADJ/32)-1:0]                i_wit_plain_addr,
    input                                               i_wit_plain_wr_en,

    input                                               i_sk_wr_en,
    input  [`CLOG2(HO_SIZE_ADJ/32)-1:0]                 i_sk_addr,
    input [WIDTH-1:0]                                   i_sk,

    input  [`CLOG2(D_HYPERCUBE)-1:0]                    i_input_mshare_sel,
    input                                               i_input_mshare_rd_en,
    input  [`CLOG2((TAU-1)*HO_SIZE_ADJ/32)-1:0]         i_input_mshare_addr,
    output [WIDTH-1:0]                                  o_input_mshare,

    output  [32-1:0]                                    o_h1,
    input   [`CLOG2(2*SEED_SIZE/32)-1:0]                i_h1_addr,
    input                                               i_h1_rd_en,

    output reg [2:0]                                    o_status_reg,

    // hash interface
    output   [32-1:0]                                   o_hash_data_in,
    input    [`CLOG2(HASH1_SIZE_ADJ/32) -1:0]           i_hash_addr,
    input                                               i_hash_rd_en,

    input    wire [32-1:0]                              i_hash_data_out,
    input    wire                                       i_hash_data_out_valid,
    output   wire                                       o_hash_data_out_ready,

    output   wire  [32-1:0]                             o_hash_input_length, // in bits
    output   wire  [32-1:0]                             o_hash_output_length, // in bits

    output   wire                                       o_hash_start,
    input    wire                                       i_hash_force_done_ack,
    output   wire                                       o_hash_force_done

);

reg exp_seed_en;
reg commit_en;
reg h1_en;
reg mpc_chal_en;
reg expand_h_en;

assign o_hash_data_in = (exp_seed_en)? ss_out:
                        (commit_en)? com_o_hash_data_in:
                        (h1_en)?     hash1_out:
                        (mpc_chal_en)? mpc_chal_o_hash_data_in:
                        (expand_h_en)? h_o_hash_data_in:
                                        0;

assign o_hash_input_length = (exp_seed_en)? SALT_SIZE+SEED_SIZE:
                             (commit_en)? com_o_hash_input_length:
                             (h1_en)?     HASH1_SIZE:
                             (mpc_chal_en)? mpc_chal_o_hash_input_length:
                             (expand_h_en)? h_o_hash_input_length:
                                             0;
                                            
assign o_hash_output_length =   (exp_seed_en)? TAU*SEED_SIZE:
                                (commit_en)?   com_o_hash_output_length:
                                (h1_en)?     2*SEED_SIZE:
                                (mpc_chal_en)? mpc_chal_o_hash_output_length:
                                (expand_h_en)? h_o_hash_output_length:
                                               0;

assign o_hash_start =   (exp_seed_en || h1_en)?      hash_start_exp_seed:
                        (commit_en)?        com_o_hash_start:
                        (mpc_chal_en)? mpc_chal_o_hash_start:
                        (expand_h_en)?h_o_hash_start:
                                            0;

assign o_hash_force_done  = (exp_seed_en || h1_en)? hash_force_done_exp_seed:
                            (commit_en)?   com_o_hash_force_done:
                            (mpc_chal_en)?   mpc_chal_o_hash_force_done:
                            (expand_h_en)?   h_o_hash_force_done:
                                            0;     


assign o_hash_data_out_ready =  (exp_seed_en || h1_en)? hash_data_out_ready_exp_seed: 
                                (commit_en)?   com_o_hash_data_out_ready:
                                (mpc_chal_en)?   mpc_chal_o_hash_data_out_ready:
                                (expand_h_en)?   h_o_hash_data_out_ready:
                                                0;

wire [31:0] ss_in;
wire [31:0] ss_out;
wire [`CLOG2((SALT_SIZE+SEED_SIZE)/32)-1:0] ss_addr;
wire [`CLOG2((SALT_SIZE+SEED_SIZE)/32)-1:0] mseed_addr_int;
wire ss_wen;

assign mseed_addr_int = {{(2){1'b0}},i_mseed_addr} + SALT_SIZE/32;

assign ss_in = i_salt_wr_en? i_salt: i_mseed;

assign ss_addr =    i_salt_wr_en?                   i_salt_addr: 
                    i_mseed_wr_en?                  mseed_addr_int: 
                    (exp_seed_en && i_hash_rd_en)?  i_hash_addr :
                                                    0;

assign ss_wen = i_salt_wr_en || i_mseed_wr_en;

mem_single #(.WIDTH(32), .DEPTH((SALT_SIZE + SEED_SIZE)/32)) 
 SALT_AND_MSEED_MEM
 (
 .clock(i_clk),
 .data(ss_in),
 .address(en_h1_move? salt_addr :ss_addr),
 .wr_en(ss_wen),
 .q(ss_out)
 );


// remove h1 signals from here
wire [31:0] seed_h;
 mem_single #(.WIDTH(32), .DEPTH(SEED_SIZE/32)) 
 SEED_H_MEM
 (
    .clock(i_clk),
    .data(h1_wr_en? i_hash_data_out: i_seed_h),
    .address(en_h1_move? {1'b0,seed_h_addr} : i_seed_h_wr_en? {1'b0,i_seed_h_addr} : h1_wr_en? h1_addr: i_h1_rd_en? i_h1_addr: 0),
    .wr_en(i_seed_h_wr_en | h1_wr_en),
    .q(seed_h)
 );
 


 wire [31:0] h1_out;
 mem_single #(.WIDTH(32), .DEPTH(2*SEED_SIZE/32)) 
 H1_MEM
 (
    .clock(i_clk),
    .data(i_hash_data_out),
    .address(h1_wr_en? h1_addr: h1_rd_mpc_chal? h1_addr_mpc_chal:  i_h1_rd_en? i_h1_addr: 0),
    .wr_en(h1_wr_en),
    .q(h1_out)
 );

assign o_h1 = h1_out;


 wire [31:0] y_int;
 mem_single #(.WIDTH(32), .DEPTH(Y_SIZE_ADJ/32), .FILE("Y_L1.MEM")) 
 Y_MEM
 (
    .clock(i_clk),
    .data(i_y),
    .address(en_h1_move? y_addr : i_y_addr),
    .wr_en(i_y_wr_en),
    .q(y_int)
 );

parameter RSEED_DEPTH = SEED_SIZE*TAU/32;
wire [31:0] rseed;
reg [`CLOG2(RSEED_DEPTH)-1:0] rseed_addr;
reg rseed_wr_en;

mem_single #(.WIDTH(32), .DEPTH(RSEED_DEPTH)) 
RSEED_MEM
 (
    .clock(i_clk),
    .data(i_hash_data_out),
    .address(rseed_addr),
    .wr_en(rseed_wr_en),
    .q(rseed)
 );



reg [`CLOG2(TAU*COMMIT_RAM_DEPTH)-1:0] commit_addr_t;
wire commit_st_en;

wire [31:0] commit;

always@(posedge i_clk)
begin
    if (i_start) begin
        commit_addr_t <= 0;
    end
    else if (commit_st_en) begin
        commit_addr_t <= commit_addr_t + 1;
    end
end

//commented because we store this in H1_MEM
// mem_single #(.WIDTH(32), .DEPTH(TAU*COMMIT_RAM_DEPTH)) 
//  FULL_COMMIT_MEM
//  (
//     .clock(i_clk),
//     .data(i_hash_data_out),
//     .address(commit_addr_t),
//     .wr_en(commit_st_en),
//     .q(commit)
//  );


wire [WIDTH-1:0] sk_int;
wire [`CLOG2(SK_SIZE_ADJ/WIDTH)-1:0] sk_addr_int;
wire sk_rd_en;

//  mem_single #(.WIDTH(WIDTH), .DEPTH(SK_SIZE_ADJ/WIDTH), .INIT(1), .FILE(FILE_SK)) 
// mem_single #(.WIDTH(WIDTH), .DEPTH(HO_SIZE_ADJ/WIDTH), .INIT(1)) 
// SECRET_KEY // S_A || q_poly || p_poly
// (
// .clock(i_clk),
// .data(i_sk),
// .address(i_sk_wr_en? i_sk_addr: sk_rd_en? sk_addr_int: sk_addr_int),
// .wr_en(i_sk_wr_en),
// .q(sk_int)
// );

 mem_single #(.WIDTH(WIDTH), .DEPTH(HO_SIZE_ADJ/WIDTH), .INIT(1)) 
 SECRET_KEY // S_A || q_poly || p_poly
 (
 .clock(i_clk),
 .data(i_wit_plain),
 .address(i_wit_plain? i_wit_plain_addr: sk_rd_en? sk_addr_int: sk_addr_int),
 .wr_en(i_wit_plain_wr_en),
 .q(sk_int)
 );





//  mem_single #(.WIDTH(32), .DEPTH(TAU*HO_SIZE_ADJ/WIDTH)) 
//  FULL_INPUT_MSHARE_MEM
//  (
//  .clock(i_clk),
//  .data(i_hash_data_out),
//  .address(commit_addr_t),
//  .wr_en(commit_st_en),
//  .q(commit)
//  );

reg hash_start_exp_seed;
reg hash_force_done_exp_seed;
reg hash_data_out_ready_exp_seed;
reg [`CLOG2(TAU)-1:0] e_count;
reg [`CLOG2(SEED_SIZE/32):0]count_rseed = 0;
reg [`CLOG2(2*SEED_SIZE/32):0] h1_addr =0;
reg h1_wr_en;

reg [4:0] state = 0;
parameter s_wait_start          = 0;
parameter s_expand_seed         = 1;
parameter s_expand_seed_done    = 2;
parameter s_force_done_stall    = 3;
parameter s_load_rseed          = 4;
parameter s_start_commit        = 5;
parameter s_wait_commit_done    = 6;
parameter s_check_rseed_addr    = 7;
parameter s_h1_start            = 8;
parameter s_h1_done             = 9;
parameter s_wait_hash_force_done = 10;
parameter s_start_mpc_chal      = 11;
parameter s_done_mpc_chal       = 12;

parameter s_start_expand_h      = 13;
parameter s_done_expand_h       = 14;

// this needs to be replaced by parallel module
parameter s_start_mat_vec_mul   = 15;
parameter s_done_mat_vec_mul    = 16;
parameter s_reading_out_s       = 17;

parameter s_start_cpb           = 18;
parameter s_done_cpb            = 19;

parameter s_check_cpb_count     = 20;
parameter s_done                = 21;

always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        rseed_addr <= 0;
        hash_force_done_exp_seed <= 0;
        o_done <= 0;
        count_rseed <= 0;
        e_count <= 1;
        o_status_reg <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            rseed_addr <= 0;
            hash_force_done_exp_seed <= 0;
            o_done <= 0;
            count_rseed <= 0;
            e_count <= 1;
            h1_addr <= 0;
            if (i_start) begin
                state <= s_expand_seed;
                o_status_reg <= 1;
//                state <= s_start_mpc_chal;
            end
        end

        else if (state == s_expand_seed) begin
            state <= s_expand_seed_done;
            hash_force_done_exp_seed <= 0;
            o_done <= 0;
        end

        else if (state == s_expand_seed_done) begin
            if (rseed_addr == RSEED_DEPTH-1) begin
                state <= s_force_done_stall;
                rseed_addr <= 0;
                hash_force_done_exp_seed <= 1;
            end
            else begin
                hash_force_done_exp_seed <= 0;
                if (i_hash_data_out_valid) begin
                    rseed_addr <= rseed_addr + 1; 
                end
            end
        end

        else if (state == s_force_done_stall) begin
            hash_force_done_exp_seed <= 0;
            if (i_hash_force_done_ack) begin
                state <= s_check_rseed_addr;
            end
        end

        else if (state == s_load_rseed) begin
            hash_force_done_exp_seed <= 0;
            if (count_rseed == SEED_SIZE/32) begin
               count_rseed <= 0; 
            //    rseed_addr <= rseed_addr + 1;
               state <= s_start_commit;
            end
            else begin
                count_rseed <= count_rseed + 1;
                rseed_addr <= rseed_addr + 1;
            end
        end

        else if (state == s_start_commit) begin
            state <= s_wait_commit_done;
            hash_force_done_exp_seed <= 0;
            o_status_reg <= 2;
        end

        else if (state == s_wait_commit_done) begin
            hash_force_done_exp_seed <= 0;
            if (done_commit) begin
                state <= s_check_rseed_addr;
                e_count <= e_count+1;
            end
        end

        else if (state == s_check_rseed_addr) begin
            hash_force_done_exp_seed <= 0;
            if (e_count == TAU + 1) begin
            // if (e_count == 2) begin
                // state <= s_done;
                state <= s_h1_start;
            end
            else begin
                state <= s_load_rseed;
                count_rseed <= count_rseed + 1;
                rseed_addr <= rseed_addr + 1;
            end
        end

        else if (state == s_h1_start) begin
            state <= s_h1_done;
            o_status_reg <= 3;
        end

        else if (state == s_h1_done) begin
            if (h1_addr == 2*SEED_SIZE/32 - 1) begin
//                state <= s_done;
                state <= s_wait_hash_force_done;
                hash_force_done_exp_seed <= 1;
            end
            else begin
                if (i_hash_data_out_valid) begin
                    h1_addr <= h1_addr + 1;
                end
                hash_force_done_exp_seed <= 0;
            end
        end
        
        else if (state == s_wait_hash_force_done) begin
            if (i_hash_force_done_ack) begin
                state <= s_start_mpc_chal;
            end
        end
        
        else if (state == s_start_mpc_chal) begin
            state <= s_done_mpc_chal;
            h1_addr <= 0;
            o_status_reg <= 4;
        end
        
        else if (state == s_done_mpc_chal) begin
            if (done_mpc_chal) begin
                state <= s_start_expand_h;         
            end
        end

        else if (state == s_start_expand_h) begin
            if (i_hash_force_done_ack) begin
                state <= s_done_expand_h;
                o_status_reg <= 5;
            end
        end
        
        else if (state == s_done_expand_h) begin
            if (done_expand_h) begin
                // state <= s_start_cpb;
                state <= s_start_mat_vec_mul;
            end
        end


        else if (state == s_start_mat_vec_mul) begin
                state <= s_done_mat_vec_mul;
        end
        
        else if (state == s_done_mat_vec_mul) begin
            s_test_count <= 0;
            if (done_mat_vec_mul) begin
                state <= s_reading_out_s;
            end
        end

        else if (state == s_reading_out_s) begin
            if (s_test_count == M) begin
                state <= s_start_cpb;
                s_test_count <= 0;
            end
            else begin
                state <= s_reading_out_s;
                s_test_count <= s_test_count + 1;
            end
        end

        else if (state == s_start_cpb) begin
            o_status_reg <= 6;
            if (alpha_beta_addr < TAU) begin
                state <= s_done_cpb;
            end
            else begin
                state <= s_done;
            end
        end
        
        if (state == s_done_cpb) begin
            if (done_cpb) begin
                state <= s_start_cpb;
            end
        end

        else if (state == s_done) begin
            state <= s_wait_start;
            o_done <= 1;
            h1_addr <= 0;
            o_status_reg <= 0;
        end
    end
end


always@(*)
begin
    case(state)

    s_wait_start: begin
        hash_start_exp_seed <= 0;
        rseed_wr_en <= 0;
        hash_data_out_ready_exp_seed <= 0;
        seed_e_wr_en <= 0;
        commit_en <= 0;
        start_commit <= 0;
        h1_en <= 0;
        h1_wr_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 0;
        start_expand_h <= 0;
        expand_h_en <= 0;
        start_cpb <= 0;
        r_rd <=0;
        eps_rd <=0;
        if (i_start) begin
            exp_seed_en <= 1;
        end
        else begin
            exp_seed_en <= 0;
        end
    end

    s_expand_seed: begin
        hash_start_exp_seed <= 1;
        rseed_wr_en <= 0;
        exp_seed_en <= 1;
        hash_data_out_ready_exp_seed <= 0;
        commit_en <= 0;
        start_commit <= 0;
        seed_e_wr_en <= 0;
        h1_en <= 0;
        h1_wr_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 0;
        start_expand_h <= 0;
        expand_h_en <= 0;
        start_cpb <= 0;
        r_rd <=0;
        eps_rd <=0;
        
    end

    s_expand_seed_done: begin
        hash_start_exp_seed <= 0;
        exp_seed_en <= 1;
        commit_en <= 0;
        start_commit <= 0;
        seed_e_wr_en <= 0;
        h1_en <= 0;
        h1_wr_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 0;
        start_expand_h <= 0;
        expand_h_en <= 0;
        start_cpb <= 0;
        r_rd <=0;
        eps_rd <=0;
        if (i_hash_data_out_valid) begin
            rseed_wr_en <= 1;
            hash_data_out_ready_exp_seed <= 1;
        end
        else begin
            rseed_wr_en <= 0;
            hash_data_out_ready_exp_seed <= 0;
        end
    end
    s_force_done_stall: begin
        commit_en <= 0;
        hash_start_exp_seed <= 0;
        rseed_wr_en <= 0;
        hash_data_out_ready_exp_seed <= 0;
        start_commit <= 0;
        exp_seed_en <= 1;
        seed_e_wr_en <= 0;
        h1_en <= 0;
        h1_wr_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 0;
        start_expand_h <= 0;
        expand_h_en <= 0;
        start_cpb <= 0;
        r_rd <=0;
        eps_rd <=0;
    end
    
    s_load_rseed: begin
        commit_en <= 1;
        hash_start_exp_seed <= 0;
        rseed_wr_en <= 0;
        hash_data_out_ready_exp_seed <= 0;
        start_commit <= 0;
        exp_seed_en <= 0;
        seed_e_wr_en <= 1;
        h1_en <= 0;
        h1_wr_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 0;
        start_expand_h <= 0;
        expand_h_en <= 0;
        start_cpb <= 0;
        r_rd <=0;
        eps_rd <=0;
    end

    s_start_commit: begin
        commit_en <= 1;
        hash_start_exp_seed <= 0;
        rseed_wr_en <= 0;
        hash_data_out_ready_exp_seed <= 0;
        start_commit <= 1;
        exp_seed_en <= 0;
        seed_e_wr_en <= 0;
        h1_en <= 0;
        h1_wr_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 0;
        start_expand_h <= 0;
        expand_h_en <= 0;
        start_cpb <= 0;
        r_rd <=0;
        eps_rd <=0;
    end

    s_wait_commit_done: begin
        commit_en <= 1;
        hash_start_exp_seed <= 0;
        rseed_wr_en <= 0;
        hash_data_out_ready_exp_seed <= 0;
        start_commit <= 0;
        exp_seed_en <= 0;
        seed_e_wr_en <= 0;
        h1_en <= 0;
        h1_wr_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 0;
        start_expand_h <= 0;
        expand_h_en <= 0;
        start_cpb <= 0;
        r_rd <=0;
        eps_rd <=0;
    end

    s_check_rseed_addr: begin
        commit_en <= 1;
        hash_start_exp_seed <= 0;
        rseed_wr_en <= 0;
        hash_data_out_ready_exp_seed <= 0;
        start_commit <= 0;
        exp_seed_en <= 0;
        seed_e_wr_en <= 0;
        h1_en <= 0;
        h1_wr_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 0;
        start_expand_h <= 0;
        expand_h_en <= 0;
        start_cpb <= 0;
        r_rd <=0;
        eps_rd <=0;
    end

    s_h1_start: begin
        commit_en <= 0;
        h1_en <= 1;
        hash_start_exp_seed <= 1;
        rseed_wr_en <= 0;
        hash_data_out_ready_exp_seed <= 0;
        start_commit <= 0;
        exp_seed_en <= 0;
        seed_e_wr_en <= 0;
        h1_wr_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 0;
        start_expand_h <= 0;
        expand_h_en <= 0;
        start_cpb <= 0;
        r_rd <=0;
        eps_rd <=0;
    end

    s_h1_done: begin
        commit_en <= 0;
        h1_en <= 1;
        hash_start_exp_seed <= 0;
        rseed_wr_en <= 0;
        hash_data_out_ready_exp_seed <= 1;
        start_commit <= 0;
        exp_seed_en <= 0;
        seed_e_wr_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 0;
        start_expand_h <= 0;
        expand_h_en <= 0;
        start_cpb <= 0;
        r_rd <=0;
        eps_rd <=0;
        if (i_hash_data_out_valid) begin
            h1_wr_en <= 1;
        end
        else begin
            h1_wr_en <= 0;
        end
    end
    
    s_wait_hash_force_done: begin
        hash_start_exp_seed <= 0;
        rseed_wr_en <= 0;
        hash_data_out_ready_exp_seed <= 1;
        start_commit <= 0;
        commit_en <= 0;
        seed_e_wr_en <= 0;
        h1_en <= 1;
        h1_wr_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 0;
        start_expand_h <= 0;
        expand_h_en <= 0;
        start_cpb <= 0;
        r_rd <=0;
        eps_rd <=0;
        exp_seed_en <= 0;
    end
    
    s_start_mpc_chal: begin
        hash_start_exp_seed <= 0;
        rseed_wr_en <= 0;
        hash_data_out_ready_exp_seed <= 0;
        start_commit <= 0;
        commit_en <= 0;
        seed_e_wr_en <= 0;
        h1_en <= 0;
        h1_wr_en <= 0;
        start_expand_h <= 0;
        expand_h_en <= 0;
        start_cpb <= 0;
        r_rd <=0;
        eps_rd <=0;
        exp_seed_en <= 0;
        if (i_hash_force_done_ack) begin
            start_mpc_chal <= 1;
            mpc_chal_en <= 1;
        end 
        else begin
            start_mpc_chal <= 0;
            mpc_chal_en <= 0;
        end
    end
    
     s_done_mpc_chal: begin
        hash_start_exp_seed <= 0;
        rseed_wr_en <= 0;
        hash_data_out_ready_exp_seed <= 0;
        start_commit <= 0;
        commit_en <= 0;
        seed_e_wr_en <= 0;
        h1_en <= 0;
        h1_wr_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 1;
        start_expand_h <= 0;
        expand_h_en <= 0;
        start_cpb <= 0;
        r_rd <=0;
        eps_rd <=0;
        exp_seed_en <= 0;
    end


    s_start_expand_h: begin
        hash_start_exp_seed <= 0;
        rseed_wr_en <= 0;
        hash_data_out_ready_exp_seed <= 0;
        start_commit <= 0;
        commit_en <= 0;
        seed_e_wr_en <= 0;
        h1_en <= 0;
        h1_wr_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 0;
        start_cpb <= 0;
        r_rd <=0;
        eps_rd <=0;
        exp_seed_en <= 0;
        if (i_hash_force_done_ack) begin
            start_expand_h <= 1;
            expand_h_en <= 1;
        end
        else begin
            start_expand_h <= 0;
            expand_h_en <= 0;
        end
    end
    
     s_done_expand_h: begin
        hash_start_exp_seed <= 0;
        rseed_wr_en <= 0;
        hash_data_out_ready_exp_seed <= 0;
        start_commit <= 0;
        commit_en <= 0;
        seed_e_wr_en <= 0;
        h1_en <= 0;
        h1_wr_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 0;
        start_expand_h <= 0;
        expand_h_en <= 1;
        start_cpb <= 0;
        r_rd <=0;
        eps_rd <=0;
        exp_seed_en <= 0;
    end

    s_start_mat_vec_mul: begin
        hash_start_exp_seed <= 0;
        rseed_wr_en <= 0;
        hash_data_out_ready_exp_seed <= 0;
        start_commit <= 0;
        commit_en <= 0;
        seed_e_wr_en <= 0;
        h1_en <= 0;
        h1_wr_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 0;
        start_expand_h <= 0;
        expand_h_en <= 0;
        start_cpb <= 0;
        start_mat_vec_mul <= 1;
        r_rd <=0;
        eps_rd <=0;
        exp_seed_en <= 0;
    end

    s_done_mat_vec_mul: begin
        hash_start_exp_seed <= 0;
        rseed_wr_en <= 0;
        hash_data_out_ready_exp_seed <= 0;
        start_commit <= 0;
        commit_en <= 0;
        seed_e_wr_en <= 0;
        h1_en <= 0;
        h1_wr_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 0;
        start_expand_h <= 0;
        expand_h_en <= 0;
        start_cpb <= 0;
        start_mat_vec_mul <= 0;
        r_rd <=0;
        eps_rd <=0;
        exp_seed_en <= 0;
    end

    s_reading_out_s: begin
        hash_start_exp_seed <= 0;
        rseed_wr_en <= 0;
        hash_data_out_ready_exp_seed <= 0;
        start_commit <= 0;
        commit_en <= 0;
        seed_e_wr_en <= 0;
        h1_en <= 0;
        h1_wr_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 0;
        start_expand_h <= 0;
        expand_h_en <= 0;
        start_cpb <= 0;
        start_mat_vec_mul <= 0;
        r_rd <=0;
        eps_rd <=0;
        exp_seed_en <= 0;
    end

    s_start_cpb: begin
        hash_start_exp_seed <= 0;
        rseed_wr_en <= 0;
        hash_data_out_ready_exp_seed <= 0;
        start_commit <= 0;
        commit_en <= 0;
        seed_e_wr_en <= 0;
        h1_en <= 0;
        h1_wr_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 0;
        start_expand_h <= 0;
        expand_h_en <= 0;
        exp_seed_en <= 0;
        
        r_rd <=1;
        eps_rd <=1;
        if (alpha_beta_addr < TAU) begin
            start_cpb <= 1;
        end
        else begin
            start_cpb <= 0;
        end
    end
    
     s_done_cpb: begin
        hash_start_exp_seed <= 0;
        rseed_wr_en <= 0;
        hash_data_out_ready_exp_seed <= 0;
        start_commit <= 0;
        commit_en <= 0;
        seed_e_wr_en <= 0;
        h1_en <= 0;
        h1_wr_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 0;
        start_cpb <= 0;
        start_expand_h <= 0;
        expand_h_en <= 0;
        r_rd <=1;
        eps_rd <=1;
        exp_seed_en <= 0;
    end
    
    s_done: begin
        hash_start_exp_seed <= 0;
        rseed_wr_en <= 0;
        hash_data_out_ready_exp_seed <= 0;
        start_commit <= 0;
        commit_en <= 0;
        seed_e_wr_en <= 0;
        h1_en <= 0;
        h1_wr_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 0;
        start_expand_h <= 0;
        expand_h_en <= 0;
        start_cpb <= 0;
        r_rd <=0;
        eps_rd <=0;
        exp_seed_en <= 0;
    end 

    default: begin
        hash_start_exp_seed <= 0;
        rseed_wr_en <= 0;
        hash_data_out_ready_exp_seed <= 0;
        seed_e_wr_en <= 0;
        commit_en <= 0;
        seed_e_wr_en <= 0;
        h1_wr_en <= 0;
        h1_en <= 0;
        start_mpc_chal <= 0;
        mpc_chal_en <= 0;
        start_expand_h <= 0;
        expand_h_en <= 0;
        start_cpb <= 0;
        r_rd <=0;
        eps_rd <=0;
        exp_seed_en <= 0;
    end

    endcase
end


wire [32-1:0]                                       com_o_hash_data_in;
wire [`CLOG2(COMMIT_INPUT_SIZE_LAST/32) -1:0]       com_i_hash_addr;
wire                                                com_i_hash_rd_en;
wire [32-1:0]                                       com_i_hash_data_out;
wire                                                com_i_hash_data_out_valid;
wire                                                com_o_hash_data_out_ready;
wire  [32-1:0]                                      com_o_hash_input_length; // in bits
wire  [32-1:0]                                      com_o_hash_output_length; // in bits
wire                                                com_o_hash_start;
wire                                                com_i_hash_force_done_ack;
wire                                                com_o_force_done_ack;



reg start_commit;
wire done_commit; 


wire [31:0] seed_e;
reg [`CLOG2(SEED_SIZE/32)-1:0] seed_e_addr;
reg seed_e_wr_en;

assign com_i_hash_addr = i_hash_addr;
assign com_i_hash_rd_en = i_hash_rd_en;
assign com_i_hash_data_out = i_hash_data_out;
assign com_i_hash_data_out_valid = i_hash_data_out_valid;
assign com_i_hash_force_done_ack = i_hash_force_done_ack;

assign seed_e = rseed;
always@(posedge i_clk)
begin
    seed_e_addr <= count_rseed;
end

commit #(.FIELD(FIELD), .PARAMETER_SET(PARAMETER_SET), .FILE_SK("SK_POLY_L1.MEM"))
// commit #(.FIELD(FIELD), .PARAMETER_SET(PARAMETER_SET), .FILE_SK("ZERO.MEM"))
COMMIT_BLOCK 
(
.i_clk              (i_clk),
.i_rst              (i_rst),
.i_start            (start_commit),

.i_seed_root        (seed_e),
.i_seed_root_addr   (seed_e_addr),
.i_seed_root_wr_en  (seed_e_wr_en),

.i_e                (e_count),


.i_salt             (i_salt),
.i_salt_addr        (i_salt_addr),
.i_salt_wr_en       (i_salt_wr_en),

.o_done             (done_commit       ),

.o_sk_rd_en         (sk_rd_en),
.o_sk_addr          (sk_addr_int),
.i_sk               (sk_int),

// .i_sk_wr_en         (i_sk_wr_en),
// .i_sk_addr          (i_sk_addr),
// .i_sk               (i_sk),

.i_acc_rd           (0),
.i_acc_addr         (0),
.o_acc              (),

.i_commit_rd        (0),
.i_commit_addr      (0),
.o_commit           (),

.o_last_commit         (last_commit),

.o_a         (beav_a_in),
.o_b         (beav_b_in),
.o_c         (beav_c_in),

// .i_input_mshare_sel (0),
.i_input_mshare_rd  (input_mshare_rd),
.i_input_mshare_addr (input_mshare_addr),
.o_input_mshare     (input_mshare),

.o_commit_st_en       (commit_st_en),

.o_hash_data_in          (com_o_hash_data_in       ),   
.i_hash_addr             (com_i_hash_addr          ),   
.i_hash_rd_en            (com_i_hash_rd_en         ),   
.i_hash_data_out         (com_i_hash_data_out      ),   
.i_hash_data_out_valid   (com_i_hash_data_out_valid),   
.o_hash_data_out_ready   (com_o_hash_data_out_ready),   
.o_hash_input_length     (com_o_hash_input_length  ),   
.o_hash_output_length    (com_o_hash_output_length ),   
.o_hash_start            (com_o_hash_start         ),   
.i_hash_force_done_ack   (com_i_hash_force_done_ack),   
.o_hash_force_done       (com_o_hash_force_done    )

);



wire [31:0] hash1_data;
wire [31:0] hash1_out;
reg [31:0] hash1_in_reg;
wire [31:0] hash1_in;
reg hash1_wr_en;
reg [`CLOG2(HASH1_SIZE_ADJ/WIDTH)-1:0] hash1_addr;
reg [1:0] h1_sel_type;
reg first_h1;
reg last_h1;

always@(posedge i_clk)
begin
    // if (h1_sel_type == 0) begin // seed_h
    //     hash1_in_reg <= seed_h;
    // end
    // else if (h1_sel_type == 1) begin //y
    //     hash1_in_reg <= y_int;
    // end
    // else if (h1_sel_type == 2) begin //salt
    //     hash1_in_reg <= ss_out;
    // end
    // else begin // commit 
    //     if (commit_st_en) begin
    //         hash1_in_reg <= i_hash_data_out;
    //     end 
    // end
    if (hash1_wr_en || commit_st_en) begin
        hash1_in_reg <= hash1_in;
    end
end

 assign hash1_in = (h1_sel_type == 0)? seed_h:
                   (h1_sel_type == 1)? y_int:
                   (h1_sel_type == 2)? ss_out:
                                       i_hash_data_out;

 assign hash1_data = first_h1?  {8'h01, hash1_in[31:8]}:
                     last_h1?   {hash1_in_reg[7:0], 24'h000000}:
                                {hash1_in_reg[7:0], hash1_in[31:8]};


 mem_single #(.WIDTH(WIDTH), .DEPTH(HASH1_SIZE_ADJ/WIDTH), .INIT(0)) 
 HASH1_MEM // 01 || SEED_H || y || SALT || COMMITS
 (
 .clock(i_clk),
 .data(hash1_data),
 .address(hash1_wr_en? hash1_addr: (i_hash_rd_en & h1_en)? i_hash_addr : i_com_rd_en? i_com_addr :0),
 .wr_en(hash1_wr_en),
 .q(hash1_out)
 );

assign o_com = hash1_out;

 reg [3:0] h_state              = 0;
 parameter h_wait_start_com     = 0;
 parameter h_first_byte         = 1;
 parameter h_move_seed_h        = 2;
 parameter h_move_y             = 3;
 parameter h_move_salt          = 4;
 parameter h_capture_commit     = 5;
 parameter h_done               = 6;

reg [`CLOG2(SEED_SIZE/32):0] seed_h_addr;
reg [`CLOG2((SALT_SIZE+SEED_SIZE)/32)-1:0] salt_addr;
reg [`CLOG2(Y_SIZE_ADJ/32):0] y_addr;

reg en_h1_move;
reg done_h1_mem_prep;

always@(posedge i_clk)
begin
    if (i_rst) begin
        h_state <= h_wait_start_com;
        hash1_addr <= 0;
        salt_addr <= 0;
        seed_h_addr <= 0;
        y_addr <= 0;
        done_h1_mem_prep <= 0;
    end
    else begin
        if (h_state == h_wait_start_com) begin
            hash1_addr <= 0;
            salt_addr <= 0;
            y_addr <= 0;
            seed_h_addr <= 0;
            done_h1_mem_prep <= 0;
            if (start_commit) begin
                h_state <= h_first_byte;
            end
        end

        if (h_state == h_first_byte) begin
            hash1_addr <= 0;
            salt_addr <= 0;
            y_addr <= 0;
            h_state <= h_move_seed_h;
            seed_h_addr <= seed_h_addr + 1;
            hash1_addr <= hash1_addr+1;
        end
        
        else if (h_state == h_move_seed_h) begin
            if (seed_h_addr == SEED_SIZE/32) begin
                hash1_addr <= hash1_addr+1;
                h_state <= h_move_y;
                seed_h_addr <= 0;
                y_addr <= y_addr + 1;
            end
            else begin
                hash1_addr <= hash1_addr + 1;
                seed_h_addr <= seed_h_addr + 1;
            end
        end

        else if (h_state == h_move_y) begin
            if (y_addr == Y_SIZE_ADJ/32) begin
                hash1_addr <= hash1_addr+1;
                y_addr <= 0;
                h_state <= h_move_salt;
                salt_addr <= salt_addr + 1;
            end
            else begin
                hash1_addr <= hash1_addr + 1;
                y_addr <= y_addr + 1;
            end
        end

        else if (h_state == h_move_salt) begin
            if (salt_addr == SALT_SIZE/32 - 1) begin
                hash1_addr <= hash1_addr+1;
                salt_addr <= 0;
                h_state <= h_capture_commit;
            end
            else begin
                hash1_addr <= hash1_addr + 1;
                salt_addr <= salt_addr + 1;
            end
        end


        else if (h_state == h_capture_commit) begin
            if (commit_st_en) begin
               hash1_addr <= hash1_addr + 1; 
            end
            else if (e_count == TAU + 1) begin
                h_state <= h_done;
            end
        end

        else if (h_state == h_done) begin
            h_state <= h_wait_start_com;
            done_h1_mem_prep <= 1;
        end

    end
end


always@(*)
begin
    case(h_state)
        h_wait_start_com: begin
            h1_sel_type <= 0;
            first_h1 <= 0;
            hash1_wr_en <= 0;
            last_h1 <= 0;
            if (start_commit) begin
                en_h1_move <= 1;
            end
            else begin
                en_h1_move <= 0;
            end
        end

        h_first_byte: begin
            en_h1_move <= 1;
            first_h1 <= 1;
            h1_sel_type <= 0;
            hash1_wr_en <= 1;
            last_h1 <= 0;
        end

        h_move_seed_h: begin
            en_h1_move <= 1;
            first_h1 <= 0;
            hash1_wr_en <= 1;
            last_h1 <= 0;
            if (seed_h_addr == SEED_SIZE/32) begin
                h1_sel_type <= 1;
            end
            else begin
                h1_sel_type <= 0;
            end
        end

        h_move_y: begin
            en_h1_move <= 1;
            first_h1 <= 0;
            hash1_wr_en <= 1;
            last_h1 <= 0;
            if (y_addr == Y_SIZE_ADJ/32) begin
                h1_sel_type <= 2;
            end
            else begin
                h1_sel_type <= 1;
            end
        end
        
        h_move_salt: begin
            en_h1_move <= 1;
            first_h1 <= 0;
            hash1_wr_en <= 1;
            last_h1 <= 0;
            if (salt_addr == SALT_SIZE/32) begin
                h1_sel_type <= 3;
            end
            else begin
                h1_sel_type <= 2;
            end
        end

        h_capture_commit: begin
            en_h1_move <= 0;
            first_h1 <= 0;
            h1_sel_type <= 3;
            last_h1 <= 0;
            if (commit_st_en) begin
                hash1_wr_en <= 1;
            end
            else begin
                hash1_wr_en <= 0;
            end
        end

        h_done: begin
            en_h1_move <= 0;
            first_h1 <= 0;
            last_h1 <= 1;
            h1_sel_type <= 3;
            hash1_wr_en <= 1;
        end

        default: begin
            en_h1_move <= 0;
            first_h1 <= 0;
            hash1_wr_en <= 0;
            h1_sel_type <= 0;
            last_h1 <= 0;
        end
    endcase

end


reg                                 input_mshare_rd;
reg [`CLOG2(HO_SIZE_ADJ/32)-1:0]    input_mshare_addr;
wire [D_HYPERCUBE*WIDTH-1:0]         input_mshare;

reg [`CLOG2((TAU-1)*HO_SIZE_ADJ/32)-1:0]    input_mshare_addr_full;

reg in_mshare_wen;

wire [WIDTH-1:0] m_share_for_out [D_HYPERCUBE-1:0];


genvar k;
generate
    for(k=0;k<D_HYPERCUBE;k=k+1) begin
        mem_single #(.WIDTH(WIDTH), .DEPTH((TAU-1)*HO_SIZE_ADJ/WIDTH), .INIT(1)) 
        INPUT_M_SHARE_FULL
        (
        .clock(i_clk),
        .data(input_mshare[(D_HYPERCUBE-k)*WIDTH-1:(D_HYPERCUBE-k-1)*WIDTH]),
        .address(i_input_mshare_rd_en? i_input_mshare_addr : input_mshare_addr_full),
        .wr_en(in_mshare_wen),
        .q(m_share_for_out[k])
        );
    end
endgenerate

assign o_input_mshare = (i_input_mshare_sel == 0)? m_share_for_out[0]:
                        (i_input_mshare_sel == 1)? m_share_for_out[1]:
                        (i_input_mshare_sel == 2)? m_share_for_out[2]:
                        (i_input_mshare_sel == 3)? m_share_for_out[3]:
                        (i_input_mshare_sel == 4)? m_share_for_out[4]:
                        (i_input_mshare_sel == 5)? m_share_for_out[5]:
                        (i_input_mshare_sel == 6)? m_share_for_out[6]:
                                                   m_share_for_out[7];


reg [3:0] m_state = 0;
parameter m_wait_start  = 0;
parameter m_last_commit = 1;
parameter m_load_mshare = 2;
parameter m_done        = 3;

always@(posedge i_clk)
begin
    if (i_rst) begin
        m_state <= m_wait_start;
        input_mshare_addr <= 0;
        input_mshare_addr_full <= 0;
    end
    else begin
        if (m_state == m_wait_start) begin
            input_mshare_addr <= 0;
            input_mshare_addr_full <= 0;
            if (i_start) begin
                m_state <= m_last_commit;
            end
        end

        else if (m_state == m_last_commit) begin
            if (last_commit) begin
                m_state <= m_load_mshare;
                input_mshare_addr <= input_mshare_addr + 1;
            end
        end

        else if (m_state == m_load_mshare) begin
            if (input_mshare_addr == HO_SIZE_ADJ/WIDTH) begin
                m_state <= m_done;
                input_mshare_addr_full <= input_mshare_addr_full + 1;
            end
            else begin
                input_mshare_addr <= input_mshare_addr + 1;
                input_mshare_addr_full <= input_mshare_addr_full + 1;
            end
        end

        else if (m_state == m_done) begin
            input_mshare_addr <= 0;
            if (done_commit) begin
                m_state <= m_last_commit;
            end
        end
        
    end
end


always@(*)
begin
    case(m_state)
        m_wait_start: begin
            input_mshare_rd <= 0;
            in_mshare_wen <= 0;
        end

        m_last_commit: begin
            in_mshare_wen <= 0;
            if (last_commit) begin
                input_mshare_rd <= 1;
            end
            else begin
                input_mshare_rd <= 0;
            end
        end

        m_load_mshare: begin
            if (last_commit) begin
                input_mshare_rd <= 1;
                in_mshare_wen <= 1;
            end
            else begin
                input_mshare_rd <= 0;
                in_mshare_wen <= 0;
            end
        end

        m_done: begin
            input_mshare_rd <= 0;
            in_mshare_wen <= 0;
        end

        default: begin
            input_mshare_rd <= 0;
            in_mshare_wen <= 0;
        end
    endcase
end


reg  start_mpc_chal;
wire done_mpc_chal;
wire h1_rd_mpc_chal;
wire [`CLOG2(2*SEED_SIZE/32)-1:0] h1_addr_mpc_chal;
//wire [31:0] h1;

wire [32-1:0]                                       mpc_chal_o_hash_data_in;
wire [`CLOG2(COMMIT_INPUT_SIZE_LAST/32) -1:0]       mpc_chal_i_hash_addr;
wire                                                mpc_chal_i_hash_rd_en;
wire [32-1:0]                                       mpc_chal_i_hash_data_out;
wire                                                mpc_chal_i_hash_data_out_valid;
wire                                                mpc_chal_o_hash_data_out_ready;
wire  [32-1:0]                                      mpc_chal_o_hash_input_length; // in bits
wire  [32-1:0]                                      mpc_chal_o_hash_output_length; // in bits
wire                                                mpc_chal_o_hash_start;
wire                                                mpc_chal_i_hash_force_done_ack;
wire                                                mpc_chal_o_hash_force_done;



wire [T*32-1:0] r_out;
wire [`CLOG2(TAU)-1:0] r_addr;
reg r_rd;

wire [T*32-1:0] eps_out;
wire [`CLOG2(TAU)-1:0] eps_addr;
reg eps_rd;

// expand MPC Challenge
assign mpc_chal_i_hash_addr = (mpc_chal_en)? i_hash_addr : 0;
assign mpc_chal_i_hash_rd_en = (mpc_chal_en)? i_hash_rd_en : 0;
assign mpc_chal_i_hash_data_out_valid = (mpc_chal_en)? i_hash_data_out_valid : 0;
assign mpc_chal_i_hash_data_out =  i_hash_data_out;
assign mpc_chal_i_hash_force_done_ack = i_hash_force_done_ack;


assign r_addr = beav_abc_addr_out;
assign eps_addr = beav_abc_addr_out;

expand_mpc_challenge #(.PARAMETER_SET(PARAMETER_SET))
EXP_MPC_CHAL 
(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_start(start_mpc_chal),
    .o_done(done_mpc_chal),
    
    
    .o_h1_rd(h1_rd_mpc_chal),
    .o_h1_addr(h1_addr_mpc_chal),
    .i_h1(h1_out),
    
    .o_r(r_out),
    .i_r_addr(r_addr),
    .i_r_rd(r_rd),
    
    .o_eps(eps_out),
    .i_eps_addr(eps_addr),
    .i_eps_rd(eps_rd),
    
    
    .o_hash_data_in          (mpc_chal_o_hash_data_in       ),   
    .i_hash_addr             (mpc_chal_i_hash_addr          ),   
    .i_hash_rd_en            (mpc_chal_i_hash_rd_en         ),   
    .i_hash_data_out         (mpc_chal_i_hash_data_out      ),   
    .i_hash_data_out_valid   (mpc_chal_i_hash_data_out_valid),   
    .o_hash_data_out_ready   (mpc_chal_o_hash_data_out_ready),   
    .o_hash_input_length     (mpc_chal_o_hash_input_length  ),   
    .o_hash_output_length    (mpc_chal_o_hash_output_length ),   
    .o_hash_start            (mpc_chal_o_hash_start         ),   
    .i_hash_force_done_ack   (mpc_chal_i_hash_force_done_ack),   
    .o_hash_force_done       (mpc_chal_o_hash_force_done    )

);



// Compute Plain Broadcast



//ExpandH
// reg expand_h_en;
reg start_expand_h;
wire done_expand_h;
wire h_out_en;
wire [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0] h_out_addr;
wire [PROC_SIZE-1:0] h_out;

wire [32-1:0]                                       h_o_hash_data_in;
wire [`CLOG2(COMMIT_INPUT_SIZE_LAST/32) -1:0]       h_i_hash_addr;
wire                                                h_i_hash_rd_en;
wire [32-1:0]                                       h_i_hash_data_out;
wire                                                h_i_hash_data_out_valid;
wire                                                h_o_hash_data_out_ready;
wire  [32-1:0]                                      h_o_hash_input_length; // in bits
wire  [32-1:0]                                      h_o_hash_output_length; // in bits
wire                                                h_o_hash_start;
wire                                                h_o_hash_force_done;


assign h_i_hash_addr = (expand_h_en)? i_hash_addr : 0;
assign h_i_hash_rd_en = (expand_h_en)? i_hash_rd_en : 0;
assign h_i_hash_data_out_valid = (expand_h_en)? i_hash_data_out_valid : 0;
assign h_i_hash_data_out =  i_hash_data_out;
assign h_i_hash_force_done_ack = i_hash_force_done_ack;
assign h_o_hash_input_length = SEED_SIZE;
assign h_o_hash_output_length = H_SHAKE_SQUEEZE;

gen_H_seq #(.FIELD(FIELD), .PARAMETER_SET(PARAMETER_SET), .N_GF(N_GF))
EXPAND_H 
(
    .i_clk(i_clk),      
    .i_rst(i_rst),
    .i_start(start_expand_h),
    .i_seed_h(i_seed_h),
    .i_seed_h_addr(i_seed_h_addr),
    .i_seed_wr_en(i_seed_h_wr_en),

    // .o_start_h_proc(o_hash_start_h),
    .o_seed_h_prng(h_o_hash_data_in),

    .o_start_prng(h_o_hash_start),

    .i_prng_rd(h_i_hash_rd_en),
    .i_prng_addr(h_i_hash_rd_en? h_i_hash_addr : 0),

    .i_prng_out(h_i_hash_data_out),
    .i_prng_out_valid(h_i_hash_data_out_valid),
    .o_prng_out_ready(h_o_hash_data_out_ready),

    .o_prng_force_done(h_o_hash_force_done),

    .i_h_out_en(o_mat_vec_rd),
    // .i_h_out_en(h_out_en),
    .i_h_out_addr(o_mat_vec_rd? h_mat_addr:0),
    .o_h_out(h_mat),

    .o_done(done_expand_h)
);



always@(posedge i_clk)
begin
    if (i_start | i_rst) begin
        beav_abc_addr_in <= 0;
        // beav_b_addr_in <= 0;
        // beav_c_addr_in  <= 0;
    end
    else begin
        if (done_commit) begin
            beav_abc_addr_in <= beav_abc_addr_in + 1;
            // beav_b_addr_in <= beav_b_addr_in + 1;
            // beav_c_addr_in <= beav_c_addr_in + 1;
        end
    end
end


always@(posedge i_clk)
begin
    if (i_start | i_rst) begin
        beav_abc_addr_out <= 0;
        // beav_b_addr_in <= 0;
        // beav_c_addr_in  <= 0;
    end
    else begin
        if (done_cpb) begin
            beav_abc_addr_out <= beav_abc_addr_out + 1;
            // beav_b_addr_in <= beav_b_addr_in + 1;
            // beav_c_addr_in <= beav_c_addr_in + 1;
        end
    end
end

wire [T*32-1:0] beav_a_in;
wire [T*32-1:0] beav_b_in;
wire [T*32-1:0] beav_c_in;
wire [T*32-1:0] beav_a_out;
wire [T*32-1:0] beav_b_out;
wire [T*32-1:0] beav_c_out;

reg [`CLOG2(TAU)-1:0] beav_abc_addr_in;
// reg [`CLOG2(TAU)-1:0] beav_b_addr_in;
// reg [`CLOG2(TAU)-1:0] beav_c_addr_in;

reg [`CLOG2(TAU)-1:0] beav_abc_addr_out;
// reg [`CLOG2(TAU)-1:0] beav_b_addr_out;
// reg [`CLOG2(TAU)-1:0] beav_c_addr_out;

parameter FILE_A = (TEST_SET == 0)? "beav_a_0.in":
                   (TEST_SET == 1)? "beav_a_1.in":
                                    "beav_a_2.in";

parameter FILE_B = (TEST_SET == 0)? "beav_b_0.in":
                     (TEST_SET == 1)? "beav_b_1.in":
                                        "beav_b_2.in";

parameter FILE_C = (TEST_SET == 0)? "beav_c_0.in":
                     (TEST_SET == 1)? "beav_c_1.in":
                                        "beav_c_2.in";                                    

//assign beav_abc_addr_out = alpha_beta_addr;
mem_single #(.WIDTH(32*T), .DEPTH(TAU), .INIT(0), .FILE(FILE_A)) 
    beav_A
    (
    .clock(i_clk),
    .data({{(24*T){1'b0}},beav_a_in[8*T-1:0]}),
    .address(done_commit? beav_abc_addr_in : beav_abc_addr_out),
    // .wr_en(done_commit),
    .wr_en(),
    .q(beav_a_out)
    );

 mem_single #(.WIDTH(32*T), .DEPTH(TAU), .INIT(0), .FILE(FILE_B)) 
    beav_B
    (
    .clock(i_clk),
    .data({{(24*T){1'b0}},beav_b_in[8*T-1:0]}),
    .address(done_commit? beav_abc_addr_in : beav_abc_addr_out),
    // .wr_en(done_commit),
    .wr_en(),
    .q(beav_b_out)
    );

 mem_single #(.WIDTH(32*T), .DEPTH(TAU), .INIT(0), .FILE(FILE_C))  
    beav_C
    (
    .clock(i_clk),
    // .data({{(24*T){1'b0}},beav_c_in[8*T-1:0]}),
    .data(),
    .address(done_commit? beav_abc_addr_in : beav_abc_addr_out),
    // .wr_en(done_commit),
    .wr_en(),
    .q(beav_c_out)
    );

mem_single #(.WIDTH(8), .DEPTH(M), .FILE("S_L1.mem")) 
    Q_values
    (
    .clock(i_clk),
    .data(0),
    .address(q_rd?q_addr:0),
    .wr_en(0),
    .q(q_out)
    );

 mem_single #(.WIDTH(8), .DEPTH(M), .FILE("S_L1.mem")) 
    S_values
    (
    .clock(i_clk),
    .data(0),
    .address(s_rd? s_addr: 0),
    .wr_en(0),
    .q(s_out)
    );

reg start_cpb;
wire done_cpb;

wire [32*T-1:0] alpha;
wire [32*T-1:0] beta;

wire  [7:0]          q_out;
wire [`CLOG2(M)-1:0] q_addr;
wire                 q_rd;

wire  [7:0]          s_out;
wire [`CLOG2(M)-1:0] s_addr;
wire                 s_rd;




compute_plain_broadcast_top #(.PARAMETER_SET(PARAMETER_SET), .FIELD(FIELD))
COMP_PLAIN_BROAD  
    (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_start(start_cpb),

    .i_q(q_out),
    .o_q_addr(q_addr),
    .o_q_rd(q_rd),

    .i_s(s_out),
    .o_s_addr(s_addr),
    .o_s_rd(s_rd),

    .i_a(beav_a_out),
    .i_b(beav_b_out),

    .i_r(r_out),
    .i_eps(eps_out),


    .o_alpha(alpha),
    .o_beta(beta),



    .o_done(done_cpb)
    );


reg [`CLOG2(TAU)-1:0] alpha_beta_addr;
// reg [`CLOG2(TAU)-1:0] beta_addr;

always@(posedge i_clk)
begin
    if (i_start | i_rst) begin
        alpha_beta_addr <= 0;
        // beta_addr <= 0;
    end
    else begin
        if (done_cpb) begin
            alpha_beta_addr <= alpha_beta_addr + 1;
            // beta_addr <= beta_addr + 1;
        end
    end
end


mem_single #(.WIDTH(32*T), .DEPTH(TAU), .INIT(1)) 
    ALPHA
    (
    .clock(i_clk),
    .data(alpha),
    .address(done_cpb? alpha_beta_addr : 0),
    .wr_en(done_cpb),
    .q(o_alpha)
    );

 mem_single #(.WIDTH(32*T), .DEPTH(TAU), .INIT(1)) 
    BETA
    (
    .clock(i_clk),
    .data(beta ),
    .address(done_cpb? alpha_beta_addr : 0),
    .wr_en(done_cpb),
    .q(o_beta)
    );



// this needs to be replaced by parallel code

reg [`CLOG2(M)-1:0] s_test_count;

 mem_single #(.WIDTH(8), .DEPTH(M), .FILE("S_L1.mem")) 
    S_test_values
    (
    .clock(i_clk),
    .data(0),
    .address(o_mat_vec_rd? s_vec_addr: 0),
    .wr_en(0),
    .q(s_o)
    );

reg start_mat_vec_mul;
wire done_mat_vec_mul;
wire [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0] h_mat_addr;
wire [`CLOG2(M)-1:0] s_vec_addr;
wire [PROC_SIZE-1:0] h_mat;
wire [7:0] s_vec;
wire [7:0] s_o;
wire o_mat_vec_rd;

mat_vec_mul_ser
#(
.FIELD(FIELD),
.PARAMETER_SET(PARAMETER_SET),
.MAT_ROW_SIZE_BYTES(MAT_ROW_SIZE_BYTES),
.MAT_COL_SIZE_BYTES(MAT_COL_SIZE_BYTES),
.VEC_SIZE_BYTES(K),
.VEC_WEIGHT(K),
.N_GF(N_GF)
)
MAT_VEC_MUL
(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_start(start_mat_vec_mul),
    .o_mat_addr(h_mat_addr),
    .o_vec_addr(s_vec_addr),
    .o_mat_vec_rd(o_mat_vec_rd),
    .i_mat(h_mat),
    .i_vec(s_o),

    .o_res(),
    .i_res_en(0),
    .i_res_addr(0),
    .o_done(done_mat_vec_mul),

    .i_vec_add_addr(0),
    .i_vec_add_wen(0),
    .i_vec_add()
);

endmodule