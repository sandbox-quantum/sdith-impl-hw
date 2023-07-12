/*
 * This file is SampleWitness module.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module keygen 
#(

    parameter PARAMETER_SET = "L1",
    
    parameter LAMBDA =  (PARAMETER_SET == "L1")? 128:
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

    parameter D =   (PARAMETER_SET == "L1")? 1:
                        (PARAMETER_SET == "L3")? 2:
                        (PARAMETER_SET == "L5")? 2:
                                                 1,
    
    parameter N_GF = 8, 
                                                    
    parameter MAT_ROW_SIZE_BYTES = (PARAMETER_SET == "L1")? 104:
                                   (PARAMETER_SET == "L3")? 159:
                                   (PARAMETER_SET == "L5")? 202:
                                                            8,
                                                            
    parameter MAT_COL_SIZE_BYTES  =(PARAMETER_SET == "L1")? 126:
                                   (PARAMETER_SET == "L3")? 193:
                                   (PARAMETER_SET == "L5")? 278:
                                                            8,
    
    parameter VEC_S_WEIGHT =  (PARAMETER_SET == "L1")? 126:
                            (PARAMETER_SET == "L3")? 193:
                            (PARAMETER_SET == "L5")? 278:
                                                     8,

    parameter VEC_SIZE_BYTES = (PARAMETER_SET == "L1")? 126:
                               (PARAMETER_SET == "L3")? 193:
                               (PARAMETER_SET == "L5")? 278:
                                                        8,

    parameter MAT_SIZE_BYTES = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES,
    
    parameter PROC_SIZE = N_GF*8,
    
    parameter MRS_BITS = MAT_ROW_SIZE_BYTES*8,
    parameter MCS_BITS = MAT_COL_SIZE_BYTES*8,
    
    parameter MAT_ROW_SIZE = MRS_BITS + (PROC_SIZE - MRS_BITS%PROC_SIZE)%PROC_SIZE,
    parameter MAT_COL_SIZE = MCS_BITS + (PROC_SIZE - MCS_BITS%PROC_SIZE)%PROC_SIZE,


    
    parameter MAT_SIZE = MAT_ROW_SIZE*MAT_COL_SIZE_BYTES,
    
    parameter MS = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES*8,
    parameter SHAKE_SQUEEZE = MS + (32-MS%32)%32
    
    

)(
    input                                   i_clk,
    input                                   i_rst,
    input                                   i_start,

    input   [32-1:0]                        i_seed_root,
    input   [`CLOG2(LAMBDA/32)-1:0]         i_seed_root_addr,
    input                                   i_seed_root_wr_en,


    output  [7:0]                           o_q,
    input   [`CLOG2(WEIGHT/D + 1):0]        i_q_addr,
    input                                   i_q_rd,

    output  [7:0]                           o_s,
    input   [`CLOG2(M):0]                   i_s_addr,
    input                                   i_s_rd,

    output  [7:0]                           o_p,
    input   [`CLOG2(WEIGHT):0]              i_p_addr,
    input                                   i_p_rd,

    `ifdef TWO_SHARES
        output  [7:0]                           o_q_0,
        input   [`CLOG2(WEIGHT/D + 1):0]        i_q_0_addr,
        input                                   i_q_0_rd,

        output  [7:0]                           o_p_0,
        input   [`CLOG2(WEIGHT/D):0]            i_p_0_addr,
        input                                   i_p_0_rd,    
    `endif 
    
    output [31:0]                           o_seed_h,
    input   [`CLOG2(WEIGHT/D):0]            i_seed_h_addr,
    input                                   i_seed_h_rd,

    output  [PROC_SIZE-1:0]                 o_y,
    input   [`CLOG2(MAT_ROW_SIZE/PROC_SIZE)-1:0] i_y_addr,
    input                                   i_y_rd,

    output   reg                            o_done,


    output   [32-1:0]                       o_hash_data_in,
    input    [`CLOG2(LAMBDA/32) -1:0]       i_hash_addr,
    input                                   i_hash_rd_en,

    input    wire [32-1:0]                  i_hash_data_out,
    input    wire                           i_hash_data_out_valid,
    output   wire                           o_hash_data_out_ready,

    output   wire  [32-1:0]                 o_hash_input_length, // in bits
    output   wire  [32-1:0]                 o_hash_output_length, // in bits

    output   wire                           o_hash_start,
    input    wire                           i_hash_force_done_ack,
    output   wire                           o_hash_force_done
);



wire    [32-1:0]                    i_hash_data_out_wit;
wire    [32-1:0]                    o_hash_data_in_wit;
wire                                o_hash_data_out_ready_wit;
wire    [32-1:0]                    o_hash_input_length_wit;
wire    [32-1:0]                    o_hash_output_length_wit;
wire                                o_hash_start_wit;
wire                                o_hash_force_done_wit;
wire                                i_hash_rd_en_wit;
wire    [`CLOG2(LAMBDA/32) -1:0]    i_hash_addr_wit;

wire     [32-1:0]                   i_hash_data_out_h;
wire     [32-1:0]                   o_hash_data_in_h;
wire                                o_hash_data_out_ready_h;
wire    [32-1:0]                    o_hash_input_length_h;
wire    [32-1:0]                    o_hash_output_length_h;
wire                                o_hash_start_h;
wire                                o_hash_force_done_h;
wire                                i_hash_rd_en_h;
wire    [`CLOG2(LAMBDA/32) -1:0]    i_hash_addr_h;


wire     [32-1:0]                   i_hash_data_out_root;
wire     [32-1:0]                   o_hash_data_in_root;
reg                                 o_hash_data_out_ready_root;
wire    [32-1:0]                    o_hash_input_length_root;
wire    [32-1:0]                    o_hash_output_length_root;
reg                                 o_hash_start_root;
reg                                 o_hash_force_done_root;
wire    [`CLOG2(LAMBDA/32) -1:0]    i_hash_addr_root;


// o_hash_data_in;
// o_hash_data_out_ready;
// o_hash_input_length;
// o_hash_output_length;
// o_hash_start;
// o_hash_force_done;

//2'b00 - ROOT Seed Processing
//2'b01 - WITNESS Seed Processing
//2'b10 - H SEED Processing
reg [1:0] sel_hash;

assign o_hash_data_in = (sel_hash == 2'b01)? o_hash_data_in_wit :
                        (sel_hash == 2'b10)? o_hash_data_in_h:
                                             q_seed_root;

assign o_hash_input_length = LAMBDA;

assign o_hash_output_length = (sel_hash == 2'b01)?  o_hash_output_length_wit :
                              (sel_hash == 2'b10)?  SHAKE_SQUEEZE:
                                                    2*LAMBDA;
                                                
assign o_hash_data_out_ready = (sel_hash == 2'b01)?  o_hash_data_out_ready_wit :
                               (sel_hash == 2'b10)?  o_hash_data_out_ready_h:
                                                     o_hash_data_out_ready_root;

assign o_hash_start = o_hash_start_wit | o_hash_start_h | o_hash_start_root;
// assign o_hash_force_done =  o_hash_force_done_h | o_hash_force_done_root;
assign o_hash_force_done = o_hash_force_done_h | o_hash_force_done_wit | o_hash_force_done_root;

assign i_hash_rd_en_root = (sel_hash == 0)? i_hash_rd_en : 0;
assign i_hash_rd_en_wit = (sel_hash == 1)? i_hash_rd_en : 0;
assign i_hash_rd_en_h = (sel_hash == 2)? i_hash_rd_en : 0;

assign i_hash_addr_wit = i_hash_addr;
assign i_hash_addr_h = i_hash_addr;

assign i_hash_data_out_wit = i_hash_data_out;
assign i_hash_data_out_h = i_hash_data_out;


assign i_hash_data_out_valid_wit = (sel_hash == 1)? i_hash_data_out_valid :0;
assign i_hash_data_out_valid_h = (sel_hash == 2)? i_hash_data_out_valid :0;


mem_single #(.WIDTH(32), .DEPTH(LAMBDA/32)) 
 SEED_ROOT
 (
 .clock(i_clk),
 .data(i_seed_root),
 .address(i_seed_root_wr_en? i_seed_root_addr: i_hash_rd_en? i_hash_addr: 0),
 .wr_en(i_seed_root_wr_en),
 .q(q_seed_root)
 );

reg start_wit;
wire [31:0] seed_wit; 
reg [`CLOG2(LAMBDA/32)-1:0] seed_wit_addr;
reg seed_wit_wr_en;
wire done_wit;

assign seed_wit = i_hash_data_out;
assign o_s = s_out;

samplewitness #(.PARAMETER_SET(PARAMETER_SET))
SAMP_WIT 
(
.i_clk                  (i_clk                      ),
.i_rst                  (i_rst                      ),
.i_start                (start_wit                  ),
.i_seed_wit             (seed_wit                   ),
.i_seed_wit_addr        (seed_wit_addr              ),
.i_seed_wit_wr_en       (seed_wit_wr_en             ),
.o_q                    (o_q                        ),
.i_q_addr               (i_q_addr                   ),
.i_q_rd                 (i_q_rd                     ),
.o_p                    (o_p                        ),
.i_p_addr               (i_p_addr                   ),
.i_p_rd                 (i_p_rd                     ),
.o_s                    (s_out                      ),
.i_s_addr               (i_s_rd? i_s_addr :o_mat_vec_rd? s_vec_addr: vec_s_rd? vec_add_s_addr: 0 ),
.i_s_rd                 (o_mat_vec_rd | vec_s_rd    ),
.o_done                 (done_wit                   ),

`ifdef TWO_SHARES
.o_q_0                  (o_q_0                      ),
.i_q_0_addr             (i_q_0_addr                 ),
.i_q_0_rd               (i_q_0_rd                   ),
.o_p_0                  (o_p_0                      ),
.i_p_0_addr             (i_p_0_addr                 ),
.i_p_0_rd               (i_p_0_rd                   ),
`endif 

.o_hash_data_in          (o_hash_data_in_wit       ),   
.i_hash_addr             (i_hash_addr_wit          ),   
.i_hash_rd_en            (i_hash_rd_en_wit         ),   
.i_hash_data_out         (i_hash_data_out_wit      ),   
.i_hash_data_out_valid   (i_hash_data_out_valid_wit),   
.o_hash_data_out_ready   (o_hash_data_out_ready_wit),   
.o_hash_input_length     (o_hash_input_length_wit  ),   
.o_hash_output_length    (o_hash_output_length_wit ),   
.o_hash_start            (o_hash_start_wit         ),   
.o_hash_force_done       (o_hash_force_done_wit    )

);


reg start_gen_h;
wire [31:0] seed_h;
reg [`CLOG2(LAMBDA/32)-1:0] seed_h_addr;
reg seed_h_wr_en;

wire done_gen_h;

assign seed_h = i_hash_data_out;

//gen_H #(.PARAMETER_SET(PARAMETER_SET), .N_GF(N_GF))
gen_H_seq #(.PARAMETER_SET(PARAMETER_SET), .N_GF(N_GF))
H_Matrix_Gen 
(
.i_clk(i_clk),      
.i_rst(i_rst),
.i_start(start_gen_h),
.i_seed_h(seed_h),
.i_seed_h_addr(seed_h_addr),
.i_seed_wr_en(seed_h_wr_en),

// .o_start_h_proc(o_hash_start_h),
.o_seed_h_prng(o_hash_data_in_h),

.o_start_prng(o_hash_start_h),

.i_prng_rd(i_hash_rd_en_h | i_seed_h_rd),
.i_prng_addr(i_hash_rd_en_h? i_hash_addr_h : i_seed_h_rd? i_seed_h_addr : 0),

.i_prng_out(i_hash_data_out_h),
.i_prng_out_valid(i_hash_data_out_valid_h),
.o_prng_out_ready(o_hash_data_out_ready_h),

.o_prng_force_done(o_hash_force_done_h    ),

.i_h_out_en(o_mat_vec_rd),
.i_h_out_addr(h_mat_addr),
.o_h_out(h_mat),

.o_done(done_gen_h)
);

assign o_seed_h = o_hash_data_in_h;

reg start_mat_vec_mul;
wire done_mat_vec_mul;
wire [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0] h_mat_addr;
wire [`CLOG2(M)-1:0] s_vec_addr;
reg [`CLOG2(M)-1:0] s_vec_addr_reg;
wire [PROC_SIZE-1:0] h_mat;
wire [`CLOG2(M)+7:0] s_vec;
wire [7:0] s_out;
wire o_mat_vec_rd;

always@(posedge i_clk) 
begin
    s_vec_addr_reg <= s_vec_addr;
end

assign s_vec = {s_vec_addr_reg,s_out};
assign o_y = vec_res;

// mat_sparvec_mul
// #(
// .MAT_ROW_SIZE_BYTES(MAT_ROW_SIZE_BYTES),
// .MAT_COL_SIZE_BYTES(MAT_COL_SIZE_BYTES),
// .VEC_SIZE_BYTES(VEC_SIZE_BYTES),
// .VEC_WEIGHT(VEC_S_WEIGHT),
// .N_GF(N_GF)
// )
// MAT_VEC_MUL
// (
//     .i_clk(i_clk),
//     .i_rst(i_rst),
//     .i_start(start_mat_vec_mul),
//     .o_mat_addr(h_mat_addr),
//     .o_vec_addr(s_vec_addr),
//     .o_mat_vec_rd(o_mat_vec_rd),
//     .i_mat(h_mat),
//     .i_vec(s_vec),

//     .o_res(vec_res),
//     .i_res_en(vec_s_rd | i_y_rd),
//     .i_res_addr(i_y_rd? i_y_addr: vec_add_vec_addr),
//     .o_done(done_mat_vec_mul),

//     .i_vec_add_addr(o_res_vec_add_addr),
//     .i_vec_add_wen(o_res_vec_add_wr_en),
//     .i_vec_add(o_res_vec_add)
// );

mat_vec_mul_ser
#(
.PARAMETER_SET(PARAMETER_SET),
.MAT_ROW_SIZE_BYTES(MAT_ROW_SIZE_BYTES),
.MAT_COL_SIZE_BYTES(MAT_COL_SIZE_BYTES),
.VEC_SIZE_BYTES(VEC_SIZE_BYTES),
.VEC_WEIGHT(VEC_S_WEIGHT),
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
    .i_vec(s_out),

    .o_res(vec_res),
    .i_res_en(vec_s_rd | i_y_rd),
    .i_res_addr(i_y_rd? i_y_addr: vec_add_vec_addr),
    .o_done(done_mat_vec_mul),

    .i_vec_add_addr(o_res_vec_add_addr),
    .i_vec_add_wen(o_res_vec_add_wr_en),
    .i_vec_add(o_res_vec_add)
);

reg start_vec_add;
wire [PROC_SIZE-1:0] o_res_vec_add;
wire [`CLOG2(MAT_ROW_SIZE/PROC_SIZE)-1:0] o_res_vec_add_addr;
wire o_res_vec_add_wr_en;

wire vec_s_rd;
wire [`CLOG2(MAT_ROW_SIZE/PROC_SIZE)-1:0] vec_add_vec_addr;
wire [PROC_SIZE-1:0] vec_res;
wire done_vec_add;

wire [`CLOG2(M)-1:0] vec_add_s_addr;
wire [7:0] s_vec_add;

assign s_vec_add = s_out;

vec_add
#(
.PARAMETER_SET(PARAMETER_SET),
.MAT_ROW_SIZE_BYTES(MAT_ROW_SIZE_BYTES),
.M(M),
.S_START_ADDR(MAT_COL_SIZE_BYTES),
.N_GF(N_GF)
)
VECTOR_ADD
(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_start(start_vec_add),

    .o_vec_addr(vec_add_vec_addr),
    .i_vec(vec_res),
    .o_s_addr(vec_add_s_addr),
    .i_s(s_vec_add),
    .o_vec_s_rd(vec_s_rd),

    .o_res_wr_en(o_res_vec_add_wr_en),
    .o_res(o_res_vec_add),
    .o_res_addr(o_res_vec_add_addr),
    .o_done(done_vec_add)
);

reg done_wit_tracker = 0;
reg done_gen_h_tracker = 0;

always@(posedge i_clk)
begin
    if (i_start || o_done) begin
        done_wit_tracker <= 0;
    end
    else if (done_wit) begin
        done_wit_tracker <= 1;
    end
end

always@(posedge i_clk)
begin
    if (i_start || o_done) begin
        done_gen_h_tracker <= 0;
    end
    else if (done_gen_h) begin
        done_gen_h_tracker <= 1;
    end
end

reg [3:0] state;
parameter s_wait_start                 =0;
parameter s_expand_root_and_load_h     =1;
parameter s_expand_root_and_load_wit   =2;
parameter s_stall_force_done           =3;
parameter s_sample_witness             =4;
parameter s_sample_witness_done        =5;
parameter s_gen_h                      =6;
parameter s_hsa                        =7;
parameter s_sb_plus_hsa                =8;
parameter s_done                       =9;



always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        o_done <= 0;
        o_hash_data_out_ready_root <= 0;
        seed_wit_addr <= 0;
        seed_h_addr <= 0;
        o_hash_force_done_root <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            o_done <= 0;
            o_hash_data_out_ready_root <= 1;
            o_hash_force_done_root <= 0;
            if (i_start) begin
                state <= s_expand_root_and_load_wit;
            end
        end
        
        else if (state == s_expand_root_and_load_wit) begin
            o_hash_data_out_ready_root <= 1;
            if (i_hash_data_out_valid) begin
                if (seed_wit_addr == LAMBDA/32 - 1) begin
                    seed_wit_addr <= 0; 
                    state <= s_expand_root_and_load_h;
                end
                else begin
                    seed_wit_addr <= seed_wit_addr + 1;
                end
            end
            o_done <= 0;
        end

        else if (state == s_expand_root_and_load_h) begin
            if (i_hash_data_out_valid) begin
                if (seed_h_addr == LAMBDA/32 - 1) begin
                    seed_h_addr <= 0; 
                    state <= s_stall_force_done;
                    o_hash_data_out_ready_root <= 0;
                end
                else begin
                    seed_h_addr <= seed_h_addr + 1;
                    o_hash_data_out_ready_root <= 1;
                end
            end
            o_done <= 0;
        end

        else if (state == s_stall_force_done) begin
            o_hash_force_done_root <= 1;
            state <= s_sample_witness;
            o_done <= 0;
        end

        else if (state == s_sample_witness) begin
            o_hash_force_done_root <= 0;
            if (i_hash_force_done_ack) begin
                state <= s_sample_witness_done;
                o_done <= 0;
            end
        end

        else if (state == s_sample_witness_done) begin
            if (i_hash_force_done_ack) begin
                state <= s_gen_h;
            end
            o_done <= 0;
        end

        else if (state == s_gen_h) begin
            // if (done_wit) begin
            if (done_wit_tracker && done_gen_h_tracker) begin
                state <= s_hsa;
            end
            o_done <= 0;
        end

        else if (state == s_hsa) begin
            if (done_mat_vec_mul) begin
                state <= s_sb_plus_hsa;
                // state <= s_done;
            end
            o_done <= 0;
        end

        else if (state == s_sb_plus_hsa) begin
            if (done_vec_add) begin
                state <= s_done;
            end
            o_done <= 0;
        end

        else if (state == s_done) begin
            state <= s_wait_start;
            o_done <= 1;
        end

    end
end

always@(state, i_start, i_hash_data_out_valid, done_wit, i_hash_force_done_ack, done_mat_vec_mul, done_wit_tracker, done_gen_h_tracker)
begin

    case(state)
        
    s_wait_start: begin
        sel_hash <= 0;
        seed_wit_wr_en <= 0;
        seed_h_wr_en <= 0;
        start_wit <= 0;
        start_mat_vec_mul <= 0;
        start_vec_add <= 0; 
        if (i_start) begin
            o_hash_start_root <= 1;
        end
        else begin
            o_hash_start_root <= 0;
        end
    end
    
    s_expand_root_and_load_wit: begin
        o_hash_start_root <= 0;
        seed_h_wr_en <= 0;
        start_wit <= 0;
        start_mat_vec_mul <= 0;
        start_vec_add <= 0; 
        if (i_hash_data_out_valid) begin
            seed_wit_wr_en <= 1;
        end
        else begin
            seed_wit_wr_en <= 0;
        end 
    end

    s_expand_root_and_load_h: begin
        o_hash_start_root <= 0;
        seed_wit_wr_en <= 0;
        start_wit <= 0;
        start_mat_vec_mul <= 0;
        start_vec_add <= 0; 
        if (i_hash_data_out_valid) begin
            seed_h_wr_en <= 1;
        end
        else begin
            seed_h_wr_en <= 0;
        end 
    end

    s_stall_force_done: begin
        start_wit <= 0;
        sel_hash <= 0;
        seed_h_wr_en <= 0;
        seed_wit_wr_en <= 0;
        o_hash_start_root <= 0;
        start_mat_vec_mul <= 0;
        start_vec_add <= 0; 
    end

    s_sample_witness: begin
        o_hash_start_root <= 0;
        seed_h_wr_en <= 0;
        seed_wit_wr_en <= 0;
        start_mat_vec_mul <= 0;
        start_vec_add <= 0; 
        if (i_hash_force_done_ack) begin
            start_wit <= 1;
            sel_hash <= 1;
        end
        else begin
            start_wit <= 0;
            sel_hash <= 0;
        end
    end

    s_sample_witness_done: begin
        start_wit <= 0;
        seed_wit_wr_en <= 0;
        seed_h_wr_en <= 0;
        o_hash_start_root <= 0;
        start_mat_vec_mul <= 0;
        start_vec_add <= 0; 
        if (i_hash_force_done_ack) begin
            start_gen_h <= 1;
            sel_hash <= 2;
        end
        else begin
            start_gen_h <= 0;
            sel_hash <= 1;
        end
    end

    s_gen_h: begin
        sel_hash <= 2;
        start_wit <= 0;
        o_hash_start_root <= 0;
        seed_wit_wr_en <= 0;
        seed_h_wr_en <= 0;
        start_wit <= 0;
        start_gen_h <= 0;
        start_vec_add <= 0; 
        // if (done_wit) begin
        if (done_wit_tracker && done_gen_h_tracker) begin
            start_mat_vec_mul <= 1;
        end
        else begin
            start_mat_vec_mul <= 0;  
        end
    end

    s_hsa: begin
        sel_hash <= 0;
        start_wit <= 0;
        o_hash_start_root <= 0;
        seed_wit_wr_en <= 0;
        seed_h_wr_en <= 0;
        start_wit <= 0;
        start_gen_h <= 0;
        start_mat_vec_mul <= 0;  
        if (done_mat_vec_mul) begin
            start_vec_add <= 1;
        end
        else begin
            start_vec_add <= 0;  
        end
    end

    s_sb_plus_hsa: begin
        sel_hash <= 0;
        start_wit <= 0;
        o_hash_start_root <= 0;
        seed_wit_wr_en <= 0;
        seed_h_wr_en <= 0;
        start_wit <= 0;
        start_gen_h <= 0;
        start_mat_vec_mul <= 0;  
        start_vec_add <= 0;  
    end

    s_done: begin
        sel_hash <= 0;
        start_wit <= 0;
        o_hash_start_root <= 0;
        seed_wit_wr_en <= 0;
        seed_h_wr_en <= 0;
        start_wit <= 0;
        start_gen_h <= 0;
        start_mat_vec_mul <= 0;
        start_vec_add <= 0;   
    end
     
     default: begin
        o_hash_start_root <= 0;
        seed_wit_wr_en <= 0;
        seed_h_wr_en <= 0;
        start_wit <= 0;
        sel_hash <= 0;
        start_gen_h <= 0;
        start_mat_vec_mul <= 0;
    end
    
    endcase
    
end

endmodule