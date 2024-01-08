/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module expand_mpc_challenge 
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
    parameter SIZE_OF_EPS   = TAU*T*D_SPLIT*8
    

)(
    input                                               i_clk,
    input                                               i_rst,

    input                                               i_start,
    output reg                                          o_done,

    input   [32-1:0]                                    i_h1,
    output   reg [`CLOG2(2*SEED_SIZE/32)-1:0]           o_h1_addr,
    output   reg                                        o_h1_rd,

    output   [T*32-1:0]                                  o_r,
    input   [`CLOG2(TAU*D_SPLIT)-1:0]                   i_r_addr,
    input                                               i_r_rd,

    output   [T*32-1:0]                                  o_eps,
    input   [`CLOG2(TAU*D_SPLIT)-1:0]                   i_eps_addr,
    input                                               i_eps_rd,

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
assign o_hash_output_length = 4*TAU*D_SPLIT*T*32;

// reg [31:0] i_hash_data_out_reg;

// always@(posedge i_clk)
// begin
//     if (i_hash_data_out_valid) begin
//         i_hash_data_out_reg <= i_hash_data_out;
//     end
// end


reg [`CLOG2(2*SEED_SIZE/32)-1:0] h1_addr;
reg h1_wr_en;
always@(posedge i_clk)
begin
    h1_addr <= o_h1_addr;
    h1_wr_en <= o_h1_rd;
end

mem_single #(.WIDTH(32), .DEPTH(2*SEED_SIZE/32), .INIT(1)) 
 H1_MEM
 (
 .clock(i_clk),
 .data(i_h1),
 .address(i_hash_rd_en? i_hash_addr: h1_addr),
 .wr_en(h1_wr_en),
 .q(o_hash_data_in)
 );


reg [T*32-1:0] r_esp_in;

// generate 
//     if (PARAMETER_SET != "L5") begin
//         assign r_esp_in =   (count == 0) ?  i_hash_data_out[31:8] :
//                             (count == 1) ?   {i_hash_data_out_reg[7:0], i_hash_data_out[31:16]} :
//                             (count == 2) ?   {i_hash_data_out_reg[15:0], i_hash_data_out[31:24]} :
//                                             i_hash_data_out_reg[23:0];
//     end
//     else begin
//         assign r_in = i_hash_data_out;
//     end
// endgenerate

always@(posedge i_clk)
begin
    if (i_hash_data_out_valid) begin
        r_esp_in <= {r_esp_in[T*32-32-1:0], i_hash_data_out};
    end
end

reg r_wen;
reg [`CLOG2(TAU*D_SPLIT)-1:0] r_addr;

 mem_single #(.WIDTH(T*32), .DEPTH(TAU*D_SPLIT)) 
 r_MEM
 (
 .clock(i_clk),
 .data(r_esp_in),
 .address(i_r_rd? i_r_addr:r_addr),
 .wr_en(r_wen),
 .q(o_r)
 );

reg esp_wen;
reg [`CLOG2(TAU*D_SPLIT)-1:0] eps_addr;

 mem_single #(.WIDTH(T*32), .DEPTH(TAU*D_SPLIT)) 
 esp_MEM
 (
 .clock(i_clk),
 .data(r_esp_in),
 .address(i_eps_rd? i_eps_addr: r_addr),
 .wr_en(esp_wen),
 .q(o_eps)
 );

 reg [2:0] state = 0;

reg [1:0] count = 0;

parameter s_wait_start               = 0;
parameter s_load_h1                  = 1;
parameter s_start_hash               = 2;
parameter s_wait_hash_valid          = 3;
parameter s_r_load                   = 4;
parameter s_esp_load                 = 5;
parameter s_done                     = 6;



always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        o_h1_addr <= 0;
        r_addr <= 0;
        count <= 0;
        o_done <= 0;
        o_hash_force_done <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            r_addr <= 0;
            count <= 0;
            o_done <= 0;
            o_hash_force_done <= 0;
            if (i_start) begin
                state <= s_load_h1;
                o_h1_addr <= o_h1_addr + 1;
            end
            else begin
                o_h1_addr <= 0;
            end
        end 

        else if (state == s_load_h1) begin
            if (o_h1_addr == 2*SEED_SIZE/32 - 1) begin
                state <= s_start_hash;
                o_h1_addr <= 0;
            end
            else begin
                o_h1_addr <= o_h1_addr + 1;
            end
        end

        else if (state == s_start_hash) begin
            state <= s_wait_hash_valid;
        end

        else if (state == s_wait_hash_valid) begin
            if (i_hash_data_out_valid) begin
                state <= s_r_load;
                // r_addr <= r_addr + 1;
                // count <= count + 1;
            end
        end

        else if (state ==  s_r_load) begin
            if (r_addr == TAU*D_SPLIT) begin
                r_addr <= 0;
                state <= s_esp_load;
                if (i_hash_data_out_valid) begin
                    if (count == 2) begin
                        count <= 0;
                        r_addr <= r_addr + 1;
                    end
                    else begin
                        count <= count + 1;
                    end
                end
            end
            else begin
                if (i_hash_data_out_valid) begin
                    if (count == 2) begin
                        count <= 0;
                        r_addr <= r_addr + 1;
                    end
                    else begin
                        count <= count + 1;
                    end
                end
            end
        end

        else if (state ==  s_esp_load) begin
            if (r_addr == TAU*D_SPLIT) begin
                r_addr <= 0;
                state <= s_done;
            end
            else begin
                if (i_hash_data_out_valid) begin
                    if (count == 2) begin
                        count <= 0;
                        r_addr <= r_addr + 1;
                    end
                    else begin
                        count <= count + 1;
                    end
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
        r_wen <= 0;
        esp_wen <= 0;
        o_hash_data_out_ready <= 0;
        o_hash_start <= 0;
        if (i_start) begin
            o_h1_rd <= 1;
        end
        else begin
            o_h1_rd <= 0;
        end
    end

    s_load_h1: begin
        r_wen <= 0;
        esp_wen <= 0;
        o_hash_data_out_ready <= 0;
        o_h1_rd <= 1;
        o_hash_start <= 0;
    end

    s_start_hash: begin
        o_h1_rd <= 0;
        r_wen <= 0;
        esp_wen <= 0;
        o_hash_data_out_ready <= 0;
        o_hash_start <= 1;
    end

    s_wait_hash_valid: begin
        o_h1_rd <= 0;
        esp_wen <= 0;
        o_hash_start <= 0;
        r_wen <= 0;
        if (i_hash_data_out_valid) begin
            // r_wen <= 1;
            o_hash_data_out_ready <= 1;
        end
        else begin
            // r_wen <= 0;
            o_hash_data_out_ready <= 0;
        end
    end

    s_r_load: begin
        o_h1_rd <= 0;
        esp_wen <= 0;
        o_hash_start <= 0;
        o_hash_data_out_ready <= 1;
        if (i_hash_data_out_valid) begin
            if (count == 2) begin
                r_wen <= 1;
            end
            else begin
               r_wen <= 0; 
            end
        end
        else begin
            r_wen <= 0;
        end
    end

    s_esp_load:begin
        o_h1_rd <= 0;
        r_wen <= 0;
        o_hash_start <= 0;
        o_hash_data_out_ready <= 1;
        if (i_hash_data_out_valid) begin
            if (count == 2) begin
                esp_wen <= 1;
            end
            else begin
                esp_wen <= 0;
            end
        end
        else begin
            esp_wen <= 0;
        end
    end

    s_done: begin
        o_h1_rd <= 0;
        r_wen <= 0;
        o_hash_data_out_ready <= 0;
        o_hash_start <= 0;
        esp_wen <= 0;
    end

    default:begin
        o_h1_rd <= 0;
        r_wen <= 0;
        o_hash_data_out_ready <= 0;
        o_hash_start <= 0;
        esp_wen <= 0;
    end

    endcase
end





endmodule