/*
 * This file is Witness SeedExpansion.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module seed_wit_expansion 
#(
    parameter FIELD = "GF256", 
    
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
    
    parameter FILE_SEED = (PARAMETER_SET == "L1")? "SEED_SAMPLE.mem":
                        (PARAMETER_SET == "L3")? "SEED_SAMPLE_L3.mem":
                        (PARAMETER_SET == "L5")? "SEED_SAMPLE_L5.mem":
                                                 "SEED_SAMPLE.mem"
                                                 
)(
    input                                   i_clk,
    input                                   i_rst,
    input                                   i_start,

    input   [32-1:0]                        i_seed_wit,
    input   [`CLOG2(LAMBDA/32)-1:0]         i_seed_wit_addr,
    input                                   i_seed_wit_wr_en,

    output   [32-1:0]                       o_hash_data_in,
    input    [`CLOG2(LAMBDA/32) -1:0]       i_hash_addr,

    input                                   i_hash_rd_en,

    input    wire [32-1:0]                  i_hash_data_out,
    input    wire                           i_hash_data_out_valid,
    output   reg                            o_hash_data_out_ready,

    output   wire  [32-1:0]                 o_hash_input_length, // in bits
    output   wire  [32-1:0]                 o_hash_output_length, // in bits

    output   reg                            o_hash_start,
    output   reg                            o_hash_force_done,

    input      [`CLOG2(WEIGHT/D)-1:0]       i_pos_addr,
    input                                   i_pos_rd,
    output     [7:0]                        o_pos,

    input      [`CLOG2(WEIGHT/D)-1:0]       i_val_addr,
    input                                   i_val_rd,
    output     [7:0]                        o_val,

    input      [`CLOG2(M/D)-1:0]            i_x_addr_0,
    input                                   i_x_rd_0,
    output     [7:0]                        o_x_0,

    input      [`CLOG2(M/D)-1:0]            i_x_addr_1,
    input                                   i_x_rd_1,
    output     [7:0]                        o_x_1,


// SHARE 0 Ports for L3 and L5
`ifdef TWO_SHARES
    input      [`CLOG2(WEIGHT/D)-1:0]       i_pos_0_addr,
    input                                   i_pos_0_rd,
    output     [7:0]                        o_pos_0,

    input      [`CLOG2(WEIGHT/D)-1:0]       i_val_0_addr,
    input                                   i_val_0_rd,
    output     [7:0]                        o_val_0,

    input      [`CLOG2(M/D)-1:0]            i_x_0_addr_0,
    input                                   i_x_0_rd_0,
    output     [7:0]                        o_x_0_0,

    input      [`CLOG2(M/D)-1:0]            i_x_0_addr_1,
    input                                   i_x_0_rd_1,
    output     [7:0]                        o_x_0_1,
`endif

    output   wire                           o_done_p,
    output   reg                            o_done_xv
);

assign o_done_p = done_sampling && (count_shares == D-1);
assign o_hash_input_length = LAMBDA;
assign o_hash_output_length = 4096;
// assign o_hash_data_out_ready = 1;

wire [31:0] q_seed_wit;

mem_single #(.WIDTH(32), .DEPTH(LAMBDA/32), .FILE(FILE_SEED)) 
 SEED_WIT_MEM
 (
 .clock(i_clk),
 .data(i_seed_wit),
 .address(i_seed_wit_wr_en? i_seed_wit_addr: i_hash_rd_en? i_hash_addr: 0),
 .wr_en(i_seed_wit_wr_en),
 .q(q_seed_wit)
 );
assign o_hash_data_in = q_seed_wit;


reg [31:0] pos;
wire pos_rd; 
reg load_hash_in;
reg shift_hash_in;

always@(posedge i_clk)
begin
    if (load_hash_in) begin
        pos <= i_hash_data_out;
    end
    else if (shift_hash_in) begin
        pos <= {pos[23:0], 8'h00};
    end
end

reg start_sampling;
wire done_sampling;
wire pos_rd;
reg pos_valid;
sampling #(.PARAMETER_SET(PARAMETER_SET))
SAMPLE_0 (
.i_clk(i_clk),
.i_rst(i_rst),
.i_start(start_sampling),
.i_pos_valid(pos_valid),
.i_pos(pos[31:24]),
// .o_duplicate_detected(o_duplicate_detected),
.o_pos_rd(pos_rd),

// .o_non_zero_pos(o_pos),
// .i_non_zero_pos_rd(i_pos_rd | pos_rd_x),
// .i_non_zero_pos_addr(i_pos_rd? i_pos_addr: pos_addr_x),

.o_non_zero_pos(o_pos),
.i_non_zero_pos_rd(i_pos_rd),
.i_non_zero_pos_addr(i_pos_addr),

.o_non_zero_pos_x(pos_x),
.i_non_zero_pos_rd_x(pos_rd_x | pos_2_rd),
.i_non_zero_pos_addr_x(pos_2_rd? pos_val_2_mv_addr: pos_addr_x),

.o_done(done_sampling)

);

// wire [7:0] pos_2;
reg [`CLOG2(WEIGHT/D)-1:0] pos_val_2_mv_addr;
reg [`CLOG2(WEIGHT/D)-1:0] pos_val_2_mv_addr_reg;
reg pos_2_rd;
reg pos_2_wr_en;

// reg [`CLOG2(WEIGHT/D)-1:0] val_2_addr;
reg val_2_rd;
reg val_2_wr_en;

`ifdef TWO_SHARES
 mem_single #(.WIDTH(8), .DEPTH(WEIGHT/D)) 
 NON_ZERO_POS_2
 (
 .clock(i_clk),
 .data(pos_x),
 .address(i_pos_0_rd? i_pos_0_addr :pos_rd_x? pos_addr_x :pos_val_2_mv_addr_reg),
 .wr_en(pos_2_wr_en),
 .q(o_pos_0)
 );

mem_single #(.WIDTH(8), .DEPTH(WEIGHT/D), .FILE(FILE_SEED)) 
 NON_ZERO_VAL_2
 (
 .clock(i_clk),
 .data(o_val),
 .address(i_val_0_rd? i_val_0_addr :pos_rd_x? pos_addr_x :pos_val_2_mv_addr_reg),
 .wr_en(val_2_wr_en),
 .q(o_val_0)
 );

 mem_dual #(.WIDTH(8), .DEPTH(M/D), .FILE("zero.mem")) 
X_MEM_2
 (
 .clock(i_clk),
 .data_0(o_val_0),
 .data_1(0),
 .address_0(i_x_0_rd_0? i_x_0_addr_0 : o_pos_0),
 .address_1(i_x_0_rd_1? i_x_0_addr_1 : 0),
 .wren_0(wr_en_x),
 .wren_1(0),
 .q_0(o_x_0_0),
 .q_1(o_x_0_1)
 );

`endif

// `ifndef TWO_SHARES

// `endif

reg wr_en_cv;
reg [`CLOG2(WEIGHT/D):0] count_val;
wire [7:0] val;

assign val = pos[31:24];
mem_single #(.WIDTH(8), .DEPTH(WEIGHT/D), .FILE(FILE_SEED)) 
 NON_ZERO_VAL
 (
 .clock(i_clk),
 .data(val),
 .address(i_val_rd? i_val_addr :pos_rd_x? pos_addr_x : val_2_rd? pos_val_2_mv_addr: count_val[`CLOG2(WEIGHT/D)-1:0]),
 .wr_en(wr_en_cv),
 .q(o_val)
 );

always@(posedge i_clk)
begin
    if (i_start || count_val == WEIGHT/D - 1) begin
        count_val <= 0;
    end
    else if (wr_en_cv) begin
        count_val <= count_val + 1;
    end
end

wire [7:0] pos_x;
reg wr_en_x;
reg [`CLOG2(WEIGHT/D)-1:0] pos_addr_x;
wire [`CLOG2(M/D)-1:0] addr_x;
reg  pos_rd_x;

assign addr_x = {1'b0,pos_addr_x};

mem_dual #(.WIDTH(8), .DEPTH(M/D), .FILE("zero.mem")) 
X_MEM
 (
 .clock(i_clk),
 .data_0(o_val),
 .data_1(0),
 .address_0(i_x_rd_0? i_x_addr_0 : pos_x),
 .address_1(i_x_rd_1? i_x_addr_1 : 0),
 .wren_0(wr_en_x),
 .wren_1(0),
 .q_0(o_x_0),
 .q_1(o_x_1)
 );




reg [2:0] count = 0;

reg [3:0] state;
parameter s_wait_start              = 0;
parameter s_hash_proc               = 1;
parameter s_hash_out_load_f         = 2;
parameter s_hash_out_load           = 3;
parameter s_hash_out_shift          = 4;
parameter s_hash_val_load           = 5;
parameter s_hash_val_shift          = 6;
parameter s_wait_for_hash_valid     = 7;
parameter s_wait_for_hash_valid_0     = 8;
parameter s_prepare_x               = 9;
parameter s_load_x                  = 10;
parameter s_done                    = 11;


parameter s_start_second_sampling     = 12;
parameter s_hash_out_load_2           = 13;
parameter s_hash_out_shift_2          = 14;

reg [`CLOG2(D):0] count_shares;
reg start_mv_pos;
reg start_mv_val;

always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        o_done_xv <= 0;
        count <= 0;
        o_hash_data_out_ready <= 0;
        count_val <= 0;
        o_hash_force_done <=0;
        pos_addr_x <= 0;
        count_shares <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            o_done_xv <= 0;
            count <= 0;
            o_hash_data_out_ready <= 0;
            count_val <= 0;
            o_hash_force_done <= 0;
            pos_addr_x <= 0;
            count_shares <= 0;
            if (i_start) begin
                state <= s_hash_proc;
            end
        end

        else if (state == s_hash_proc) begin
            o_hash_force_done <= 0;
            count_shares <= 0;
            if (i_hash_data_out_valid) begin
                state <= s_hash_out_load_f;
                // o_hash_data_out_ready <= 1;
            end
        end

        else if (state == s_hash_out_load_f) begin
            o_hash_data_out_ready <= 0;
            o_hash_force_done <= 0;
            if (pos_rd) begin
                count <= count + 1;
                state <= s_hash_out_shift;
            end
        end

        else if (state == s_hash_out_load) begin
            o_hash_data_out_ready <= 0;
            if (done_sampling) begin
                if (count == 0) begin
                    state <=   s_hash_val_load;
                end
                else begin 
                    state <= s_hash_val_shift;
                end
            end
            else begin
                if (pos_rd) begin
                    count <= count + 1;
                    state <= s_hash_out_shift;
                end
            end
        end

        else if (state == s_hash_out_shift) begin
            o_hash_force_done <= 0;
            if (done_sampling) begin
                if (count == 0) begin
                    state <=   s_hash_val_load;
                end
                else begin 
                    state <= s_hash_val_shift;
                end
                o_hash_data_out_ready <= 0;
            end
            else begin
                if (pos_rd) begin
                    if (count == 3) begin
                        count <= 0;
                         if (i_hash_data_out_valid) begin
                            state <= s_hash_out_load;
                            // o_hash_data_out_ready <= 1;
                        end
                        else begin
                            state <= s_wait_for_hash_valid_0;
                            // o_hash_data_out_ready <= 0;
                        end
                    end 
                    else begin
                        count <= count + 1;
                        o_hash_data_out_ready <= 0;
                    end
                    if (count == 2) begin
                        if (i_hash_data_out_valid) begin
                            o_hash_data_out_ready <= 1;
                        end
                        else begin
                            o_hash_data_out_ready <= 0;
                        end
                    end 
                    else begin
                        o_hash_data_out_ready <= 0;
                    end
                end
                else begin
                    o_hash_data_out_ready <= 0;
                end
            end
        end

        else if (state == s_wait_for_hash_valid_0) begin
            o_hash_force_done <= 0;
            if (done_sampling) begin
                state <= s_wait_for_hash_valid;
            end
            else if (i_hash_data_out_valid) begin
                state <= s_hash_out_load;
                o_hash_data_out_ready <= 1;
            end
        end

        else if (state == s_hash_val_load) begin
            o_hash_data_out_ready <= 0;
            o_hash_force_done <= 0;
            if (count_val == WEIGHT/D - 1) begin
                if (count_shares == D-1) begin
                    state <= s_prepare_x;
                end
                else begin
                    if (PARAMETER_SET == "L3" || PARAMETER_SET == "L5") begin
                        state <= s_start_second_sampling;
                    end
                end  
            end
            else begin
                if (i_hash_data_out_valid) begin
                    count <= count + 1;
                    state <= s_hash_val_shift;
                end
            end
        end

         else if (state == s_hash_val_shift) begin
            o_hash_force_done <= 0;
            if (count_val == WEIGHT/D - 1) begin
                if (count_shares == D-1) begin
                    state <= s_prepare_x;
                end
                else begin
                    if (PARAMETER_SET == "L3" || PARAMETER_SET == "L5") begin
                        state <= s_start_second_sampling;
                    end
                end  
            end
            else begin
                    if (count == 3) begin
                        count <= 0;
                        if (i_hash_data_out_valid) begin
                            state <= s_hash_val_load;
                            // o_hash_data_out_ready <= 1;
                        end
                        else begin
                            state <= s_wait_for_hash_valid;
                            // o_hash_data_out_ready <= 0;
                        end
                    end 
                    else begin
                        count <= count + 1;
                        // o_hash_data_out_ready <= 0;
                    end

                    if (count == 2) begin
                        if (i_hash_data_out_valid) begin
                            o_hash_data_out_ready <= 1;
                        end
                        else begin
                            o_hash_data_out_ready <= 0;
                        end
                    end 
                    else begin
                        o_hash_data_out_ready <= 0;
                    end
            end
        end

        else if (state == s_wait_for_hash_valid) begin
            o_hash_force_done <= 0;
            if (i_hash_data_out_valid) begin
                if (count == 2) begin
                    o_hash_data_out_ready <= 1;
                end
                else begin
                    o_hash_data_out_ready <= 0;
                end
                state <= s_hash_val_load;
                    
            end
        end



         else if (state == s_start_second_sampling) begin
            count_shares = count_shares + 1;
            if (count == 0) begin
                state <= s_hash_out_load;
                o_hash_data_out_ready <= 0;
            end
            else begin 
                state <= s_hash_out_shift;
                count <= count + 1;
                if (count == 2) begin
                    if (i_hash_data_out_valid) begin
                        o_hash_data_out_ready <= 1;
                    end
                    else begin
                        o_hash_data_out_ready <= 0;
                    end
                end
            end
         end


        else if (state == s_prepare_x) begin
            pos_addr_x <= pos_addr_x + 1;
            state <= s_load_x;
        end

         else if (state == s_load_x) begin
            if (pos_addr_x == WEIGHT/D -1) begin
                state <= s_done;
                pos_addr_x <= 0;
            end
            else begin
                pos_addr_x <= pos_addr_x + 1;
            end
        end

        else if (state == s_done) begin
            state <= s_wait_start;
            o_done_xv <= 1;
            o_hash_force_done <= 1;

        end
    end
end

always@(state, i_start, i_hash_data_out_valid, pos_rd, val, count_val, done_sampling, count_shares, D)
begin

    case(state)
        
    s_wait_start: begin
        load_hash_in <=0;
        shift_hash_in <= 0;
        start_sampling <= 0;
        pos_valid <= 0;
        wr_en_cv <= 0;
        pos_rd_x <= 0;
        wr_en_x <= 0;
        start_mv_pos <= 0;
        start_mv_val <= 0;
        if (i_start) begin
            o_hash_start <= 1;
        end
        else begin
            o_hash_start <= 0;
        end
    end
    
    s_hash_proc: begin
        o_hash_start <= 0;
        load_hash_in <=0;
        shift_hash_in <= 0;
        pos_valid <= 0;
        wr_en_cv <= 0;
        pos_rd_x <= 0;
        wr_en_x <= 0;
        start_mv_pos <= 0;
        start_mv_val <= 0;
        if (i_hash_data_out_valid) begin
            start_sampling <= 1;
        end
        else begin
            start_sampling <= 0;
        end
    end

    s_hash_out_load_f: begin
        if (pos_rd) begin
            load_hash_in <=1;
        end
        else begin
            load_hash_in <=0;
        end
        shift_hash_in <= 0;
        start_sampling <= 0;  
        pos_valid <= 0; 
        wr_en_cv <= 0;
        pos_rd_x <= 0;
        wr_en_x <= 0;
        start_mv_pos <= 0;
        start_mv_val <= 0;
    end

    s_hash_out_load: begin
        wr_en_cv <= 0;
        pos_rd_x <= 0;
        wr_en_x <= 0;
        if (pos_rd) begin
            load_hash_in <=1;
            pos_valid <= 1;
        end
        else begin
            load_hash_in <=0;
            pos_valid <= 0;
        end
        shift_hash_in <= 0;
        start_sampling <= 0;   
        if (done_sampling) begin
            if (D == 2 && count_shares < 1) begin
                start_mv_pos <= 1;
            end
            else begin
                start_mv_pos <= 0;
            end
        end
        else begin
            start_mv_pos <= 0;
        end
        start_mv_val <= 0;
    end

    s_hash_out_shift: begin
        wr_en_cv <= 0;
        load_hash_in <=0;
        pos_rd_x <= 0;
        wr_en_x <= 0;
        start_mv_val <= 0;
        if (pos_rd) begin
            shift_hash_in <=1;
            pos_valid <= 1;
        end
        else begin
            shift_hash_in <=0;
            pos_valid <= 0;
        end
        start_sampling <= 0;
         if (done_sampling) begin
            if (D == 2 && count_shares < 1) begin
                start_mv_pos <= 1;
            end
            else begin
                start_mv_pos <= 0;
            end
        end
        else begin
            start_mv_pos <= 0;
        end
    end

    s_wait_for_hash_valid_0:begin
        start_sampling <= 0; 
        pos_valid <= 0;
        load_hash_in <=0;
        shift_hash_in <=0;
        wr_en_cv <= 0;
        pos_rd_x <= 0;
        wr_en_x <= 0;
        start_mv_pos <= 0;
        start_mv_val <= 0;
    end

    s_hash_val_load: begin
        shift_hash_in <= 0;
        pos_valid <= 0;
        pos_rd_x <= 0;
        wr_en_x <= 0;
        start_sampling <= 0; 
        start_mv_pos <= 0;
        start_mv_val <= 0;
        if (count_val <= WEIGHT/D -1) begin 
            if (i_hash_data_out_valid) begin
                load_hash_in <=1;
                if (val == 0 || (FIELD == "P251" && val > 250)) begin
                    wr_en_cv <= 0;
                end
                else begin
                    wr_en_cv <= 1;
                end
            end
            else begin
                wr_en_cv <= 0;
                load_hash_in <=0;
            end
        end
        else begin
            wr_en_cv <= 0;
            load_hash_in <=0;
        end
    end

    s_hash_val_shift: begin
        shift_hash_in <=1;
        pos_valid <= 0;
        load_hash_in <=0;
        pos_rd_x <= 0;
        wr_en_x <= 0;
        start_sampling <= 0; 
        start_mv_pos <= 0;
        start_mv_val <= 0;
        if (count_val <= WEIGHT/D -1) begin  
            if (val == 0 || (FIELD == "P251" && val > 250)) begin
                wr_en_cv <= 0;
            end
            else begin
                wr_en_cv <= 1;
            end
        end
        else begin
            wr_en_cv <= 0;
        end
    end

    s_wait_for_hash_valid:begin
        start_sampling <= 0; 
        pos_valid <= 0;
        load_hash_in <=0;
        shift_hash_in <=0;
        wr_en_cv <= 0;
        pos_rd_x <= 0;
        wr_en_x <= 0;
        start_mv_pos <= 0;
        start_mv_val <= 0;
    end


    s_start_second_sampling: begin
        start_sampling <= 1; 
        pos_valid <= 0;
        load_hash_in <=0;
        shift_hash_in <=0;
        wr_en_cv <= 0;
        pos_rd_x <= 0;
        wr_en_x <= 0;
        start_mv_pos <= 0;
        start_mv_val <= 0;
        if (D == 2 && count_shares < 1) begin
                start_mv_val <= 1;
        end
        else begin
            start_mv_val <= 0;
        end
    end


    
    s_prepare_x: begin
        start_sampling <= 0; 
        pos_valid <= 0;
        load_hash_in <=0;
        shift_hash_in <=0;
        wr_en_cv <= 0;
        pos_rd_x <= 1;
        wr_en_x <= 0;
        start_mv_pos <= 0;
        start_mv_val <= 0;
    end

    s_load_x: begin
        start_sampling <= 0; 
        pos_valid <= 0;
        load_hash_in <=0;
        shift_hash_in <=0;
        wr_en_cv <= 0;
        wr_en_x <= 1;
        pos_rd_x <= 1;
        start_mv_pos <= 0;
        start_mv_val <= 0;
    end

    s_done: begin
        o_hash_start <= 0;
        load_hash_in <=0;
        shift_hash_in <= 0;
        start_sampling <= 0;
        pos_rd_x <= 0;
        wr_en_x <= 1;
        wr_en_cv <= 0;
        start_mv_pos <= 0;
        start_mv_val <= 0;
    end
     
     default: begin
        o_hash_start <= 0;
        load_hash_in <=0;
        shift_hash_in <= 0;
        start_sampling <= 0;
        wr_en_cv <= 0;
        pos_rd_x <= 0;
        wr_en_x <= 0;
        start_mv_pos <= 0;
        start_mv_val <= 0;
    end
    
    endcase
    
end

reg [2:0] state_mv = 0;
parameter s_wait_start_mv_pos   = 0;
parameter s_mv_pos              = 1;
parameter s_wait_start_mv_val   = 2;
parameter s_mv_val              = 3;

always@(posedge i_clk) begin
    if (i_rst) begin
        state_mv <= s_wait_start_mv_pos;
        pos_val_2_mv_addr <= 0;
        pos_2_rd <= 0;
        val_2_rd <= 0;
    end
    else begin
        if (state_mv == s_wait_start_mv_pos) begin
            val_2_rd <= 0;
            if (start_mv_pos) begin
                pos_val_2_mv_addr <= 0;
                state_mv <= s_mv_pos;
                pos_2_rd <= 1;
            end
            else begin
                 pos_val_2_mv_addr <= 0;
                 pos_2_rd <= 0;
            end
        end

        else if (state_mv == s_mv_pos) begin
            val_2_rd <= 0;
            if (pos_val_2_mv_addr ==  WEIGHT/D - 1) begin
                pos_val_2_mv_addr <= 0;
                pos_2_rd <= 0;
                state_mv <= s_wait_start_mv_val;
            end
            else begin
                 pos_val_2_mv_addr <= pos_val_2_mv_addr + 1;
                 pos_2_rd <= 1;
            end
        end

        else if (state_mv == s_wait_start_mv_val) begin
            pos_2_rd <= 0;
            pos_val_2_mv_addr <= 0;
            if (start_mv_val) begin 
                state_mv <= s_mv_val;
                val_2_rd <= 1;
            end
            else begin
                val_2_rd <= 0;
            end
        end

        else if (state_mv == s_mv_val) begin
            pos_2_rd <= 0;
            if (pos_val_2_mv_addr ==  WEIGHT/D - 1) begin
                pos_val_2_mv_addr <= 0;
                val_2_rd <= 0;
                state_mv <= s_wait_start_mv_pos;
            end
            else begin
                 pos_val_2_mv_addr <= pos_val_2_mv_addr + 1;
                 val_2_rd <= 1;
            end
        end
        
    end
    pos_2_wr_en <= pos_2_rd;
    val_2_wr_en <= val_2_rd;
    pos_val_2_mv_addr_reg <= pos_val_2_mv_addr;
end

endmodule