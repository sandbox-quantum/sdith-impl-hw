/*
 * This file is testbench for KeyGen module.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module keygen_tb
#(
    parameter FIELD = "GF256",
//    parameter FIELD = "P251",
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

    parameter MAT_SIZE_BYTES = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES,
    
    
    parameter MAT_ROW_SIZE = MAT_ROW_SIZE_BYTES*8,
    parameter MAT_COL_SIZE = MAT_COL_SIZE_BYTES*8,


    
    parameter MAT_SIZE = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES*8,
    parameter PROC_SIZE = N_GF*8    
    
)(

);

reg                                 i_clk = 0;
reg                                 i_rst;
reg                                 i_start;

reg   [32-1:0]                     i_seed_root;
reg  [`CLOG2(LAMBDA/32)-1:0]       i_seed_root_addr;
reg                                i_seed_root_wr_en;

wire  [8-1:0]                       o_q;
reg   [`CLOG2(M):0]                 i_q_addr;
reg                                 i_q_rd = 0;
wire  [8-1:0]                       o_p;
reg   [`CLOG2(M):0]                 i_p_addr;
reg                                 i_p_rd = 0;
wire  [8-1:0]                       o_s;
reg   [`CLOG2(M):0]                 i_s_addr;
reg                                 i_s_rd = 0;

wire  [8-1:0]                       o_q_0;
reg   [`CLOG2(M):0]                 i_q_0_addr;
reg                                 i_q_0_rd = 0;
wire  [8-1:0]                       o_p_0;
reg   [`CLOG2(M):0]                 i_p_0_addr;
reg                                 i_p_0_rd = 0;

wire  [31:0]                        o_seed_h;
reg   [`CLOG2(LAMBDA/32):0]         i_seed_h_addr;
reg                                 i_seed_h_rd = 0;

wire  [PROC_SIZE-1:0]                   o_s;
reg   [`CLOG2(M):0]                 i_s_addr;
reg                                 i_s_rd = 0;

wire  [PROC_SIZE-1:0]                   o_y;
reg   [`CLOG2(M):0]                 i_y_addr;
reg                                 i_y_rd = 0;

wire  [32-1:0]                        o_seed_h;
reg   [`CLOG2(MAT_ROW_SIZE/PROC_SIZE)-1:0] i_seed_h_addr =0;
reg                                   i_seed_h_rd=0;

wire                                o_done;

wire [32-1:0]                       o_hash_data_in;
wire [`CLOG2(LAMBDA/32) -1:0]       i_hash_addr;
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

keygen #(.FIELD(FIELD), .PARAMETER_SET(PARAMETER_SET), .N_GF(N_GF))
DUT 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(i_start),
.i_seed_root(i_seed_root),
.i_seed_root_addr(i_seed_root_addr),
.i_seed_root_wr_en(i_seed_root_wr_en),
.o_q(o_q),
.i_q_addr(i_q_addr),
.i_q_rd(i_q_rd),
.o_p(o_p),
.i_p_addr(i_p_addr),
.i_p_rd(i_p_rd),
.o_s(o_s),
.i_s_addr(i_s_addr),
.i_s_rd (i_s_rd ),

`ifdef TWO_SHARES
.o_q_0                  (o_q_0                      ),
.i_q_0_addr             (i_q_0_addr                 ),
.i_q_0_rd               (i_q_0_rd                          ),
.o_p_0                  (o_p_0                      ),
.i_p_0_addr             (i_p_0_addr                 ),
.i_p_0_rd               (i_p_0_rd                         ),
`endif

.o_seed_h(o_seed_h),
.i_seed_h_addr(i_seed_h_addr),
.i_seed_h_rd (i_seed_h_rd),

.o_y(o_y),
.i_y_addr(i_y_addr),
.i_y_rd(i_y_rd ),

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


hash_mem_interface #(.IO_WIDTH(32), .MAX_RAM_DEPTH(LAMBDA/32), .PARAMETER_SET(PARAMETER_SET))
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
integer mult_start_time;
integer gen_h_start_time;
initial 
begin
    i_rst <= 1;
    i_start <= 0;

    #100

    i_rst <= 0;

    i_seed_root <= 0;
    i_seed_root <= 0;i_seed_root_wr_en <= 1;
    i_seed_root <= 0;i_seed_root_addr <= 0; #10  
    i_seed_root <= 0;i_seed_root_addr <= 1; #10  
    i_seed_root <= 0;i_seed_root_addr <= 2; #10  
    i_seed_root <= 0;i_seed_root_addr <= 3; #10
    if (PARAMETER_SET == "L3") begin
        i_seed_root <= 0;i_seed_root_addr <= 4; #10  
        i_seed_root <= 0;i_seed_root_addr <= 5; #10;
    end
   
    if (PARAMETER_SET == "L5") begin
        i_seed_root <= 0;i_seed_root_addr <= 4; #10  
        i_seed_root <= 0;i_seed_root_addr <= 5; #10  
        i_seed_root <= 0;i_seed_root_addr <= 6; #10  
        i_seed_root <= 0;i_seed_root_addr <= 7; #10; 
    end
    
    i_seed_root_wr_en <= 0;
    
    #10
    i_start <= 1;
    start_time = $time;
    #10
    i_start <= 0;

    #100

    @(posedge i_hash_force_done_ack)
    @(posedge i_hash_force_done_ack)
    $display("Time taken by SampleWitness module to release SHAKE=", ($time-start_time-5)/10 );
    
    gen_h_start_time <= $time;
    
    if (PARAMETER_SET == "L3" || PARAMETER_SET == "L5") begin
        @(posedge DUT.done_wit)
        $display("Time taken for SampleWitness =", ($time-start_time-5)/10 );
        
        
        @(posedge DUT.done_gen_h)
        $display("Time taken for Generate H =", ($time-gen_h_start_time)/10 );
        
    end
    
    if (PARAMETER_SET == "L1") begin
        @(posedge DUT.done_gen_h)
        $display("Time taken for Generate H =", ($time-gen_h_start_time)/10 );
        
        @(posedge DUT.done_wit)
        $display("Time taken for SampleWitness =", ($time-start_time-5)/10 );         
        
    end
    
    mult_start_time = $time;
    @(posedge DUT.done_mat_vec_mul)
    $display("Time taken for Poly Mult =", ($time-mult_start_time)/10 );
    
    @(posedge o_done)
    end_time = $time;

    $display("Time taken for KeyGen =", (end_time-start_time-5)/10 );
    
    
    #100
    $finish;

end

 always
 begin
     @(posedge o_done)
     $writememb("H_L1.mem", DUT.H_Matrix_Gen.RESULT_MEM.mem);
     $writememb("HSA_L1.mem", DUT.MAT_VEC_MUL.RESULT_MEM.mem);
//     $writememb("S_L3.mem", DUT.SAMP_WIT.COMP_S.S_MEM.mem);
//     $writememb("S_L3.mem", DUT.SAMP_WIT.S_combined_MEM.mem);
//     $writememb("H_L3.mem", DUT.H_Matrix_Gen.RESULT_MEM.mem);
 end

always #5 i_clk = ! i_clk;

 

endmodule