/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/


`timescale 1ns/1ps

module duplicate_detection_ct_tb;
//  #(
//    parameter INT_WIDTH = 16,
//    parameter INDEX_WIDTH = 8,
//    parameter LIST_LEN = 256,// total number of elements to be sorted
//    parameter k = `CLOG2(LIST_LEN)
//  );

// input  
reg clk = 1'b0;
reg rst = 1'b0;
wire [14:0] location;
reg start = 1'b0;
reg done_reg = 1'b0;

// output
wire done;
wire [31:0] vector;
wire [6:0] rd_addr;
reg [6:0] wr_addr;
reg wr_en;
wire rd_en;
wire ready;
wire valid;

reg [15-1:0] wr_data;

wire [32-1:0] error_0;
wire rd_e_0; 
wire [10 -1:0]rd_addr_e_0;
wire collision;
wire [32-1:0] error_1;
wire rd_e_1; 
wire [10 -1:0]rd_addr_e_1;

reg init_mem;
//    input clk,
//    input rst,
//    input init_mem,
//    input [(m-1):0] location,
    
//    output reg [LOGTAU-1:0] rd_addr,
//    output reg rd_en,
//    input start,
//    output collision,
//    output ready,
//    output valid,
//    output done,
    
//    output [E0_WIDTH-1:0] error_0,
//    input rd_e_0, 
//    input [LOGE0W -1:0]rd_addr_e_0,
    
//    output [WIDTH-1:0] error_1,
//    input rd_e_1, 
//    input [LOGW -1:0]rd_addr_e_1
  
  duplicate_detection_ct DUT (
    .clk(clk),
    .rst(rst),
    .init_mem(init_mem),
    .location(location),
    .start(start),
    .rd_addr(rd_addr),
    .rd_en(rd_en),
    .ready(ready),
    .valid(valid),
    .collision(collision),
    .done(done)
    
    // .error_0(error_0),
    // .rd_e_0(0), 
    // .rd_addr_e_0(0),
    
    // .error_1(error_1),
    // .rd_e_1(0), 
    // .rd_addr_e_1(0)
    
    );

  
  integer start_time;
  
  initial
    begin
    wr_addr <= 0;
    wr_en <= 0;
    rst <= 1'b1;
    init_mem <= 0;
    # 20;
    rst <= 1'b0;
    #100
    start_time = $time;
    
    init_mem <= 1;
    #10
    init_mem <= 0;
    
    #6000
    
    if(ready);
    #10
    start = 1'b1;
    #10
    
    start = 1'b0;
//    location = 16;

    @(posedge collision)
    #10
    wr_addr <= rd_addr;
    #10
    wr_en <= 1'b1; wr_data <= 0; #10
    wr_en <= 1'b0;
    
    #20
    start = 1'b1;
    #10
    
    start = 1'b0;
    
    @(posedge collision)
    #10
    wr_addr <= rd_addr;
    #10
//    wr_en <= 1'b1; wr_data <= 2613; #10
    wr_en <= 1'b1; wr_data <= 11350; #10
    wr_en <= 1'b0;
    
    #20
    start = 1'b1;
    #10
    
    start = 1'b0;
    
    @(posedge collision)
    #10
    wr_addr <= rd_addr;
    #10
    wr_en <= 1'b1; wr_data <= 2613; #10
    wr_en <= 1'b0;
    
    #20
    start = 1'b1;
    #10
    
    start = 1'b0;
    
    
//      @(posedge DUT.dout_valid_sh);
//      dout_ready_sh <= 1'b0;
//      $display("\nruntime for merge sort: %0d cycles\n", ($time-start_time)/10);
//      $fflush();
//      # 10000;
//      $finish;
    end
  
  always 
    begin
      @(posedge DUT.done);
      $writememb("onetbmem.out", DUT.mem_dual_A.mem);
      $fflush();
    end
    

    mem_dual #(.WIDTH(15), .DEPTH(66), .FILE("locations.mem")) mem_dual_A (
    .clock(clk),
    .data_0(wr_data),
    .data_1(0),
    .address_0(rd_addr),
    .address_1(0),
    .wren_0(wr_en),
    .wren_1(0),
    .q_0(location),
    .q_1()
  );    
  
always 
  # 5 clk = !clk;
  
  
endmodule

  
  
  