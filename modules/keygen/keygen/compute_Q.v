/*
 *Copyright (c) SandboxAQ. All rights reserved.
 *SPDX-License-Identifier: Apache-2.0   
*/



module compute_Q
#(
    parameter FIELD = "P251",
    parameter PARAMETER_SET = "L5",
    
                                                    
    parameter WEIGHT =  (PARAMETER_SET == "L1")? 79:
                        (PARAMETER_SET == "L3")? 120:
                        (PARAMETER_SET == "L5")? 150:
                                                 3,
                                                            
    parameter D =   (PARAMETER_SET == "L1")? 1:
                    (PARAMETER_SET == "L3")? 2:
                    (PARAMETER_SET == "L5")? 2:
                                                 1,
    parameter DEPTH_OF_Q = WEIGHT/D    

)(
    input                           i_clk,
    input                           i_rst,
    input                           i_start,
    input   [7:0]                   i_non_zero_pos,
    output  reg [`CLOG2(WEIGHT)-1:0]    o_non_zero_pos_addr,
    output  reg                     o_non_zero_pos_rd,


    output  [7:0]                   o_q,
    input   [`CLOG2(DEPTH_OF_Q):0]i_q_addr,
    input                           i_q_rd,

    output                          o_done
);


wire [`CLOG2(DEPTH_OF_Q):0] DEPTH = DEPTH_OF_Q;

assign o_done = done_int;
assign o_q = (DEPTH[0]==1)? m0_q_0 : m1_q_0;
// assign o_non_zero_pos_addr = addr_i;



reg  wren_0;
reg  wren_1;

wire [8-1:0] q_0, q_1;
reg init;
reg sel;

assign data_0 = init ? 1 : 
                     0; 
                    //  (mul_out_reg ^ mul_out); 

// assign data_1 = init? i_non_zero_pos: 
//                 ((m0_addr_1 == 0 && (~sel_mem)) || (m1_addr_1 == 0 && sel_mem))?  mul_out: 
//                 (q_0 ^ mul_out);

assign data_1 = init? i_non_zero_pos: 
                ((m0_addr_1 == 0 && (~sel_mem_reg)) || (m1_addr_1 == 0 && sel_mem_reg))?  mul_out: 
                (add_q_0_mul_out);
                // (q_0_reg ^ mul_out);

                // (q_0 + mul_out)%251;

wire [7:0] add_q_0_mul_out;
wire [7:0] q_0_reg;
wire [7:0] mul_out;
generate
        if (FIELD == "P251") begin 
            p251_add
            #(
            .REG_IN(0),
            .REG_OUT(0)
            ) 
            P251_ADD_0 
            (
    //            .clk(i_clk), 
    //            .start(start_dot_mul), 
                .in_1(q_0_reg), 
                .in_2(mul_out),
    //            .done(done_dot_mul[i]), 
                .out(add_q_0_mul_out) 
            );
        end
        else  begin
        gf_add 
            #(
            .REG_IN(0),
            .REG_OUT(0),
            .WIDTH(8)
            )
            GF_ADD_0 
            (
                .i_clk(i_clk), 
                .i_start(done_mul), 
                .in_1(q_0_reg), 
                .in_2(mul_out),
    //            .done(done_dot_mul[i]), 
                .out(add_q_0_mul_out) 
            );
        end
endgenerate

// assign o_q = q_1;

wire done_mul;
reg start_mul;

wire [7:0] mul_in_1, mul_in_2;

reg [7:0] mul_out_reg;
reg update_addr_zero;

always@(posedge i_clk)
begin
    if (init) begin
        mul_out_reg <= 1;
    end
    else if (done_mul) begin    
        mul_out_reg <= data_0;
    end
end


pipeline_reg_gen #(.WIDTH(8), .REG_STAGES(2))
REG_STATE_Q_0
(
    .i_clk(i_clk),
    .i_data_in(q_0),
    .o_data_out(q_0_reg)
   );

wire [`CLOG2(DEPTH_OF_Q):0] m0_addr_1_reg; 
pipeline_reg_gen #(.WIDTH(8), .REG_STAGES(2))
REG_STATE_M0_ADDR
(
    .i_clk(i_clk),
    .i_data_in(m0_addr_1),
    .o_data_out(m0_addr_1_reg)
   );

wire [`CLOG2(DEPTH_OF_Q):0] m1_addr_1_reg; 
wire [`CLOG2(DEPTH_OF_Q):0] addr_j_reg_reg; 
pipeline_reg_gen #(.WIDTH(`CLOG2(DEPTH_OF_Q)+1), .REG_STAGES(2))
REG_STATE_M1_ADDR
(
    .i_clk(i_clk),
    .i_data_in(addr_j_reg),
    .o_data_out(addr_j_reg_reg)
   );



wire sel_mem_reg; 
pipeline_reg_gen #(.WIDTH(1), .REG_STAGES(3))
REG_STATE_SEL_MEM
(
    .i_clk(i_clk),
    .i_data_in(sel_mem),
    .o_data_out(sel_mem_reg)
   );

// wire sel_mem_reg; 
// pipeline_reg_gen #(.WIDTH(1), .REG_STAGES(2))
// REG_STATE_SEL_MEM
// (
//     .i_clk(i_clk),
//     .i_data_in(sel_mem),
//     .o_data_out(sel_mem_reg)
//    );

wire wren_1_reg; 
pipeline_reg_gen #(.WIDTH(1), .REG_STAGES(2))
REG_STATE_WREN_1
(
    .i_clk(i_clk),
    .i_data_in(~init & wren_1),
    .o_data_out(wren_1_reg)
   );

 
assign q_0 = sel_mem? m0_q_0: m1_q_0;
assign q_1 = sel_mem? m0_q_1: m1_q_1;

assign mul_in_1 = update_addr_zero? mul_out_reg: q_1;
assign mul_in_2 = i_non_zero_pos;

// gf_mul #(.REG_IN(1), .REG_OUT(1))
//     GF_MULT 
//     (
//         .clk(i_clk), 
//         .start(start_mul), 
//         .in_1(mul_in_1), 
//         .in_2(mul_in_2),
//         .done(done_mul), 
//         .out(mul_out) 
//     );

generate
    if (FIELD == "P251") begin 
        p251_mul #(.REG_IN(1), .REG_OUT(1))
        P251_MULT 
        (
            .clk(i_clk), 
            .start(start_mul), 
            .in_1(mul_in_1), 
            .in_2(mul_in_2),
            .done(done_mul), 
            .out(mul_out) 
        );
    end
    else begin 
        gf_mul #(.REG_IN(1), .REG_OUT(1))
        GF_MULT 
        (
            .clk(i_clk), 
            .start(start_mul), 
            .in_1(mul_in_1), 
            .in_2(mul_in_2),
            .done(done_mul), 
            .out(mul_out) 
        );
    end
endgenerate

// assign mul_out = (mul_in_1 * mul_in_2) % 251;
// assign done_mul = start_mul;


wire [8-1:0] data_0;
wire [8-1:0] data_1;
wire [`CLOG2(DEPTH_OF_Q):0] m0_addr_0; 
wire [`CLOG2(DEPTH_OF_Q):0] m0_addr_1; 
wire m0_wren_0, m0_wren_1;
wire [8-1:0] m0_q_0;
wire [8-1:0] m0_q_1;
wire sel_mem;
wire not_sel_mem_reg;

assign not_sel_mem_reg = ~sel_mem_reg;
assign not_sel_mem = ~sel_mem;

assign sel_mem = o_non_zero_pos_addr[0];

assign m0_addr_0 =  i_q_rd ? i_q_addr:
                    init ?  addr_j: 
                            addr_j-1;
assign m0_addr_1 =  init ? addr_i : 
                    update_addr_zero  ? 0 :
                    // ~sel_mem? addr_j_reg:
                    ~sel_mem_reg && m0_wren_1? addr_j_reg_reg:
                                    addr_j;
// assign addr_1 = addr_i;
assign m0_wren_0 = init? wren_0: (~sel_mem) & wren_0;
// assign m0_wren_1 = init? wren_1: (~sel_mem_reg) & wren_1_reg;
// assign m0_wren_1 = init? wren_1: (~sel_mem) & wren_1;
assign m0_wren_1 = init? wren_1: (~sel_mem_reg) & done_mul;

mem_dual #(.WIDTH(8), .DEPTH(DEPTH_OF_Q+1), .INIT(1))
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

wire [`CLOG2(DEPTH_OF_Q):0] m1_addr_0; 
wire [`CLOG2(DEPTH_OF_Q):0] m1_addr_1; 
wire m1_wren_0, m1_wren_1;

assign m1_addr_0 =  i_q_rd ? i_q_addr:
                    init ?  addr_j: 
                            addr_j-1;
assign m1_addr_1 =  init ? addr_i : 
                    update_addr_zero  ? 0 :
                    // sel_mem ? addr_j_reg:
                    sel_mem_reg && m1_wren_1? addr_j_reg_reg:
                                    addr_j;

assign m1_wren_0 = init? wren_0: (sel_mem) & wren_0;
// assign m1_wren_1 = init? wren_1: (sel_mem) & wren_1;
assign m1_wren_1 = init? wren_1: (sel_mem_reg) & done_mul;

wire [8-1:0] m1_q_0;
wire [8-1:0] m1_q_1;

mem_dual #(.WIDTH(8), .DEPTH(DEPTH_OF_Q+1), .INIT(1))
RESULT_MEM_1 
(
  .clock(i_clk),
  .data_0(data_0),
  .data_1(data_1),
  .address_0(m1_addr_0),
  .address_1(m1_addr_1),
  .wren_0(m1_wren_0),
  .wren_1(m1_wren_1),
  .q_0(m1_q_0),
  .q_1(m1_q_1)

);

parameter s_wait_start      = 0;
parameter s_init            = 1;
parameter s_i_inc           = 2;
parameter s_stall_1         = 8;
parameter s_j_inc           = 3;
parameter s_q0_update       = 4;
parameter s_done            = 5;
parameter s_stall_0         = 6;
parameter s_update_addr_zero = 7;
parameter s_stall_2         = 9;
parameter s_stall_3         = 10;

reg [3:0] state = 0;
reg [`CLOG2(DEPTH_OF_Q):0] addr_i;
reg [`CLOG2(DEPTH_OF_Q):0] addr_j, addr_j_reg;
reg [`CLOG2(DEPTH_OF_Q):0] store_addr_i;



reg done_int;
always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        addr_i <= 0;
        addr_j <= 0;
        o_non_zero_pos_addr <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            addr_i <= 0;
            addr_j <= 1;
            o_non_zero_pos_addr <= 0;
            if (i_start) begin
                state <= s_init;
            end
        end

        else if (state == s_init) begin
            state <= s_stall_0;
            addr_i <= 1;
            addr_j <= 2;
            store_addr_i <= 1;
            o_non_zero_pos_addr <= 1;
        end 

        else if (state == s_stall_0) begin
            // state <= s_stall_2;
            state <= s_j_inc;
            addr_i <= addr_i - 1;
            addr_j <= addr_j - 1;
        end 

       

            
        else if (state ==  s_i_inc) begin
            // if (o_non_zero_pos_addr == DEPTH_OF_Q + 1) begin
            if (o_non_zero_pos_addr == DEPTH_OF_Q-1) begin
                addr_i <= 0;
                addr_j <= 1;
                state <= s_done;
            end
            else begin
                // state <= s_j_inc;
                state <= s_stall_1;
                o_non_zero_pos_addr <= store_addr_i + 1;
                addr_i <= store_addr_i + 1;
                addr_j <= store_addr_i + 2;
            end

        end
            
        else if (state ==  s_stall_1) begin
            // state <= s_j_inc;
            state <= s_stall_2;
            // o_non_zero_pos_addr <= store_addr_i + 1;
            // addr_i <= store_addr_i + 1;
            // addr_j <= store_addr_i + 2;
            // addr_j <= addr_j - 1;
        end

        else if (state == s_stall_2) begin
            state <= s_stall_3;
            // addr_i <= addr_i - 1;
            // addr_j <= addr_j - 1;
        end 

        else if (state == s_stall_3) begin
            state <= s_j_inc;
            // addr_i <= addr_i - 1;
            addr_j <= addr_j - 1;
        end 

        else if (state ==  s_j_inc) begin
            if (addr_j == 1) begin
                addr_j <= 0;
                addr_i <= store_addr_i;
                // state <= s_q0_update;
                state <= s_update_addr_zero;
            end
            else begin
                store_addr_i <=  addr_i; 
                state <= s_j_inc;
                addr_j <= addr_j - 1;
                // addr_i <= addr_i - 1;
            end
        end

        else if (state ==  s_update_addr_zero) begin
                state <= s_i_inc;
                // state <= s_stall_2;
                addr_i <= store_addr_i;
                // o_non_zero_pos_addr <= store_addr_i + 1;
        end

        

        else if (state ==  s_done) begin
            state <= s_wait_start;
        end

    end
    addr_j_reg <= addr_j;
end

always@(state, i_start, addr_i, addr_j, done_mul)
begin

    case(state)
        
    s_wait_start: begin
        wren_0 <= 0;
        wren_1 <= 0;
        init <= 0;
        start_mul <= 0;
        sel <= 0;
        update_addr_zero <= 0;
        done_int <= 0;
        if (i_start) begin
            o_non_zero_pos_rd <= 1;
        end
        else begin
            o_non_zero_pos_rd <= 0;
        end
    end
    
    s_init: begin
        wren_0 <= 1;
        wren_1 <= 1;
        o_non_zero_pos_rd <= 1;
        init <= 1;
        start_mul <= 0;
        sel <= 0;
        update_addr_zero <= 0;
        done_int <= 0;
    end

    s_stall_0: begin
        wren_0 <= 0;
        wren_1 <= 0;
        o_non_zero_pos_rd <= 1;
        init <= 0;
        start_mul <= 0;
        sel <= 0;
        update_addr_zero <= 0;
        done_int <= 0;
    end


    s_i_inc: begin
        wren_0 <= 0;
        if (done_mul) begin
            wren_1 <= 1;
        end
        else begin
            wren_1 <= 0;
        end
        o_non_zero_pos_rd <= 1;
        init <= 0;
        start_mul <= 1;
        sel <= 0;
        update_addr_zero <= 0;
        done_int <= 0;
    end

    s_stall_1: begin
        wren_0 <= 0;
        if (done_mul) begin
            wren_1 <= 1;
        end
        else begin
            wren_1 <= 0;
        end
        o_non_zero_pos_rd <= 1;
        init <= 0;
        start_mul <= 0;
        sel <= 0;
        update_addr_zero <= 0;
        done_int <= 0;
    end

    s_stall_2: begin
        wren_0 <= 0;
        if (done_mul) begin
            wren_1 <= 1;
        end
        else begin
            wren_1 <= 0;
        end
        o_non_zero_pos_rd <= 1;
        init <= 0;
        start_mul <= 0;
        sel <= 0;
        update_addr_zero <= 0;
        done_int <= 0;
    end

    s_stall_3: begin
        wren_0 <= 0;
        if (done_mul) begin
            wren_1 <= 1;
        end
        else begin
            wren_1 <= 0;
        end
        o_non_zero_pos_rd <= 1;
        init <= 0;
        start_mul <= 0;
        sel <= 0;
        update_addr_zero <= 0;
        done_int <= 0;
    end

    s_j_inc: begin
        wren_0 <= 0;
        if (done_mul) begin
            wren_1 <= 1;
        end
        else begin
            wren_1 <= 0;
        end
        o_non_zero_pos_rd <= 1;
        init <= 0;
        start_mul <= 1;
        update_addr_zero <= 0;
        done_int <= 0;
        if (addr_j == 1) begin
            sel <= 1;
            // wren_1 <= 1;
        end
        else begin
            sel <= 0;
            // wren_1 <= 0;
        end
    end

    s_update_addr_zero: begin
        wren_0 <= 0;
        wren_1 <= 1;
        o_non_zero_pos_rd <= 1;
        init <= 0;
        start_mul <= 1;
        sel <= 0;
        update_addr_zero <= 0;
        done_int <= 0;
    end

    s_stall_2: begin
        wren_0 <= 0;
        wren_1 <= 0;
        o_non_zero_pos_rd <= 1;
        init <= 0;
        start_mul <= 1;
        sel <= 0;
        update_addr_zero <= 0;
        done_int <= 0;
    end


    s_done: begin
        wren_0 <= 0;
        wren_1 <= 1;
        o_non_zero_pos_rd <= 0;
        init <= 0;
        start_mul <= 0;
        sel <= 0;
        done_int <= 1;
    end

     
     default: begin
                wren_0 <= 0;
                o_non_zero_pos_rd <= 0;
                wren_1 <= 0;
                init <= 0;
                done_int <= 0;
    end
    
    endcase
    
end

endmodule