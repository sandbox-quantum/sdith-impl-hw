/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/


`timescale 1ns/1ps
`include "clog2.v"

module hash_mem_interface_tb  #(
    parameter IO_WIDTH = 32, 
    parameter DATA_IN_WIDTH = 2760, //34*32,                                      
    parameter DATA_OUT_WIDTH = 128,                                      
    parameter MAX_RAM_DEPTH = 1+DATA_IN_WIDTH/32                                       
                                      
  );

//input
reg                                       clk = 0;
reg                                       rst;
wire [IO_WIDTH-1:0]                       i_data_in;
reg                                       i_data_out_ready = 1;
reg  [IO_WIDTH-1:0]                       i_output_length;
reg  [IO_WIDTH-1:0]                       i_input_length;
reg                                       i_start;
//outputs
wire                                      o_rd_en;
wire [`CLOG2(MAX_RAM_DEPTH) -1:0]         o_addr;
wire [IO_WIDTH-1:0]                       o_data_out;
wire                                      o_data_out_valid;
wire                                      o_done;
 
 always 
  # 5 clk = !clk;


  hash_mem_interface #(.IO_WIDTH(IO_WIDTH), .MAX_RAM_DEPTH(MAX_RAM_DEPTH))
  DUT
   (
    .clk(clk),
    .rst(rst),
        
    .i_data_in(i_data_in),
    .i_data_out_ready(i_data_out_ready),
    .i_input_length(i_input_length),
    .i_output_length(i_output_length),
    .i_start(i_start),
    
    .o_rd_en(o_rd_en),
    .o_addr(o_addr),
    .o_data_out(o_data_out),
    .o_data_out_valid(o_data_out_valid),
    .o_done(o_done)
    
    );

  
  integer start_time, end_time;
  
  initial
    begin
    rst <= 1'b1;
    i_start = 1'b0;
    # 20;
    rst <= 1'b0;
    #100
    start_time = $time;
    
    i_start = 1'b1;
    i_output_length <=  DATA_OUT_WIDTH;
    i_input_length <= 2760;
    #10
    
    i_start = 1'b0;

    
    
    @(posedge o_data_out_valid);
    end_time = $time -5;
    $display("Total Clock Cycles:", (end_time - start_time)/10);
      # 1000;
      $finish;
    end
  
 

 
  mem_single #(.WIDTH(IO_WIDTH), .DEPTH(MAX_RAM_DEPTH), .FILE("HASH_MEM_INTERFACE_TB.MEM") ) rand_mem_2
 (
        .clock(clk),
        .data(0),
        .address(o_rd_en? o_addr : 0),
        .wr_en(0),
        .q(i_data_in)
 );  
  

  
  
endmodule

  
  
  