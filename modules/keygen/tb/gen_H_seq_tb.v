/*
 * This file is testbench for H matrix generation.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module gen_H_seq_tb
#(
    
    parameter FIELD = "P251",
    parameter PARAMETER_SET = "L3",
    parameter MAT_ROW_SIZE_BYTES = (PARAMETER_SET == "L1")? 104:
                                   (PARAMETER_SET == "L3")? 159:
                                   (PARAMETER_SET == "L5")? 202:
                                                            8,
                                                            
    parameter MAT_COL_SIZE_BYTES  =(PARAMETER_SET == "L1")? 126:
                                   (PARAMETER_SET == "L3")? 193:
                                   (PARAMETER_SET == "L5")? 278:
                                                            8,

    parameter SEED_SIZE =   (PARAMETER_SET == "L1")? 128:
                            (PARAMETER_SET == "L3")? 192:
                            (PARAMETER_SET == "L5")? 256:
                                                     128,
    parameter N_GF = 8, 
    
    parameter MAT_SIZE_BYTES = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES,
    
    parameter PROC_SIZE = N_GF*8,

    parameter MRAS_BITS = MAT_ROW_SIZE_BYTES*8,
    parameter MRCS_BITS = MAT_COL_SIZE_BYTES*8,
    
    parameter MAT_ROW_SIZE = MRAS_BITS + (PROC_SIZE - MRAS_BITS%PROC_SIZE)%PROC_SIZE,
    parameter MAT_COL_SIZE = MRCS_BITS + (PROC_SIZE - MRCS_BITS%PROC_SIZE)%PROC_SIZE,

    
    
    // parameter MAT_SIZE = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE,
    parameter MAT_SIZE = MAT_ROW_SIZE*MAT_COL_SIZE_BYTES,
    
    parameter MS = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES*8,
    parameter SHAKE_SQUEEZE = 2*(MS + (32-MS%32)%32),

    parameter SEED_FILE = (PARAMETER_SET == "L1")? "SEED_H.mem":
                          (PARAMETER_SET == "L3")? "SEED_H_L3.mem":
                          (PARAMETER_SET == "L5")? "SEED_H_L5.mem":
                                                   "SEED_H.mem"

    
    
)(

);

reg i_clk = 0;
reg i_rst;
reg i_start;

reg  [31:0]     i_seed_h = 0;
wire  [`CLOG2(SEED_SIZE/32)-1:0]      i_seed_h_addr;
wire  [`CLOG2(SEED_SIZE/32)-1:0]      i_prng_addr;
reg             i_seed_wr_en = 0;
// wire            o_start_h_proc;

wire  [31:0]    o_seed_h_prng;
wire          o_start_prng;

wire   [31:0]  i_prng_out;
wire          i_prng_out_valid;
wire          o_prng_out_ready;
    
reg           i_h_out_en =0;
reg [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0] i_h_out_addr;
wire [PROC_SIZE-1:0] o_h_out;

wire          o_done;
wire          prng_rd;

gen_H_seq #(.FIELD(FIELD),.PARAMETER_SET(PARAMETER_SET), .N_GF(N_GF), .SEED_FILE(SEED_FILE))
H_Matrix_Gen 
(
.i_clk(i_clk),      
.i_rst(i_rst),
.i_start(i_start),
.i_seed_h(i_seed_h),
.i_seed_h_addr(i_seed_h_addr),
.i_seed_wr_en(i_seed_wr_en),

// .o_start_h_proc(o_start_h_proc),
.o_seed_h_prng(o_seed_h_prng),

.o_start_prng(o_start_prng),
.i_prng_rd(prng_rd),
.i_prng_out(i_prng_out),
.i_prng_out_valid(i_prng_out_valid),
.o_prng_out_ready(o_prng_out_ready), 
.i_prng_addr(i_prng_addr),

.i_h_out_en(i_h_out_en),
.i_h_out_addr(i_h_out_addr),
.o_h_out(o_h_out),
.o_done(o_done)
);


// gen_H #(.PARAMETER_SET(PARAMETER_SET))
// H_Matrix_Gen 
// (
// .i_clk(i_clk),      
// .i_rst(i_rst),
// .i_start(start_gen_h),
// .i_seed_h(seed_h),
// .i_seed_h_addr(seed_h_addr),
// .i_seed_wr_en(seed_h_wr_en),

// .o_start_h_proc(o_hash_start_h),
// .o_seed_h_prng(o_hash_data_in_h),

// .o_start_prng(o_hash_start_h),

// .i_prng_rd(i_hash_rd_en_h | i_seed_h_rd),
// .i_prng_addr(i_hash_rd_en_h? i_hash_addr_h : i_seed_h_rd? i_seed_h_addr : 0),

// .i_prng_out(i_hash_data_out_h),
// .i_prng_out_valid(i_hash_data_out_valid_h),
// .o_prng_out_ready(o_hash_data_out_ready_h),

// .o_prng_force_done(o_hash_force_done_h    ),

// .i_h_out_en(o_mat_vec_rd),
// .i_h_out_addr(h_mat_addr),
// .o_h_out(h_mat),

// .o_done(done_gen_h)
// );


hash_mem_interface #(.PARAMETER_SET(PARAMETER_SET), .IO_WIDTH(32), .MAX_RAM_DEPTH(SEED_SIZE/32))
  DUT
   (
    .clk(i_clk),
    .rst(i_rst),
        
    .i_data_in(o_seed_h_prng),
    
    .i_input_length(SEED_SIZE),
//    .i_output_length(MAT_COL_SIZE_BYTES*MAT_ROW_SIZE_BYTES*8),
    .i_output_length(SHAKE_SQUEEZE),
    .i_start(o_start_prng),
    
    .o_rd_en(prng_rd),
    .i_data_out_ready(o_prng_out_ready),
    .o_addr(i_prng_addr),
    .o_data_out(i_prng_out),
    .o_data_out_valid(i_prng_out_valid),
    .i_force_done(0),
    .o_done(o_done)
    
    );

integer start_time, end_time;
initial 
begin
    i_rst <= 1;
    i_start <= 0;
    //  i_prng_out_valid <= 0;

    #100

    i_rst <= 0;
    
    #10
    i_start <= 1;
    start_time = $time;
    #10
    i_start <= 0;

    #100



    @(posedge o_done)
    end_time = $time;

    $display("Time taken to generate H matrix =", (end_time-start_time-5)/10 );
    
    #100

    $finish;

end

always #5 i_clk = ! i_clk;

 always
 begin
     @(posedge o_done)
     $writememb("H_L1.mem", H_Matrix_Gen.RESULT_MEM.mem);
 end

endmodule