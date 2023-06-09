/*
 * This file is the testbench for the XOR based Adder.
 *
 * Copyright (C) 2022
 * Authors: Sanjay Deshpande <sanjay.deshpande@yale.edu>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
*/

`timescale 1ns/1ps
`include "clog2.v"

module hash_mem_interface_tb  #(
    parameter IO_WIDTH = 32, 
    parameter DATA_IN_WIDTH = 128, //34*32,                                      
    parameter DATA_OUT_WIDTH = 128,                                      
    parameter MAX_RAM_DEPTH = DATA_IN_WIDTH/32                                       
                                      
  );

//input
reg                                       clk = 0;
reg                                       rst;
wire [IO_WIDTH-1:0]                       i_data_in;
reg                                       o_data_out_ready = 1;
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
    .o_data_out_ready(o_data_out_ready),
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
    i_input_length <= DATA_IN_WIDTH;
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

  
  
  