/*
 * This file is the H matrix generation.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module gen_H
#(

    parameter PARAMETER_SET = "L3",
    
    parameter SEED_SIZE =   (PARAMETER_SET == "L1")? 128:256,
                                                    
    parameter MAT_ROW_SIZE_BYTES = (PARAMETER_SET == "L1")? 104:
                                   (PARAMETER_SET == "L2")? 159:
                                   (PARAMETER_SET == "L3")? 202:
                                                            8,
                                                            
    parameter MAT_COL_SIZE_BYTES  =(PARAMETER_SET == "L1")? 126:
                                   (PARAMETER_SET == "L2")? 193:
                                   (PARAMETER_SET == "L3")? 278:
                                                            8,

    parameter MAT_SIZE_BYTES = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES,
    
    
    parameter MAT_ROW_SIZE = MAT_ROW_SIZE_BYTES*8,
    parameter MAT_COL_SIZE = MAT_COL_SIZE_BYTES*8,

    parameter N_GF = 8, 
    
    parameter MAT_SIZE = MAT_ROW_SIZE_BYTES*MAT_COL_SIZE_BYTES*8,
    parameter PROC_SIZE = N_GF*8,
    
    parameter COL_SIZE_MEM = MAT_COL_SIZE_BYTES/N_GF,
    parameter ROW_SIZE_MEM = MAT_ROW_SIZE_BYTES/N_GF
    
    
)(
    input               i_clk,
    input               i_rst,
    input               i_start,

    input   [31:0]      i_seed_h,
    input   [`CLOG2(SEED_SIZE/32)-1:0]       i_seed_h_addr,
    input               i_seed_wr_en,
    output              o_start_h_proc,

    output  [31:0]     o_seed_h_prng,

    output   reg        o_start_prng,

    input   [31:0]      i_prng_out,
    input               i_prng_out_valid,
    output   reg        o_prng_out_ready,
    
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
reg [PROC_SIZE-1:0] data_shift_reg;

wire [PROC_SIZE-1:0] q_0, q_1;

generate 
    if(PROC_SIZE > 32) begin

        always@(posedge i_clk) begin
            if (i_prng_out_valid == 1) begin
                if (count == 0) begin
                    data_shift_reg <= {{(PROC_SIZE-32){1'b0}},i_prng_out};
                end
                else begin
                    data_shift_reg <= {data_shift_reg[PROC_SIZE-1-32:0],i_prng_out};
                end
            end
            wren_0_reg <= wren_0;
            addr_0_reg <= addr_0;
        end
        assign data_0 = data_shift_reg;
    end
    else if (PROC_SIZE == 32) begin        
        always@(wren_0, i_prng_out, addr_0, data_shift_reg )
        begin
            data_shift_reg <= i_prng_out;
            wren_0_reg <= wren_0;
            addr_0_reg <= addr_0;
        end
    end
endgenerate


assign data_0 = data_shift_reg; 
assign o_h_out = q_1;
assign wren_1 = 0;
assign addr_1 = i_h_out_addr;

mem_dual #(.WIDTH(PROC_SIZE), .DEPTH(MAT_SIZE/PROC_SIZE))
RESULT_MEM 
(
  .clock(i_clk),
  .data_0(data_0),
  .data_1(0),
  .address_0(addr_0_reg),
  .address_1(addr_1),
  .wren_0(wren_0_reg),
  .wren_1(wren_1),
  .q_0(q_0),
  .q_1(q_1)

);




mem_single #(.WIDTH(32), .DEPTH(SEED_SIZE/32), .FILE("zero.mem"))
SEED_MEM 
(
  .clock(i_clk),
  .data(i_seed_h),
  .address(i_seed_h_addr),
  .wr_en(i_seed_wr_en),
  .q(o_seed_h_prng)
);


parameter s_wait_start      = 0;
parameter s_wr_seed_to_hproc   = 1;
parameter s_wait_prng_out    = 2;
parameter s_done            = 3;

reg [2:0] state = 0;
reg [7:0] vect_shift_count;
reg [`CLOG2(PROC_SIZE/32):0] count;
reg done_int;
always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        addr_0 <= 0;
        count <= 0;
        o_prng_out_ready <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            count <= 0;
            addr_0 <= 0;
            o_prng_out_ready <= 0;
            if (i_start) begin
                state <= s_wait_prng_out;
                done_int <= 0;
            end
            else begin
                done_int <= 0;
            end
        end


        else if (state == s_wait_prng_out) begin
            done_int <= 0;
            if (addr_0 == MAT_SIZE/PROC_SIZE) begin
               state <= s_done; 
               count <= 0;
               addr_0 <= 0;
               o_prng_out_ready <= 0;
            end
            else begin
                 o_prng_out_ready <= 1;
                if (i_prng_out_valid) begin
                    if (count == PROC_SIZE/32 - 1) begin
                        count <= 0;
                        addr_0 <= addr_0 + 1;
                    end
                    else begin
                        count <= count + 1;
                    end
                end      
            end
        end
            
          
        else if (state == s_done) begin
            state <= s_wait_start;
            done_int <= 1;
        end
       
    end
end

always@(state, i_start, i_prng_out_valid, count)
begin

    case(state)
        
    s_wait_start: begin
        if (i_start) begin
            wren_0 <= 0;
            o_start_prng <= 1;
        end
        else begin
            o_start_prng <= 0;
        end
    end
    

    s_wait_prng_out: begin
        o_start_prng <= 0;
       if (PROC_SIZE != 32) begin
            if (i_prng_out_valid == 1 && count == PROC_SIZE/32 - 1) begin
                wren_0 <= 1;
            end
            else begin
                wren_0 <= 0;
            end
       end
       else  begin
            if (i_prng_out_valid == 1) begin
                wren_0 <= 1;
            end
            else begin
                wren_0 <= 0;
            end
       end
    end
                
     s_done: begin
                wren_0 <= 0;
                o_start_prng <= 0;
    end
     
     default: begin
                wren_0 <= 0;
                o_start_prng <= 0;
    end
    
    endcase
    
end

endmodule