/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module get_seed_sibling_path 
#(
    parameter PARAMETER_SET = "L1",
    
    parameter LAMBDA =      (PARAMETER_SET == "L1")? 128:
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
    parameter SALT_SIZE = 2*LAMBDA,
    
    parameter D_HYPERCUBE = 8,
    
    parameter NUMBER_OF_SEED_BITS = (2**(D_HYPERCUBE)+1) * LAMBDA,

    parameter SIZE_OF_R     = TAU*T*D_SPLIT*8,
    parameter SIZE_OF_EPS   = TAU*T*D_SPLIT*8,
    
    parameter FILE_SS  = ""
    

)(
    input                                               i_clk,
    input                                               i_rst,

    input                                               i_start,
    output reg                                          o_done,

    input  [7:0]                                        i_i_star,

    input [`CLOG2(SEED_SIZE + SALT_SIZE)-1:0]           i_salt_seed_addr,             
    input                                               i_salt_seed_wen,
    input [31:0]                                        i_salt_seed, 

    output [31:0]                                      o_tree_seed,
    output wire                                        o_tree_seed_valid,
    output reg [`CLOG2((8*SEED_SIZE/32)) -1:0]         o_tree_seed_addr,

    // hash interface
    output   [32-1:0]                                   o_hash_data_in,
    input    [`CLOG2((SALT_SIZE+SEED_SIZE)/32) -1:0]            i_hash_addr,
    input                                               i_hash_rd_en,

    input    wire [32-1:0]                              i_hash_data_out,
    input    wire                                        i_hash_data_out_valid,
    output   reg                                        o_hash_data_out_ready,

    output   wire  [32-1:0]                             o_hash_input_length, // in bits
    output   wire  [32-1:0]                             o_hash_output_length, // in bits

    output   reg                                        o_hash_start,
    input    wire                                       i_hash_force_done_ack,
    output   reg                                        o_hash_force_done

);


assign o_hash_input_length = SALT_SIZE + SEED_SIZE;
assign o_hash_output_length = 2*SEED_SIZE;


assign o_tree_seed = i_hash_data_out;
assign o_tree_seed_valid = tree_valid_seed_int & valid_seed;

// reg [`CLOG2(2*SEED_SIZE/32)-1:0] h1_addr;

// wire [31:0] h2_out;
wire wen_seed;

assign wen_seed = (out_pos[1]);

reg [`CLOG2((SALT_SIZE+SEED_SIZE)/32)-1:0] ss_addr;

wire wen_ss;
assign wen_ss = (wen_seed_block & valid_seed) | i_salt_seed_wen;

mem_single #(.WIDTH(32), .DEPTH((SALT_SIZE+SEED_SIZE)/32), .INIT(0), .FILE(FILE_SS)) 
 SEED_SALT
 (
 .clock(i_clk),
 .data(i_salt_seed_wen? i_salt_seed: i_hash_data_out),
 .address(i_salt_seed_wen? i_salt_seed_addr :i_hash_rd_en?i_hash_addr : wen_ss? ss_addr:0),
 .wr_en(wen_ss),
 .q(o_hash_data_in)
 );
// assign o_hash_data_in = h2_out;
// assign o_h2 = h2_out;


reg [7:0] i_reg;
reg load; 
reg shift;
reg shift_reg;
reg i_reg_reg;

always@(posedge i_clk)
begin
    if (load) begin
        i_reg <= i_i_star;
    end
    else if (shift) begin
        i_reg <= {i_reg[6:0],1'b0};
    end
end

always@(posedge i_clk)
begin
    shift_reg <= load | shift;
    i_reg_reg <= i_reg[7];
end

reg [7:0] position;
always@(posedge i_clk)
begin
    if (load) begin
        position <= 0;
    end
    else if (shift_reg) begin
        position <= {position[6:0], i_reg[7]};
    end
end

wire [7:0] in_pos;
wire [7:0] out_pos;
assign in_pos = {position[7:1],{position[0] ^ 1'b1}};

// reg i_star_wen;
reg [`CLOG2(D_HYPERCUBE)-1:0] tree_path_addr_reg;
wire [`CLOG2(D_HYPERCUBE)-1:0] pos_addr;

reg in_pos_wen;

always@(posedge i_clk)
begin
    tree_path_addr_reg <= tree_path_addr[`CLOG2(D_HYPERCUBE)-1:0];
    in_pos_wen <= shift;
end

assign pos_addr = in_pos_wen? tree_path_addr_reg : tree_path_addr[`CLOG2(D_HYPERCUBE)-1:0];


mem_single #(.WIDTH(8), .DEPTH(D_HYPERCUBE), .INIT(1)) 
 TREEPOS_MEM
 (
 .clock(i_clk),
 .data(in_pos),
 .address(pos_addr),
 .wr_en(in_pos_wen),
 .q(out_pos)
 );

reg [`CLOG2(D_HYPERCUBE)-1:0] valid_in_pos_addr;
always@(posedge i_clk) 
begin
    if (i_start) begin
        valid_in_pos_addr <= 0;
    end
    else if (in_pos_wen && (in_pos == 0)) begin
        valid_in_pos_addr <= pos_addr;
    end
end

reg valid_seed;
reg wen_seed_block;
reg [`CLOG2(2*SEED_SIZE/32)-1:0] count_seed_block = 0;
reg tree_valid_seed_int;

reg [2:0] state = 0;
// reg [`CLOG2(D_HYPERCUBE):0] tree_path_addr = 0;
reg [`CLOG2(D_HYPERCUBE):0] tree_path_addr = 0;
parameter s_wait_start               = 0;
parameter s_shift                    = 1;
parameter s_scan                     = 2;
parameter s_wait_hash_valid          = 3;
parameter s_check_the_pos            = 4;
parameter s_expand_tree              = 5;
// parameter s_shift                    = 5;
parameter s_done                     = 6;



always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        o_done <= 0;
        o_hash_force_done <= 0;
        // o_seed_i_addr <= 0;
        tree_path_addr <= 0;
        count_seed_block <= 0;
        o_tree_seed_addr <= 0;
        ss_addr <= SALT_SIZE/32;
        o_hash_force_done <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            tree_path_addr <= 0;
            o_done <= 0;
            o_hash_force_done <= 0;
            // o_seed_i_addr <= 0;
            o_tree_seed_addr <= 0;
            o_hash_force_done <= 0;
            ss_addr <= SALT_SIZE/32;
            if (i_start) begin
                state <= s_shift;
            end
        end 

        else if (state == s_shift) begin
            o_hash_force_done <= 0;
            if (tree_path_addr == D_HYPERCUBE - 1) begin
                tree_path_addr <= 1;
                state <= s_wait_hash_valid;
            end
            else begin
                tree_path_addr <= tree_path_addr + 1;
            end
        end

        else if (state == s_wait_hash_valid) begin
            o_hash_force_done <= 0;
            if (i_hash_data_out_valid) begin
                state <= s_expand_tree;
            end
        end

        else if (state == s_check_the_pos) begin
            // if (tree_path_addr == D_HYPERCUBE - 1) begin
            o_hash_force_done <= 0;
            if (tree_path_addr == D_HYPERCUBE) begin
                state <= s_done;
            end
            else begin
                // state <= s_expand_tree;
                if (i_hash_force_done_ack) begin
                    state <= s_wait_hash_valid;
                end
                // state <= s_done;
            end
        end

        else if (state == s_expand_tree) begin
            if  (count_seed_block == 2*SEED_SIZE/32 - 1)  begin
                count_seed_block <= 0;
                state <= s_check_the_pos;
                o_hash_force_done <= 1;
                ss_addr <= SALT_SIZE/32;
                tree_path_addr <= tree_path_addr + 1;
                if (o_tree_seed_valid) begin
                        o_tree_seed_addr <= o_tree_seed_addr + 1;
                end
                // o_tree_seed_addr <= o_tree_seed_addr + 1;
            end
            else begin
                o_hash_force_done <= 0;
                if (i_hash_data_out_valid) begin
                    count_seed_block <= count_seed_block + 1;
                    if (o_tree_seed_valid) begin
                        o_tree_seed_addr <= o_tree_seed_addr + 1;
                    end
                    else begin
                        ss_addr <= ss_addr + 1;
                    end
                end
            end
        end

        else if (state == s_done) begin
            state <= s_wait_start;
            o_done <= 1;
            o_hash_force_done <= 0;
        end

    end
end

always@(*)
begin
    case(state)

    s_wait_start:begin
        o_hash_data_out_ready <= 0;
        shift <= 0;
        valid_seed <= 0;
        wen_seed_block <= 0;
        tree_valid_seed_int <= 0;
        if (i_start) begin
            load <= 1;
            o_hash_start <= 1;
        end
        else begin
            load <= 0;
            o_hash_start <= 0;
        end
    end

    s_shift: begin
        o_hash_data_out_ready <= 0;
        shift <= 1;
        load <= 0;
        o_hash_start <= 0;
        valid_seed <= 0;
        wen_seed_block <= 0;
        tree_valid_seed_int <= 0;
    end

    s_wait_hash_valid: begin
        o_hash_start <= 0;
        shift <= 0;
        load <= 0;
        o_hash_data_out_ready <= 0;
        valid_seed <= 0;
        wen_seed_block <= 0;
        tree_valid_seed_int <= 0;
    end

    s_check_the_pos: begin
        // if (tree_path_addr >= valid_in_pos_addr) begin
        //     valid_seed <= 1;
        // end
        // else begin
        //     valid_seed <= 0;
        // end
        if (tree_path_addr < D_HYPERCUBE && i_hash_force_done_ack) begin
            o_hash_start <= 1;
        end
        else begin
            o_hash_start <= 0; 
        end
        shift <= 0;
        load <= 0;
        o_hash_data_out_ready <= 0;
        wen_seed_block <= 0;
        tree_valid_seed_int <= 0;
        valid_seed <= 0;
    end

    s_expand_tree: begin
        if (tree_path_addr >= valid_in_pos_addr) begin
            valid_seed <= 1;
        end
        else begin
            valid_seed <= 0;
        end
        if (tree_path_addr > valid_in_pos_addr) begin
            if (out_pos[0] == 1) begin
                if (count_seed_block > SEED_SIZE/32 - 1 || tree_path_addr == D_HYPERCUBE-1) begin
                    wen_seed_block <= 0;
                    tree_valid_seed_int <= 1;
                end
                else begin
                    wen_seed_block <= 1;
                    tree_valid_seed_int <= 0;
                end     
            end
            else begin
                if ((count_seed_block < SEED_SIZE/32 || tree_path_addr == D_HYPERCUBE-1)) begin
                    wen_seed_block <= 0;
                    tree_valid_seed_int <= 1;
                end
                else begin
                    wen_seed_block <= 1;
                    tree_valid_seed_int <= 0;
                end  
            end
        end
        else begin
            wen_seed_block <= 0;
            tree_valid_seed_int <= 0;
        end
        o_hash_start <= 0;
        shift <= 0;
        load <= 0;
        o_hash_data_out_ready <= 1;
    end

    s_done: begin
        o_hash_data_out_ready <= 0;
        o_hash_start <= 0;
        load <= 0;
        shift <= 0;
        valid_seed <= 0;
        wen_seed_block <= 0;
        tree_valid_seed_int <= 0;
    end

    default:begin
        o_hash_data_out_ready <= 0;
        o_hash_start <= 0;
        load <= 0;
        shift <= 0;
        valid_seed <= 0;
        wen_seed_block <= 0;
        tree_valid_seed_int <= 0;
    end

    endcase
end





endmodule