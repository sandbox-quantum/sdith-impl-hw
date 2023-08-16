/*
 * This file is commit module which part of SDitH sign.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module commit 
#(
   parameter WIDTH = 32,

   parameter FIELD = "GF256",
//     parameter FIELD = "P251",

    parameter PARAMETER_SET = "L1",
    
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
    
    parameter D_HYPERCUBE = 8,
    parameter ETA = 4,

    parameter T =   (PARAMETER_SET == "L5")? 4:
                                             3, 

    parameter SEED_SIZE = LAMBDA,
    parameter SALT_SIZE = 2*LAMBDA,
    parameter NUMBER_OF_SEED_BITS = (2**D_HYPERCUBE) * SEED_SIZE,

    parameter HASH_INPUT_SIZE = LAMBDA + 2*LAMBDA,
    
    // parameter HASH_OUTPUT_SIZE = 8*(K + 2*WEIGHT + T*(2*D_SPLIT + 1)*ETA),
    parameter HASH_OUTPUT_SIZE = 8*(K + 2*D_SPLIT*WEIGHT + T*D_SPLIT*3),
    parameter HO_SIZE_ADJ = HASH_OUTPUT_SIZE + (WIDTH - HASH_OUTPUT_SIZE%WIDTH)%WIDTH,
    
    parameter SK_SIZE = 8*(K + 2*D_SPLIT*WEIGHT),
    parameter SK_SIZE_ADJ = SK_SIZE + (WIDTH - SK_SIZE%WIDTH)%WIDTH,

    parameter COMMIT_INPUT_SIZE = SALT_SIZE + SEED_SIZE + 32,
    parameter COMMIT_INPUT_SIZE_LAST = SALT_SIZE + SEED_SIZE + HASH_OUTPUT_SIZE + 32,
    parameter COMMIT_OUTPUT_SIZE = LAMBDA,
    parameter COMMIT_RAM_DEPTH = (COMMIT_OUTPUT_SIZE*(2**D_HYPERCUBE))/32,

    parameter FIRST_ADDR_ABC = 8*(K + 2*D_SPLIT*WEIGHT)/WIDTH,
    

    parameter FIRST_ADDR_C = 8*(K + 2*D_SPLIT*WEIGHT + T*D_SPLIT*2),
    parameter FIRST_ADDR_C_ADJ = FIRST_ADDR_C + (WIDTH - FIRST_ADDR_C%WIDTH)%WIDTH,

    parameter ABC_SIZE = 8*T*3*D_SPLIT,
    parameter ABC_SIZE_ADJ = ABC_SIZE + (WIDTH - ABC_SIZE%WIDTH)%WIDTH,
    parameter START_ADDR_A  =   (8*(K + 2*D_SPLIT*WEIGHT)) % WIDTH,

    parameter FILE_SK = ""
    

)(
    input                                               i_clk,
    input                                               i_rst,
    input                                               i_start,

    input      [4:0]                                    i_e,

    input   [32-1:0]                                    i_seed_root,
    input   [`CLOG2(SEED_SIZE/32)-1:0]                  i_seed_root_addr,
    input                                               i_seed_root_wr_en,

    // input   [32-1:0]                                    i_seed_e,
    // output  reg [`CLOG2(NUMBER_OF_SEED_BITS/32)-1:0]    o_seed_e_addr,
    // output  reg                                         o_seed_e_rd,

    input   [32-1:0]                                    i_salt,
    input   [`CLOG2(SALT_SIZE/32)-1:0]                  i_salt_addr,
    input                                               i_salt_wr_en,

    output reg                                          o_done,

    output reg                                          o_sk_rd_en,
    output reg [`CLOG2(HO_SIZE_ADJ/32)-1:0]             o_sk_addr,
    // input                                               i_sk_wr_en,
    // input  [`CLOG2(HO_SIZE_ADJ/32)-1:0]                 i_sk_addr,
    input [WIDTH-1:0]                                   i_sk,


    input                                               i_acc_rd,
    input  [`CLOG2(HO_SIZE_ADJ/32)-1:0]                 i_acc_addr,
    output [WIDTH-1:0]                                  o_acc,

    input                                               i_commit_rd,
    input  [`CLOG2(COMMIT_RAM_DEPTH)-1:0]               i_commit_addr,
    output [31:0]                                       o_commit,

    output                                              o_last_commit,
    // input  [`CLOG2(D_HYPERCUBE)-1:0]                    i_input_mshare_sel,
    input                                               i_input_mshare_rd,
    input  [`CLOG2(HO_SIZE_ADJ/32)-1:0]                 i_input_mshare_addr,
    // output [WIDTH-1:0]                                  o_input_mshare,
    output [D_HYPERCUBE*WIDTH-1:0]                      o_input_mshare,

    output                                              o_commit_st_en,

    output  [8*T*D_SPLIT - 1 : 0]                       o_a,
    output  [8*T*D_SPLIT - 1 : 0]                       o_b,
    output  [8*T*D_SPLIT - 1 : 0]                       o_c,

    // hash interface
    output   [32-1:0]                                   o_hash_data_in,
    input    [`CLOG2(COMMIT_INPUT_SIZE_LAST/32) -1:0]   i_hash_addr,
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


wire   [32-1:0]                             i_seed_e;
reg [`CLOG2(NUMBER_OF_SEED_BITS/32)-1:0]    o_seed_e_addr;
reg                                         o_seed_e_rd;

wire start_treeprg;
wire done_treeprg;
wire [31:0] salt_treeprg;
wire [`CLOG2(SALT_SIZE/32)-1:0] salt_treeprg_addr;
wire salt_treeprg_rd;

wire treeprg_processing;

wire [32-1:0]                                       tprg_o_hash_data_in;
wire [`CLOG2(COMMIT_INPUT_SIZE_LAST/32) -1:0]       tprg_i_hash_addr;
wire                                                tprg_i_hash_rd_en;
wire [32-1:0]                                       tprg_i_hash_data_out;
wire                                                tprg_i_hash_data_out_valid;
wire                                                tprg_o_hash_data_out_ready;
wire  [32-1:0]                                      tprg_o_hash_input_length; 
wire  [32-1:0]                                      tprg_o_hash_output_length;
wire                                                tprg_o_hash_start;
wire                                                tprg_i_hash_done;
wire                                                tprg_i_hash_force_done_ack;
wire                                                tprg_o_hash_force_done;


assign salt_treeprg = data_out;
assign tprg_i_hash_data_out_valid = i_hash_data_out_valid & treeprg_processing;
assign tprg_i_hash_addr = i_hash_addr;
assign tprg_i_hash_rd_en = i_hash_rd_en & treeprg_processing;
assign tprg_i_hash_data_out = i_hash_data_out;
assign tprg_i_hash_force_done_ack = i_hash_force_done_ack;
assign start_tree_prg = i_start;

treeprg #(.PARAMETER_SET(PARAMETER_SET))
TREE_PRG 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(start_tree_prg),
.o_done(done_treeprg),

//connect seed e port here
.o_seed_e(i_seed_e),
.i_seed_e_addr(o_seed_e_addr + 4),
.i_seed_e_rd(o_seed_e_rd),

//connect input root seed here
.i_seed(i_seed_root),
.i_seed_addr(i_seed_root_addr),
.i_seed_wr_en(i_seed_root_wr_en),

// .i_salt(i_salt),
// .i_salt_addr(i_salt_addr),
// .i_salt_wr_en(i_salt_wr_en),

.o_treeprg_processing(treeprg_processing),

.i_salt(salt_treeprg),
.o_salt_addr(salt_treeprg_addr),
.o_salt_rd(salt_treeprg_rd),


.o_hash_data_in          (tprg_o_hash_data_in       ),   
.i_hash_addr             (tprg_i_hash_addr          ),   
.i_hash_rd_en            (tprg_i_hash_rd_en         ),   
.i_hash_data_out         (tprg_i_hash_data_out      ),   
.i_hash_data_out_valid   (tprg_i_hash_data_out_valid),   
.o_hash_data_out_ready   (tprg_o_hash_data_out_ready),   
.o_hash_input_length     (tprg_o_hash_input_length  ),   
.o_hash_output_length    (tprg_o_hash_output_length ),   
.o_hash_start            (tprg_o_hash_start         ),   
.i_hash_force_done_ack   (tprg_i_hash_force_done_ack),   
.o_hash_force_done       (tprg_o_hash_force_done    )

);

reg commit = 0;

assign o_hash_input_length =        treeprg_processing?     tprg_o_hash_input_length:
                                (last_commit && commit)?    COMMIT_INPUT_SIZE_LAST:
                                                commit?     COMMIT_INPUT_SIZE:
                                                            HASH_INPUT_SIZE;

assign o_hash_output_length =   treeprg_processing? tprg_o_hash_output_length:
                                commit?             COMMIT_OUTPUT_SIZE :
                                                    2*HASH_OUTPUT_SIZE;

assign o_hash_data_out_ready = (treeprg_processing)? tprg_o_hash_data_out_ready: hash_data_out_ready;
assign o_hash_start = (treeprg_processing)? tprg_o_hash_start: hash_start;
assign o_hash_force_done = (treeprg_processing)? tprg_o_hash_force_done: hash_force_done;
 
assign o_last_commit = last_commit;
reg commit_wr_en;
reg [`CLOG2(COMMIT_RAM_DEPTH)-1:0] commit_addr;


//commented because we don't need to store here
// mem_single #(.WIDTH(32), .DEPTH(COMMIT_RAM_DEPTH)) 
//  COMMIT_MEM
//  (
//  .clock(i_clk),
//  .data(i_hash_data_out),
//  .address(i_commit_rd? i_commit_addr : commit_addr),
//  .wr_en(commit_wr_en),
//  .q(o_commit)
//  );

assign o_commit_st_en = commit_wr_en;

reg i_hash_data_out_valid_reg;
always@(posedge i_clk)
begin
    i_hash_data_out_valid_reg <= i_hash_data_out_valid;
end

wire [31:0] ss_input;
reg ss_type;
reg [`CLOG2(HASH_INPUT_SIZE/32) -1:0] ss_addr;
reg ss_wen;
wire [`CLOG2(COMMIT_INPUT_SIZE_LAST/32) -1:0] hash_addr_int;


// assign ss_input = (ss_type == 1)? i_salt : i_seed_e;
assign ss_input = (i_salt_wr_en)? i_salt : i_seed_e;

wire [`CLOG2(COMMIT_INPUT_SIZE_LAST/32) -1:0] hash_addr_int;
wire [31:0] data_out;

assign hash_addr_int = (commit == 0) ? i_hash_addr:
                       (last_commit == 1 && commit == 1 && i_hash_addr >= (SALT_SIZE+SEED_SIZE+32)/32)? i_hash_addr - (SALT_SIZE+SEED_SIZE+32)/32:
                       (commit == 1 && i_hash_addr <= SALT_SIZE/32 - 1)?   i_hash_addr:
                                                                      i_hash_addr - 1;
assign o_hash_data_in = (treeprg_processing)? tprg_o_hash_data_in:
                        (commit == 1 && i_hash_addr == SALT_SIZE/32 + 1)? {{3'b000, i_e}, {7'b0000000, loop_count_i}}:
                        ((commit == 1 && i_hash_addr > (SALT_SIZE+SEED_SIZE+32)/32))?  q_1:
                                                                                    data_out;


 mem_single #(.WIDTH(32), .DEPTH(HASH_INPUT_SIZE/32)) 
 SEED_E
 (
 .clock(i_clk),
 .data(ss_input),
//  .address(ss_wen? ss_addr: i_hash_rd_en? i_hash_addr: 0),
 .address(i_salt_wr_en? i_salt_addr:ss_wen? ss_addr: i_hash_rd_en? hash_addr_int[`CLOG2(HASH_INPUT_SIZE/32) -1:0]: 0),
 .wr_en(ss_wen || i_salt_wr_en),
 .q(data_out)
 );

reg load =0;
reg shift =0;
reg [31:0] hash_out_sreg;
reg [WIDTH-1:0] input_share;
wire [7:0] input_share_byte;
wire threshold;
reg in_share_valid;

assign input_share_byte = hash_out_sreg[31:24];

assign threshold = (input_share_byte < 251)? 1 : 0;

generate
    if (FIELD == "P251") begin
        always@(posedge i_clk) begin
            if (load) begin
                hash_out_sreg <= i_hash_data_out;
            end
            else if (shift) begin
                hash_out_sreg <= {hash_out_sreg[23:0],{(8){1'b0}}};
            end
        end
        always@(posedge i_clk)
        begin
            if (in_share_valid) begin
                input_share <= {input_share[WIDTH-8-1:0],input_share_byte};
            end
        end
    end
    else begin
        if (WIDTH == 32) begin
            always@(posedge i_clk)
            begin
                if (i_hash_data_out_valid) begin
                    input_share <= i_hash_data_out;
                end
            end
        end
        else if (WIDTH > 32) begin
            always@(posedge i_clk)
            begin
                if (i_hash_data_out_valid) begin
                    input_share <= {input_share[WIDTH-32-1:0],i_hash_data_out};
                end
            end
        end
    end
endgenerate

wire [WIDTH-1:0] input_share_bram;
wire [WIDTH-1:0] input_share_last;


generate 
    if (HASH_OUTPUT_SIZE%WIDTH !=0) begin
        assign input_share_last = {input_share[WIDTH-1:WIDTH-HASH_OUTPUT_SIZE%WIDTH],{(WIDTH-HASH_OUTPUT_SIZE%WIDTH){1'b0}}};
    end
endgenerate

reg [WIDTH-1:0] input_share_reg;
always@(posedge i_clk)
begin
    if (i_hash_data_out_valid_reg && loop_count_i == 2**D_HYPERCUBE) begin
        input_share_reg <= input_share;
    end
    else begin
       input_share_reg <= 0; 
    end
end
wire [31:0] input_share_final_d_adj;
wire [31:0] input_share_final_d;

generate 
    if (8*((K+2*WEIGHT))%WIDTH == 0) begin
        assign  input_share_final_d = (last_ab)?{input_share[WIDTH-1:FIRST_ADDR_C%WIDTH], {(WIDTH-FIRST_ADDR_C%WIDTH){1'b0}}}:
                                                                                    input_share;
    end
endgenerate

// generate 
//     if (8*((K+2*WEIGHT))%WIDTH != 0) begin
//         assign input_share_final_adj = {input_share_reg[WIDTH-1:START_ADDR_A], input_share[START_ADDR_A-1:0]};
//         assign input_share_final_d = (last_ab)?{input_share_final_adj[WIDTH-1:FIRST_ADDR_C%WIDTH], {(WIDTH-FIRST_ADDR_C%WIDTH){1'b0}}}:
//                                                 input_share_final_adj;
//     end
// endgenerate

// assign input_share_bram = (loop_count_i == 2**D_HYPERCUBE)? {input_share_reg[WIDTH-1:START_ADDR_A], input_share[START_ADDR_A-1:0]}:
assign input_share_bram = (loop_count_i == 2**D_HYPERCUBE)? input_share_final_d:
                          ((HASH_OUTPUT_SIZE%WIDTH !=0) && (in_share_addr == HO_SIZE_ADJ/WIDTH) && (WIDTH == 32) && (FIELD == "GF256"))?      input_share_last : 
                          ((HASH_OUTPUT_SIZE%WIDTH !=0) && (in_share_addr == HO_SIZE_ADJ/WIDTH - 1) && ((WIDTH != 32 && (FIELD == "GF256")) || (FIELD == "P251") ))?    input_share_last : 
                                                                                                                        input_share;
wire [WIDTH-1:0] acc;

wire [WIDTH/8 -1:0] done_add;
wire  start_add;

assign start_add = in_share_wr_en;

genvar j;
generate
    for(j=0;j<WIDTH/8;j=j+1) begin
        if (FIELD == "P251") begin 
            p251_add #(.REG_IN(1), .REG_OUT(1))
            P251_ADD 
            (
                .i_clk(i_clk), 
                .i_start(start_add), 
                .in_1(input_share_bram[WIDTH-j*8-1 : WIDTH-j*8-8]), 
                .in_2(q_1[WIDTH-j*8-1 : WIDTH-j*8-8]),
                .o_done(done_add[j]), 
                .out(acc[WIDTH-j*8-1 : WIDTH-j*8-8]) 
            );
        end
        else begin 
            gf_add #(.REG_IN(1), .REG_OUT(0))
            GF_ADD 
            (
                .i_clk(i_clk), 
                .i_start(start_add), 
                .in_1(input_share_bram[WIDTH-j*8-1 : WIDTH-j*8-8]), 
                .in_2(q_1[WIDTH-j*8-1 : WIDTH-j*8-8]),
                .o_done(done_add[j]), 
                .out(acc[WIDTH-j*8-1 : WIDTH-j*8-8]) 
            );
        end
    end
endgenerate

parameter REG_STAGES_IN_ADDER = (FIELD == "P251")? 3: 3;

pipeline_reg_gen #(.REG_STAGES(REG_STAGES_IN_ADDER), .WIDTH(`CLOG2(HO_SIZE_ADJ/WIDTH)))
REG_IN_SHARE_ADDR
  (
    .i_clk(i_clk),
    .i_data_in(in_share_addr),
    .o_data_out(in_acc_addr)
  );


wire [WIDTH-1:0] data_0, data_1;
wire [`CLOG2(HO_SIZE_ADJ/WIDTH)-1:0] in_acc_addr;
wire [WIDTH-1:0] q_1;

reg c_wen;
reg sel_c;

reg [`CLOG2(HO_SIZE_ADJ/WIDTH)-1:0] sk_addr_int;

always@(posedge i_clk)
begin
    sk_addr_int <= o_sk_addr;
    sk_wr_en <= o_sk_rd_en;
end

reg sk_wr_en;

assign data_0 = sk_wr_en? i_sk : acc;

assign data_1 = (first_c)?  {q_1[WIDTH-1:FIRST_ADDR_C%WIDTH], c[23:8]}:
                            {c[7:0],{(24){1'b0}}};

// mem_dual #(.WIDTH(WIDTH), .DEPTH(HO_SIZE_ADJ/WIDTH), .INIT(1), .FILE(FILE_SK),) 
mem_dual #(.WIDTH(WIDTH), .DEPTH(HO_SIZE_ADJ/WIDTH), .INIT(1)) 
 SEED_SHARE
 (
 .clock(i_clk),
//  .data_0(input_share_bram),
 .data_0(data_0),
 .data_1(data_1),
 .address_0(sk_wr_en? sk_addr_int :i_acc_rd? i_acc_addr: in_acc_addr),
 .address_1(i_hash_rd_en? hash_addr_int[`CLOG2(HO_SIZE_ADJ/32) -1:0]:(abc_rd || sel_c)? abc_addr :in_share_addr),
//  .address_1(i_hash_rd_en? hash_addr_int:(abc_rd || sel_c)? abc_addr :in_share_addr),
//  .wren_0(in_share_wr_en),
 .wren_0(done_add[0] | sk_wr_en),
 .wren_1(c_wen),
 .q_0(o_acc),
 .q_1(q_1)
 );

reg [`CLOG2(HO_SIZE_ADJ/WIDTH)-1:0] in_share_addr = 0;
reg in_share_wr_en;
reg last_ab;

 reg [4:0] state = 0;

parameter COUNT_WIDTH = (FIELD == "P251")? WIDTH/8:WIDTH/32;
reg [`CLOG2(COUNT_WIDTH):0] count;

reg [`CLOG2(LAMBDA/32)-1:0] count_hash = 0;

parameter s_wait_start              = 0;
parameter s_wait_hash_valid         = 1;
parameter s_sample_gf256            = 3;
parameter s_sample_gf256_store      = 4;

parameter s_sample_p251_load        = 5;
parameter s_sample_p251_store       = 6;

parameter s_sample_last_ab_p251     = 9;
parameter s_sample_store_ab_p251    = 10;

parameter s_terminate_shake         = 11;
parameter s_commit                  = 12;
parameter s_commit_done             = 13;

parameter s_wait_hash_valid_last    = 14;
parameter s_sample_last_ab_gf256    = 15;
parameter s_wait_for_last_commit    = 16;
 
parameter s_done                    = 17;

reg first_block = 0;

reg [D_HYPERCUBE:0] loop_count_i = 1;

reg start_inner_loop;
reg done_inner_loop;
reg last_commit;

reg hash_data_out_ready;
reg hash_start;
reg hash_force_done;
reg wait_for_last_commit;

always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        count <= 0;
        in_share_addr <= 0;
        count_hash <= 0;
        first_block <= 1;
        // o_hash_force_done <= 0;
        hash_force_done <= 0;
        done_inner_loop <= 0;
        commit <= 0;
        commit_addr <= 0;
        last_commit <= 0;
        wait_for_last_commit <= 0;
    end
    else begin
      if (state == s_wait_start) begin
            count <= 0;
            count_hash <= 0;
            first_block <= 1;
            // o_hash_force_done <= 0;
            hash_force_done <= 0;
            done_inner_loop <= 0;
            commit <= 0;
            last_commit <= 0;
            wait_for_last_commit <= 0;
            if (loop_count_i < 2**D_HYPERCUBE) begin
                in_share_addr <= 0;
            end
            else begin
                in_share_addr <= FIRST_ADDR_ABC;
            end
            if (start_inner_loop) begin
                if (loop_count_i < 2**D_HYPERCUBE) begin
                    state <= s_wait_hash_valid;
                end
                else begin
                    state <= s_wait_hash_valid_last;
                end
            end
      end 

      else if (state == s_wait_hash_valid) begin  
            
            first_block <= 1;
            // o_hash_force_done <= 0;
            hash_force_done <= 0;
            done_inner_loop <= 0;
            commit <= 0;
            last_commit <= 0;
            if (FIELD == "P251") begin
                in_share_addr <= 0;
                if (i_hash_data_out_valid) begin
                    state <= s_sample_p251_store;
                    // count <= count + 1;
                    count_hash <= count_hash+1;
                end
            end
            else begin
                if (i_hash_data_out_valid) begin
                    if (WIDTH == 32) begin
                        state <= s_sample_gf256;
                        in_share_addr <= in_share_addr + 1;
                        // in_share_addr <= 0;
                    end
                    else begin
                        state <= s_sample_gf256;
                        in_share_addr <= 0;
                    end
                    if (WIDTH == 32) begin
                        count <= 0;
                    end
                    else begin
                        count <= count + 1;
                    end
                end
            end
      end


      else if (state == s_sample_gf256) begin  
            // o_hash_force_done <= 0;
            hash_force_done <= 0;
            done_inner_loop <= 0;
            commit <= 0;
            if (in_share_addr == HO_SIZE_ADJ/WIDTH) begin
                // state <= s_done;
                // o_hash_force_done <= 1;
                hash_force_done <= 1;
                state <= s_terminate_shake;
            end
            else begin
                if (WIDTH ==32) begin
                    state <= s_sample_gf256;
                    if (i_hash_data_out_valid) begin
                         in_share_addr <= in_share_addr + 1;
                    end
                end
                else begin
                    if (i_hash_data_out_valid) begin
                        if (count == WIDTH/32 - 1) begin
                            count <= 0;
                            state <= s_sample_gf256_store;
                        end
                        else begin
                            count <= count + 1;
                        end
                    end
                end
            end
      end

      else if (state == s_sample_gf256_store) begin
            // o_hash_force_done <= 0;
            hash_force_done <= 0;
            done_inner_loop <= 0;
            commit <= 0;
            if (in_share_addr == HO_SIZE_ADJ/WIDTH) begin
                // state <= s_done;
                state <= s_terminate_shake;
                // o_hash_force_done <= 1;
                hash_force_done <= 1;
            end
            else begin
                if (i_hash_data_out_valid) begin
                    count <= count + 1;
                end
                state <= s_sample_gf256;
                if (count == 0) begin
                    in_share_addr <= in_share_addr + 1;
                end
            end
      end

      else if (state == s_sample_p251_load) begin  
            first_block <= 0;
            // o_hash_force_done <= 0;
            hash_force_done <= 0;
            done_inner_loop <= 0;
            commit <= 0;
            if (in_share_addr == HO_SIZE_ADJ/WIDTH) begin
                // state <= s_done;
                state <= s_terminate_shake;
                // o_hash_force_done <= 1;
                hash_force_done <= 1;
            end
            else begin
                if (i_hash_data_out_valid) begin
                    count_hash <= count_hash+1;
                    state <= s_sample_p251_store;

                    if ((count == WIDTH/8 - 1) && (threshold)) begin
                        count <= 0;
                    end
                    else begin
                        if (threshold) begin
                            count <= count + 1;
                        end
                    end

                    if ((count == 0) &&  (~first_block) && threshold) begin
                        in_share_addr <= in_share_addr + 1;
                    end
                end
            end
      end

      else if (state == s_sample_p251_store) begin  
            first_block <= 0;
            // o_hash_force_done <= 0;
            hash_force_done <= 0;
            done_inner_loop <= 0;
            commit <= 0;
            if (in_share_addr == HO_SIZE_ADJ/WIDTH) begin
                // state <= s_done;
                state <= s_terminate_shake;
                // o_hash_force_done <= 1;
                hash_force_done <= 1;
            end
            else begin
                if (count_hash == 3) begin
                    count_hash <= 0;
                    state <= s_sample_p251_load;
                end
                else begin
                    count_hash <= count_hash + 1;
                end
                if ((count == WIDTH/8 - 1) && threshold) begin
                    count <= 0;
                end
                else begin
                    if (threshold) begin
                        count <= count + 1;
                    end
                end
                if ((count == 0) &&  (~first_block) && threshold) begin
                        in_share_addr <= in_share_addr + 1;
                end
            end
      end
      
      else if (state == s_terminate_shake) begin
            // o_hash_force_done <= 0;
            hash_force_done <= 0;
            if (i_hash_force_done_ack) begin
                state <= s_commit;
                commit <= 1;
                // state <= s_done;
            end
      end

      else if (state == s_wait_hash_valid_last) begin
            if (in_share_addr == FIRST_ADDR_C_ADJ/WIDTH - 1) begin
                state <= s_sample_last_ab_gf256;
                // o_hash_force_done <= 1;
                hash_force_done <= 1;
            end
            else begin
                if (i_hash_data_out_valid) begin
                    in_share_addr <= in_share_addr + 1;
                end
            end
      end

      else if (state == s_sample_last_ab_gf256) begin
            // o_hash_force_done <= 0;
            hash_force_done <= 0;
            
            last_commit <= 1;
            commit <= 1;
            if (loop_count_i < 2**D_HYPERCUBE) begin
                state <= s_commit;
                wait_for_last_commit <= 0;
            end
            else begin
                state <= s_wait_for_last_commit;
                wait_for_last_commit <= 1;
            end
      end

      else if (state == s_wait_for_last_commit) begin
            wait_for_last_commit <= 0;
            if (start_last_commit) begin
                state <= s_commit;
            end
      end

      else if (state == s_commit) begin
            commit <= 1;
            count <= 0;
            in_share_addr <= 0;
            count_hash <= 0;
            first_block <= 0;
            // o_hash_force_done <= 0;
            hash_force_done <= 0;
            done_inner_loop <= 0;
            state <= s_commit_done;
      end

      else if (state == s_commit_done) begin
            commit <= 1;
            count <= 0;
            in_share_addr <= 0;
            // count_hash <= 0;
            first_block <= 0;
            // o_hash_force_done <= 0;
            hash_force_done <= 0;
            done_inner_loop <= 0;
            if (count_hash == LAMBDA/32 - 1) begin
                commit_addr <= commit_addr + 1;;
                count_hash <= 0;
                state <= s_done;
            end
            else begin
                if (i_hash_data_out_valid) begin
                    commit_addr <= commit_addr + 1;
                    count_hash <= count_hash + 1;
                end
            end
      end
      


      else if (state == s_done) begin
            done_inner_loop <= 1;
            // o_hash_force_done <= 1;
            hash_force_done <= 1;
            state <= s_wait_start;
            commit <= 0;
            last_commit <= 0;
            wait_for_last_commit <= 0;
            if (commit_addr == COMMIT_RAM_DEPTH-1) begin
                commit_addr <= 0;
            end
      end

    end
end

always@(state, start_inner_loop, i_hash_data_out_valid, i_hash_data_out_valid_reg, count, first_block, threshold, FIELD, WIDTH)
begin
    case(state)

    s_wait_start:begin
        // o_hash_data_out_ready <= 0;
        hash_data_out_ready <= 0;
        in_share_wr_en <= 0;
        load <= 0;
        shift <= 0;
        in_share_valid <= 0;
        commit_wr_en <= 0;
        last_ab <= 0;
        if (start_inner_loop) begin
            // o_hash_start <= 1;
            hash_start <= 1;
        end
        else begin
            // o_hash_start <= 0;
            hash_start <= 0;
        end
        // if (WIDTH == 32 && i_hash_data_out_valid && FIELD == "GF256") begin
        //     in_share_wr_en <= 1;
        // end
        // else begin
        //     in_share_wr_en <= 0;
        // end
    end

    s_wait_hash_valid:begin
        // o_hash_start <= 0;
        hash_start <= 0;
        in_share_wr_en <= 0;
        shift <= 0;
        in_share_valid <= 0;
        commit_wr_en <= 0;
        last_ab <= 0;
        if (i_hash_data_out_valid) begin
            // o_hash_data_out_ready <= 1;
            hash_data_out_ready <= 1;
            load <= 1;
        end
        else begin
            load <= 0;
            // o_hash_data_out_ready <= 0;
            hash_data_out_ready <= 0;
        end
    end

    s_sample_gf256:begin
        // o_hash_start <= 0;
        hash_start <= 0;
        // o_hash_data_out_ready <= 1;
        hash_data_out_ready <= 1;
        load <= 0;
        shift <= 0;
        in_share_valid <= 0;
        commit_wr_en <= 0;
        last_ab <= 0;
        if (i_hash_data_out_valid || (FIELD == "GF256" && i_hash_data_out_valid_reg && WIDTH == 32)) begin
            if (count == 0) begin
                in_share_wr_en <= 1;
            end
            else begin
                in_share_wr_en <= 0;
            end
        end
        else begin
            in_share_wr_en <= 0;
        end
    end

    s_sample_gf256_store: begin
        // o_hash_start <= 0;
        hash_start <= 0;
        // o_hash_data_out_ready <= 1;
        hash_data_out_ready <= 1;
        load <= 0;
        shift <= 0;
        in_share_valid <= 0;
        commit_wr_en <= 0;
        last_ab <= 0;
        if (count == 0) begin
            in_share_wr_en <= 1;
        end
        else begin
            in_share_wr_en <= 0;
        end
    end

    s_sample_p251_load:begin
        // o_hash_start <= 0;
        hash_start <= 0;
        hash_data_out_ready <= 1;
        // o_hash_data_out_ready <= 1;
        commit_wr_en <= 0;
        last_ab <= 0;
        if (i_hash_data_out_valid) begin
            load <= 1;
            shift <= 0;
            if (threshold) begin
                in_share_valid <= 1;
            end
            else begin
                in_share_valid <= 0;
            end
            if (count == 0 && threshold) begin
                in_share_wr_en <= 1;
            end
            else begin
                in_share_wr_en <= 0;
            end
        end
        else begin
            in_share_wr_en <= 0;
            load <= 0;
            shift <= 0;
            in_share_valid <= 0;
        end
    end

    s_sample_p251_store:begin
        // o_hash_start <= 0;
        hash_start <= 0;
        // o_hash_data_out_ready <= 0;
        hash_data_out_ready <= 0;
        load <= 0;
        shift <= 1;
        commit_wr_en <= 0;
        last_ab <= 0;
        if (threshold) begin
            in_share_valid <= 1;
        end
        else begin
            in_share_valid <= 0;
        end
        if ((count == 0) && (~first_block)&& threshold) begin
            in_share_wr_en <= 1;
        end
        else begin
            in_share_wr_en <= 0;
        end
    end

    s_terminate_shake: begin
        // o_hash_start <= 0;
        hash_start <= 0;
        // o_hash_data_out_ready <= 0;
        hash_data_out_ready <= 0;
        in_share_wr_en <= 0;
        load <= 0;
        shift <= 0;
        in_share_valid <= 0;
        commit_wr_en <= 0;
        last_ab <= 0;
    end

    s_wait_hash_valid_last:begin
        // o_hash_start <= 0;
        hash_start <= 0;
        shift <= 0;
        in_share_valid <= 0;
        commit_wr_en <= 0;
        last_ab <= 0;
        if (i_hash_data_out_valid) begin
            // o_hash_data_out_ready <= 1;
            hash_data_out_ready <= 1;
        end
        else begin
            // o_hash_data_out_ready <= 0;
            hash_data_out_ready <= 0;
        end
        if (i_hash_data_out_valid_reg) begin
            load <= 1;
            in_share_wr_en <= 1;
        end
        else begin
            load <= 0;
            in_share_wr_en <= 0;
        end
        // if (i_hash_data_out_valid || (FIELD == "GF256" && i_hash_data_out_valid_reg && WIDTH == 32)) begin
        //     if (count == 0) begin
        //         in_share_wr_en <= 1;
        //     end
        //     else begin
        //         in_share_wr_en <= 0;
        //     end
        // end
        // else begin
        //     in_share_wr_en <= 0;
        // end
    end

    s_sample_last_ab_gf256: begin
        // o_hash_start <= 0;
        hash_start <= 0;
        shift <= 0;
        in_share_valid <= 0;
        commit_wr_en <= 0;
        last_ab <= 1;
        if (i_hash_data_out_valid) begin
            // o_hash_data_out_ready <= 1;
            hash_data_out_ready <= 1;
        end
        else begin
            // o_hash_data_out_ready <= 0;
            hash_data_out_ready <= 0;
        end
        if (i_hash_data_out_valid_reg) begin
            load <= 1;
            in_share_wr_en <= 1;
        end
        else begin
            load <= 0;
            in_share_wr_en <= 0;
        end
    end

    s_wait_for_last_commit: begin
        // o_hash_start <= 0;
        hash_start <= 0;
        shift <= 0;
        in_share_valid <= 0;
        commit_wr_en <= 0;
        last_ab <= 0;
        // o_hash_data_out_ready <= 0;
        hash_data_out_ready <= 0;
        load <= 0;
        in_share_wr_en <= 0;
    end

    s_commit: begin
        // o_hash_data_out_ready <= 0;
        hash_data_out_ready <= 0;
        in_share_wr_en <= 0;
        load <= 0;
        shift <= 0;
        in_share_valid <= 0;
        commit_wr_en <= 0;
        // o_hash_start <= 1;
        hash_start <= 1;
        last_ab <= 0;
    end

    s_commit_done: begin
        // o_hash_data_out_ready <= 0;
        // hash_data_out_ready <= 0;
        in_share_wr_en <= 0;
        load <= 0;
        shift <= 0;
        in_share_valid <= 0;
        // o_hash_start <= 0;
        hash_start <= 0;
        last_ab <= 0;
        if (i_hash_data_out_valid) begin
            // o_hash_data_out_ready <= 1;
            hash_data_out_ready <= 1;
            commit_wr_en <= 1;
        end
        else begin
            // o_hash_data_out_ready <= 0;
            hash_data_out_ready <= 0;
            commit_wr_en <= 0;
        end

    end

    s_done:begin
        // o_hash_start <= 0;
        hash_start <= 0;
        // o_hash_data_out_ready <= 0;
        hash_data_out_ready <= 0;
        in_share_wr_en <= 0;
        load <= 0;
        shift <= 0;
        in_share_valid <= 0;
        commit_wr_en <= 0;
        last_ab <= 0;
    end

    default:begin
        // o_hash_start <= 0;
        hash_start <= 0;
        // o_hash_data_out_ready <= 0;
        hash_data_out_ready <= 0;
        in_share_wr_en <= 0;
        load <= 0;
        shift <= 0;
        in_share_valid <= 0;
        commit_wr_en <= 0;
        last_ab <= 0;
    end

    endcase
end

genvar i;

wire [`CLOG2(HO_SIZE_ADJ/WIDTH)-1:0] in_acc_addr = 0;
wire [WIDTH-1:0] m_share_for_out [D_HYPERCUBE-1:0];
wire [WIDTH-1:0] m_share_mem_pool_out [D_HYPERCUBE-1:0];
wire [WIDTH-1:0] in_mshare [D_HYPERCUBE-1:0];
wire [WIDTH/8-1:0] m_share_add_done [D_HYPERCUBE-1:0];
genvar k;

wire [WIDTH-1:0] input_share_mshare;
wire [D_HYPERCUBE:0] i_minus_1;


assign input_share_mshare = input_share_bram;

assign i_minus_1 = loop_count_i - 1;

generate
    for(k=0;k<D_HYPERCUBE;k=k+1) begin
        // generate
        for(i=0;i<WIDTH/8;i=i+1) begin
            if (FIELD == "P251") begin 
                p251_add #(.REG_IN(1), .REG_OUT(1))
                P251_ADD 
                (
                    .i_clk(i_clk), 
                    .i_start(start_add), 
                    .in_1(input_share_mshare[WIDTH-i*8-1 : WIDTH-i*8-8]), 
                    .in_2(m_share_mem_pool_out[k][WIDTH-i*8-1 : WIDTH-i*8-8]),
                    .o_done(m_share_add_done[k][i]),
                    .out(in_mshare[k][WIDTH-i*8-1 : WIDTH-i*8-8]) 
                );
            end
            else begin 
                gf_add #(.REG_IN(1), .REG_OUT(0))
                GF_ADD 
                (
                    .i_clk(i_clk), 
                    .i_start(start_add), 
                    .in_1(input_share_mshare[WIDTH-i*8-1 : WIDTH-i*8-8]), 
                    .in_2(m_share_mem_pool_out[k][WIDTH-i*8-1 : WIDTH-i*8-8]),
                    .o_done(m_share_add_done[k][i]),
                    .out(in_mshare[k][WIDTH-i*8-1 : WIDTH-i*8-8]) 
                );
            end
        end
        // endgenerate

        mem_dual #(.WIDTH(WIDTH), .DEPTH(HO_SIZE_ADJ/WIDTH), .INIT(1)) 
        INPUT_M_SHARE
        (
        .clock(i_clk),
        .data_0(in_mshare[k]),
        .data_1(0),
        .address_0(i_input_mshare_rd? i_input_mshare_addr : in_acc_addr),
        .address_1(in_share_addr),
        // .wren_0(m_share_add_done[k][0] && (~loop_count_i[k]) && (loop_count_i != 2**D)),
        .wren_0(m_share_add_done[k][0] && (~i_minus_1[k])),
        .wren_1(0),
        .q_0(m_share_for_out[k]),
        .q_1(m_share_mem_pool_out[k])
        );
    end
endgenerate

// assign o_input_mshare = (i_input_mshare_sel == 0)? m_share_for_out[0]:
//                         (i_input_mshare_sel == 1)? m_share_for_out[1]:
//                         (i_input_mshare_sel == 2)? m_share_for_out[2]:
//                         (i_input_mshare_sel == 3)? m_share_for_out[3]:
//                         (i_input_mshare_sel == 4)? m_share_for_out[4]:
//                         (i_input_mshare_sel == 5)? m_share_for_out[5]:
//                         (i_input_mshare_sel == 6)? m_share_for_out[6]:
//                                                    m_share_for_out[7];

assign o_input_mshare =  {m_share_for_out[0], m_share_for_out[1], m_share_for_out[2], m_share_for_out[3], m_share_for_out[4], m_share_for_out[5], m_share_for_out[6] ,m_share_for_out[7]};
                        



// reg [3:0] c_state;
// parameter c_s_wait_start = 0;

// always@(posedge i_clk)
// begin
//     if (i_rst) begin
//         c_state <= c_s_wait_start;
//     end
//     else begin
//     end
// end

// always@(*)
// begin
//     case(c_state)


//     endcase
// end

//seed manager
reg [4:0] h_state;
parameter h_s_wait_start            = 0;
parameter h_s_stall_0               = 1;
parameter h_s_load_pk               = 2;
parameter s_wait_done_treeprg       = 3;
parameter h_s_stall_1               = 4;
parameter h_s_load_seed             = 5;
parameter h_s_start_iloop           = 6;
parameter h_s_done_iloop            = 7;
parameter h_s_check_i               = 8;

parameter h_s_last_seed             = 9;
parameter h_s_start_last_seed       = 10;

parameter h_s_done_last_seed        = 11;

parameter h_s_load_out_ABC          = 12;
parameter h_s_stall_2               = 13;
parameter h_s_mul_add_ab            = 14;
parameter h_s_mul_add_ab_done       = 15;

parameter h_s_wr_c_back_start       = 16;
parameter h_s_wr_c_back_done        = 17;
parameter h_s_done                  = 18;

reg [`CLOG2(SEED_SIZE/32):0] count_seed_block = 0;

reg first_c;

reg start_last_commit = 0;

always@(posedge i_clk)
begin
    if (i_rst) begin
        h_state <= h_s_wait_start;
        o_seed_e_addr <= 0;
        ss_addr <= 0;
        count_seed_block <=0;
        o_done <= 0;
        loop_count_i <= 1;
        abc_addr <= FIRST_ADDR_ABC;
        start_last_commit <= 0;
        o_sk_addr <= 0;
    end
    else begin
        if (h_state == h_s_wait_start) begin
            // ss_addr <= 0;
            o_done <= 0;
            loop_count_i <= 1;
            start_last_commit <= 0;
            abc_addr <= FIRST_ADDR_ABC;
            o_sk_addr <= 0;
            ss_addr <= SALT_SIZE/32;
            if (i_start) begin
            // if (done_treeprg) begin
                h_state <= h_s_stall_0;
                // h_state <= h_s_stall_1;                
                // o_seed_e_addr <= o_seed_e_addr + 1;
                // count_seed_block <= count_seed_block + 1;
            end
            else begin
                // o_seed_e_addr <= 0;
                // count_seed_block <= 0;
            end
        end

        else if (h_state == h_s_stall_0) begin
            h_state <= h_s_load_pk;
            // ss_addr <= 0;
            // o_seed_e_addr <= 0;
            // count_seed_block <= 0;
            o_sk_addr <= o_sk_addr+1;
        end

        else if (h_state == h_s_load_pk) begin
            if (o_sk_addr == HO_SIZE_ADJ/WIDTH - 1) begin
                h_state <= s_wait_done_treeprg;
                // o_salt_addr <= 0;
                // ss_addr <= ss_addr + 1;
            end 
            else begin
                o_sk_addr <= o_sk_addr + 1;
                // ss_addr <= ss_addr + 1;
            end
        end

        else if (h_state == s_wait_done_treeprg) begin
            ss_addr <= SALT_SIZE/32;
            if (done_treeprg) begin
                h_state <= h_s_stall_1;
                count_seed_block <= count_seed_block + 1;
                o_seed_e_addr <= o_seed_e_addr + 1;
            end
            else begin
                count_seed_block <= 0;
                o_seed_e_addr <= 0;
            end
        end

        else if (h_state == h_s_stall_1) begin
            ss_addr <= ss_addr + 1;
            h_state <= h_s_load_seed;
            o_seed_e_addr <= o_seed_e_addr + 1;
            count_seed_block <= count_seed_block + 1;
        end

        else if (h_state == h_s_load_seed) begin
            if (count_seed_block == SEED_SIZE/32) begin
                ss_addr <= SALT_SIZE/32;
                // o_seed_e_addr <= o_seed_e_addr + 1;
                h_state <= h_s_start_iloop;
                count_seed_block <= 0;
            end 
            else begin
                 ss_addr <= ss_addr + 1;
                 count_seed_block <= count_seed_block + 1;
                 o_seed_e_addr <= o_seed_e_addr + 1;
            end
        end 
        
        else if (h_state == h_s_start_iloop) begin
            h_state <= h_s_done_iloop;
        end

        else if (h_state == h_s_done_iloop) begin
            if (done_inner_loop || wait_for_last_commit) begin
                h_state <= h_s_check_i;
                loop_count_i <= loop_count_i + 1;
            end
        end

        else if (h_state == h_s_check_i) begin
            if (loop_count_i == 2**D_HYPERCUBE+1) begin
        //    if (loop_count_i == 1) begin
                h_state <= h_s_load_out_ABC;
                loop_count_i <= loop_count_i - 1;
                // h_state <= h_s_last_seed;
                // loop_count_i <= 0;
                // o_seed_e_addr <= o_seed_e_addr + 1;
            end
            else begin
                h_state <= 0;
                o_seed_e_addr <= o_seed_e_addr + 1;
                count_seed_block <= count_seed_block + 1;
                h_state <= h_s_load_seed;
            end
        end

        else if (h_state == h_s_last_seed) begin
             if (count_seed_block == SEED_SIZE/32) begin
                ss_addr <= SALT_SIZE/32;
                h_state <= h_s_start_last_seed;
                count_seed_block <= 0;
            end 
            else begin
                 ss_addr <= ss_addr + 1;
                 count_seed_block <= count_seed_block + 1;
                 o_seed_e_addr <= o_seed_e_addr + 1;
            end   
        end

        else if (h_state == h_s_start_last_seed) begin
            h_state <= h_s_done_last_seed;
        end

        else if (h_state == h_s_done_last_seed) begin
            start_last_commit <= 0;
            if (done_inner_loop) begin
                h_state <= h_s_done;
            end
        end

        else if (h_state == h_s_load_out_ABC) begin
            if (abc_addr == HO_SIZE_ADJ/WIDTH - 1) begin
                abc_addr <= FIRST_ADDR_ABC;
                h_state <= h_s_stall_2;
            end
            else begin
                abc_addr <= abc_addr + 1;
            end
        end

        else if (h_state == h_s_stall_2) begin
           h_state <= h_s_mul_add_ab;
        end

        else if (h_state == h_s_mul_add_ab) begin
           h_state <= h_s_mul_add_ab_done;
           abc_addr <= FIRST_ADDR_C_ADJ/WIDTH - 1;
        end

        else if (h_state == h_s_mul_add_ab_done) begin
            if (done_add_c[0]) begin
                h_state <= h_s_wr_c_back_start;
                abc_addr <= abc_addr + 1;
            end
        end

        else if (h_state == h_s_wr_c_back_start) begin
            if (abc_addr == HO_SIZE_ADJ/WIDTH - 1) begin
                // h_state <= h_s_done;
                h_state <= h_s_done_last_seed;
                start_last_commit <= 1;
            end
            else begin
                h_state <= h_s_wr_c_back_start;
                abc_addr <= abc_addr + 1;
                start_last_commit <= 0;
            end
        end

        //add logic for final commit

        else if (h_state == h_s_done) begin
            o_done <= 1;
           h_state <= h_s_wait_start;
        end
    end
end

always@(*)
begin
    case(h_state)
        h_s_wait_start:begin
            ss_wen <= 0;
            ss_type <= 1;
            abc_rd <= 0;
            start_mul_ab<= 0;
            first_c <= 0;
            c_wen <= 0;
            sel_c <= 0;
            // sk_wr_en <= 0;
            o_sk_rd_en <= 0;
            o_seed_e_rd <= 0;
            start_inner_loop <= 0;
            // if (i_start) begin
            // if (done_treeprg) begin
            //     o_seed_e_rd <= 1;
            // end
            // else begin
            //     o_seed_e_rd <= 0;
            // end
        end

        h_s_stall_0:begin
            o_seed_e_rd <= 0;
            ss_wen <= 0;
            ss_type <= 1;
            abc_rd <= 0;
            start_mul_ab<= 0;
            first_c <= 0;
            c_wen <= 0;
            sel_c <= 0;
            // sk_wr_en <= 0;
            o_sk_rd_en <= 1;
            start_inner_loop <= 0;
        end

        h_s_load_pk:begin
            o_seed_e_rd <= 0;
            ss_wen <= 0;
            ss_type <= 0;
            abc_rd <= 0;
            start_mul_ab<= 0;
            first_c <= 0;
            c_wen <= 0;
            sel_c <= 0;
            // sk_wr_en <= 1;
            o_sk_rd_en <= 1;
            start_inner_loop <= 0;
        end

        s_wait_done_treeprg: begin
            ss_wen <= 0;
            ss_type <= 1;
            abc_rd <= 0;
            start_mul_ab<= 0;
            first_c <= 0;
            c_wen <= 0;
            sel_c <= 0;
            // sk_wr_en <= 0;
            o_sk_rd_en <= 0;
            start_inner_loop <= 0;
            if (done_treeprg) begin
                o_seed_e_rd <= 1;
            end
            else begin
                o_seed_e_rd <= 0;
            end
        end

        h_s_stall_1: begin
            o_seed_e_rd <= 1;
            ss_wen <= 1;
            ss_type <= 1;
            abc_rd <= 0;
            start_mul_ab<= 0;
            first_c <= 0;
            c_wen <= 0;
            sel_c <= 0;
            // sk_wr_en <= 0;
            o_sk_rd_en <= 0;
            start_inner_loop <= 0;
        end

        h_s_load_seed: begin
            o_seed_e_rd <= 1;
            ss_wen <= 1;
            ss_type <= 0;
            abc_rd <= 0;
            start_mul_ab<= 0;
            first_c <= 0;
            sel_c <= 0;
            // sk_wr_en <= 0;
            o_sk_rd_en <= 0;
            start_inner_loop <= 0;
        end

        h_s_start_iloop: begin
            o_seed_e_rd <= 1;
            ss_wen <= 0;
            ss_type <= 0;
            start_inner_loop <= 1;
            abc_rd <= 0;
            start_mul_ab<= 0;
            first_c <= 0;
            c_wen <= 0;
            sel_c <= 0;
            // sk_wr_en <= 0;
            o_sk_rd_en <= 0;
        end

        h_s_done_iloop: begin
            o_seed_e_rd <= 1;
            ss_wen <= 0;
            ss_type <= 0;
            start_inner_loop <= 0;
            abc_rd <= 0;
            start_mul_ab<= 0;
            first_c <= 0;
            c_wen <= 0;
            sel_c <= 0;
            // sk_wr_en <= 0;
            o_sk_rd_en <= 0;
        end

        h_s_check_i: begin
            o_seed_e_rd <= 1;
            ss_wen <= 0;
            ss_type <= 0;
            start_inner_loop <= 0;
            abc_rd <= 0;
            start_mul_ab<= 0;
            first_c <= 0;
            c_wen <= 0;
            sel_c <= 0;
            // sk_wr_en <= 0;
            o_sk_rd_en <= 0;
        end

        h_s_last_seed: begin
            o_seed_e_rd <= 1;
            ss_wen <= 1;
            ss_type <= 0;
            abc_rd <= 0;
            start_mul_ab<= 0;
            start_inner_loop <= 0;
            first_c <= 0;
            c_wen <= 0;
            sel_c <= 0;
            // sk_wr_en <= 0;
            o_sk_rd_en <= 0;
        end

        h_s_start_last_seed: begin
            o_seed_e_rd <= 1;
            ss_wen <= 0;
            ss_type <= 0;
            abc_rd <= 0;
            start_mul_ab<= 0;
            start_inner_loop <= 1;
            first_c <= 0;
            sel_c <= 0;
            // sk_wr_en <= 0;
            o_sk_rd_en <= 0;
        end

        h_s_done_last_seed: begin
            o_seed_e_rd <= 1;
            ss_wen <= 0;
            ss_type <= 0;
            abc_rd <= 0;
            start_mul_ab<= 0;
            start_inner_loop <= 0;
            first_c <= 0;
            sel_c <= 0;
            c_wen <= 0;
            // sk_wr_en <= 0;
            o_sk_rd_en <= 0;
        end

        h_s_load_out_ABC: begin
            o_seed_e_rd <= 1;
            ss_wen <= 0;
            ss_type <= 0;
            start_inner_loop <= 0;
            abc_rd <= 1;
            start_mul_ab<= 0;
            first_c <= 0;
            c_wen <= 0;
            sel_c <= 0;
            // sk_wr_en <= 0;
            o_sk_rd_en <= 0;
        end

        h_s_stall_2: begin
            o_seed_e_rd <= 1;
            ss_wen <= 0;
            ss_type <= 0;
            start_inner_loop <= 0;
            abc_rd <= 1;
            start_mul_ab<= 0;
            first_c <= 0;
            c_wen <= 0;
            sel_c <= 0;
            // sk_wr_en <= 0;
            o_sk_rd_en <= 0;
        end

        h_s_mul_add_ab: begin
            o_seed_e_rd <= 1;
            ss_wen <= 0;
            ss_type <= 0;
            start_inner_loop <= 0;
            abc_rd <= 0;
            start_mul_ab<= 1;
            first_c <= 0;
            c_wen <= 0;
            sel_c <= 0;
            // sk_wr_en <= 0;
            o_sk_rd_en <= 0;
        end

        h_s_mul_add_ab_done: begin
            o_seed_e_rd <= 1;
            ss_wen <= 0;
            ss_type <= 0;
            start_inner_loop <= 0;
            start_mul_ab<= 0;
            sel_c <= 1;
            // sk_wr_en <= 0;
            o_sk_rd_en <= 0;
            if (done_add_c[0]) begin
                first_c <= 1;
                c_wen <= 1;
            end
            else begin
                first_c <= 0;
                c_wen <= 0;
            end
        end

        h_s_wr_c_back_start: begin
            o_seed_e_rd <= 1;
            ss_wen <= 0;
            ss_type <= 0;
            start_inner_loop <= 0;
            abc_rd <= 0;
            start_mul_ab<= 0;
            first_c <= 0;
            c_wen <= 1;
            sel_c <= 1;
            // sk_wr_en <= 0;
            o_sk_rd_en <= 0;
        end

        h_s_done:begin
            o_seed_e_rd <= 0; 
            ss_wen <= 0;
            ss_type <= 0;
            abc_rd <= 0;
            start_mul_ab<= 0;
            c_wen <= 0;
            sel_c <= 0;
            // sk_wr_en <= 0;
            o_sk_rd_en <= 0;
        end

        default:begin
            o_seed_e_rd <= 0;
            ss_wen <= 0;
            ss_type <= 0;
            start_inner_loop <= 0;
            abc_rd <= 0;
            c_wen <= 0;
            first_c <= 0;
            sel_c <= 0;
            // sk_wr_en <= 0;
            o_sk_rd_en <= 0;
        end
    endcase
end



reg [`CLOG2(HO_SIZE_ADJ/WIDTH)-1:0] abc_addr = 0;
reg abc_rd = 0;
// reg in_share_wr_en;
reg [ABC_SIZE_ADJ-1:0] abc_reg;

// Logic for ABC
always@(posedge i_clk)
begin
    if (i_start) begin
        abc_reg <= 0;
    end
    else if (abc_rd) begin
        abc_reg <= {abc_reg[ABC_SIZE_ADJ-WIDTH-1:0],q_1};
    end
end

wire [D_SPLIT*T*8 -1: 0] a;
wire [D_SPLIT*T*8 -1: 0] b;
wire [D_SPLIT*T*8 -1: 0] c, c_1, c_2;

assign a = abc_reg[ABC_SIZE_ADJ-START_ADDR_A-1:ABC_SIZE_ADJ-START_ADDR_A-D_SPLIT*T*8];
assign b = abc_reg[ABC_SIZE_ADJ-START_ADDR_A-D_SPLIT*T*8-1:ABC_SIZE_ADJ-START_ADDR_A-D_SPLIT*T*8-D_SPLIT*T*8];
assign c_1 = abc_reg[ABC_SIZE_ADJ-START_ADDR_A-D_SPLIT*T*8-D_SPLIT*T*8-1:ABC_SIZE_ADJ-START_ADDR_A-D_SPLIT*T*8-D_SPLIT*T*8-D_SPLIT*T*8];


reg start_mul_ab;
wire [T-1:0] done_mul_ab;
genvar iz;
generate
    for(iz=0;iz<T;iz=iz+1) begin
        if (FIELD == "P251") begin 
            p251_mul 
            P251_MULT 
            (
                .clk(i_clk), 
                .start(start_mul_ab), 
                .in_1(a[8*T-iz*8-1 : 8*T-iz*8-8]), 
                .in_2(b[8*T-iz*8-1 : 8*T-iz*8-8]),
                .done(done_mul_ab[iz]), 
                .out(c_2[8*T-iz*8-1 : 8*T-iz*8-8]) 
            );
        end
        else begin 
            gf_mul 
            GF_MULT 
            (
                .clk(i_clk), 
                .start(start_mul_ab), 
                .in_1(a[8*T-iz*8-1 : 8*T-iz*8-8]), 
                .in_2(b[8*T-iz*8-1 : 8*T-iz*8-8]),
                .done(done_mul_ab[iz]), 
                .out(c_2[8*T-iz*8-1 : 8*T-iz*8-8]) 
            );
        end
    end
endgenerate

wire start_add_c;
wire [T-1:0]done_add_c;

assign start_add_c = done_mul_ab[0];

genvar jz;
generate
    for(jz=0;jz<T;jz=jz+1) begin
        if (FIELD == "P251") begin 
            p251_add #(.REG_IN(1), .REG_OUT(1))
            P251_ADD_C 
            (
                .i_clk(i_clk), 
                .i_start(start_add_c), 
                .in_1(c_1[8*T-jz*8-1 : 8*T-jz*8-8]), 
                .in_2(c_2[8*T-jz*8-1 : 8*T-jz*8-8]),
                .o_done(done_add_c[jz]), 
                .out(c[8*T-jz*8-1 : 8*T-jz*8-8]) 
            );
        end
        else begin 
            gf_add #(.REG_IN(1), .REG_OUT(1))
            GF_ADD_C 
            (
                .i_clk(i_clk), 
                .i_start(start_add_c), 
                .in_1(c_1[8*T-jz*8-1 : 8*T-jz*8-8]), 
                .in_2(c_2[8*T-jz*8-1 : 8*T-jz*8-8]),
                .o_done(done_add_c[jz]), 
                .out(c[8*T-jz*8-1 : 8*T-jz*8-8]) 
            );
        end
    end
endgenerate

assign o_a = a;
assign o_b = b;
assign o_c = c;

endmodule