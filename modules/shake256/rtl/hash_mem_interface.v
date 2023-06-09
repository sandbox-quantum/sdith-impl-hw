`timescale 1ns / 1ps

/*
 * 
 * Copyright (C): 2023
 * Author:        Sanjay Deshpande
 * Updated:       
 *          
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
*/

module hash_mem_interface
#(
    parameter PARAMETER_SET = "L1",
    parameter SHAKE256 = (PARAMETER_SET == "L1")? 1'b0 : 1'b1,
    parameter IO_WIDTH = 32,
    parameter MAX_RAM_DEPTH = 16,
    parameter MAX_MSG_SIZE = 8_388_608 //in bits, e.g., 1 MB= 8388608 bits
)
(
                input     wire                                                clk,
                input     wire                                                rst,
                  
                //ports for RAM connected to SHAKE256
                input     wire [IO_WIDTH-1:0]                                 i_data_in,
                output    wire [`CLOG2(MAX_RAM_DEPTH) -1:0]                   o_addr,

                output    reg                                                 o_rd_en,

                output    wire [IO_WIDTH-1:0]                                 o_data_out,
                output    wire                                                o_data_out_valid,
                input     wire                                                i_data_out_ready,

                input     wire  [IO_WIDTH-1:0]                                i_input_length, // in bits
                input     wire  [IO_WIDTH-1:0]                                i_output_length, // in bits

                
                input     wire                                                i_start,
                output    wire                                                o_done
                  
    );    
    

 reg shake_din_valid; 
 wire shake_din_ready;
 wire [IO_WIDTH-1:0] shake_din;
 wire shake_dout_ready;
 wire [IO_WIDTH-1:0] shake_dout_scram;
 wire shake_dout_valid;

 reg [IO_WIDTH-1:0] input_length;
 reg [IO_WIDTH-1:0] input_length_reg;
 reg [IO_WIDTH-1:0] first_block;
 reg [1:0] sel_din;

wire [IO_WIDTH-1:0] data_in_le;

//input data
genvar i;
generate
    for (i=0; i< IO_WIDTH/8; i = i+1) begin
        assign data_in_le[8+8*i-1 : 8*i] = i_data_in[IO_WIDTH-8*i-1:IO_WIDTH-8*i-8];
    end
endgenerate

//output data
genvar j;
generate
    for (j=0; j< IO_WIDTH/8; j = j+1) begin
        assign o_data_out[8+8*j-1 : 8*j] = shake_dout_scram[IO_WIDTH-8*j-1:IO_WIDTH-8*j-8];
    end
endgenerate

 assign o_addr = h_addr[`CLOG2(MAX_RAM_DEPTH)-1:0];


 assign shake_din = (sel_din == 1)? first_block:
                    (sel_din == 2)? 1088: //second_block
                    (sel_din == 3)? 32'h80000000 | input_length_reg:
                                    data_in_le;

//  assign shake_dout_ready = i_data_out_ready;

 assign o_data_out_valid = shake_dout_valid;
 assign shake_dout_ready = i_data_out_ready;

 keccak_top
    SHAKE_128_256(
    .clk(clk),
    .rst(rst),
    .din_valid(shake_din_valid),
    .din_ready(shake_din_ready),
    .din(shake_din),
    .dout_valid(shake_dout_valid),
    .dout_ready(shake_dout_ready),
    .dout(shake_dout_scram),
    .force_done(0)
    );

 reg [2:0] h_state              =   0;
 parameter h_wait_start         =   0;
 parameter h_check_shake_ready  =   1;
 parameter h_first_block        =   2;
 parameter h_second_block       =   3;
 parameter h_load_shake         =   4;
 parameter h_load_interm        =   5;
 parameter h_stall              =   6;

reg [`CLOG2(MAX_RAM_DEPTH)-1:0] count_hash_input;
reg done_hash_load;
reg [`CLOG2(MAX_MSG_SIZE)-1:0] h_addr;


always@(posedge clk)
begin
    if (rst) begin
        h_state <= h_wait_start;
        done_hash_load <= 1'b0;
        h_addr <= 0;
        count_hash_input <= 0;
    end
    else begin
        if (h_state == h_wait_start) begin
            h_addr <= 0;
            done_hash_load <= 1'b0;
            if (i_start) begin
				h_state <= h_check_shake_ready;
                if (SHAKE256) begin
                    first_block <= 32'h40000000 + i_output_length;
                end
                else begin
                     first_block <= 32'h00000000 + i_output_length;
                end
                input_length_reg <= i_input_length;  
                input_length <= i_input_length;  
			end
        end
        
        else if (h_state == h_check_shake_ready) begin
            if (shake_din_ready) begin
                    h_state <= h_first_block;
            end
        end
        
        else if (h_state == h_first_block) begin
            h_state <= h_second_block;
            done_hash_load <= 1'b0;
	    end
	    
	    else if (h_state == h_second_block) begin
            done_hash_load <= 1'b0;
                h_state <= h_load_shake;
                h_addr <= h_addr + 1;
                count_hash_input <= count_hash_input + 1;
	    end  
		
		else if (h_state == h_load_shake) begin          
                if ((h_addr == input_length[IO_WIDTH-1:`CLOG2(IO_WIDTH)] - 1) && (input_length <= 1088)) begin
                    h_addr <= 0;
                    count_hash_input <= 0;
                    h_state <= h_stall;
                    done_hash_load <= 1'b1;
                end
                else if (((h_addr == input_length[IO_WIDTH-1:`CLOG2(IO_WIDTH)] + 1) && (input_length > 1088))) begin
                    h_addr <= 0;
                    count_hash_input <= 0;
                    h_state <= h_wait_start;
                    done_hash_load <= 1'b1;
                end
                else if (count_hash_input == 1088/IO_WIDTH) begin
                        if (shake_din_ready) begin
                            h_state <= h_load_interm;
                            count_hash_input <= 0;
                            input_length_reg <= input_length_reg - 1088;
                        end
                end
                else begin
                    done_hash_load <= 1'b0;
                    if (shake_din_ready) begin
                        h_state <= h_load_shake;
                        h_addr <= h_addr+1;
                        count_hash_input <= count_hash_input + 1; 
                    end
                end
	    end
	    
	    else if (h_state == h_load_interm) begin
	        if (shake_din_ready) begin
                    h_state <= h_load_shake;
                    h_addr <= h_addr+1;
                    count_hash_input <= count_hash_input + 1;
            end
	    end
	    
	     else if (h_state == h_stall) begin
	        if (shake_din_ready) begin
                h_state <= h_wait_start;
            end
	    end
			
    end 
end


always@(h_state, i_start, shake_din_ready, input_length_reg, count_hash_input, h_addr, input_length) 
begin
    case (h_state)
     h_wait_start: 
     begin
        shake_din_valid <= 1'b0;
        if (i_start) begin
            sel_din <= 1; 
            o_rd_en <= 0;
        end
        else begin
            sel_din <= 0;
            o_rd_en <= 0;
        end
     end
     
     h_check_shake_ready:
     begin
            o_rd_en <= 1;  
     end

      h_first_block:
     begin
        if (shake_din_ready) begin
           shake_din_valid <= 1'b1;
           sel_din <= 1;
       end
       else begin
           shake_din_valid <= 1'b0;
           sel_din <= 0;
       end

        o_rd_en <= 1;
        
     end
     
     h_second_block:
     begin
        if (shake_din_ready) begin
           shake_din_valid <= 1'b1;
           if (input_length_reg > 1088) begin
               sel_din <= 2;
           end
           else begin
                sel_din <= 3;
            end
       end
       else begin
           shake_din_valid <= 1'b0;
           sel_din <= 0;
       end

        o_rd_en <= 1;
     end
     
     h_load_shake:
     begin
        sel_din <= 0;
        if (shake_din_ready) begin
            shake_din_valid <= 1'b1;
        end
        else begin
            shake_din_valid <= 1'b0;
        end
        o_rd_en <= 1;        
     end
   
    h_load_interm:
    begin
        if (shake_din_ready) begin
           shake_din_valid <= 1'b1;
            if (input_length_reg < 1088) begin
                sel_din <= 3;
            end
            else begin
                sel_din <= 2;
            end
       end
       else begin
           shake_din_valid <= 1'b0;
       end

       if (shake_din_ready) begin
            o_rd_en <= 1;
        end
    end
    
    h_stall:
     begin
        sel_din <= 0;
        o_rd_en <= 0;
        if (shake_din_ready) begin
        shake_din_valid <= 1'b1;
        end
        else begin
            shake_din_valid <= 1'b0;
        end
     end
        
	  default: 
	  begin
	    shake_din_valid <= 1'b0;
        sel_din <= 0;
        o_rd_en <= 0;
	  end         
      
    endcase

end 
 
    
    
endmodule
