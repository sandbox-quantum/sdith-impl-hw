`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/26/2023 02:51:47 PM
// Design Name: 
// Module Name: gf_mul_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module h_gen_and_mat_vec_mul_tb #(
    
    // parameter FIELD = "P251",
   parameter FIELD = "GF256",
    
    parameter PARAMETER_SET = "L1",

    parameter M =  (PARAMETER_SET == "L1")? 230:
                    (PARAMETER_SET == "L3")? 352:
                    (PARAMETER_SET == "L5")? 480:
                                             230,

    parameter MAT_ROW_SIZE_BYTES = (PARAMETER_SET == "L1")? 104:
                                   (PARAMETER_SET == "L3")? 159:
                                   (PARAMETER_SET == "L5")? 202:
                                                            8,
                                                            
    parameter MAT_COL_SIZE_BYTES  =(PARAMETER_SET == "L1")? 126:
                                   (PARAMETER_SET == "L3")? 193:
                                   (PARAMETER_SET == "L5")? 278:
                                                            8,
    parameter VEC_SIZE_BYTES = (PARAMETER_SET == "L1")? 126:
                               (PARAMETER_SET == "L3")? 193:
                               (PARAMETER_SET == "L5")? 278:
                                                        8,
    
    parameter VEC_WEIGHT = (PARAMETER_SET == "L1")? 126:
                           (PARAMETER_SET == "L3")? 193:
                           (PARAMETER_SET == "L5")? 278:
                                                     8,
    
    parameter VEC_SIZE = VEC_SIZE_BYTES*8,
    parameter N_GF = 4, 
    
    parameter MAT_SIZE_BYTES = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES,
    
    parameter PROC_SIZE = N_GF*8,
    
    parameter MRS_BITS = MAT_ROW_SIZE_BYTES*8,
    parameter MCS_BITS = MAT_COL_SIZE_BYTES*8,
    
    parameter MAT_ROW_SIZE = MRS_BITS + (PROC_SIZE - MRS_BITS%PROC_SIZE)%PROC_SIZE,
    parameter MAT_COL_SIZE = MCS_BITS + (PROC_SIZE - MCS_BITS%PROC_SIZE)%PROC_SIZE,

    parameter SEED_SIZE =   (PARAMETER_SET == "L1")?    128:
                            (PARAMETER_SET == "L3")?    192:
                            (PARAMETER_SET == "L5")?    256:
                                                        128,
    
    parameter MAT_SIZE = MAT_ROW_SIZE*MAT_COL_SIZE_BYTES
    
)
(

    );
    
reg i_clk = 0;
reg i_rst = 0;
reg i_start = 0;
reg i_res_en = 0;
wire [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0] o_mat_addr;
wire [`CLOG2(M)-1:0] o_vec_addr;

wire [PROC_SIZE-1:0] i_mat;
wire [8-1:0] i_vec;
wire [PROC_SIZE-1:0] o_res;
wire [`CLOG2(VEC_SIZE/PROC_SIZE)-1:0] i_res_addr;
wire o_done;
reg i_vec_add_wen = 0;

wire [32-1:0]                       o_hash_data_in;
wire [`CLOG2((SEED_SIZE)/32) -1:0]       i_hash_addr;
wire                                i_hash_rd_en;
wire [32-1:0]                       i_hash_data_out;
wire                                i_hash_data_out_valid;
wire                                o_hash_data_out_ready;
wire  [32-1:0]                      o_hash_input_length; // in bits
wire  [32-1:0]                      o_hash_output_length; // in bits
wire                                o_hash_start;
wire                                i_hash_done;
wire                                i_hash_force_done_ack;
wire                                o_force_done_ack;
wire                                o_hash_force_done;

h_gen_and_mat_vec_mul
#(
.FIELD(FIELD),
.PARAMETER_SET(PARAMETER_SET),
.MAT_ROW_SIZE_BYTES(MAT_ROW_SIZE_BYTES),
.MAT_COL_SIZE_BYTES(MAT_COL_SIZE_BYTES),
.VEC_SIZE_BYTES(VEC_SIZE_BYTES),
.VEC_WEIGHT(VEC_WEIGHT),
.N_GF(N_GF)
)
DUT
(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_start(i_start),

    .i_seed_h(0),
    .i_seed_h_wr_en(0),
    .i_seed_h_addr(0),

    .o_vec_addr(o_vec_addr),
    .i_vec(i_vec),
    .o_res(o_res),
    .i_res_en(i_res_en),
    .i_res_addr(i_res_addr),
    .i_vec_add_wen(i_vec_add_wen),
    .o_done(o_done),

.o_hash_data_in          (o_hash_data_in       ),   
.i_hash_addr             (i_hash_addr          ),   
.i_hash_rd_en            (i_hash_rd_en         ),   
.i_hash_data_out         (i_hash_data_out      ),   
.i_hash_data_out_valid   (i_hash_data_out_valid),   
.o_hash_data_out_ready   (o_hash_data_out_ready),   
.o_hash_input_length     (o_hash_input_length  ),   
.o_hash_output_length    (o_hash_output_length ),   
.o_hash_start            (o_hash_start         ),   
.i_hash_force_done_ack   (i_hash_force_done_ack),   
.o_hash_force_done       (o_hash_force_done    )
);


hash_mem_interface #(.IO_WIDTH(32), .MAX_RAM_DEPTH(SEED_SIZE/32), .PARAMETER_SET(PARAMETER_SET))
  HASH_INTERFACE
   (
    .clk                (i_clk                   ),
    .rst                (i_rst                   ),
    .i_data_in          (o_hash_data_in          ),
    .o_addr             (i_hash_addr             ),            
    .o_rd_en            (i_hash_rd_en            ),
    .o_data_out         (i_hash_data_out         ),
    .o_data_out_valid   (i_hash_data_out_valid   ),
    .i_data_out_ready   (o_hash_data_out_ready   ), 
    .i_input_length     (o_hash_input_length     ),
    .i_output_length    (o_hash_output_length    ),                 
    .i_start            (o_hash_start            ),
    .o_force_done_ack   (i_hash_force_done_ack   ),
    .i_force_done       (o_hash_force_done       ) 
    
    );
 
 integer start_time, end_time;
 initial
 begin
     i_start <= 0;
     i_rst <= 1;
     #100

     i_rst <= 0;

     #10
     
     i_start <= 1;
     start_time = $time;
     #10 
     
     i_start <= 0;
     
     @(posedge o_done)
     end_time = $time;
     $display("Total Clock Cycles = %d", (end_time-start_time-5)/10);
     #100
     $finish;
     
 end
 
 always #5 i_clk = ~i_clk;
 
// input wire                     clock,
//    input wire [WIDTH-1:0]         data,
//    input wire [`CLOG2(DEPTH)-1:0] address,
//    input wire                     wr_en,
//    output reg [WIDTH-1:0]         q
 
 mem_single #(.WIDTH(8), .DEPTH(M), .FILE("S_L1.mem")) 
 VECTOR
 (
 .clock(i_clk),
 .data(0),
 .address(o_vec_addr),
 .wr_en(0),
 .q(i_vec)
 );
 
 
endmodule
