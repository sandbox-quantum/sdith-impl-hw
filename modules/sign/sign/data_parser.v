/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/


module data_parser 
#(
    parameter IN_WIDTH              = 32,
    parameter OUT_WIDTH              = 8,
    parameter SOURCE_BRAM_DEPTH      =  4,
    parameter DESTINATION_BRAM_DEPTH =  15

)(
    input                                               i_clk,
    input                                               i_rst,
    input                                               i_start,
    output reg                                          o_done,

    input   [IN_WIDTH-1:0]                              i_wide_in,
    output  reg [`CLOG2(SOURCE_BRAM_DEPTH)-1:0]            o_wide_in_addr,
    output  reg                                           o_wide_in_rd,

    input   [OUT_WIDTH-1:0]                             o_narrow_out,
    output  reg  [`CLOG2(DESTINATION_BRAM_DEPTH)-1:0]   o_narrow_out_addr,
    output  reg                                           o_narrow_out_en

);

reg shift;
reg load;

reg [IN_WIDTH-1:0] in_reg;

assign o_narrow_out = in_reg[IN_WIDTH-1:IN_WIDTH-OUT_WIDTH];

always@(posedge i_clk)
begin
    if (load) begin
        in_reg <= i_wide_in;
    end
    else if (shift) begin
        in_reg <= {in_reg[IN_WIDTH-OUT_WIDTH-1:0], {OUT_WIDTH{1'b0}}};
    end
end


reg [3:0] state =0;
reg [`CLOG2(IN_WIDTH/OUT_WIDTH):0] count =0;
parameter s_wait_start              = 0;
parameter s_stall                   = 1;
parameter s_load                    = 2;
parameter s_shift                   = 3;
parameter s_done                    = 4;



always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        count <= 0;
        o_wide_in_addr <= 0;
        o_narrow_out_addr <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            if (i_start) begin
                state <= s_stall;
                count <= 0;
                o_wide_in_addr <= 0;
            end
        end 

        else if (state == s_stall) begin
            state <= s_shift;
            count <= count + 1;
        end

        else if (state == s_load) begin
            if (o_narrow_out_addr == DESTINATION_BRAM_DEPTH -1) begin
                state <= s_done;
                o_narrow_out_addr <= 0;
            end
            else begin
                state <= s_shift;
                count <= count + 1;
                o_narrow_out_addr <= o_narrow_out_addr + 1;
            end
        end 

        else if (state == s_shift) begin
            if (o_narrow_out_addr == DESTINATION_BRAM_DEPTH -1) begin
                state <= s_done;
                o_narrow_out_addr <= 0;
            end 
            else begin
                o_narrow_out_addr <= o_narrow_out_addr + 1;
                if (count == IN_WIDTH/OUT_WIDTH - 1) begin
                    count <= 0; 
                    state <= s_load;
                end
                else begin
                    count <= count + 1;
                end
                
                if (count == IN_WIDTH/OUT_WIDTH - 2) begin
                    o_wide_in_addr <= o_wide_in_addr + 1;
                end
            end
        end 

        else if (state == s_done) begin
            state <= s_wait_start;
        end

    end
end

always@(*)
begin
    case(state)

    s_wait_start:begin
        shift <= 0;
        load <= 0;
        o_done <= 0;
        o_narrow_out_en <= 0;
        if (i_start) begin
            o_wide_in_rd <= 1;
        end
        else begin
            o_wide_in_rd <= 0;
        end
    end
     
    s_stall:begin
        shift <= 0;
        load <= 1;
        o_wide_in_rd <= 1;
        o_narrow_out_en <= 0;
        o_done <= 0;
    end

    s_load:begin
        shift <= 0;
        load <= 1;
        o_wide_in_rd <= 1;
        o_narrow_out_en <= 1;  
        o_done <= 0;  
    end
    
    s_shift:begin
        shift <= 1;
        load <= 0;
        o_wide_in_rd <= 1;
        o_narrow_out_en <= 1;  
        o_done <= 0;
    end

    s_done: begin
        shift <= 0;
        load <= 0;
        o_wide_in_rd <= 0; 
        o_narrow_out_en <= 0;  
        o_done <= 1;   
    end

    default:begin
        shift <= 0;
        load <= 0;
        o_wide_in_rd <= 0;
        o_narrow_out_en <= 0;
        o_done <= 0;
    end

    endcase
end





endmodule