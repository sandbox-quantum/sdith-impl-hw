/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module gen_H_seq
#(
//    parameter FIELD = "P251",
    parameter FIELD = "GF256",
    parameter PARAMETER_SET = "L1",
    
    parameter SEED_SIZE =   (PARAMETER_SET == "L1")? 128:
                            (PARAMETER_SET == "L3")? 192:
                            (PARAMETER_SET == "L5")? 256:
                                                     128,
                                                    
    parameter MAT_ROW_SIZE_BYTES = (PARAMETER_SET == "L1")? 104:
                                   (PARAMETER_SET == "L3")? 159:
                                   (PARAMETER_SET == "L5")? 202:
                                                            8,
                                                            
    parameter MAT_COL_SIZE_BYTES  =(PARAMETER_SET == "L1")? 126:
                                   (PARAMETER_SET == "L3")? 193:
                                   (PARAMETER_SET == "L5")? 278:
                                                            8,

    parameter MAT_SIZE_BYTES = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES,
    
    parameter PROC_SIZE = N_GF*8,

    parameter MRS_BITS = MAT_ROW_SIZE_BYTES*8,
    parameter MCS_BITS = MAT_COL_SIZE_BYTES*8,
    
    parameter MAT_ROW_SIZE = MRS_BITS + (PROC_SIZE - MRS_BITS%PROC_SIZE)%PROC_SIZE,
    parameter MAT_COL_SIZE = MCS_BITS + (PROC_SIZE - MCS_BITS%PROC_SIZE)%PROC_SIZE,

    parameter N_GF = 8, 
    
    // parameter MAT_SIZE = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE,
    parameter MAT_SIZE = MAT_ROW_SIZE*MAT_COL_SIZE_BYTES,

    // parameter PAD_BITS = (PROC_SIZE - MCS_BITS%PROC_SIZE)%PROC_SIZE,
    parameter PAD_BITS = (PROC_SIZE - MRS_BITS%PROC_SIZE)%PROC_SIZE,

    parameter SEED_FILE  = ""
    
    
    
    
)(
    input               i_clk,
    input               i_rst,
    input               i_start,

    input   [31:0]      i_seed_h,
    input   [`CLOG2(SEED_SIZE/32)-1:0]       i_seed_h_addr,
    input               i_seed_wr_en,
    // output              o_start_h_proc,

    output  [31:0]     o_seed_h_prng,

    output   reg        o_start_prng,

    input   [`CLOG2(SEED_SIZE/32)-1:0]       i_prng_addr,
    input                                    i_prng_rd,

    input   [31:0]      i_prng_out,
    input               i_prng_out_valid,
    output   reg        o_prng_out_ready,
    output   reg        o_prng_force_done,
    
    input               i_h_out_en,
    input [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0] i_h_out_addr,
    output [PROC_SIZE-1:0] o_h_out,

    output              o_done
);



assign o_done = done_int;

wire [PROC_SIZE-1:0] data_0;

reg [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0] addr_0; 
wire [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0] addr_1; 
reg  wren_0;
reg  wren_0_reg;
reg [`CLOG2(MAT_SIZE/PROC_SIZE)-1:0] addr_0_reg; 
// reg [PROC_SIZE+32-1:0] data_shift_reg;
reg [PROC_SIZE-1:0] data_shift_reg;

wire [PROC_SIZE-1:0] q_0, q_1;

reg [31:0] i_prng_out_reg;


reg load_in, shift_in;
reg big_shift_reg_en;

always@(posedge i_clk)
begin
    if (load_in) begin
        i_prng_out_reg <= i_prng_out;
    end
    else if (shift_in) begin
        i_prng_out_reg <= {i_prng_out_reg[23:0],8'b0};
    end
end

wire [7:0] byte_in;
wire [7:0] byte_next;
assign byte_in = i_prng_out_reg[31:24];

assign byte_next = i_prng_out_reg[23:16];


always@(posedge i_clk) begin
    if (big_shift_reg_en) begin
        data_shift_reg <= {data_shift_reg[PROC_SIZE-8:0], byte_in};
    end
end

assign data_0 = (count_row_block == MAT_ROW_SIZE/PROC_SIZE - 1)? {data_shift_reg[PROC_SIZE-PAD_BITS-1:0], {(PAD_BITS){1'b0}}} : data_shift_reg; 

assign o_h_out = q_1;
assign wren_1 = 0;
assign addr_1 = i_h_out_addr;

mem_dual #(.WIDTH(PROC_SIZE), .DEPTH(MAT_SIZE/PROC_SIZE))
RESULT_MEM 
(
  .clock(i_clk),
  .data_0(data_0),
  .data_1(0),
  .address_0(addr_0),
  .address_1(addr_1),
  .wren_0(wren_0),
  .wren_1(wren_1),
  .q_0(q_0),
  .q_1(q_1)

);




mem_single #(.WIDTH(32), .DEPTH(SEED_SIZE/32), .FILE())
SEED_MEM 
(
  .clock(i_clk),
  .data(i_seed_h),
  .address(i_prng_rd? i_prng_addr: i_seed_h_addr),
  .wr_en(i_seed_wr_en),
  .q(o_seed_h_prng)
);

parameter s_wait_start                  = 0;
parameter s_stall_0                     = 1;
parameter s_stall_1                     = 2;
parameter s_wait_prng_out               = 3;
parameter s_update_shake_reg            = 4;
parameter s_finish_storage              = 5;
parameter s_wait_prng_out_valid         = 6;
parameter s_stall_2                     = 7;
parameter s_done                        = 8;

reg [3:0] state = 0;
reg [`CLOG2(N_GF):0] vect_shift_count;
// reg [`CLOG2(N_GF)-1:0] vs_count_tracker;
reg [1:0] count;
reg [`CLOG2(MAT_ROW_SIZE/PROC_SIZE)-1:0] count_row_block;
reg done_int;
reg load_first;
reg last_block;
reg [1:0] type;



always@(posedge i_clk) begin
    if (i_start) begin
        count_row_block <= 0;
    end
    else if (wren_0) begin
        if (count_row_block == MAT_ROW_SIZE/PROC_SIZE-1) begin
            count_row_block <= 0;
        end
        else begin
            count_row_block <= count_row_block + 1;
        end
    end
end
wire debug_last;
assign debug_last = wren_0 & count_row_block == MAT_COL_SIZE/PROC_SIZE-1;

// always@(posedge i_clk)
// begin
//     if (i_start) begin
//         vs_count_tracker <= N_GF - 1;
//     end
//     // if (wren_0) begin
//     //     if ((vect_shift_count == vs_count_tracker-PAD_BITS/N_GF) && (count_row_block == MAT_ROW_SIZE/PROC_SIZE-1)) begin
//     //         vs_count_tracker <= vs_count_tracker-PAD_BITS/N_GF;
//     //     end
//     // end
// end

always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        addr_0 <= 0;
        count <= 0;
        o_prng_force_done <= 0;
        last_block <= 0;
        type <= 0;
        vect_shift_count <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            count <= 0;
            addr_0 <= 0;
            o_prng_force_done <= 0;
            last_block <=0;
            vect_shift_count <= 0;
            done_int <= 0;
            if (i_start) begin
                state <= s_stall_0;
            end
        end

        else if (state == s_stall_0) begin
            if (i_prng_out_valid) begin
                state <= s_stall_1;
            end
        end

        else if (state == s_stall_1) begin
                state <= s_wait_prng_out;
                count <= count + 1;
        end

        else if (state == s_wait_prng_out) begin
            done_int <= 0;
            o_prng_force_done <= 0;
            
            if (addr_0 == MAT_SIZE/PROC_SIZE) begin
               state <= s_done; 
               count <= 0;
               addr_0 <= 0;
            end
            else begin
                if (count == 2) begin
                    state <= s_update_shake_reg;
                    count <= count + 1;
                end
                else begin
                    count <= count + 1;
                end    
                if (big_shift_reg_en) begin 
                    if (vect_shift_count == N_GF-1 || ((vect_shift_count == N_GF-1-PAD_BITS/N_GF) && (count_row_block == MAT_ROW_SIZE/PROC_SIZE-1))) begin
                        vect_shift_count <= 0;
                        addr_0 <= addr_0 + 1;     
                    end
                    else begin
                        vect_shift_count <= vect_shift_count + 1;
                    end
                end
            end
        end

        else if (state == s_update_shake_reg) begin
            if (addr_0 == MAT_SIZE/PROC_SIZE) begin  // added && vect_shift_count == N_GF-1 to support last block filling
//                addr_0 <= 0;
                state <= s_done;
//                count <= 0;
            end
            else begin
                if (i_prng_out_valid) begin
                    state <= s_wait_prng_out;
                    count <= count + 1;
                end
                else begin
                    state <= s_finish_storage;
                end
                if (big_shift_reg_en) begin 
                    if (vect_shift_count == N_GF-1 || ((vect_shift_count == N_GF-1-PAD_BITS/N_GF) && (count_row_block == MAT_ROW_SIZE/PROC_SIZE-1))) begin
                        vect_shift_count <= 0;
                        addr_0 <= addr_0 + 1;
                    end
                    else begin
                        vect_shift_count <= vect_shift_count + 1;
                    end
                end
            end
        end

        else if (state == s_finish_storage) begin
            if (addr_0 == MAT_SIZE/PROC_SIZE) begin
               state <= s_done;
            end
            else begin  
                state <= s_wait_prng_out_valid;
            end
        end


        else if (state == s_wait_prng_out_valid) begin
            if (addr_0 == MAT_SIZE/PROC_SIZE) begin
               state <= s_done; 
               count <= 0;
               addr_0 <= 0;
            end
            else begin
                if (i_prng_out_valid || (addr_0==MAT_SIZE/PROC_SIZE - 1 && (vect_shift_count == N_GF-1 || ((vect_shift_count == N_GF-1-PAD_BITS/N_GF) && (count_row_block == MAT_ROW_SIZE/PROC_SIZE-1))))) begin
                    state <= s_stall_2;
                    if (count == 3) begin
                        count <= 0;
                    end
                    else begin
                        count <= count + 1;
                    end
                end
            end
        end
            
        else if (state == s_stall_2) begin
                state <= s_wait_prng_out;
                count <= count + 1;
                if (big_shift_reg_en || addr_0==MAT_SIZE/PROC_SIZE - 1) begin 
                    if (vect_shift_count == N_GF-1 || ((vect_shift_count == N_GF-1-PAD_BITS/N_GF) && (count_row_block == MAT_ROW_SIZE/PROC_SIZE-1))) begin
                        vect_shift_count <= 0;
                        addr_0 <= addr_0 + 1;
                    end
                    else begin
                        vect_shift_count <= vect_shift_count + 1;
                    end
                end
        end

        else if (state == s_done) begin
            state <= s_wait_start;
            done_int <= 1;
            o_prng_force_done <= 1;
            last_block <=0;
             addr_0 <= 0;
             count <=  0;
        end
       
    end
    if (FIELD == "P251") begin
        if ((byte_next > 250 && shift_in)|| (i_prng_out[31:24] >250 && load_in)) begin
            big_shift_reg_en <= 0;
        end
        else begin
            big_shift_reg_en <= shift_in | load_in;
        end
    end
    else begin
        big_shift_reg_en <= shift_in | load_in;
    end
end




always@(state, i_start, i_prng_out_valid, vect_shift_count, count, count_row_block, big_shift_reg_en, addr_0)
begin

    case(state)
        
    s_wait_start: begin
        load_in <= 0;
        o_prng_out_ready <= 0;
         wren_0 <= 0;
        if (i_start) begin
//            wren_0 <= 0;
            o_start_prng <= 1;
        end
        else begin
            o_start_prng <= 0;
        end
    end

    s_stall_0: begin
        wren_0 <= 0;
        o_start_prng <= 0;
        if (i_prng_out_valid) begin
            load_in <= 1;
            o_prng_out_ready <= 1;
        end
        else begin
            load_in <= 0;
        end
    end

    s_stall_1: begin
        wren_0 <= 0;
        o_start_prng <= 0;
        o_prng_out_ready <= 0;
        load_in <= 0;
        shift_in <= 1;
    end
    

    s_wait_prng_out: begin
        o_start_prng <= 0;
        load_in <= 0;
        shift_in <= 1;
        o_prng_out_ready <= 0;
        if (big_shift_reg_en) begin
            if (vect_shift_count == N_GF-1 || ((vect_shift_count == N_GF-1-PAD_BITS/N_GF) && (count_row_block == MAT_ROW_SIZE/PROC_SIZE-1))) begin
                wren_0 <= 1;
            end
            else begin
                wren_0 <= 0;
            end
        end
        else begin
            wren_0 <= 0;
        end
    end

    s_update_shake_reg: begin
        o_start_prng <= 0;
        shift_in <= 0;
        if (i_prng_out_valid) begin
            load_in <= 1;
            o_prng_out_ready <= 1;
        end
        else begin
            load_in <= 0;
            o_prng_out_ready <= 0;
        end
        if (big_shift_reg_en) begin
            if (vect_shift_count == N_GF-1 || ((vect_shift_count == N_GF-1-PAD_BITS/N_GF) && (count_row_block == MAT_ROW_SIZE/PROC_SIZE-1))) begin
                wren_0 <= 1;
            end
            else begin
                wren_0 <= 0;
            end
        end
        else begin
            wren_0 <= 0;
        end
    end

    s_finish_storage: begin
        o_start_prng <= 0;
        shift_in <= 0;
        load_in <= 0;
        shift_in <= 0;
        o_prng_out_ready <= 0;
        wren_0 <= 1;
    
    end


    s_wait_prng_out_valid: begin
        wren_0 <= 0;
        o_start_prng <= 0;
        if (i_prng_out_valid) begin
            load_in <= 1;
            o_prng_out_ready <= 1;  
        end
        else begin
            load_in <= 0;
            o_prng_out_ready <= 0;
        end
        

    end

    s_stall_2: begin
        o_start_prng <= 0;
        o_prng_out_ready <= 0;
        load_in <= 0;
        shift_in <= 1;
        if (big_shift_reg_en) begin
            if (vect_shift_count == N_GF-1 || ((vect_shift_count == N_GF-1-PAD_BITS/N_GF) && (count_row_block == MAT_ROW_SIZE/PROC_SIZE-1))) begin
                wren_0 <= 1;
            end
            else begin
                wren_0 <= 0;
            end
        end
        else begin
            wren_0 <= 0;
        end
    end
                
     s_done: begin
                wren_0 <= 0;
                o_start_prng <= 0;
                load_in <= 0;
                shift_in <= 0;
                o_prng_out_ready <=0;

    end
     
     default: begin
                wren_0 <= 0;
                o_start_prng <= 0;
                load_in <= 0;
                shift_in <= 0;
                o_prng_out_ready <= 0;
    end
    
    endcase
    
end

endmodule