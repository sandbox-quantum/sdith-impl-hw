/*
 * This file is the  Vector Addition module.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/



module vec_add
#(

    parameter PARAMETER_SET = "L1",
    parameter MAT_ROW_SIZE_BYTES = (PARAMETER_SET == "L1")? 104:
                                   (PARAMETER_SET == "L3")? 159:
                                   (PARAMETER_SET == "L5")? 202:
                                                            8,

    parameter M =   (PARAMETER_SET == "L1")? 230:
                    (PARAMETER_SET == "L3")? 352:
                    (PARAMETER_SET == "L5")? 480:
                                             230,

    parameter MAT_ROW_SIZE = MAT_ROW_SIZE_BYTES*8,

    
    parameter S_START_ADDR = (PARAMETER_SET == "L1")? 126:
                            (PARAMETER_SET == "L3")? 120:
                            (PARAMETER_SET == "L5")? 150:
                                                     3,
    
    parameter N_GF = 8, 
    
    parameter PROC_SIZE = N_GF*8,
    parameter PAD_BITS = (PROC_SIZE - MAT_ROW_SIZE%PROC_SIZE)%PROC_SIZE
    
    
)(
    input i_clk,
    input i_rst,
    input i_start,
   
    output reg [`CLOG2(MAT_ROW_SIZE/PROC_SIZE)-1:0] o_vec_addr,
    input [PROC_SIZE-1:0] i_vec,
    
    output reg [`CLOG2(M)-1:0] o_s_addr,
    input  [8-1:0] i_s,

    output reg o_vec_s_rd,

    output  reg o_res_wr_en,
    output [PROC_SIZE-1:0] o_res,
    output reg [`CLOG2(MAT_ROW_SIZE/PROC_SIZE)-1:0] o_res_addr,
    output o_done

);

reg [PROC_SIZE-1:0] s_vec; 
reg init;
reg shift;

assign o_done = done_int;

always@(posedge i_clk) begin
    if (init) begin
        s_vec <= {{(PROC_SIZE-8){1'b0}},i_s}; 
    end 
    else if (shift) begin 
        s_vec <= {s_vec[PROC_SIZE-1-8:0],i_s};
    end 
end

always@(posedge i_clk) begin
    o_res_addr <= o_vec_addr;
end

wire [PROC_SIZE-1:0] s_vec_mux;

assign s_vec_mux = (o_res_addr == MAT_ROW_SIZE/PROC_SIZE)? {s_vec[PROC_SIZE-PAD_BITS-1:0],{(PAD_BITS){1'b0}}} : s_vec;

// assign o_res = (o_res_addr == MAT_ROW_SIZE/PROC_SIZE)? i_vec ^ {s_vec[PROC_SIZE-PAD_BITS-1:0],{(PAD_BITS){1'b0}}} :i_vec ^ s_vec;
assign o_res = i_vec ^ s_vec_mux;

parameter s_wait_start      = 0;
parameter s_stall_0         = 1;
parameter s_load_s          = 2;
parameter s_stall_1         = 3;
parameter s_done            = 4;

reg [2:0] state = 0;
reg [7:0] count;
reg done_int;
always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        o_vec_addr <= 0;
        o_s_addr <= S_START_ADDR;
        done_int <= 0;
        count <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            
            count <= 0;
            o_vec_addr <= 0;
            o_s_addr <= S_START_ADDR;
            done_int <= 0;
            if (i_start) begin
                state <= s_stall_0;
                done_int <= 0;
            end
        end

        else if (state == s_stall_0) begin
            done_int <= 0;
            // count <= count + 1;
            state <= s_load_s;
            o_s_addr <= o_s_addr + 1;
        end

        else if (state == s_load_s) begin
            if (o_s_addr == M) begin
                o_s_addr <= S_START_ADDR;
                state <= s_stall_1;
                o_vec_addr <= 0;
            end
            else begin
                if (count == N_GF-1) begin
                    // state <= s_load_new_vec;
                    count <= 0;
                    o_vec_addr <= o_vec_addr+1;
                    o_s_addr <= o_s_addr + 1;
                end
                else begin
                    o_s_addr <= o_s_addr + 1; 
                    count <= count + 1;
                end
            end
        end
        
        else if (state == s_stall_1) begin
            state <= s_done;
        end

        else if (state == s_done) begin
            state <= s_wait_start;
            done_int <= 1;
        end
       
    end
end

always@(state, i_start, o_vec_addr, count)
begin

    case(state)
        
    s_wait_start: begin
        init <= 0;
        shift <= 0;
        o_res_wr_en <= 0;
        if (i_start) begin
            o_vec_s_rd <= 1;
        end
        else begin
            o_vec_s_rd <= 0;
        end
    end
    

    s_stall_0: begin
        init <= 0;
        shift <= 0;
        o_res_wr_en <= 0;
        o_vec_s_rd <= 1;
    end      

    s_load_s: begin
        o_vec_s_rd <= 1;
        
        if (count == 0) begin 
            init <= 1;
            shift <= 0;   
        end
        else begin
            init <= 0;
            shift <= 1;
        end

        if (o_vec_addr > 0 && count == 0) begin
            o_res_wr_en <= 1;
        end
        else begin
            o_res_wr_en <= 0;
        end
    end 

    s_stall_1: begin
        init <= 0;
        shift <= 0;
        o_res_wr_en <= 1;
        o_vec_s_rd <= 1;
    end 

     s_done: begin
        init <= 0;
        shift <= 0;
        o_res_wr_en <= 0;
        o_vec_s_rd <= 0;
    end
     
     default: begin
        init <= 0;
        shift <= 0;
        o_res_wr_en <= 0;
        o_vec_s_rd <= 0;
    end
    
    endcase
    
end

endmodule