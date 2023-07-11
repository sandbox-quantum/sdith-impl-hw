/*
 * This file is Witness SeedExpansion.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *          
*/


module seed_wit_expansion 
#(

    parameter PARAMETER_SET = "L1",
    
    parameter LAMBDA =  (PARAMETER_SET == "L1")? 128:
                        (PARAMETER_SET == "L2")? 192:
                        (PARAMETER_SET == "L3")? 256:
                                                 128,
                                                    
    parameter M =  (PARAMETER_SET == "L1")? 230:
                        (PARAMETER_SET == "L2")? 352:
                        (PARAMETER_SET == "L3")? 480:
                                                 230,

    parameter WEIGHT =  (PARAMETER_SET == "L1")? 79:
                        (PARAMETER_SET == "L2")? 120:
                        (PARAMETER_SET == "L3")? 150:
                                                 79,

    parameter D =   (PARAMETER_SET == "L1")? 1:
                        (PARAMETER_SET == "L2")? 2:
                        (PARAMETER_SET == "L3")? 2:
                                                 1,
    
    parameter FILE_SEED = "SEED_SAMPLE.mem"
//     parameter FILE_SEED = "zero.mem"

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

    output   wire                           o_done_p,
    output   reg                            o_done_xv
);

assign o_done_p = done_sampling;
assign o_hash_input_length = LAMBDA;
assign o_hash_output_length = 2048;
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
.i_non_zero_pos_rd_x(pos_rd_x),
.i_non_zero_pos_addr_x(pos_addr_x),

.o_done(done_sampling)

);



generate
if (PARAMETER_SET == "L3" || PARAMETER_SET == "L5") begin
    reg start_sampling_2;
    wire [7:0] pos_x_2;
    reg [`CLOG2(WEIGHT/D)-1:0] pos_addr_x_2;
    reg  pos_rd_x_2;  
    wire done_sampling_2;  
    wire pos_rd_2;

        sampling #(.PARAMETER_SET(PARAMETER_SET))
        SAMPLE_1 (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_start(start_sampling_2),
        .i_pos_valid(pos_valid),
        .i_pos(pos[31:24]),
        // .o_duplicate_detected(o_duplicate_detected),
        .o_pos_rd(pos_rd_2),

        // .o_non_zero_pos(o_pos),
        // .i_non_zero_pos_rd(i_pos_rd | pos_rd_x),
        // .i_non_zero_pos_addr(i_pos_rd? i_pos_addr: pos_addr_x),

        .o_non_zero_pos(o_pos_2),
        .i_non_zero_pos_rd(i_pos_rd_2),
        .i_non_zero_pos_addr(i_pos_addr_2),

        .o_non_zero_pos_x(pos_x_2),
        .i_non_zero_pos_rd_x(pos_rd_x_2),
        .i_non_zero_pos_addr_x(pos_addr_x_2),

        .o_done(done_sampling_2)
        );

end
else begin

    reg start_sampling_2 =0;
    wire [7:0] pos_x_2 =0;
    reg [`CLOG2(WEIGHT/D)-1:0] pos_addr_x_2 =0;
    reg  pos_rd_x_2 =0;  
    wire done_sampling_2 =0;  
    wire pos_rd_2 =0;
    wire pos_rd_2 = 0;

end
endgenerate

reg wr_en_cv;
reg [`CLOG2(WEIGHT/D):0] count_val;
wire [7:0] val;

assign val = pos[31:24];
mem_single #(.WIDTH(8), .DEPTH(WEIGHT/D), .FILE(FILE_SEED)) 
 NON_ZERO_VAL
 (
 .clock(i_clk),
 .data(val),
 .address(i_val_rd? i_val_addr :pos_rd_x? pos_addr_x :count_val[`CLOG2(WEIGHT/D)-1:0]),
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
parameter s_prepare_x               = 8;
parameter s_load_x                  = 9;
parameter s_done                    = 10;

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
        // pos_valid <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            o_done_xv <= 0;
            count <= 0;
            o_hash_data_out_ready <= 0;
            count_val <= 0;
            o_hash_force_done <= 0;
            pos_addr_x <= 0;
            // pos_valid <= 0;
            if (i_start) begin
                state <= s_hash_proc;
            end
        end

        else if (state == s_hash_proc) begin
            // pos_valid <= 0;
            o_hash_force_done <= 0;
            if (i_hash_data_out_valid) begin
                state <= s_hash_out_load_f;
                o_hash_data_out_ready <= 1;
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
                        state <= s_hash_val_load;
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
                        state <= s_hash_val_load;
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
                        o_hash_data_out_ready <= 1;
                        state <= s_hash_out_load;
                    end 
                    else begin
                        count <= count + 1;
                        o_hash_data_out_ready <= 0;
                    end
                end
            end
        end

        else if (state == s_hash_val_load) begin
            o_hash_data_out_ready <= 0;
            o_hash_force_done <= 0;
            if (count_val == WEIGHT/D - 1) begin
                state <= s_prepare_x;
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
                state <= s_prepare_x;
            end
            else begin
                    if (count == 3) begin
                        count <= 0;
                        if (i_hash_data_out_valid) begin
                            state <= s_hash_val_load;
                            o_hash_data_out_ready <= 1;
                        end
                        else begin
                            state <= s_wait_for_hash_valid;
                            o_hash_data_out_ready <= 0;
                        end
                    end 
                    else begin
                        count <= count + 1;
                        o_hash_data_out_ready <= 0;
                    end
            end
        end

        else if (state == s_wait_for_hash_valid) begin
            o_hash_force_done <= 0;
            if (i_hash_data_out_valid) begin
                    state <= s_hash_val_load;
                    o_hash_data_out_ready <= 1;
            end
        end

        else if (state == s_prepare_x) begin
            pos_addr_x <= pos_addr_x + 1;
            state <= s_load_x;
        end

         else if (state == s_load_x) begin
            if (pos_addr_x == WEIGHT-1) begin
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

always@(state, i_start, i_hash_data_out_valid, pos_rd, val, count_val)
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
    end

    s_hash_out_shift: begin
        wr_en_cv <= 0;
        load_hash_in <=0;
        pos_rd_x <= 0;
        wr_en_x <= 0;
        if (pos_rd) begin
            shift_hash_in <=1;
            pos_valid <= 1;
        end
        else begin
            shift_hash_in <=0;
            pos_valid <= 0;
        end
        start_sampling <= 0;
    end

    s_hash_val_load: begin
        shift_hash_in <= 0;
        start_sampling <= 0; 
        pos_valid <= 0;
        pos_rd_x <= 0;
        wr_en_x <= 0;
        if (count_val <= WEIGHT/D -1) begin 
            if (i_hash_data_out_valid) begin
                load_hash_in <=1;
                if (val == 0) begin
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
        else begin
            wr_en_cv <= 0;
        end
    end

    s_hash_val_shift: begin
        start_sampling <= 0; 
        pos_valid <= 0;
        load_hash_in <=0;
        shift_hash_in <=1;
        pos_rd_x <= 0;
        wr_en_x <= 0;
        if (count_val <= WEIGHT/D -1) begin 
            if (val == 0) begin
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
    end
    
    s_prepare_x: begin
        start_sampling <= 0; 
        pos_valid <= 0;
        load_hash_in <=0;
        shift_hash_in <=0;
        wr_en_cv <= 0;
        pos_rd_x <= 1;
        wr_en_x <= 0;
    end

    s_load_x: begin
        start_sampling <= 0; 
        pos_valid <= 0;
        load_hash_in <=0;
        shift_hash_in <=0;
        wr_en_cv <= 0;
        wr_en_x <= 1;
        pos_rd_x <= 1;
    end

    s_done: begin
        o_hash_start <= 0;
        load_hash_in <=0;
        shift_hash_in <= 0;
        start_sampling <= 0;
        pos_rd_x <= 0;
        wr_en_x <= 1;
    end
     
     default: begin
        o_hash_start <= 0;
        load_hash_in <=0;
        shift_hash_in <= 0;
        start_sampling <= 0;
        wr_en_cv <= 0;
        pos_rd_x <= 0;
        wr_en_x <= 0;
    end
    
    endcase
    
end

endmodule