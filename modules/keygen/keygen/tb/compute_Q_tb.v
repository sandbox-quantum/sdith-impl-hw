/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module compute_Q_tb
#(

    parameter PARAMETER_SET = "L1",
    
    parameter FIELD = "GF256",
    
                                                    
    parameter WEIGHT =  (PARAMETER_SET == "L1")? 79:
                        (PARAMETER_SET == "L3")? 120:
                        (PARAMETER_SET == "L5")? 150:
                                                 32,
                                                            
    parameter D =   (PARAMETER_SET == "L1")? 1:
                    (PARAMETER_SET == "L3")? 2:
                    (PARAMETER_SET == "L5")? 2:
                                            1,
    parameter DEPTH_OF_Q = WEIGHT/D,
    
    parameter TV_type = 2  
    
    
)(

);



reg                           i_clk = 0;
reg                           i_rst;
reg                           i_start;
wire  [7:0]                   i_non_zero_pos;
wire  [`CLOG2(WEIGHT)-1:0]    o_non_zero_pos_addr;
wire                         o_non_zero_pos_rd;


wire  [7:0]                     o_q ;
reg   [`CLOG2(DEPTH_OF_Q)-1:0]  i_q_addr = 0;
reg                           i_q_rd = 0;

wire                         o_done;

compute_Q #(.PARAMETER_SET(PARAMETER_SET), .FIELD(FIELD) ,.WEIGHT(WEIGHT), .D(D))
COMP_Q 
(
.i_clk(i_clk),      
.i_rst(i_rst),
.i_start(i_start),
.i_non_zero_pos(i_non_zero_pos),
.o_non_zero_pos_addr(o_non_zero_pos_addr),
.o_non_zero_pos_rd(o_non_zero_pos_rd),

.o_q(o_q),
.i_q_addr(i_q_addr),

.i_q_rd(i_q_rd),
.o_done(o_done)
);

parameter VCD_NAME =    (TV_type == 0)?"compute_Q_tb_0.vcd" :
                        (TV_type == 1)?"compute_Q_tb_1.vcd" :
                                       "compute_Q_tb_2.vcd" ;

integer start_time, end_time;
initial 
begin
    i_rst <= 1;
    i_start <= 0;
    $dumpfile(VCD_NAME);
    $dumpvars(1, compute_Q_tb);
    
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

    $display("Time taken to Compute Q =", (end_time-start_time-5)/10 );
    
    #100
    i_q_rd <= 1;
    i_q_addr <= 1;
    #100
    $finish;

end

always #5 i_clk = ! i_clk;


 parameter NON_ZERO_VAL_NAME = (TV_type == 0)? "non_zero_val_L1_0.mem":
                               (TV_type == 1)? "non_zero_val_L1_1.mem":
                                               "non_zero_val_L1_2.mem";
                                               
mem_single #(.WIDTH(8), .DEPTH(DEPTH_OF_Q), .FILE(NON_ZERO_VAL_NAME)) 
 NON_ZERO_POSITIONS
 (
 .clock(i_clk),
 .data(0),
 .address(o_non_zero_pos_rd? o_non_zero_pos_addr: 0),
 .wr_en(0),
 .q(i_non_zero_pos)
 );

endmodule