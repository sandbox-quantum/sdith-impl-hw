/*
 * This file is SampleWitness module.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module samplewitness 
#(

    parameter PARAMETER_SET = "L1",
    
    parameter LAMBDA =  (PARAMETER_SET == "L1")? 128:
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

    parameter D =   (PARAMETER_SET == "L1")? 1:
                        (PARAMETER_SET == "L3")? 2:
                        (PARAMETER_SET == "L5")? 2:
                                                 1,
                                    
    parameter FILE_SEED = ""


)(
    input                                   i_clk,
    input                                   i_rst,
    input                                   i_start,

    input   [32-1:0]                        i_seed_wit,
    input   [`CLOG2(LAMBDA/32)-1:0]         i_seed_wit_addr,
    input                                   i_seed_wit_wr_en,


    output  [7:0]                           o_q,
    input   [`CLOG2(WEIGHT/D + 1):0]        i_q_addr,
    input                                   i_q_rd,

    output  [7:0]                           o_s,
    input   [`CLOG2(M)-1:0]                 i_s_addr,
    // input   [`CLOG2(M/D):0]                 i_s_addr,
    input                                   i_s_rd,

    output  [7:0]                           o_p,
    input   [`CLOG2(WEIGHT/D):0]            i_p_addr,
    input                                   i_p_rd,

    `ifdef TWO_SHARES
        output  [7:0]                           o_q_0,
        input   [`CLOG2(WEIGHT/D + 1):0]        i_q_0_addr,
        input                                   i_q_0_rd,

        // output  [7:0]                           o_s_0,
        // input   [`CLOG2(M/D):0]                 i_s_0_addr,
        // input                                   i_s_0_rd,

        output  [7:0]                           o_p_0,
        input   [`CLOG2(WEIGHT/D):0]            i_p_0_addr,
        input                                   i_p_0_rd,

        
    `endif 

    output   reg                            o_done,

    output   [32-1:0]                       o_hash_data_in,
    input    [`CLOG2(LAMBDA/32) -1:0]       i_hash_addr,

    input                                   i_hash_rd_en,

    input    wire [32-1:0]                  i_hash_data_out,
    input    wire                           i_hash_data_out_valid,
    output   wire                           o_hash_data_out_ready,

    output   wire  [32-1:0]                 o_hash_input_length, // in bits
    output   wire  [32-1:0]                 o_hash_output_length, // in bits

    output   wire                           o_hash_start,
    output   wire                           o_hash_force_done
);



wire done_wit_exp;
reg start_wit_exp;
//=============================================
seed_wit_expansion #(.PARAMETER_SET(PARAMETER_SET), .FILE_SEED(FILE_SEED))
SEED_WIT_EXP 
(
.i_clk                  (i_clk                 ),
.i_rst                  (i_rst                 ),
.i_start                (start_wit_exp         ),
.i_seed_wit             (i_seed_wit            ),
.i_seed_wit_addr        (i_seed_wit_addr       ),
.i_seed_wit_wr_en       (i_seed_wit_wr_en      ),

.o_hash_data_in          (o_hash_data_in       ),   
.i_hash_addr             (i_hash_addr          ),   
.i_hash_rd_en            (i_hash_rd_en         ),   
.i_hash_data_out         (i_hash_data_out      ),   
.i_hash_data_out_valid   (i_hash_data_out_valid),   
.o_hash_data_out_ready   (o_hash_data_out_ready),   
.o_hash_input_length     (o_hash_input_length  ),   
.o_hash_output_length    (o_hash_output_length ),   
.o_hash_start            (o_hash_start         ),   
.o_hash_force_done       (o_hash_force_done    ), 

.i_pos_addr             (q_non_zero_pos_addr   ), 
.i_pos_rd               (q_non_zero_pos_rd     ), 
.o_pos                  (q_non_zero_pos        ), 

.i_val_addr             (0                     ), 
.i_val_rd               (0                     ), 
// .o_val                  (o_val                 ), 

.i_x_addr_0             (p_x_addr              ), 
.i_x_rd_0               (p_x_rd                ), 
.o_x_0                  (p_x                  ), 

.i_x_addr_1             (s_x_addr              ), 
.i_x_rd_1               (s_x_rd                ), 
.o_x_1                  (q1_x                  ), 

`ifdef TWO_SHARES
    .i_pos_0_addr             (q_non_zero_pos_0_addr   ), 
    .i_pos_0_rd               (q_non_zero_pos_0_rd     ), 
    .o_pos_0                  (q_non_zero_pos_0        ), 

    .i_val_0_addr             (0                     ), 
    .i_val_0_rd               (0                     ), 
    // .o_val                  (o_val                 ), 

    .i_x_0_addr_0             (p_x_0_addr              ), 
    .i_x_0_rd_0               (p_x_0_rd                ), 
    .o_x_0_0                  (p_x_0                  ),

    .i_x_0_addr_1             (s_0_x_addr             ), 
    .i_x_0_rd_1               (s_0_x_rd               ), 
    .o_x_0_1                  (s_0_x                  ), 

    // .i_x_0_addr_0             (p_x_2_addr              ), 
    // .i_x_0_rd_0               (p_x_2_rd                ), 
    // .o_x_0_0                  (q0_2_x                  ), 

    // .i_x_0_addr_1             (s_x_2_addr              ), 
    // .i_x_0_rd_1               (s_x_2_rd                ), 
    // .o_x_0_1                  (q1_x_2                  ), 
`endif

.o_done_xv              (done_wit_exp          )
);
//================================================

//==================X-mem======================
wire [7:0] q0_x, q1_x;
// mem_dual #(.WIDTH(8), .DEPTH(M), .FILE("x_L1.mem")) 
//  X_MEM
//  (
//  .clock(i_clk),
//  .data_0(0),
//  .data_1(0),
//  .address_0(p_x_rd? p_x_addr: 0),
//  .address_1(s_x_rd? s_x_addr: 0),
//  .wren_0(0),
//  .wren_1(0),
//  .q_0(q0_x),
//  .q_1(q1_x)
//  );
//================================================



// mem_single #(.WIDTH(8), .DEPTH(WEIGHT/D), .FILE("NON_ZERO_POS_L1.mem")) 
//  NON_ZERO_POSITIONS
//  (
//  .clock(i_clk),
//  .data(0),
//  .address(q_non_zero_pos_rd? q_non_zero_pos_addr: 0),
//  .wr_en(0),
//  .q(q_non_zero_pos)
//  );

//==================ComputeQ======================
reg start_q;
wire done_q;
wire [7:0] q_int;
wire   [`CLOG2(WEIGHT/D + 1):0] q_addr_int;
wire  [7:0]                   q_non_zero_pos;
wire  [`CLOG2(WEIGHT)-1:0]    q_non_zero_pos_addr;
wire                          q_non_zero_pos_rd;

compute_Q #(.PARAMETER_SET(PARAMETER_SET), .WEIGHT(WEIGHT), .D(D))
COMP_Q 
(
.i_clk(i_clk),      
.i_rst(i_rst),
.i_start(start_q),
.i_non_zero_pos(q_non_zero_pos),
.o_non_zero_pos_addr(q_non_zero_pos_addr),
.o_non_zero_pos_rd(q_non_zero_pos_rd),

.o_q(q_int),
.i_q_addr(q_addr_int),

.i_q_rd(i_q_rd | p_q_rd),
.o_done(done_q)
);

assign o_q = q_int;
assign q_addr_int = i_q_rd? i_q_addr:
                    p_q_rd? p_addr_q: 
                            p_addr_q;


`ifdef TWO_SHARES
    wire [7:0] q_0_int;
    wire   [`CLOG2(WEIGHT/D + 1):0] q_0_addr_int;
    wire  [7:0]                   q_non_zero_pos_0;
    wire  [`CLOG2(WEIGHT)-1:0]    q_non_zero_pos_0_addr;
    wire                          q_non_zero_pos_rd_0;
    wire  done_q_0;

    compute_Q #(.PARAMETER_SET(PARAMETER_SET), .WEIGHT(WEIGHT), .D(D))
    COMP_Q_0 
    (
    .i_clk(i_clk),      
    .i_rst(i_rst),
    .i_start(start_q),
    .i_non_zero_pos(q_non_zero_pos_0),
    .o_non_zero_pos_addr(q_non_zero_pos_0_addr),
    .o_non_zero_pos_rd(q_non_zero_pos_0_rd),

    .o_q(q_0_int),
    .i_q_addr(q_0_addr_int),

    .i_q_rd(i_q_0_rd | p_q_0_rd),
    // .i_q_rd(0),
    .o_done(done_q_0)
    );

    assign o_q_0 = q_0_int;
    assign q_0_addr_int = i_q_0_rd?   i_q_0_addr:
                        p_q_0_rd?   p_addr_q_0: 
                                    p_addr_q_0;

`endif 
//===================================================


//==================ComputeP=========================
wire start_p;
wire [7:0] p_x;
wire [`CLOG2(M/D)-1:0] p_x_addr;
wire p_x_rd;
wire [`CLOG2(WEIGHT/D + 1):0] p_addr_q;
wire p_q_rd;
wire done_p;

assign start_p = done_q;
// assign p_x = q0_x;

compute_SP #(.PARAMETER_SET(PARAMETER_SET), .M(M), .WEIGHT(WEIGHT), .D(D), .TYPE("P"))
COMP_P 
(
.i_clk(i_clk),      
.i_rst(i_rst),
.i_start(start_p),

.i_x(p_x),
.o_x_addr(p_x_addr),
.o_x_rd(p_x_rd),

.i_q_fp(q_int),
.o_q_fp_addr(p_addr_q),
.o_q_fp_rd(p_q_rd),

.o_sp(o_p),
.i_sp_addr(i_p_addr),
.i_sp_rd(i_p_rd),


.o_done(done_p)
);

`ifdef TWO_SHARES
    wire [7:0] q0_0_x, q1_0_x;
    wire [7:0] p_x_0;
    wire [`CLOG2(M/D)-1:0] p_x_0_addr;
    wire p_x_0_rd;
    wire [`CLOG2(WEIGHT/D + 1):0] p_addr_q_0;
    wire p_q_0_rd;
    wire done_p_0;

    // assign start_p = done_q_0;
    // assign p_x_0 = q0_0_x;

    compute_SP #(.PARAMETER_SET(PARAMETER_SET), .M(M), .WEIGHT(WEIGHT), .D(D), .TYPE("P"))
    COMP_P_0 
    (
    .i_clk(i_clk),      
    .i_rst(i_rst),
    .i_start(start_p),

    .i_x(p_x_0),
    .o_x_addr(p_x_0_addr),
    .o_x_rd(p_x_0_rd),

    .i_q_fp(q_0_int),
    .o_q_fp_addr(p_addr_q_0),
    .o_q_fp_rd(p_q_0_rd),

    .o_sp(o_p_0),
    .i_sp_addr(i_p_0_addr),
    .i_sp_rd(i_p_0_rd),


    .o_done(done_p_0)
);
`endif 
//===================================================


//==================ComputeS=========================
parameter FILE_FP = (PARAMETER_SET == "L1")?    "f_poly_L1.mem" :
                    (PARAMETER_SET == "L3")?    "f_poly_L3.mem" :
                    (PARAMETER_SET == "L5")?    "f_poly_L5.mem" :
                                                "f_poly_L1.mem";

wire [7:0] f_poly;

`ifndef TWO_SHARES
    mem_single #(.WIDTH(8), .DEPTH(M/D +1), .FILE(FILE_FP)) 
    F_POLY_MEM
    (
    .clock(i_clk),
    .data(0),
    .address(s_addr_fp),
    .wr_en(0),
    .q(f_poly)
    );
 `endif 

 `ifdef TWO_SHARES
 wire [7:0] f_0_poly;
    mem_dual #(.WIDTH(8), .DEPTH(M/D +1), .FILE(FILE_FP)) 
    F_POLY_MEM
    (
    .clock(i_clk),
    .data_0(0),
    .data_1(0),
    .address_0(s_addr_fp),
    .address_1(s_0_addr_fp),
    .wren_0(0),
    .wren_1(0),
    .q_0(f_poly),
    .q_1(f_0_poly)
    );
 `endif 




reg start_s;
wire [7:0] s_x;
wire [`CLOG2(M/D)-1:0] s_x_addr;
wire s_x_rd;
wire [`CLOG2(M/D + 1)-1:0] s_addr_fp;
wire s_fp_rd;
wire done_s;

assign s_x = q1_x;

compute_SP #(.PARAMETER_SET(PARAMETER_SET), .M(M), .WEIGHT(WEIGHT), .D(D), .TYPE("S"))
COMP_S 
(
.i_clk(i_clk),      
.i_rst(i_rst),
.i_start(start_s),

.i_x(s_x),
.o_x_addr(s_x_addr),
.o_x_rd(s_x_rd),

.i_q_fp(f_poly),
.o_q_fp_addr(s_addr_fp),
.o_q_fp_rd(s_fp_rd),

`ifndef TWO_SHARES
    .o_sp(o_s),
    .i_sp_addr(i_s_addr),
    .i_sp_rd(i_s_rd),
`endif 

`ifdef TWO_SHARES
    .o_sp(s_1),
    .i_sp_addr(s_addr_int),
    .i_sp_rd(s_rd_int),
`endif 

.o_done(done_s)
);


`ifdef TWO_SHARES

    wire [7:0] s_0_x;
    wire [`CLOG2(M/D)-1:0] s_0_x_addr;
    wire s_0_x_rd;
    wire [`CLOG2(M/D + 1)-1:0] s_0_addr_fp;
    wire s_0_fp_rd;
    wire done_s_0;

    // assign s_0_x = q1_0_x;

    compute_SP #(.PARAMETER_SET(PARAMETER_SET), .M(M), .WEIGHT(WEIGHT), .D(D), .TYPE("S"))
    COMP_S_0 
    (
    .i_clk(i_clk),      
    .i_rst(i_rst),
    .i_start(start_s),

    .i_x(s_0_x),
    .o_x_addr(s_0_x_addr),
    .o_x_rd(s_0_x_rd),

    .i_q_fp(f_0_poly),
    .o_q_fp_addr(s_0_addr_fp),
    .o_q_fp_rd(s_0_fp_rd),

    // .o_sp(o_s_0),
    // .i_sp_addr(i_s_0_addr),
    // .i_sp_rd(i_s_0_rd),

    .o_sp(s_0),
    .i_sp_addr(s_addr_int),
    .i_sp_rd(s_rd_int),

    .o_done(done_s_0)
    );

`endif 
//===================================================

wire [7:0] s_mv_int;
reg [7:0] s_mv_int_reg = 0;
reg [`CLOG2(M)-1:0] s_mv_addr;
wire [7:0] s_0, s_1;
reg s_rd_int;
reg sel_d, sel_d_reg;
reg s_mv_wr_en;

assign s_mv_int = (sel_d_reg)? s_1 : s_0;

always@(posedge i_clk)
begin
    if (sel_d) begin
        s_mv_addr <= M/D + s_addr_int;
    end
    else begin
        s_mv_addr <= {1'b0,s_addr_int};
    end
end
 
`ifdef TWO_SHARES

    mem_single #(.WIDTH(8), .DEPTH(M)) 
    S_combined_MEM
    (
    .clock(i_clk),
    .data(s_mv_int),
    .address(i_s_rd? i_s_addr: s_mv_addr),
    .wr_en(s_mv_wr_en),
    .q(o_s)
    );

        // mem_dual #(.WIDTH(8), .DEPTH(M/D +1), .FILE(FILE_FP)) 
        // S_combined_MEM
        // (
        // .clock(i_clk),
        // .data_0(0),
        // .data_1(0),
        // .address_0(s_addr_fp),
        // .address_1(s_0_addr_fp),
        // .wren_0(0),
        // .wren_1(0),
        // .q_0(f_poly),
        // .q_1(f_0_poly)
        // );
 `endif 

reg [3:0] state;
parameter s_wait_start      =0;
parameter s_sampling        =1;
parameter s_start_QSP       =2;
parameter s_stall_0         =3;
parameter s_sa_load         =4;
parameter s_stall_1         =5;
parameter s_sb_load         =6;
parameter s_done            =7;

reg [`CLOG2(M/D)-1:0] s_addr_int;
reg s_rd_int;

always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        o_done <= 0;
        s_rd_int <= 0;
        s_addr_int <= 0;
        // sel_d <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            o_done <= 0;
            s_rd_int <= 0;
            s_addr_int <= 0;
            // sel_d <= 0;
            if (i_start) begin
                state <= s_sampling;
            end
        end

        else if (state == s_sampling) begin
            if (done_wit_exp) begin
                state <= s_start_QSP;
            end
            o_done <= 0;
        end

        else if (state == s_start_QSP) begin
            o_done <= 0;
            s_addr_int <= 0;
            // sel_d <= 0;
            if (done_s) begin
                if (D > 1) begin
                    state <= s_stall_0;
                    s_rd_int <= 1;
                end
                else begin
                    state <= s_done;
                    s_rd_int <= 0;
                end
            end
        end

        else if (state == s_stall_0) begin
            state <= s_sa_load;
            s_rd_int <= 1;
            s_addr_int <= s_addr_int + 1;
        end

        else if (state == s_sa_load) begin
            s_rd_int <= 1;
            // sel_d <= 0;
            if (s_addr_int == M/D - 1) begin
                s_addr_int <= 0;
                state <= s_stall_1;
            end
            else begin
                s_addr_int <= s_addr_int + 1;
            end
        end
        else if (state == s_stall_1) begin
            state <= s_sb_load;
            s_rd_int <= 1;
            s_addr_int <= s_addr_int + 1;
        end

        else if (state == s_sb_load) begin
            s_rd_int <= 1;
            // sel_d <= 1;
            if (s_addr_int == M/D - 1) begin
                s_addr_int <= 0;
                state <= s_done;
            end
            else begin
                s_addr_int <= s_addr_int + 1;
            end
        end

        else if (state == s_done) begin
            state <= s_wait_start;
            o_done <= 1;
            s_rd_int <= 0;
            // sel_d <= 0;
        end
    end
    sel_d_reg <= sel_d;
end

always@(state, i_start, done_wit_exp)
begin

    case(state)
        
    s_wait_start: begin
       start_s <= 0;
        start_q <= 0;
        sel_d <= 0;
        s_mv_wr_en <= 0;
        if (i_start) begin
            start_wit_exp <= 1;
        end
        else begin
            start_wit_exp <= 0;
        end
    end
    
    s_sampling: begin
        start_wit_exp <= 0; 
        sel_d <= 0;
        s_mv_wr_en <= 0;
        if (done_wit_exp) begin
            start_s <= 1;
            start_q <= 1;
        end
        else begin
            start_s <= 0;
            start_q <= 0;
        end
    end

    s_start_QSP: begin
        start_s <= 0;
        start_q <= 0;
        start_wit_exp <= 0; 
        sel_d <= 0;
        s_mv_wr_en <= 0;
    end

    s_stall_0: begin
        start_s <= 0;
        start_q <= 0;
        start_wit_exp <= 0; 
        sel_d <= 0;
        s_mv_wr_en <= 0;
    end

    s_sa_load: begin
        start_s <= 0;
        start_q <= 0;
        start_wit_exp <= 0; 
        sel_d <= 0;
        s_mv_wr_en <= 1;
    end

    s_stall_1: begin
        start_s <= 0;
        start_q <= 0;
        start_wit_exp <= 0; 
        sel_d <= 1;
        s_mv_wr_en <= 1;
    end

    s_sb_load: begin
        start_s <= 0;
        start_q <= 0;
        start_wit_exp <= 0; 
        sel_d <= 1;
        s_mv_wr_en <= 1;
    end

    s_done: begin
        start_s <= 0;
        start_q <= 0;
        start_wit_exp <= 0; 
        sel_d <= 1;
        // s_mv_wr_en <= 1;
    end
     
     default: begin
        start_s <= 0;
        start_q <= 0;
        start_wit_exp <= 0; 
        sel_d <= 0;
        s_mv_wr_en <= 0;
    end
    
    endcase
    
end

endmodule