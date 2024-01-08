/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module commit 
#(
   parameter FIELD = "GF256",
    // parameter FIELD = "P251",

    parameter PARAMETER_SET = "L1",
    
    parameter LAMBDA =   (PARAMETER_SET == "L1")? 128:
                            (PARAMETER_SET == "L3")? 192:
                            (PARAMETER_SET == "L5")? 256:
                                                     128,
                                                    
    parameter M =  (PARAMETER_SET == "L1")? 230:
                        (PARAMETER_SET == "L3")? 352:
                        (PARAMETER_SET == "L5")? 480:
                                                 230,

    parameter WEIGHT =  (PARAMETER_SET == "L1")? 79:
                        (PARAMETER_SET == "L3")? 120:
                        (PARAMETER_SET == "L5")? 150:
                                                 79,

    parameter D_SPLIT = (PARAMETER_SET == "L1")? 1:
                        (PARAMETER_SET == "L3")? 2:
                        (PARAMETER_SET == "L5")? 2:
                                                 1,
    //  k + 2w + t(2d + 1)η

    parameter  K =  (PARAMETER_SET == "L1")? 126:
                    (PARAMETER_SET == "L3")? 193:
                    (PARAMETER_SET == "L5")? 278:
                                               1,
    
    parameter ETA = 4,

    parameter T =   (PARAMETER_SET == "L5")? 4:
                                             3, 

    parameter SEED_SIZE = LAMBDA,
    parameter SALT_SIZE = 2*LAMBDA,

    parameter HASH_INPUT_SIZE = LAMBDA + 2*LAMBDA,
    parameter HASH_OUTPUT_SIZE = 8*(K + 2*WEIGHT + T*(2*D_SPLIT + 1)*ETA),

    parameter HO_SIZE_ADJ = HASH_OUTPUT_SIZE + (WIDTH - HASH_OUTPUT_SIZE%WIDTH)%WIDTH,
    parameter WIDTH = 64
    

)(
    input                                   i_clk,
    input                                   i_rst,
    input                                   i_start,

    input   [32-1:0]                        i_seed_root,
    input   [`CLOG2(HASH_INPUT_SIZE/32)-1:0]         i_seed_root_addr,
    input                                   i_seed_root_wr_en,

    output reg                              o_done,

    // hash interface
    output   [32-1:0]                       o_hash_data_in,
    input    [`CLOG2(HASH_INPUT_SIZE/32) -1:0]       i_hash_addr,
    input                                   i_hash_rd_en,

    input    wire [32-1:0]                  i_hash_data_out,
    input    wire                           i_hash_data_out_valid,
    output   reg                            o_hash_data_out_ready,

    output   wire  [32-1:0]                 o_hash_input_length, // in bits
    output   wire  [32-1:0]                 o_hash_output_length, // in bits

    output   reg                           o_hash_start,
    input    wire                           i_hash_force_done_ack,
    output   wire                           o_hash_force_done

);


assign o_hash_input_length = HASH_INPUT_SIZE;
assign o_hash_output_length = 2*HASH_OUTPUT_SIZE;


mem_single #(.WIDTH(32), .DEPTH(HASH_INPUT_SIZE/32)) 
 SEED_ROOT
 (
 .clock(i_clk),
 .data(i_seed_root),
 .address(i_seed_root_wr_en? i_seed_root_addr: i_hash_rd_en? i_hash_addr: 0),
 .wr_en(i_seed_root_wr_en),
 .q(o_hash_data_in)
 );

reg load =0;
reg shift =0;
reg [31:0] hash_out_sreg;
reg [WIDTH-1:0] input_share;
wire [7:0] input_share_byte;
wire threshold;
reg in_share_valid;

assign input_share_byte = hash_out_sreg[31:24];

assign threshold = (input_share_byte < 251)? 1 : 0;

generate
    if (FIELD == "P251") begin
        always@(posedge i_clk) begin
            if (load) begin
                hash_out_sreg <= i_hash_data_out;
            end
            else if (shift) begin
                hash_out_sreg <= {hash_out_sreg[23:0],{(8){1'b0}}};
            end
        end
        always@(posedge i_clk)
        begin
            if (in_share_valid) begin
                input_share <= {input_share[WIDTH-8-1:0],input_share_byte};
            end
        end
    end
    else begin
        always@(posedge i_clk)
        begin
            if (i_hash_data_out_valid) begin
                input_share <= {input_share[WIDTH-32-1:0],i_hash_data_out};
            end
        end
    end
endgenerate

wire [WIDTH-1:0] input_share_bram;
wire [WIDTH-1:0] input_share_last;


generate 
    if (HASH_OUTPUT_SIZE%WIDTH !=0) begin
        assign input_share_last = {input_share[WIDTH-1:WIDTH-HASH_OUTPUT_SIZE%WIDTH],{(WIDTH-HASH_OUTPUT_SIZE%WIDTH){1'b0}}};
    end
endgenerate

assign input_share_bram = ((HASH_OUTPUT_SIZE%WIDTH !=0) && (in_share_addr == HO_SIZE_ADJ/WIDTH - 1))?   input_share_last : 
                                                                                                        input_share;

mem_dual #(.WIDTH(WIDTH), .DEPTH(HO_SIZE_ADJ/WIDTH)) 
 SEED_SHARE
 (
 .clock(i_clk),
 .data_0(input_share_bram),
 .data_1(0),
 .address_0(in_share_addr),
 .address_1(0),
 .wren_0(in_share_wr_en),
 .wren_1(0),
 .q_0(),
 .q_1()
 );

reg [`CLOG2(HO_SIZE_ADJ/WIDTH)-1:0] in_share_addr = 0;
reg in_share_wr_en;

 reg [3:0] state = 0;

// generate 
//     if (FIELD == "P251") begin
//         reg [`CLOG2(WIDTH/8):0] count;
//     end
//     else begin
//        reg [`CLOG2(WIDTH/32):0] count; 
//     end
// endgenerate
parameter COUNT_WIDTH = (FIELD == "P251")? WIDTH/8:WIDTH/32;
// reg [`CLOG2(WIDTH/8):0] count;
reg [`CLOG2(COUNT_WIDTH):0] count;

reg [1:0] count_hash = 0;

parameter s_wait_start              = 0;
parameter s_wait_hash_valid         = 1;
parameter s_sample_gf256            = 2;
parameter s_sample_gf256_store      = 3;

parameter s_sample_p251_load        = 4;
parameter s_sample_p251_store       = 5;
parameter s_done                    = 6;

reg first_block = 0;



always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        count <= 0;
        in_share_addr <= 0;
        count_hash <= 0;
        first_block <= 1;
    end
    else begin
      if (state == s_wait_start) begin
            count <= 0;
            in_share_addr <= 0;
            count_hash <= 0;
            first_block <= 1;
            if (i_start) begin
                o_done <= 0;
                state <= s_wait_hash_valid;
            end
      end 

      else if (state == s_wait_hash_valid) begin  
            o_done <= 0;
            in_share_addr <= 0;
            first_block <= 1;
            if (FIELD == "P251") begin
                if (i_hash_data_out_valid) begin
                    state <= s_sample_p251_store;
                    // count <= count + 1;
                    count_hash <= count_hash+1;
                end
            end
            else begin
                if (i_hash_data_out_valid) begin
                    state <= s_sample_gf256;
                    count <= count + 1;
                end
            end
      end

      else if (state == s_sample_gf256) begin  
            o_done <= 0;
            if (in_share_addr == HO_SIZE_ADJ/WIDTH) begin
                state <= s_done;
            end
            else begin
                if (i_hash_data_out_valid) begin
                    if (count == WIDTH/32 - 1) begin
                        count <= 0;
                        state <= s_sample_gf256_store;
                    end
                    else begin
                        count <= count + 1;
                    end
                end
            end
      end

      else if (state == s_sample_gf256_store) begin
            if (in_share_addr == HO_SIZE_ADJ/WIDTH) begin
                state <= s_done;
            end
            else begin
                if (i_hash_data_out_valid) begin
                    count <= count + 1;
                end
                state <= s_sample_gf256;
                if (count == 0) begin
                    in_share_addr <= in_share_addr + 1;
                end
            end
      end

      else if (state == s_sample_p251_load) begin  
            o_done <= 0;
            first_block <= 0;
            if (in_share_addr == HO_SIZE_ADJ/WIDTH) begin
                state <= s_done;
            end
            else begin
                if (i_hash_data_out_valid) begin
                    count_hash <= count_hash+1;
                    state <= s_sample_p251_store;

                    if ((count == WIDTH/8 - 1) && (threshold)) begin
                        count <= 0;
                    end
                    else begin
                        if (threshold) begin
                            count <= count + 1;
                        end
                    end

                    if ((count == 0) &&  (~first_block) && threshold) begin
                        in_share_addr <= in_share_addr + 1;
                    end
                end
            end
      end

      else if (state == s_sample_p251_store) begin  
            o_done <= 0;
            first_block <= 0;
            if (in_share_addr == HO_SIZE_ADJ/WIDTH) begin
                state <= s_done;
            end
            else begin
                if (count_hash == 3) begin
                    count_hash <= 0;
                    state <= s_sample_p251_load;
                end
                else begin
                    count_hash <= count_hash + 1;
                end
                if ((count == WIDTH/8 - 1) && threshold) begin
                    count <= 0;
                end
                else begin
                    if (threshold) begin
                        count <= count + 1;
                    end
                end
                if ((count == 0) &&  (~first_block) && threshold) begin
                        in_share_addr <= in_share_addr + 1;
                end
            end
      end

      else if (state == s_done) begin
            o_done <= 1;
      end

    end
end

always@(state, i_start, i_hash_data_out_valid, count, first_block, threshold)
begin
    case(state)

    s_wait_start:begin
        o_hash_data_out_ready <= 0;
        in_share_wr_en <= 0;
        load <= 0;
        shift <= 0;
        in_share_valid <= 0;
        if (i_start) begin
            o_hash_start <= 1;
        end
        else begin
            o_hash_start <= 0;
        end
    end

    s_wait_hash_valid:begin
        o_hash_start <= 0;
        in_share_wr_en <= 0;
        shift <= 0;
        in_share_valid <= 0;
        if (i_hash_data_out_valid) begin
            o_hash_data_out_ready <= 1;
            load <= 1;
        end
        else begin
            load <= 0;
            o_hash_data_out_ready <= 0;
        end
    end

    s_sample_gf256:begin
        o_hash_start <= 0;
        o_hash_data_out_ready <= 1;
        load <= 0;
        shift <= 0;
        in_share_valid <= 0;
        if (i_hash_data_out_valid) begin
            if (count == 0) begin
                in_share_wr_en <= 1;
            end
            else begin
                in_share_wr_en <= 0;
            end
        end
        else begin
            in_share_wr_en <= 0;
        end
    end

    s_sample_gf256_store: begin
        o_hash_start <= 0;
        o_hash_data_out_ready <= 1;
        load <= 0;
        shift <= 0;
        in_share_valid <= 0;
        if (count == 0) begin
            in_share_wr_en <= 1;
        end
        else begin
            in_share_wr_en <= 0;
        end
    end

    s_sample_p251_load:begin
        o_hash_start <= 0;
        o_hash_data_out_ready <= 1;

        if (i_hash_data_out_valid) begin
            load <= 1;
            shift <= 0;
            if (threshold) begin
                in_share_valid <= 1;
            end
            else begin
                in_share_valid <= 0;
            end
            if (count == 0 && threshold) begin
                in_share_wr_en <= 1;
            end
            else begin
                in_share_wr_en <= 0;
            end
        end
        else begin
            in_share_wr_en <= 0;
            load <= 0;
            shift <= 0;
            in_share_valid <= 0;
        end
    end

    s_sample_p251_store:begin
        o_hash_start <= 0;
        o_hash_data_out_ready <= 0;
        load <= 0;
        shift <= 1;
        if (threshold) begin
            in_share_valid <= 1;
        end
        else begin
            in_share_valid <= 0;
        end
        if ((count == 0) && (~first_block)&& threshold) begin
            in_share_wr_en <= 1;
        end
        else begin
            in_share_wr_en <= 0;
        end
    end

    s_done:begin
        o_hash_start <= 0;
        o_hash_data_out_ready <= 0;
        in_share_wr_en <= 0;
        load <= 0;
        shift <= 0;
        in_share_valid <= 0;
    end

    default:begin
        o_hash_start <= 0;
        o_hash_data_out_ready <= 0;
        in_share_wr_en <= 0;
        load <= 0;
        shift <= 0;
        in_share_valid <= 0;
    end

    endcase
end

endmodule