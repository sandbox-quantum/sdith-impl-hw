/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/


module expand_view_challenge 
#(
    parameter PARAMETER_SET = "L1",
    
    parameter LAMBDA =   (PARAMETER_SET == "L1")? 128:
                            (PARAMETER_SET == "L3")? 192:
                            (PARAMETER_SET == "L5")? 256:
                                                     128,


                                                    
    parameter M  =  (PARAMETER_SET == "L1")? 230:
                    (PARAMETER_SET == "L3")? 352:
                    (PARAMETER_SET == "L5")? 480:
                                             8,

    parameter D_SPLIT = (PARAMETER_SET == "L1")? 1:
                        (PARAMETER_SET == "L3")? 2:
                        (PARAMETER_SET == "L5")? 2:
                                                 1,

    parameter  K =  (PARAMETER_SET == "L1")? 126:
                    (PARAMETER_SET == "L3")? 193:
                    (PARAMETER_SET == "L5")? 278:
                                               1,

    parameter TAU = (PARAMETER_SET == "L1")? 17:
                    (PARAMETER_SET == "L3")? 17:
                    (PARAMETER_SET == "L5")? 17:
                                             17,
    
    parameter T =   (PARAMETER_SET == "L5")? 4:
                                             3, 
    parameter SEED_SIZE = LAMBDA,
    
    parameter D_HYPERCUBE = 8,
    
    parameter NUMBER_OF_SEED_BITS = (2**(D_HYPERCUBE)+1) * LAMBDA,

    parameter SIZE_OF_R     = TAU*T*D_SPLIT*8,
    parameter SIZE_OF_EPS   = TAU*T*D_SPLIT*8,
    
    parameter FILE_H2 = ""
    

)(
    input                                               i_clk,
    input                                               i_rst,

    input                                               i_start,
    output reg                                          o_done,

    input   [32-1:0]                                    i_h2,
    input   [`CLOG2(2*SEED_SIZE/32)-1:0]                i_h2_addr,
    input                                               i_h2_wr_en,

    input                                               i_h2_rd_en,
    output  [32-1:0]                                    o_h2,

    output  [7:0]                                       o_i_star,
    input   [`CLOG2(TAU)-1:0]                           i_i_star_addr,
    input                                               i_i_star_rd_en,

    // hash interface
    output   [32-1:0]                                   o_hash_data_in,
    input    [`CLOG2((2*SEED_SIZE)/32) -1:0]            i_hash_addr,
    input                                               i_hash_rd_en,

    input    wire [32-1:0]                              i_hash_data_out,
    input    wire                                       i_hash_data_out_valid,
    output   reg                                        o_hash_data_out_ready,

    output   wire  [32-1:0]                             o_hash_input_length, // in bits
    output   wire  [32-1:0]                             o_hash_output_length, // in bits

    output   reg                                        o_hash_start,
    input    wire                                       i_hash_force_done_ack,
    output   reg                                        o_hash_force_done

);


assign o_hash_input_length = 2*SEED_SIZE;
assign o_hash_output_length = TAU*8 + (32-TAU*8%32)%32;



reg [`CLOG2(2*SEED_SIZE/32)-1:0] h1_addr;

wire [31:0] h2_out;

mem_single #(.WIDTH(32), .DEPTH(2*SEED_SIZE/32), .INIT(0), . FILE(FILE_H2)) 
 H2_MEM
 (
 .clock(i_clk),
 .data(i_h2),
 .address((i_h2_wr_en || i_h2_rd_en)? i_h2_addr: i_hash_addr),
 .wr_en(i_h2_wr_en),
 .q(h2_out)
 );
assign o_hash_data_in = h2_out;
assign o_h2 = h2_out;


reg [31:0] i_reg;
reg load; 
reg shift;

always@(posedge i_clk)
begin
    if (load) begin
        i_reg <= i_hash_data_out;
    end
    else if (shift) begin
        i_reg <= {i_reg[23:0],8'h00};
    end
end

reg i_star_wen;
reg [`CLOG2(TAU)-1:0] i_star_addr;


mem_single #(.WIDTH(8), .DEPTH(TAU), .INIT(1)) 
 I_STAR_MEM
 (
 .clock(i_clk),
 .data(i_reg[31:24]),
 .address((i_i_star_rd_en)? i_i_star_addr: i_star_addr),
 .wr_en(i_star_wen),
 .q(o_i_star)
 );




reg [2:0] state = 0;
reg [1:0] count = 0;
parameter s_wait_start               = 0;
parameter s_wait_hash_valid          = 1;
parameter s_load                     = 2;
parameter s_shift                    = 3;
parameter s_done                     = 4;



always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        count <= 0;
        o_done <= 0;
        o_hash_force_done <= 0;
        i_star_addr <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            count <= 0;
            o_done <= 0;
            o_hash_force_done <= 0;
            i_star_addr <= 0;
            if (i_start) begin
                state <= s_wait_hash_valid;
            end
        end 

        else if (state == s_wait_hash_valid) begin
            if (i_star_addr == TAU) begin
                state <= s_done;
            end
            else begin
                if (i_hash_data_out_valid) begin
                    state <= s_shift;
                end
            end
        end

        else if (state == s_load) begin
            if (i_star_addr == TAU) begin
                state <= s_done;
            end
            else begin
                if (i_hash_data_out_valid) begin
                    state <= s_shift;
                    i_star_addr <= i_star_addr+1;
                end
            end
        end

        else if (state ==  s_shift) begin
            if (i_star_addr == TAU) begin
                state <= s_done;
            end
            else begin
                    i_star_addr <= i_star_addr+1;
                    if (count == 2) begin
                        count <= 0;
                        state <= s_load;
                    end
                    else begin
                        count <= count + 1;
                    end
            end
        end

        else if (state == s_done) begin
            state <= s_wait_start;
            o_done <= 1;
            count <= 0;
            o_hash_force_done <= 1;
        end

    end
end

always@(*)
begin
    case(state)

    s_wait_start:begin
        o_hash_data_out_ready <= 0;
        i_star_wen <= 0;
        shift <= 0;
        load <= 0;
        if (i_start) begin
            o_hash_start <= 1;
        end
        else begin
            o_hash_start <= 0;
        end
    end


    s_wait_hash_valid: begin
        o_hash_start <= 0;
        i_star_wen <= 0;
        shift <= 0;
        o_hash_data_out_ready <= 0;
        if (i_hash_data_out_valid) begin
            load <= 1;
        end
        else begin
            load <= 0;
        end
    end

    s_load: begin
        shift <= 0;
        o_hash_start <= 0;
        o_hash_data_out_ready <= 0;
        if (i_star_addr < TAU) begin
            i_star_wen <= 1;
            load <= 1;
        end
        else begin
            load <= 0;
            i_star_wen <= 1;
        end
    end

    s_shift: begin
        o_hash_start <= 0;
        load <= 0;
        if (i_star_addr < TAU) begin
            shift <= 1;
            i_star_wen <= 1;
            if (count == 2) begin
                o_hash_data_out_ready <= 1;
            end
            else begin
                o_hash_data_out_ready <= 0;
            end 
        end
        else begin
            shift <= 0;
            i_star_wen <= 0;
            o_hash_data_out_ready <= 0;
        end
    end

    s_done: begin
        o_hash_data_out_ready <= 0;
        o_hash_start <= 0;
        load <= 0;
        shift <= 0;
        i_star_wen <= 0;
    end

    default:begin
        o_hash_data_out_ready <= 0;
        o_hash_start <= 0;
        load <= 0;
        shift <= 0;
        i_star_wen <= 0;
    end

    endcase
end





endmodule