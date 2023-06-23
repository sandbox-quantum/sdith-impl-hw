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
                        (PARAMETER_SET == "L2")? 120:
                        (PARAMETER_SET == "L3")? 150:
                                                 8,
    
    parameter M =   (PARAMETER_SET == "L1")? 230:
                        (PARAMETER_SET == "L2")? 352:
                        (PARAMETER_SET == "L3")? 480:
                                                 32,

    parameter D =   (PARAMETER_SET == "L1")? 1:
                    (PARAMETER_SET == "L2")? 2:
                    (PARAMETER_SET == "L3")? 2:
                                             1,

    parameter WIDTH = M/D,
        
    parameter LOG_WEIGHT   = `CLOG2(WEIGHT)
    
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
    input [`CLOG2(WEIGHT)-1:0] i_non_zero_pos_addr,

    output [7:0] o_non_zero_pos_x,
    input i_non_zero_pos_rd_x,
    input [`CLOG2(WEIGHT)-1:0] i_non_zero_pos_addr_x,

    output reg o_done

    );
    
wire [WIDTH-1:0] gen_one;

reg [7:0] pos_int;
reg pos_valid_reg;

//========Threshold Value (M) Check and Filter============
always@(posedge i_clk) begin
    if (i_pos_valid) begin
        if (i_pos < M) begin
            pos_int <= i_pos;
            pos_valid_reg <= 1;
        end
        
    end
    else begin
        pos_int <=0;
        pos_valid_reg <= 0;
    end
end
//========================================================


//==================Duplicate Detection===================
genvar i;
generate
for (i = 0; i < WIDTH; i=i+1) begin:vector_gen
    assign gen_one[i] = (i == pos_int) ? 1'b1 : 1'b0; 
end
endgenerate

reg duplicate;
reg [7:0] pos_reg;
reg valid_reg;

always@(posedge i_clk) 
begin
    if (pos_valid_reg) begin
        duplicate <= (map == (map | gen_one));
        pos_reg <= pos_int;
    end
    valid_reg <= pos_valid_reg;
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

reg [`CLOG2(WEIGHT):0] count;

always@(posedge i_clk) 
begin
    // if (i_start || count == WEIGHT) begin
    if (i_rst) begin
        count <= 0;
    end
    else if (i_start || o_done) begin
        count <= 0;
    end
    else if ((count < WEIGHT) && (valid_reg) && (~duplicate)) begin
        count <= count + 1;
    end
end

always@(posedge i_clk) 
begin
    if (i_rst) begin
        o_pos_rd <= 0;
    end
    else begin
        if (count == WEIGHT-2 && duplicate == 0) begin
            o_pos_rd <= 0;
        end
        else if (i_start) begin
            o_pos_rd <= 1;
        end  
    end
end

always@(posedge i_clk) 
begin
    if (o_done) begin
        o_done <= 0;
    end
    else if (count == WEIGHT-1) begin
        o_done <= 1;
    end
    else begin
        o_done <= 0;
    end
end

wire wr_en;

assign wr_en = valid_reg && ~duplicate;

// mem_single #(.WIDTH(8), .DEPTH(WEIGHT))  
//     POS_REG(
//     .clock(i_clk),
//     .data(pos_reg),
//     .address(i_non_zero_pos_rd? i_non_zero_pos_addr: count[`CLOG2(WEIGHT)-1:0]),
//     .wr_en(wr_en),
//     .q(o_non_zero_pos)
//     );

mem_dual #(.WIDTH(8), .DEPTH(WEIGHT))  
    POS_REG(
    .clock(i_clk),
    .data_0(pos_reg),
    .data_1(0),
    .address_0(i_non_zero_pos_rd? i_non_zero_pos_addr: count[`CLOG2(WEIGHT)-1:0]),
    .address_1(i_non_zero_pos_rd_x? i_non_zero_pos_addr_x: 0),
    .wren_0(wr_en),
    .wren_1(0),
    .q_0(o_non_zero_pos),
    .q_1(o_non_zero_pos_x)
    );

//========================================================

//   always@(posedge clk)
//   begin
//     gen_one_reg = gen_one;
//   end 
  
//   assign data_0 = 0;
  
//   assign decode_addr = location/WIDTH;
  
//   reg collision_s;
  
 //collision detection
//  always@(posedge clk)
//  begin
//     if (init|start) begin
//         collision_s = 1'b0;
//     end
//     else if (wren_1) begin
//         if (q_0 == data_1) begin
//             collision_s = 1'b1;
//         end
//     end
//  end 

// assign collision = collision_s;

//   assign data_1 = (q_0 | gen_one_reg_rev); 
  
  
//   genvar j;
//   generate
//     for (j = 0; j < WIDTH; j=j+1) begin:data_inverse
//         assign gen_one_reg_rev[j] = gen_one[WIDTH-j-1]; 
//     end
//   endgenerate
  


//     mem_dual #(.WIDTH(WIDTH), .DEPTH(DEPTH), .FILE(FILE)) mem_dual_A (
//     .clock(clk),
//     .data_0(data_0),
//     .data_1(data_1),
//     .address_0(addr_read),
//     .address_1(addr_1_mux),
//     .wren_0(wren_0),
//     .wren_1(wren_1),
//     .q_0(q_0),
//     .q_1(q_1)
//   );
 

// assign addr_read = reading_out? addr_0: decode_addr;

//assign addr_1_mux = rd_e_1? rd_addr_e_1: addr_1;
// assign addr_1_mux = addr_1;

// assign error_1 = q_1;

 


// always@(posedge clk)
// begin
//     if (rst) begin
// //        state = s_initialize;
//         state <= s_wait_for_init_mem;
//         addr_0 <= 0;
//         count_reg <= 0;
//         addr_1 <= 0;
//         ready_s <= 1'b0;
        
// //        E0_addr_0 <= 0;
// //        E0_addr_1 <= 0;
        
//     end
//     else begin
//         if (state == s_wait_for_init_mem) begin
//             done_s <= 1'b0;
//             valid_s <= 1'b0;
//             done_s <= 1'b0;
//             addr_1 <= 0;
//             addr_0 <= 0;
//             rd_addr <= 0;
//             count_reg <= 0;
//             ready_s <= 1'b0;
            
// //            E0_addr_0 <= 0;
// //            E0_addr_1 <= 0;
            
//             if (init_mem) begin
//                 state <= s_initialize;
//             end
            
//         end
        
//         else if (state == s_initialize) begin
//             valid_s <= 1'b0;
//             done_s <= 1'b0;
//             addr_1 <= 0;
//             addr_0 <= 0;
//             rd_addr <= 0;
//             count_reg <= 0;
//             state <= s_init_done;
//             ready_s <= 1'b0;
            
// //            E0_addr_0 <= 0;
// //            E0_addr_1 <= 0;
//         end 
        
//         else if (state == s_init_done) begin
//             if (addr_0 == DEPTH - 1) begin
//                 addr_0 <= 0;
// //                E0_addr_0 <= 0;
//                 state <= s_wait_start;
//                 ready_s <= 1'b1;
//             end
//             else begin
//                 addr_0 <= addr_0+1;
// //                E0_addr_0 <= E0_addr_0+1;
//                 state <= s_init_done;
//             end
//          end
         
//          else if (state == s_wait_start) begin
//             if (start) begin
//                 ready_s <= 1'b0;
// //                rd_addr <= 0;
//                 if (rd_addr == WEIGHT-1) begin
                    
//                     state <= s_wait_last_2;
//                 end 
//                 else begin
//                     state <= s_load_loc;
//                 end
// //                count_reg <= 0;
//             end
//          end
         
//          else if (state == s_load_loc) begin
//             if (~collision_s) begin       
//                 if (rd_addr == WEIGHT-1) begin
// //                    rd_addr <= 0;
//                     state <= s_wait_last_2;
//                     addr_1 <= decode_addr;
// //                    E0_addr_1 <= E0_decode_addr;
//                     count_reg <= count_reg + 1;
//                 end
//                 else begin
//                     state <= s_stall_for_ram;
//                     rd_addr <= rd_addr + 1;
//                     addr_0 <= decode_addr;
//                     addr_1 <= decode_addr;
                    
// //                    E0_addr_0 <= E0_decode_addr;
// //                    E0_addr_1 <= E0_decode_addr;
                    
//                     count_reg <= count_reg + 1;
//                 end 
//              end
//             else begin 
// //                state <= s_initialize;
//                 state <= s_wait_start;
//                 rd_addr <= rd_addr - 1;
//                 count_reg <= count_reg - 1;
// 				ready_s <= 1'b1;
//             end  
//          end
         
//          else if (state == s_stall_for_ram) begin
//             if (~collision_s) begin  
//                 state <= s_load_loc;
//             end
//             else begin 
// //                state <= s_initialize;
//                 state <= s_wait_start;
//                 rd_addr <= rd_addr - 1;
//                 count_reg <= count_reg - 1;
// 				ready_s <= 1'b1;
//             end
//          end
         
//          else if (state == s_wait_last_2) begin
//             if (~collision_s) begin
//                 if (count_reg == WEIGHT+2-1) begin
//                     count_reg <= 0;
//                     state <= s_done;
//                     addr_0 <= 0;
// //                    E0_addr_0 <= 0;
//                 end
//                 else begin
//                     state <= s_wait_last_2;
//                     count_reg <= count_reg + 1;
//                     addr_1 <= decode_addr;
// //                    E0_addr_1 <= E0_decode_addr;
//                 end
//              end
//             else begin 
// //                state = s_initialize;
//                 state = s_wait_start;
// //                rd_addr <= rd_addr - 1;
//                 count_reg <= count_reg - 1;
// 				ready_s <= 1'b1;
//             end 
//          end 
         
 
         
//          else if (state == s_read_out) begin
//             valid_s <= 1'b1;
//             if (addr_0 == DEPTH-1) begin
//                 state <= s_done;
//                 addr_0 <= 0;
//             end
//             else begin
//                 state <= s_read_out;
//                 addr_0 <= addr_0 + 1;
//             end 
//          end        
              
//         else if (state == s_done) begin
//             done_s <= 1'b1;
//             valid_s <= 1'b0;
//             state <= s_wait_for_init_mem;
//         end
//     end 
  
// end 

// always@(state or addr_0 or count_reg or start)
// begin
//     case (state)
//       s_initialize: begin
//                      wren_0 <= 1'b1;
//                      wren_1 <= 1'b0;
//                      init <= 1'b1;
//                      rd_en <= 1'b0;
//                      reading_out <= 1'b1;
//                     end
      
                   
//       s_init_done: begin 
//                     wren_0 <= 1'b1;
//                     wren_1 <= 1'b0; 
//                     init <= 1'b0;
                    
//                    end  
      
//       s_wait_start: begin
//                         wren_0 <= 1'b0;
//                          wren_1 <= 1'b0;
//                         reading_out <= 1'b0;
//                         if (start) begin
//                             rd_en <= 1'b1;
//                         end
//                         else begin
//                             rd_en <= 1'b0;
//                         end
//                     end  
                    
//       s_load_loc: begin
//                     rd_en <= 1'b1;
//                     wren_1 <= 1'b0;
//                   end 
                  
//       s_stall_for_ram: begin
//                             wren_1 <= 1'b1;
//                        end

                      
//       s_wait_last_2: begin
//                     rd_en <= 1'b0;
//                     if (count_reg < WEIGHT+1) begin
//                         wren_1 <= 1'b1;
//                     end
//                     else begin
//                         wren_1 <= 1'b0;
//                     end
//                   end 

//       s_read_out: begin
//                     wren_1 <= 1'b0;
//                     reading_out <= 1'b1;
//                   end     
                  
//       s_done:      begin 
//                     wren_0 <= 1'b0; 
//                     wren_1 <= 1'b0;
//                     reading_out <= 1'b0;
//                    end     
   
//       default:
//       begin 
//         wren_0 <= 1'b0;
//         wren_1 <= 1'b0;
//         init <= 1'b0;
//         rd_en <= 1'b0;
//         reading_out <= 1'b0;
//       end
//     endcase

// end     
endmodule
