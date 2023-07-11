/*
 * This file is Testbench for Sampling Module.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


`timescale 1ns/1ps

module sampling_tb
 #(
    parameter PARAMETER_SET = "L1",

    parameter WEIGHT =  (PARAMETER_SET == "L1")? 79:
                        (PARAMETER_SET == "L2")? 120:
                        (PARAMETER_SET == "L3")? 150:
                                                 8,
    
    parameter M =   (PARAMETER_SET == "L1")? 230:
                        (PARAMETER_SET == "L2")? 352:
                        (PARAMETER_SET == "L3")? 480:
                                                 32,

    parameter D =   (PARAMETER_SET == "L1")? 1:
                    (PARAMETER_SET == "L2")? 2:
                    (PARAMETER_SET == "L3")? 2:
                                             1,

    parameter WIDTH = M/D,
        
    parameter LOG_WEIGHT   = `CLOG2(WEIGHT)
 );

// input  
reg i_clk = 0;
reg i_rst = 0;

reg i_start;
reg i_pos_valid;
reg [7:0] i_pos;
wire o_duplicate_detected;
wire o_pos_rd;
 
wire o_done;
  
  sampling #(.PARAMETER_SET(PARAMETER_SET))
  DUT (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_start(i_start),
    .i_pos_valid(i_pos_valid),
    .i_pos(i_pos),
    .o_duplicate_detected(o_duplicate_detected),
    .o_pos_rd(o_pos_rd),

    .o_non_zero_pos(),
    .i_non_zero_pos_rd(0),
    .i_non_zero_pos_addr(0),

    .o_done(o_done)
    
    );

  
  integer start_time;
  
  initial
    begin

      i_rst <= 1;
      i_start <= 0;
      i_pos_valid <= 0;
      #100

      i_rst<=0;
      #20

      i_start <= 1;
      #10
      i_start <= 0;
      #10
      i_pos_valid <= 1;
      i_pos <= 33;
      #10
      i_pos_valid <= 1;
      i_pos <= 21;
      #10
      i_pos_valid <= 1;
      i_pos <= 36;
      #10
      i_pos_valid <= 1;
      i_pos <= 24;
      #10
      i_pos_valid <= 1;
      i_pos <= 25;
      #10
      i_pos_valid <= 1;
      i_pos <= 26;
      #10
      i_pos_valid <= 1;
      i_pos <= 27;
      #10
      i_pos_valid <= 1;
      i_pos <= 20;
      #10
      i_pos_valid <= 1;
      i_pos <= 24;
      #10
      i_pos_valid <= 1;
      i_pos <= 25;
      #10
      i_pos_valid <= 1;
      i_pos <= 27;
      #10
      i_pos_valid <= 1;
      i_pos <= 2;
      #10
      i_pos_valid <= 1;
      i_pos <= 3;
      #10
      i_pos_valid <= 0;
    
//      @(posedge DUT.dout_valid_sh);
//      dout_ready_sh <= 1'b0;
//      $display("\nruntime for merge sort: %0d cycles\n", ($time-start_time)/10);
//      $fflush();
//      # 10000;
//      $finish;
    end
  
  // always 
  //   begin
  //     @(posedge DUT.done);
  //     $writememb("onetbmem.out", DUT.mem_dual_A.mem);
  //     $fflush();
  //   end
    

  //   mem_dual #(.WIDTH(15), .DEPTH(66), .FILE("locations.mem")) mem_dual_A (
  //   .clock(clk),
  //   .data_0(wr_data),
  //   .data_1(0),
  //   .address_0(rd_addr),
  //   .address_1(0),
  //   .wren_0(wr_en),
  //   .wren_1(0),
  //   .q_0(location),
  //   .q_1()
  // );    
  
always 
  # 5 i_clk = !i_clk;
  
  
endmodule

  
  
  