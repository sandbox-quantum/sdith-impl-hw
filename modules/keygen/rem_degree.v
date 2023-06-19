/*
 * This file is ComputeS which is part of SampleWitness.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module remove_one_degree_factor
#(

    parameter PARAMETER_SET = "L1",
    
                                                    
    parameter M =  (PARAMETER_SET == "L1")? 230:
                        (PARAMETER_SET == "L2")? 352:
                        (PARAMETER_SET == "L3")? 480:
                                                 8,
                                                            
    parameter D =   (PARAMETER_SET == "L1")? 1:
                        (PARAMETER_SET == "L2")? 2:
                        (PARAMETER_SET == "L3")? 2:
                                                 1,
    parameter PAR_MD = M/D, 
    parameter WIDTH = 64    

)(
    input                                   i_clk,
    input                                   i_rst,
    input                                   i_start,
    input   [WIDTH-1:0]                     i_x,
    output  reg [`CLOG2(PAR_MD/WIDTH)-1:0]  o_x_addr,
    output  reg                             o_x_rd,


    output  [WIDTH-1:0]                     o_q,
    input   [`CLOG2(PAR_MD/WIDTH):0]        i_q_addr,
    input                                   i_q_rd,

    output                          o_done
);



reg  wren_0;
reg  wren_1;

wire [8-1:0] q_0, q_1;
reg init;
reg sel;

assign data_0 = 
assign data_1 = 


wire done_mul;
reg start_mul;

wire [7:0] mul_in_1, mul_in_2;
wire [7:0] mul_out;
reg [7:0] mul_out_reg;
reg update_addr_zero;


 
assign q_0 = sel_mem? m0_q_0: m1_q_0;
assign q_1 = sel_mem? m0_q_1: m1_q_1;

assign mul_in_1 = update_addr_zero? mul_out_reg: q_1;
assign mul_in_2 = i_non_zero_pos;

gf_mul #(.REG_IN(0), .REG_OUT(0))
    GF_MULT 
    (
        .clk(i_clk), 
        .start(start_mul), 
        .in_1(mul_in_1), 
        .in_2(mul_in_2),
        .done(done_mul), 
        .out(mul_out) 
    );

// assign mul_out = (mul_in_1 * mul_in_2) % 251;
// assign done_mul = start_mul;


wire [8-1:0] data_0;
wire [8-1:0] data_1;
reg [`CLOG2(DEPTH_OF_Q):0] m0_addr_0; 
reg [`CLOG2(DEPTH_OF_Q):0] m0_addr_1; 
wire m0_wren_0, m0_wren_1;
wire [8-1:0] m0_q_0;
wire [8-1:0] m0_q_1;
wire sel_mem;



assign m0_wren_0 = wren_0;
assign m0_wren_1 = wren_1;

mem_dual #(.WIDTH(WIDTH), .DEPTH(PAR_MD/WIDTH), .FILE("zero.mem"))
RESULT_MEM_0 
(
  .clock(i_clk),
  .data_0(data_0),
  .data_1(data_1),
  .address_0(m0_addr_0),
  .address_1(m0_addr_1),
  .wren_0(m0_wren_0),
  .wren_1(m0_wren_1),
  .q_0(m0_q_0),
  .q_1(m0_q_1)

);


parameter s_wait_start      = 0;
parameter s_init            = 1;


reg [3:0] state = 0;



reg done_int;
always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;

    end
    else begin
        if (state == s_wait_start) begin

        end


    end
end

always@(state, i_start, addr_i, addr_j)
begin

    case(state)
        
    s_wait_start: begin
       
    end
    


     
     default: begin

    end
    
    endcase
    
end

endmodule