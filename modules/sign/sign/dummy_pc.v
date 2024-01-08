/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module dummy_pc 
#(
    parameter FIELD = "GF256",
    parameter PARAMETER_SET = "L1",    
    parameter T =   (PARAMETER_SET == "L5")? 4:
                                             3, 
                                             
    parameter CLOCK_CYCLE_COUNT =   (FIELD == "GF256" && PARAMETER_SET == "L1")? 49463:
                                    (FIELD == "GF256" && PARAMETER_SET == "L3")? 37163:
                                    (FIELD == "GF256" && PARAMETER_SET == "L5")? 64240:
                                    (FIELD == "P251" && PARAMETER_SET == "L1")? 157662:
                                    (FIELD == "P251" && PARAMETER_SET == "L3")? 118230:
                                    (FIELD == "P251" && PARAMETER_SET == "L5")? 166427:
                                                                                 49463
    

)(
    input                                               i_clk,
    input                                               i_rst,

    input                                               i_start,

    output reg                                             o_done,

    output wire [32*T-1:0]                              o_alpha,
    output wire [32*T-1:0]                              o_beta,
    output wire [32*T-1:0]                              o_v

);

assign o_alpha = {$random,$random,$random};
assign o_beta = {$random,$random,$random};
assign o_v = {$random,$random,$random};

reg [2:0] state = 0;
parameter s_wait_start = 0;
parameter s_stall = 1;

reg [15:0] count =0;


always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        count <= 0;
        o_done <=0;
    end
    else begin
        if (state == s_wait_start) begin
            count <= 0;
            o_done <=0;
            if (i_start) begin
                state <= s_stall;
            end
        end
        else if (state == s_stall) begin
            if (count == CLOCK_CYCLE_COUNT - 1) begin
                state <= s_wait_start;
                o_done <= 1;
                count <= 0;
            end
            else begin
                count <= count + 1;
            end
        end
    end

end


endmodule