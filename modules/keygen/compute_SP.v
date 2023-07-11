/*
 * This file is ComputeS which is part of SampleWitness.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module compute_SP
#(

    parameter PARAMETER_SET = "L1",
    
    parameter TYPE = "P",
                                                    
    parameter M  =  (PARAMETER_SET == "L1")? 230:
                    (PARAMETER_SET == "L3")? 352:
                    (PARAMETER_SET == "L5")? 480:
                                             8,

    parameter WEIGHT =  (PARAMETER_SET == "L1")? 79:
                        (PARAMETER_SET == "L3")? 120:
                        (PARAMETER_SET == "L5")? 150:
                                                    8,
                                                            
    parameter D =   (PARAMETER_SET == "L1")? 1:
                    (PARAMETER_SET == "L3")? 2:
                    (PARAMETER_SET == "L5")? 2:
                                            1,
                                            
    parameter DEPTH_Q_FP = (TYPE == "S")? M/D : WEIGHT/D 


)(
    input                                   i_clk,
    input                                   i_rst,
    input                                   i_start,
    
    input   [8-1:0]                         i_x,
    output  [`CLOG2(M/D)-1:0]         o_x_addr,
    output  reg                             o_x_rd,

    input   [8-1:0]                         i_q_fp,
    output  [`CLOG2(DEPTH_Q_FP+1)-1:0]  o_q_fp_addr,
    output  reg                             o_q_fp_rd,


    output  [8-1:0]                     o_sp,
    input   [`CLOG2(WEIGHT+1):0]       i_sp_addr,
    input                              i_sp_rd,
    

    output    reg                     o_done
);



reg  wren_0;
reg  wren_1;

wire [8-1:0] q_0, q_1;
reg init;
reg sel;

// assign data_0 = 
// assign data_1 = 


wire done_mul;
reg start_mul;


reg [7:0] mul_out_reg;
reg update_addr_zero;


 
wire [`CLOG2(M)-1:0] lj_addr;
wire [8-1:0] lj_for_s;

// assign lj_addr = i;
// assign o_x_addr = i;

assign lj_addr = i_reg;
assign o_x_addr = i_reg;

parameter FILE_lj = (PARAMETER_SET == "L1")? "leading_coefficients_of_lj_for_S_L1.mem":
                    (PARAMETER_SET == "L3")? "leading_coefficients_of_lj_for_S_L3.mem":
                    (PARAMETER_SET == "L5")? "leading_coefficients_of_lj_for_S_L5.mem":
                                             "leading_coefficients_of_lj_for_S_L1.mem";

mem_single #(.WIDTH(8), .DEPTH(M/D), .FILE(FILE_lj))
LJ_MEM 
(
  .clock(i_clk),
  .data(0),
  .address(lj_addr),
  .wr_en(0),
  .q(lj_for_s)

);

wire [7:0] scalar;
// reg [7:0] scalar_reg;
wire done_scalar;

// compute scalar
gf_mul #(.REG_IN(0), .REG_OUT(1))
    SCALAR_GEN
    (
        .clk(i_clk), 
        .start(1), 
        .in_1(lj_for_s), 
        .in_2(i_x),
        .done(), 
        .out(scalar) 
    );


// reg [`CLOG2(M+1)-1:0] f_poly_addr, f_poly_addr_reg;
reg [`CLOG2(DEPTH_Q_FP +1)-1:0] f_poly_addr;
wire [8-1:0] f_poly;

assign o_q_fp_addr = f_poly_addr; 
assign f_poly = i_q_fp;


// mem_single #(.WIDTH(8), .DEPTH(M+1), .FILE("f_poly_L1.mem"))
// F_POLY_MEM 
// (
//   .clock(i_clk),
//   .data(0),
//   .address(f_poly_addr),
//   .wr_en(0),
//   .q(f_poly)

// );


wire [`CLOG2(M/D)-1:0] i_reg;
pipeline_reg_gen #(.WIDTH(`CLOG2(M/D)), .REG_STAGES(1))
I_REG_STAGE
(
    .i_clk(i_clk),
    .i_data_in(i),
    .o_data_out(i_reg)
   );

wire [8-1:0] ts_mul_in_1, ts_mul_in_2;
wire [8-1:0] ts_mul_out;
reg start_ts_mul;
wire done_ts_mul;
wire done_ts_mul_reg;
reg first;  
assign  ts_mul_in_1 = (first)? 1 : temp_ts;
assign  ts_mul_in_2 = i_reg;


gf_mul #(.REG_IN(0), .REG_OUT(1))
    REM_ONE_DEG_F_POLY
    (
        .clk(i_clk), 
        .start(start_ts_mul), 
        .in_1(ts_mul_in_1), 
        .in_2(ts_mul_in_2),
        .done(done_ts_mul), 
        .out(ts_mul_out) 
    );

wire [7:0] temp_ts;
wire [7:0] temp_ts_reg;
// reg [7:0] temp_ts_reg;
// reg [7:0] temp_ts_reg_reg;
// reg first_reg, first_reg_reg;
wire first_reg, first_reg_reg;
assign temp_ts = ts_mul_out ^ f_poly;

pipeline_reg_gen #(.WIDTH(1), .REG_STAGES(2))
FIRST_REG_STAGE
(
    .i_clk(i_clk),
    .i_data_in(first),
    .o_data_out(first_reg)
   );

pipeline_reg_gen #(.WIDTH(8), .REG_STAGES(2))
TEMP_TS_REG_STAGE
(
    .i_clk(i_clk),
    .i_data_in(temp_ts),
    .o_data_out(temp_ts_reg)
   );



wire [`CLOG2(DEPTH_Q_FP + 1)-1:0] f_poly_addr_reg;

pipeline_reg_gen #(.WIDTH(`CLOG2(M)), .REG_STAGES(2))
F_POLY_ADDR_REG_STAGE
(
    .i_clk(i_clk),
    .i_data_in(f_poly_addr),
    .o_data_out(f_poly_addr_reg)
   );

always@(posedge i_clk) begin
    s_addr_0 <= f_poly_addr_reg;
end

pipeline_reg_gen #(.WIDTH(1), .REG_STAGES(1))
DONE_TS_MUL_REG_STAGE
(
    .i_clk(i_clk),
    .i_data_in(done_ts_mul),
    .o_data_out(done_ts_mul_reg)
   );

wire [7:0] s_mul_temp_ts;
wire done_s_mul_ts;

gf_mul #(.REG_IN(0), .REG_OUT(1))
    TEMP_GF_MULT_S
    (
        .clk(i_clk), 
        .start(done_ts_mul_reg), 
        .in_1(scalar), 
        // .in_2(first_reg_reg? 1 : temp_ts_reg_reg),
        .in_2(first_reg? 1 : temp_ts_reg),
        .done(done_s_mul_ts), 
        .out(s_mul_temp_ts) 
    );

reg [`CLOG2(DEPTH_Q_FP + 1)-1:0] s_addr_0;
wire [`CLOG2(DEPTH_Q_FP + 1)-1:0] s_addr_1;
wire [7:0] s_data_0, s_data_1;
wire [7:0] s_q_0, s_q_1;
wire s_wren_0, s_wren_1;

assign s_data_0 = s_mul_temp_ts ^ s_q_1;
assign s_wren_0 = done_s_mul_ts;
assign s_addr_1 = i_sp_rd? i_sp_addr: f_poly_addr_reg;

mem_dual #(.WIDTH(8), .DEPTH(DEPTH_Q_FP), .FILE("zero.mem"))
S_MEM 
(
  .clock(i_clk),
  .data_0(s_data_0),
  .data_1(0),
  .address_0(s_addr_0),
  .address_1(s_addr_1),
  .wren_0(s_wren_0),
  .wren_1(0),
  .q_0(s_q_0),
  .q_1(s_q_1)

);

assign o_sp = s_q_1;

parameter s_wait_start      = 0;
parameter s_check_i         = 1;
// parameter s_stall_0         = 2;
parameter s_load            = 3;
parameter s_done            = 4;


reg [3:0] state = 0;
reg [`CLOG2(M/D)-1:0] i = 0;


reg done_int;
always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        f_poly_addr <= 0;
        o_done <= 0;
        i <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            o_done <=0;
            
            i <= 0;
            if(i_start) begin
                state <= s_load;
                f_poly_addr <=  f_poly_addr - 1;
            end
            else begin
                f_poly_addr <= DEPTH_Q_FP - 1;
            end
        end

        else if (state == s_check_i) begin
            if (i == M/D) begin
                i <= 0;
                state <= s_done;
            end
            else begin
                // i <= i+1;
                // state <= s_stall_0;
                state <= s_load;
                f_poly_addr <=  f_poly_addr - 1;
            end
        end
        
        // else if (state == s_stall_0) begin
        //         if (i == M/D) begin
        //             state <= s_done;
        //         end
        //         else begin
        //             state <= s_check_i;
        //         end
        // end

        else if (state == s_load) begin
            if (f_poly_addr == 0) begin
                f_poly_addr <= DEPTH_Q_FP - 1;
                // state <= s_stall_0;
                state <= s_check_i;
                // i <= i+1;
            end
            else begin
                f_poly_addr <= f_poly_addr - 1;
                // state <= s_stall_0;
                if (f_poly_addr == 1) begin
                    i <= i+1;
                end
            end
        end

        else if (state == s_done) begin
            state <= s_wait_start;
            o_done <= 1;
        end


    end
end

always@(state, i_start, f_poly_addr, i)
begin

    case(state)
        
    s_wait_start: begin
        if (i_start) begin
            first <= 1;
            o_x_rd <= 1;
            o_q_fp_rd <= 1;
            start_ts_mul <= 1;
        end 
        else begin
            o_x_rd <= 0;
            o_q_fp_rd <= 0;
            first <= 0;
            start_ts_mul <= 0;
        end
       
    end

    // s_stall_0: begin
    //     // if (i <= 1) begin
    //     //     first <= 1;
    //     //     o_x_rd <= 1;
    //     //     start_ts_mul <= 1;
    //     // end
    //     // else begin
    //         first <= 0;
    //         o_x_rd <= 0;
    //         start_ts_mul <= 0;
    //         o_q_fp_rd <= 1;
    //     // end
    // end
    
    s_check_i: begin
        o_q_fp_rd <= 1;
        if (i <= M/D - 1) begin
            first <= 1;
            o_x_rd <= 1;
            start_ts_mul <= 1;
        end
        else begin
            first <= 0;
            o_x_rd <= 0;
            start_ts_mul <= 0;
        end
    end

    s_load: begin
        o_q_fp_rd <= 1;
        first <= 0;
        o_x_rd <= 1;
        if (f_poly_addr >= 0) begin
            start_ts_mul <= 1;
        end
        else begin
            start_ts_mul <= 0;
        end
    end

    s_done: begin
        o_q_fp_rd <= 1;
        first <= 0;
        o_x_rd <= 1;
        start_ts_mul <= 0;
    end


     
     default: begin
        first <= 0;
        o_x_rd <= 0;
        start_ts_mul <= 0;
        o_q_fp_rd <= 0;
    end
    
    endcase
    
end

endmodule