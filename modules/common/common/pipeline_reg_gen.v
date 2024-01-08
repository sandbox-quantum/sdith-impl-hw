/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/


module pipeline_reg_gen
  #(
    parameter REG_STAGES = 1,
    parameter WIDTH = 8
  )
  (
    input wire                     i_clk,
    input wire [WIDTH-1:0]         i_data_in,
    output wire  [WIDTH-1:0]       o_data_out
  );
  
 

reg [WIDTH-1:0] temp [REG_STAGES-1:0];

always@(posedge i_clk)
begin
  temp[0] <= i_data_in;
end

genvar i;
generate
    for(i=1;i<REG_STAGES;i=i+1) begin
        always@(posedge i_clk)
        begin
          temp[i] <= temp[i-1];
        end
    end
endgenerate

assign o_data_out = (REG_STAGES == 0)? i_data_in : temp[REG_STAGES-1];
//assign o_data_out = temp[REG_STAGES-1];
  
endmodule
  