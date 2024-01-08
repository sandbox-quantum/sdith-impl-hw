/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module data_parser_tb
#(

    parameter IN_WIDTH                  = 32,
    parameter OUT_WIDTH                 = 8,
    parameter SOURCE_BRAM_DEPTH         =  4,
    parameter DESTINATION_BRAM_DEPTH    =  16

    
)(

);

reg                                               i_clk = 0;
reg                                               i_rst;
reg                                               i_start;
wire                                            o_done;

wire   [IN_WIDTH-1:0]                              i_wide_in;
wire   [`CLOG2(SOURCE_BRAM_DEPTH)-1:0]            o_wide_in_addr;
wire                                              o_wide_in_rd;

wire   [OUT_WIDTH-1:0]                             o_narrow_out;
wire   [`CLOG2(DESTINATION_BRAM_DEPTH)-1:0]   o_narrow_out_addr;
wire                                              o_narrow_out_en;



data_parser #(
    .IN_WIDTH(IN_WIDTH),
    .OUT_WIDTH(OUT_WIDTH),
    .SOURCE_BRAM_DEPTH(SOURCE_BRAM_DEPTH),
    .DESTINATION_BRAM_DEPTH(DESTINATION_BRAM_DEPTH)
    )
DUT 
(
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(i_start),
.o_done(o_done),

.i_wide_in(i_wide_in),
.o_wide_in_addr(o_wide_in_addr),
.o_wide_in_rd(o_wide_in_rd),

.o_narrow_out(o_narrow_out),
.o_narrow_out_addr(o_narrow_out_addr),
.o_narrow_out_en(o_narrow_out_en)
);




integer start_time, end_time;

initial 
begin
    i_rst <= 1;
    i_start <= 0;

    #100

    i_rst <= 0;
    i_start <= 1;
    start_time = $time;

    #10

    i_start <= 0;
    
    @(posedge o_done)
    end_time = $time;

    $display("Time taken by DATA PARSER =", (end_time-start_time-5)/10 );
    
    
    #100
    $finish;

end



 mem_single #(.WIDTH(IN_WIDTH), .DEPTH(SOURCE_BRAM_DEPTH), .FILE("SOURCE_32.mem")) 
 WIDE_MEM
 (
 .clock(i_clk),
 .data(0),
 .address(o_wide_in_rd? o_wide_in_addr: 0),
 .wr_en(0),
 .q(i_wide_in)
 );

  mem_single #(.WIDTH(OUT_WIDTH), .DEPTH(DESTINATION_BRAM_DEPTH), .FILE()) 
 SOURCE_MEM
 (
 .clock(i_clk),
 .data(o_narrow_out),
 .address(o_narrow_out_en? o_narrow_out_addr: 0),
 .wr_en(o_narrow_out_en),
 .q()
 );


always #5 i_clk = ! i_clk;

 

endmodule