/*
 * This file is testbench for H matrix generation.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module gen_H_tb
#(

    parameter PARAMETER_SET = "L1",
    parameter MAT_ROW_SIZE_BYTES = (PARAMETER_SET == "L1")? 104:
                                   (PARAMETER_SET == "L2")? 159:
                                   (PARAMETER_SET == "L3")? 202:
                                                            8,
                                                            
    parameter MAT_COL_SIZE_BYTES  =(PARAMETER_SET == "L1")? 126:
                                   (PARAMETER_SET == "L2")? 193:
                                   (PARAMETER_SET == "L3")? 278:
                                                            8,

    parameter SEED_SIZE =   (PARAMETER_SET == "L1")? 128:256,

    parameter MAT_SIZE_BYTES = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES,
    
    
    parameter MAT_ROW_SIZE = MAT_ROW_SIZE_BYTES*8,
    parameter MAT_COL_SIZE = MAT_COL_SIZE_BYTES*8,

    parameter N_GF = 8, 
    
    parameter MAT_SIZE = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES*8,
    parameter PROC_SIZE = N_GF*8,
    
    parameter COL_SIZE_MEM = MAT_COL_SIZE_BYTES/N_GF,
    parameter ROW_SIZE_MEM = MAT_ROW_SIZE_BYTES/N_GF
    
    
)(

);

reg i_clk = 0;
reg i_rst;
reg i_start;

reg  [31:0]     i_seed_h;
wire  [`CLOG2(SEED_SIZE/32)-1:0]      i_seed_h_addr;
reg             i_seed_wr_en;
wire            o_start_h_proc;

wire  [31:0]    o_seed_h_prng;
wire          o_start_prng;

wire   [31:0]  i_prng_out;
wire          i_prng_out_valid;
wire          o_prng_out_ready;
    
reg           i_h_out_en;
reg [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0] i_h_out_addr;
wire [PROC_SIZE-1:0] o_h_out;

wire          o_done;

gen_H #(.PARAMETER_SET(PARAMETER_SET), .FILE("SEED_H.mem"))
H_Matrix_Gen 
(
.i_clk(i_clk),      
.i_rst(i_rst),
.i_start(i_start),
.i_seed_h(i_seed_h),
.i_seed_h_addr(i_seed_h_addr),
.i_seed_wr_en(i_seed_wr_en),

.o_start_h_proc(o_start_h_proc),
.o_seed_h_prng(o_seed_h_prng),

.o_start_prng(o_start_prng),

.i_prng_out(i_prng_out),
.i_prng_out_valid(i_prng_out_valid),
.o_prng_out_ready(o_prng_out_ready), 
.i_h_out_en(i_h_out_en),
.i_h_out_addr(i_h_out_addr),
.o_h_out(o_h_out),
.o_done(o_done)
);


hash_mem_interface #(.PARAMETER_SET(PARAMETER_SET), .IO_WIDTH(32), .MAX_RAM_DEPTH(SEED_SIZE/32))
  DUT
   (
    .clk(i_clk),
    .rst(i_rst),
        
    .i_data_in(o_seed_h_prng),
    
    .i_input_length(SEED_SIZE),
    .i_output_length(MAT_SIZE),
    .i_start(o_start_prng),
    
    // .o_rd_en(),
    .i_data_out_ready(o_prng_out_ready),
    .o_addr(i_seed_h_addr),
    .o_data_out(i_prng_out),
    .o_data_out_valid(i_prng_out_valid),
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

endmodule