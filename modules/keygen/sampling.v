`timescale 1ns / 1ps
/*
 * This file is Sampling.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module sampling
    #(
    
    parameter PARAMETER_SET = "L1",

    parameter WEIGHT =  (PARAMETER_SET == "L1")? 79:
                        (PARAMETER_SET == "L3")? 120:
                        (PARAMETER_SET == "L5")? 150:
                                                 8,
    
    parameter M =   (PARAMETER_SET == "L1")? 230:
                        (PARAMETER_SET == "L3")? 352:
                        (PARAMETER_SET == "L5")? 480:
                                                 32,

    parameter D =   (PARAMETER_SET == "L1")? 1:
                    (PARAMETER_SET == "L3")? 2:
                    (PARAMETER_SET == "L5")? 2:
                                             1,

    parameter WIDTH = M/D,

    parameter WEIGHT_BY_D =  WEIGHT/D, 
    parameter LOG_WEIGHT   = `CLOG2(WEIGHT_BY_D)
    
    )
    (
    input i_clk,
    input i_rst,

    input i_start,
    input i_pos_valid,
    input [7:0] i_pos,
    
    output o_duplicate_detected,
    output reg o_pos_rd,

    output [7:0] o_non_zero_pos,
    input i_non_zero_pos_rd,
    input [`CLOG2(WEIGHT_BY_D)-1:0] i_non_zero_pos_addr,

    output [7:0] o_non_zero_pos_x,
    input i_non_zero_pos_rd_x,
    input [`CLOG2(WEIGHT_BY_D)-1:0] i_non_zero_pos_addr_x,

    output reg o_done

    );
    
wire [WIDTH-1:0] gen_one;

reg [7:0] pos_int;
reg pos_valid_reg;

//========Threshold Value (M) Check and Filter============
always@(posedge i_clk) begin
    if (i_pos_valid) begin
        if (i_pos < WIDTH) begin
            pos_int <= i_pos;
            pos_valid_reg <= 1;
        end
        
    end
    else begin
        // pos_int <=0;
        pos_valid_reg <= 0;
    end
end
//========================================================

// reg i_pos_valid_reg;
// always@(posedge i_clk) begin
//     i_pos_valid_reg <= i_pos_valid;
// end

//==================Duplicate Detection===================
genvar i;
generate
for (i = 0; i < WIDTH; i=i+1) begin:vector_gen
    assign gen_one[i] = (i == pos_int) ? 1'b1 : 1'b0; 
end
endgenerate

reg duplicate;
// wire duplicate;
// assign duplicate = (map == (map | gen_one));
// reg duplicate_reg;
reg [7:0] pos_reg;
reg valid_reg;
reg valid_reg_reg;
reg duplicate_reg;
reg duplicate_reg_reg;
always@(posedge i_clk) 
begin
    if (pos_valid_reg) begin
        duplicate <= (map == (map | gen_one));
    end
    else if (i_start) begin
        duplicate <= 0;
    end
    duplicate_reg <= duplicate;
    duplicate_reg_reg <= duplicate_reg;
end

always@(posedge i_clk) 
begin
    if (pos_valid_reg) begin
        pos_reg <= pos_int;
    end
    valid_reg <= pos_valid_reg;
    valid_reg_reg <= valid_reg;
end

reg [WIDTH-1:0] map;
  always@(posedge i_clk)
  begin
    if (i_start) begin
        map <= 0;
    end
    else if (pos_valid_reg) begin
        map <= map | gen_one; 
    end
  end

reg [`CLOG2(WEIGHT_BY_D):0] count;

always@(posedge i_clk) 
begin
    // if (i_start || count == WEIGHT) begin
    if (i_rst) begin
        count <= 0;
    end
    else if (i_start || o_done) begin
        count <= 0;
    end
    else if ((count < WEIGHT_BY_D) && (valid_reg) && (~duplicate)) begin
        count <= count + 1;
    end
end

// // always@(posedge i_clk) 
// always@(count, duplicate) 
// begin
//     // if (i_rst) begin
//     //     o_pos_rd <= 0;
//     // end
//     // else begin
//         if (count == WEIGHT-1 && duplicate == 0) begin
//             o_pos_rd <= 0;
//         end
//         else begin
//             o_pos_rd <= 1;
//         end  
//     // end
// end

// always@(posedge i_clk) 
// begin
//     if (i_rst) begin
//         o_pos_rd <= 0;
//     end
//     else begin
//         if (count == WEIGHT_BY_D-3 && duplicate == 0) begin
//             o_pos_rd <= 0;
//         end
//         else if (count == WEIGHT_BY_D-2 && duplicate == 1) begin
//             o_pos_rd <= 1;
//         end
//         else if (count == WEIGHT_BY_D-1 && duplicate == 0) begin
//             o_pos_rd <= 0;
//         end
//         else if (count == WEIGHT_BY_D-1 && duplicate == 1) begin
//             o_pos_rd <= 1;
//         end
//         else if (i_start) begin
//             o_pos_rd <= 1;
//         end  
//     end
// end

reg [2:0] state;
parameter s_wait_start          = 0;
parameter s_wait_count_w_min_3  = 1;
parameter s_check_for_duplicates  = 2;
parameter s_stall_0             = 3;
parameter s_stall_1             = 4;
parameter s_stall_2             = 5;
parameter s_stall_3             = 6;
// parameter s_wait_count_w_min_2  = 3;
// parameter s_wait_count_w_min_1  = 4;
// parameter s_wait_count_w_min_3;
// parameter s_wait_count_w_min_3;

// always@(posedge i_clk)
// begin
//     if (i_rst) begin
//         state <= s_wait_start;
//         o_pos_rd <= 0;
//     end
//     else begin
//         if (state == s_wait_start) begin
//             if (i_start) begin
//                 o_pos_rd <= 1;
//                 state <= s_wait_count_w_min_3;
//                 // rd_count <= 0;
//             end
//             else begin
//                 o_pos_rd <= 0;
//             end
//         end

//         else if (state == s_wait_count_w_min_3) begin
//             if (count == WEIGHT_BY_D-3 && duplicate == 0) begin
//                 o_pos_rd <= 0;
//                 state <= s_check_for_duplicates;
//             end
//         end

//         else if (state == s_check_for_duplicates) begin
//             if (o_done) begin
//                 state <= s_wait_start;
//                 o_pos_rd <= 0;
//             end
//             else if (i_pos_valid && i_pos > WIDTH-1) begin
//                 o_pos_rd <= 1;
//                 state <= s_stall_2;
//             end
//             //commented for testing
//             else if ((duplicate && valid_reg) && (count < WEIGHT_BY_D)) begin  // Need to fix this for L5 "L3 Works"
//             // else if ((duplicate && valid_reg) || (count < WEIGHT_BY_D)) begin  // Need to fix this for L5 "L5 Works"
//             // else if (duplicate == 1) begin
//                     o_pos_rd <= 1;
//                     state <= s_stall_0;
//             end
//         end
//         else if (state == s_stall_0) begin
//             if (o_done) begin
//                     state <= s_wait_start;
//                     o_pos_rd <= 0;
//             end
//             else if (i_pos_valid && i_pos > WIDTH-1) begin
//                 o_pos_rd <= 1;
//                 state <= s_stall_2;
//             end
//             else begin
//                 state <= s_stall_1;
//                 o_pos_rd <= 0;
//             end
//         end

//         else if (state == s_stall_1) begin
//             if (o_done) begin
//                     o_pos_rd <= 0;
//                     state <= s_wait_start;
//             end
//             else if (i_pos_valid && i_pos > WIDTH-1) begin
//                 o_pos_rd <= 1;
//                 state <= s_stall_2;
//             end
//             else begin
//                 state <= s_stall_3;
//                 o_pos_rd <= 0;
//             end
//         end

//         else if (state == s_stall_3) begin
//             if (o_done) begin
//                     o_pos_rd <= 0;
//                     state <= s_wait_start;
//             end
//             else if (i_pos_valid && i_pos > WIDTH-1) begin
//                 o_pos_rd <= 1;
//                 state <= s_stall_2;
//             end
//             else begin
//                 state <= s_check_for_duplicates;
//                 o_pos_rd <= 0;
//             end
//         end

//         else if (state == s_stall_2) begin
//             o_pos_rd <= 0;
//             if (o_done) begin
//                     state <= s_wait_start;   
//             end
//             else begin
//                 state <= s_check_for_duplicates;
//             end
//         end
//     end
// end

always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        o_pos_rd <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            if (i_start) begin
                o_pos_rd <= 1;
                state <= s_wait_count_w_min_3;
                // rd_count <= 0;
            end
            else begin
                o_pos_rd <= 0;
            end
        end

        else if (state == s_wait_count_w_min_3) begin
            if (count == WEIGHT_BY_D-3 && duplicate == 0) begin
                o_pos_rd <= 0;
                state <= s_stall_0;
            end
        end

        else if (state == s_check_for_duplicates) begin
            if (o_done) begin
                state <= s_wait_start;
                o_pos_rd <= 0;
            end
            else if (count < WEIGHT_BY_D) begin
                    o_pos_rd <= 1;
                    state <= s_stall_0;
            end
        end
        else if (state == s_stall_0) begin
            if (o_done) begin
                    state <= s_wait_start;
                    o_pos_rd <= 0;
            end
            else begin
                state <= s_stall_1;
                o_pos_rd <= 0;
            end
        end

        else if (state == s_stall_1) begin
            if (o_done) begin
                    o_pos_rd <= 0;
                    state <= s_wait_start;
            end
            else begin
                state <= s_stall_2;
                o_pos_rd <= 0;
            end
        end

        else if (state == s_stall_2) begin
            o_pos_rd <= 0;
            if (o_done) begin
                    state <= s_wait_start;   
            end
            else begin
                state <= s_stall_3;
            end
        end

        else if (state == s_stall_3) begin
            if (o_done) begin
                    o_pos_rd <= 0;
                    state <= s_wait_start;
            end
            else begin
                state <= s_check_for_duplicates;
                o_pos_rd <= 0;
            end
        end

        
    end
end

always@(posedge i_clk) 
begin
    if (i_rst) begin
        o_done <= 0;
    end
    else begin
    // else if (count == WEIGHT_BY_D) begin
        if (count == WEIGHT_BY_D) begin
            o_done <= 1;
        end
        else if (i_start) begin
            o_done <= 0;
        end
    end
end

wire wr_en;

// assign wr_en = (valid_reg_reg | valid_reg) & ~duplicate;
assign wr_en = (valid_reg) & ~duplicate;

reg [`CLOG2(WEIGHT_BY_D):0] wr_count;
reg [`CLOG2(WEIGHT_BY_D):0] rd_count;
always@(posedge i_clk)
begin
    if (i_start) begin
        wr_count <= 0;
    end
    else if (wr_en) begin
        wr_count <= wr_count+1;
    end
end

// mem_single #(.WIDTH(8), .DEPTH(WEIGHT))  
//     POS_REG(
//     .clock(i_clk),
//     .data(pos_reg),
//     .address(i_non_zero_pos_rd? i_non_zero_pos_addr: count[`CLOG2(WEIGHT)-1:0]),
//     .wr_en(wr_en),
//     .q(o_non_zero_pos)
//     );

mem_dual #(.WIDTH(8), .DEPTH(WEIGHT_BY_D))  
    POS_REG(
    .clock(i_clk),
    .data_0(pos_reg),
    .data_1(0),
    .address_0(i_non_zero_pos_rd? i_non_zero_pos_addr: count[`CLOG2(WEIGHT_BY_D)-1:0]),
    .address_1(i_non_zero_pos_rd_x? i_non_zero_pos_addr_x: 0),
    .wren_0(wr_en),
    .wren_1(0),
    .q_0(o_non_zero_pos),
    .q_1(o_non_zero_pos_x)
    );

    
endmodule
