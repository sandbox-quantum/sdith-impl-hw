/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module commit 
#(
//   parameter FIELD = "GF256",
     parameter FIELD = "P251",

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
    
    parameter D_HYPERCUBE = 8,
    parameter ETA = 4,

    parameter T =   (PARAMETER_SET == "L5")? 4:
                                             3, 

    parameter SEED_SIZE = LAMBDA,
    parameter SALT_SIZE = 2*LAMBDA,
    parameter NUMBER_OF_SEED_BITS = (2**D_HYPERCUBE) * LAMBDA,

    parameter HASH_INPUT_SIZE = LAMBDA + 2*LAMBDA,
    // parameter HASH_OUTPUT_SIZE = 8*(K + 2*WEIGHT + T*(2*D_SPLIT + 1)*ETA),
    parameter HASH_OUTPUT_SIZE = 8*(K + 2*D_SPLIT*WEIGHT + T*D_SPLIT*3),
    
    parameter WIDTH = 64,

    parameter FIRST_ADDR_ABC = 8*(K + 2*D_SPLIT*WEIGHT)/WIDTH,
    parameter HO_SIZE_ADJ = HASH_OUTPUT_SIZE + (WIDTH - HASH_OUTPUT_SIZE%WIDTH)%WIDTH
    

)(
    input                                               i_clk,
    input                                               i_rst,
    input                                               i_start,

    // input   [32-1:0]                                i_seed_root,
    // input   [`CLOG2(HASH_INPUT_SIZE/32)-1:0]        i_seed_root_addr,
    // input                                           i_seed_root_wr_en,

    input   [32-1:0]                                    i_seed_e,
    output  reg [`CLOG2(NUMBER_OF_SEED_BITS/32)-1:0]    o_seed_e_addr,
    output  reg                                         o_seed_e_rd,

    input   [32-1:0]                                    i_salt,
    output   reg [`CLOG2(SALT_SIZE/32)-1:0]             o_salt_addr,
    output   reg                                        o_salt_rd,

    output reg                                          o_done,

    input                                               i_acc_rd,
    input  [`CLOG2(HO_SIZE_ADJ/32)-1:0]                 i_acc_addr,
    output [WIDTH-1:0]                                  o_acc,

    input  [`CLOG2(D_HYPERCUBE)-1:0]                    i_input_mshare_sel,
    input                                               i_input_mshare_rd,
    input  [`CLOG2(HO_SIZE_ADJ/32)-1:0]                 i_input_mshare_addr,
    output [WIDTH-1:0]                                  o_input_mshare,

    // hash interface
    output   [32-1:0]                                   o_hash_data_in,
    input    [`CLOG2(HASH_INPUT_SIZE/32) -1:0]          i_hash_addr,
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


assign o_hash_input_length = HASH_INPUT_SIZE;
assign o_hash_output_length = 2*HASH_OUTPUT_SIZE;


// mem_single #(.WIDTH(32), .DEPTH(HASH_INPUT_SIZE/32)) 
//  SEED_ROOT
//  (
//  .clock(i_clk),
//  .data(i_seed_root),
//  .address(i_seed_root_wr_en? i_seed_root_addr: i_hash_rd_en? i_hash_addr: 0),
//  .wr_en(i_seed_root_wr_en),
//  .q(o_hash_data_in)
//  );

wire [31:0] ss_input;
reg ss_type;
reg [`CLOG2(HASH_INPUT_SIZE/32) -1:0] ss_addr;
reg ss_wen;
assign ss_input = (ss_type == 1)? i_salt : i_seed_e;

 mem_single #(.WIDTH(32), .DEPTH(HASH_INPUT_SIZE/32)) 
 SEED_E
 (
 .clock(i_clk),
 .data(ss_input),
 .address(ss_wen? ss_addr: i_hash_rd_en? i_hash_addr: 0),
 .wr_en(ss_wen),
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
wire [WIDTH-1:0] acc;

wire [WIDTH/8 -1:0] done_add;
wire  start_add;

assign start_add = in_share_wr_en;

genvar j;
generate
    for(j=0;j<WIDTH/8;j=j+1) begin
        if (FIELD == "P251") begin 
            p251_add #(.REG_IN(1), .REG_OUT(1))
            P251_ADD 
            (
                .i_clk(i_clk), 
                .i_start(start_add), 
                .in_1(input_share_bram[WIDTH-j*8-1 : WIDTH-j*8-8]), 
                .in_2(q_1[WIDTH-j*8-1 : WIDTH-j*8-8]),
                .o_done(done_add[j]), 
                .out(acc[WIDTH-j*8-1 : WIDTH-j*8-8]) 
            );
        end
        else begin 
            gf_add #(.REG_IN(1), .REG_OUT(0))
            GF_ADD 
            (
                .i_clk(i_clk), 
                .i_start(start_add), 
                .in_1(input_share_bram[WIDTH-j*8-1 : WIDTH-j*8-8]), 
                .in_2(q_1[WIDTH-j*8-1 : WIDTH-j*8-8]),
                .o_done(done_add[j]), 
                .out(acc[WIDTH-j*8-1 : WIDTH-j*8-8]) 
            );
        end
    end
endgenerate

parameter REG_STAGES_IN_ADDER = (FIELD == "P251")? 3: 2;

pipeline_reg_gen #(.REG_STAGES(REG_STAGES_IN_ADDER), .WIDTH(`CLOG2(HO_SIZE_ADJ/WIDTH)))
REG_IN_SHARE_ADDR
  (
    .i_clk(i_clk),
    .i_data_in(in_share_addr),
    .o_data_out(in_acc_addr)
  );

wire [`CLOG2(HO_SIZE_ADJ/WIDTH)-1:0] in_acc_addr = 0;
wire [WIDTH-1:0] q_1;
mem_dual #(.WIDTH(WIDTH), .DEPTH(HO_SIZE_ADJ/WIDTH), .FILE("ZERO.mem")) 
 SEED_SHARE
 (
 .clock(i_clk),
//  .data_0(input_share_bram),
 .data_0(acc),
 .data_1(0),
 .address_0(i_acc_rd? i_acc_addr: in_acc_addr),
 .address_1(abc_rd? abc_addr :in_share_addr),
//  .wren_0(in_share_wr_en),
 .wren_0(done_add[0]),
 .wren_1(0),
 .q_0(o_acc),
 .q_1(q_1)
 );

reg [`CLOG2(HO_SIZE_ADJ/WIDTH)-1:0] in_share_addr = 0;
reg in_share_wr_en;

 reg [3:0] state = 0;

parameter COUNT_WIDTH = (FIELD == "P251")? WIDTH/8:WIDTH/32;
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

reg [D_HYPERCUBE-1:0] loop_count_i = 0;

reg start_inner_loop;
reg done_inner_loop;


always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        count <= 0;
        in_share_addr <= 0;
        count_hash <= 0;
        first_block <= 1;
        o_hash_force_done <= 0;
        done_inner_loop <= 0;
    end
    else begin
      if (state == s_wait_start) begin
            count <= 0;
            in_share_addr <= 0;
            count_hash <= 0;
            first_block <= 1;
            o_hash_force_done <= 0;
            done_inner_loop <= 0;
            if (start_inner_loop) begin
                state <= s_wait_hash_valid;
            end
      end 

      else if (state == s_wait_hash_valid) begin  
            in_share_addr <= 0;
            first_block <= 1;
            o_hash_force_done <= 0;
            done_inner_loop <= 0;
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
            o_hash_force_done <= 0;
            done_inner_loop <= 0;
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
            o_hash_force_done <= 0;
            done_inner_loop <= 0;
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
            first_block <= 0;
            o_hash_force_done <= 0;
            done_inner_loop <= 0;
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
            first_block <= 0;
            o_hash_force_done <= 0;
            done_inner_loop <= 0;
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
            done_inner_loop <= 1;
            o_hash_force_done <= 1;
            state <= s_wait_start;
      end

    end
end

always@(state, start_inner_loop, i_hash_data_out_valid, count, first_block, threshold)
begin
    case(state)

    s_wait_start:begin
        o_hash_data_out_ready <= 0;
        in_share_wr_en <= 0;
        load <= 0;
        shift <= 0;
        in_share_valid <= 0;
        if (start_inner_loop) begin
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

genvar i;

wire [`CLOG2(HO_SIZE_ADJ/WIDTH)-1:0] in_acc_addr = 0;
wire [WIDTH-1:0] m_share_for_out [D_HYPERCUBE-1:0];
wire [WIDTH-1:0] m_share_mem_pool_out [D_HYPERCUBE-1:0];
wire [WIDTH-1:0] in_mshare [D_HYPERCUBE-1:0];
wire [WIDTH/8-1:0] m_share_add_done [D_HYPERCUBE-1:0];
genvar k;

wire [WIDTH-1:0] input_share_mshare;
assign input_share_mshare = input_share_bram;

generate
    for(k=0;k<D_HYPERCUBE;k=k+1) begin
        // generate
        for(i=0;i<WIDTH/8;i=i+1) begin
            if (FIELD == "P251") begin 
                p251_add #(.REG_IN(1), .REG_OUT(1))
                P251_ADD 
                (
                    .i_clk(i_clk), 
                    .i_start(start_add), 
                    .in_1(input_share_mshare[WIDTH-i*8-1 : WIDTH-i*8-8]), 
                    .in_2(m_share_mem_pool_out[k][WIDTH-i*8-1 : WIDTH-i*8-8]),
                    .o_done(m_share_add_done[k][i]),
                    .out(in_mshare[k][WIDTH-i*8-1 : WIDTH-i*8-8]) 
                );
            end
            else begin 
                gf_add #(.REG_IN(1), .REG_OUT(0))
                GF_ADD 
                (
                    .i_clk(i_clk), 
                    .i_start(start_add), 
                    .in_1(input_share_mshare[WIDTH-i*8-1 : WIDTH-i*8-8]), 
                    .in_2(m_share_mem_pool_out[k][WIDTH-i*8-1 : WIDTH-i*8-8]),
                    .o_done(m_share_add_done[k][i]),
                    .out(in_mshare[k][WIDTH-i*8-1 : WIDTH-i*8-8]) 
                );
            end
        end
        // endgenerate

        mem_dual #(.WIDTH(WIDTH), .DEPTH(HO_SIZE_ADJ/WIDTH), .INIT(1)) 
        INPUT_M_SHARE
        (
        .clock(i_clk),
        .data_0(in_mshare[k]),
        .data_1(0),
        .address_0(i_input_mshare_rd? i_input_mshare_addr : in_acc_addr),
        .address_1(in_share_addr),
        .wren_0(m_share_add_done[k][0] && (~loop_count_i[k])),
        .wren_1(0),
        .q_0(m_share_for_out[k]),
        .q_1(m_share_mem_pool_out[k])
        );
    end
endgenerate

assign o_input_mshare = (i_input_mshare_sel == 0)? m_share_for_out[0]:
                        (i_input_mshare_sel == 1)? m_share_for_out[1]:
                        (i_input_mshare_sel == 2)? m_share_for_out[2]:
                        (i_input_mshare_sel == 3)? m_share_for_out[3]:
                        (i_input_mshare_sel == 4)? m_share_for_out[4]:
                        (i_input_mshare_sel == 5)? m_share_for_out[5]:
                        (i_input_mshare_sel == 6)? m_share_for_out[6]:
                                                   m_share_for_out[7];



reg [3:0] c_state;
parameter c_s_wait_start = 0;

always@(posedge i_clk)
begin
    if (i_rst) begin
        c_state <= c_s_wait_start;
    end
    else begin
    end
end

always@(*)
begin
    case(c_state)


    endcase
end
//seed manager
reg [3:0] h_state;
parameter h_s_wait_start            = 0;
parameter h_s_stall_0               = 1;
parameter h_s_load_salt             = 2;
parameter h_s_stall_1               = 3;
parameter h_s_load_seed             = 4;
parameter h_s_start_iloop           = 5;
parameter h_s_done_iloop            = 6;
parameter h_s_check_i               = 7;
parameter h_s_load_out_ABC          = 8;
parameter h_s_stall_2               = 9;
parameter h_s_mul_add_ab            = 10;
parameter h_s_mul_add_ab_done       = 11;
parameter h_s_done                  = 15;

reg [`CLOG2(SEED_SIZE/32):0] count_seed_block = 0;

always@(posedge i_clk)
begin
    if (i_rst) begin
        h_state <= h_s_wait_start;
        loop_count_i <= 0;
        o_salt_addr <= 0;
        o_seed_e_addr <= 0;
        ss_addr <= 0;
        count_seed_block <=0;
        o_done <= 0;
        loop_count_i <= 0;
        abc_addr <= FIRST_ADDR_ABC;
    end
    else begin
        if (h_state == h_s_wait_start) begin
            o_salt_addr <= 0;
            ss_addr <= 0;
            o_seed_e_addr <= 0;
            count_seed_block <= 0;
            o_done <= 0;
            loop_count_i <= 0;
            abc_addr <= FIRST_ADDR_ABC;
            if (i_start) begin
                h_state <= h_s_stall_0;
            end
        end

        else if (h_state == h_s_stall_0) begin
            o_salt_addr <= o_salt_addr+1;
            h_state <= h_s_load_salt;
            ss_addr <= 0;
            o_seed_e_addr <= 0;
            count_seed_block <= 0;
        end

        else if (h_state == h_s_load_salt) begin
            if (o_salt_addr == SALT_SIZE/32 - 1) begin
                h_state <= h_s_stall_1;
                o_salt_addr <= 0;
                ss_addr <= ss_addr + 1;
            end 
            else begin
                o_salt_addr <= o_salt_addr + 1;
                ss_addr <= ss_addr + 1;
            end
        end

        else if (h_state == h_s_stall_1) begin
            ss_addr <= ss_addr + 1;
            h_state <= h_s_load_seed;
            o_seed_e_addr <= o_seed_e_addr + 1;
            count_seed_block <= count_seed_block + 1;
        end

        else if (h_state == h_s_load_seed) begin
            if (count_seed_block == SEED_SIZE/32) begin
                ss_addr <= SALT_SIZE/32;
                // o_seed_e_addr <= o_seed_e_addr + 1;
                h_state <= h_s_start_iloop;
                count_seed_block <= 0;
            end 
            else begin
                 ss_addr <= ss_addr + 1;
                 count_seed_block <= count_seed_block + 1;
                 o_seed_e_addr <= o_seed_e_addr + 1;
            end
        end 
        
        else if (h_state == h_s_start_iloop) begin
            h_state <= h_s_done_iloop;
        end

        else if (h_state == h_s_done_iloop) begin
            if (done_inner_loop) begin
                h_state <= h_s_check_i;
                loop_count_i <= loop_count_i + 1;
            end
        end

        else if (h_state == h_s_check_i) begin
            if (loop_count_i == 2**D_HYPERCUBE - 1) begin
                // h_state <= h_s_done;
                h_state <= h_s_load_out_ABC;
                loop_count_i <= 0;
            end
            else begin
                h_state <= 0;
                o_seed_e_addr <= o_seed_e_addr + 1;
                h_state <= h_s_load_seed;
            end
        end

        else if (h_state == h_s_load_out_ABC) begin
            if (abc_addr == HO_SIZE_ADJ/WIDTH - 1) begin
                abc_addr <= FIRST_ADDR_ABC;
                h_state <= h_s_stall_2;
            end
            else begin
                abc_addr <= abc_addr + 1;
            end
        end

        else if (h_state == h_s_stall_2) begin
           h_state <= h_s_mul_add_ab;
        end

        else if (h_state == h_s_mul_add_ab) begin
           h_state <= h_s_mul_add_ab_done;
        end

        else if (h_state == h_s_mul_add_ab_done) begin
            if (done_add_c[0]) begin
                h_state <= h_s_done;
            end
        end

        else if (h_state == h_s_done) begin
            o_done <= 1;
           h_state <= h_s_wait_start;
        end
    end
end

always@(*)
begin
    case(h_state)
        h_s_wait_start:begin
            o_seed_e_rd <= 0;
            ss_wen <= 0;
            ss_type <= 1;
            abc_rd <= 0;
            start_mul_ab<= 0;
            if (i_start) begin
                o_salt_rd <= 1;
            end
            else begin
                o_salt_rd <= 0;
            end
        end

        h_s_stall_0:begin
            o_salt_rd <= 1;
            o_seed_e_rd <= 0;
            ss_wen <= 0;
            ss_type <= 1;
            abc_rd <= 0;
            start_mul_ab<= 0;
        end

        h_s_load_salt:begin
            o_salt_rd <= 1;
            o_seed_e_rd <= 0;
            ss_wen <= 1;
            ss_type <= 1;
            abc_rd <= 0;
            start_mul_ab<= 0;
        end

        h_s_stall_1: begin
            o_salt_rd <= 0;
            o_seed_e_rd <= 1;
            ss_wen <= 1;
            ss_type <= 1;
            abc_rd <= 0;
            start_mul_ab<= 0;
        end

        h_s_load_seed: begin
            o_salt_rd <= 0;
            o_seed_e_rd <= 1;
            ss_wen <= 1;
            ss_type <= 0;
            abc_rd <= 0;
            start_mul_ab<= 0;
        end

        h_s_start_iloop: begin
            o_salt_rd <= 0;
            o_seed_e_rd <= 1;
            ss_wen <= 0;
            ss_type <= 0;
            start_inner_loop <= 1;
            abc_rd <= 0;
            start_mul_ab<= 0;
        end

        h_s_done_iloop: begin
            o_salt_rd <= 0;
            o_seed_e_rd <= 1;
            ss_wen <= 0;
            ss_type <= 0;
            start_inner_loop <= 0;
            abc_rd <= 0;
            start_mul_ab<= 0;
        end

        h_s_check_i: begin
            o_salt_rd <= 0;
            o_seed_e_rd <= 1;
            ss_wen <= 0;
            ss_type <= 0;
            start_inner_loop <= 0;
            abc_rd <= 0;
            start_mul_ab<= 0;
        end

        h_s_load_out_ABC: begin
            o_salt_rd <= 0;
            o_seed_e_rd <= 1;
            ss_wen <= 0;
            ss_type <= 0;
            start_inner_loop <= 0;
            abc_rd <= 1;
            start_mul_ab<= 0;
        end

        h_s_stall_2: begin
            o_salt_rd <= 0;
            o_seed_e_rd <= 1;
            ss_wen <= 0;
            ss_type <= 0;
            start_inner_loop <= 0;
            abc_rd <= 1;
            start_mul_ab<= 0;
        end

        h_s_mul_add_ab: begin
            o_salt_rd <= 0;
            o_seed_e_rd <= 1;
            ss_wen <= 0;
            ss_type <= 0;
            start_inner_loop <= 0;
            abc_rd <= 0;
            start_mul_ab<= 1;
        end

        h_s_mul_add_ab_done: begin
            o_salt_rd <= 0;
            o_seed_e_rd <= 1;
            ss_wen <= 0;
            ss_type <= 0;
            start_inner_loop <= 0;
            abc_rd <= 0;
            start_mul_ab<= 0;
        end

        h_s_done:begin
            o_salt_rd <= 0;
            o_seed_e_rd <= 0; 
            ss_wen <= 0;
            ss_type <= 0;
            abc_rd <= 0;
            start_mul_ab<= 0;
        end

        default:begin
            o_salt_rd <= 0;
            o_seed_e_rd <= 0;
            ss_wen <= 0;
            ss_type <= 0;
            start_inner_loop <= 0;
            abc_rd <= 0;
        end
    endcase
end

parameter ABC_SIZE = 8*T*3*D_SPLIT;
parameter ABC_SIZE_ADJ = ABC_SIZE + (WIDTH - ABC_SIZE%WIDTH)%WIDTH;

parameter START_ADDR_A  =   (8*(K + 2*D_SPLIT*WEIGHT)) % WIDTH;

reg [`CLOG2(HO_SIZE_ADJ/WIDTH)-1:0] abc_addr = 0;
reg abc_rd = 0;
// reg in_share_wr_en;
reg [ABC_SIZE_ADJ-1:0] abc_reg;

// Logic for ABC
always@(posedge i_clk)
begin
    if (i_start) begin
        abc_reg <= 0;
    end
    else if (abc_rd) begin
        abc_reg <= {abc_reg[ABC_SIZE_ADJ-WIDTH-1:0],q_1};
    end
end

wire [D_SPLIT*T*8 -1: 0] a;
wire [D_SPLIT*T*8 -1: 0] b;
wire [D_SPLIT*T*8 -1: 0] c, c_1, c_2;

assign a = abc_reg[ABC_SIZE_ADJ-START_ADDR_A-1:ABC_SIZE_ADJ-START_ADDR_A-D_SPLIT*T*8];
assign b = abc_reg[ABC_SIZE_ADJ-START_ADDR_A-D_SPLIT*T*8-1:ABC_SIZE_ADJ-START_ADDR_A-D_SPLIT*T*8-D_SPLIT*T*8];
assign c_1 = abc_reg[ABC_SIZE_ADJ-START_ADDR_A-D_SPLIT*T*8-D_SPLIT*T*8-1:ABC_SIZE_ADJ-START_ADDR_A-D_SPLIT*T*8-D_SPLIT*T*8-D_SPLIT*T*8];


reg start_mul_ab;
wire [T-1:0] done_mul_ab;
genvar iz;
generate
    for(iz=0;iz<T;iz=iz+1) begin
        if (FIELD == "P251") begin 
            p251_mul 
            P251_MULT 
            (
                .clk(i_clk), 
                .start(start_mul_ab), 
                .in_1(a[8*T-iz*8-1 : 8*T-iz*8-8]), 
                .in_2(b[8*T-iz*8-1 : 8*T-iz*8-8]),
                .done(done_mul_ab[iz]), 
                .out(c_2[8*T-iz*8-1 : 8*T-iz*8-8]) 
            );
        end
        else begin 
            gf_mul 
            GF_MULT 
            (
                .clk(i_clk), 
                .start(start_mul_ab), 
                .in_1(a[8*T-iz*8-1 : 8*T-iz*8-8]), 
                .in_2(b[8*T-iz*8-1 : 8*T-iz*8-8]),
                .done(done_mul_ab[iz]), 
                .out(c_2[8*T-iz*8-1 : 8*T-iz*8-8]) 
            );
        end
    end
endgenerate

wire start_add_c;
wire [T-1:0]done_add_c;

assign start_add_c = done_mul_ab[0];

genvar jz;
generate
    for(jz=0;jz<T;jz=jz+1) begin
        if (FIELD == "P251") begin 
            p251_add #(.REG_IN(1), .REG_OUT(1))
            P251_ADD_C 
            (
                .i_clk(i_clk), 
                .i_start(start_add_c), 
                .in_1(c_1[8*T-jz*8-1 : 8*T-jz*8-8]), 
                .in_2(c_2[8*T-jz*8-1 : 8*T-jz*8-8]),
                .o_done(done_add_c[jz]), 
                .out(c[8*T-jz*8-1 : 8*T-jz*8-8]) 
            );
        end
        else begin 
            gf_add #(.REG_IN(1), .REG_OUT(1))
            GF_ADD_C 
            (
                .i_clk(i_clk), 
                .i_start(start_add_c), 
                .in_1(c_1[8*T-jz*8-1 : 8*T-jz*8-8]), 
                .in_2(c_2[8*T-jz*8-1 : 8*T-jz*8-8]),
                .o_done(done_add_c[jz]), 
                .out(c[8*T-jz*8-1 : 8*T-jz*8-8]) 
            );
        end
    end
endgenerate



endmodule