/*
 * This file is the r^i module which works 3 r values simultaneously.
 *
 * Copyright (C) 2023
 * Authors: Sanjay Deshpande <sanjay.deshpande@sandboxquantum.com>
 *

 Algorithm: Square-and-multiply
Require: x âˆˆ {0,..., N âˆ’ 1} and K = (kâˆ’1,..., k0)2
1: r â†? 1
2: for i from  l âˆ’ 1 downto 0 do
3:      r â†? r^2 mod N
4:      if ki = 1 then
5:          r â†? r Ã— x mod N
6:      end if
7: end for
8: return r          
*/

module r_pow_i_x_t
#(
    
    // parameter FIELD = "P251",
    parameter FIELD = "GF256",
    
    
    parameter PARAMETER_SET = "L1",
    parameter M  =  (PARAMETER_SET == "L1")? 230:
                    (PARAMETER_SET == "L3")? 352:
                    (PARAMETER_SET == "L5")? 480:
                                             230,
    parameter T =   (PARAMETER_SET == "L5")? 4:
                                             3,
                                             
    parameter LOOP_COUNTER = (FIELD == "GF256")? T: 13                                    
    
    
)(
    input i_clk,
    input i_rst,
    input i_start,
    input [32*T-1:0] i_r,
    input [`CLOG2(M)-1:0] i_exp, 
    output [32*T-1:0] o_r_pow_exp,

    `ifdef GF32_MUL_SHARED
        output o_start_mul,
        output [31:0] o_x_mul,
        output [31:0] o_y_mul,
        input  [31:0] o_o_mul,
        input  i_done_mul,
    `endif 

    output reg o_done

);


reg [`CLOG2(M)-1:0] i_exp_reg;

reg load;
reg shift;
reg start_mul;
wire done_mul;
wire [31:0] mul_out;
reg [32*T-1:0] r_reg;
reg first;

reg square;
reg mul;

always@(posedge i_clk)
begin
    if (load) begin
        i_exp_reg <= i_exp;
    end
    else if (shift) begin
        // i_exp_reg <= {i_exp_reg[`CLOG2(M)-2:0],1'b0};
        i_exp_reg <= {i_exp_reg[6:0],1'b0};
    end
end

wire l_minus_1;
assign l_minus_1 = i_exp_reg[`CLOG2(M)-1];

always@(posedge i_clk)
begin
    if (i_start) begin
        r_reg <= i_r;
    end
    else if (start_mul) begin
        r_reg <= {r_reg[32*T-32-1:0], r_reg[32*T-1:32*T-32]};
    end
end


wire [31:0] i_x;
wire [31:0] i_y;


assign i_x = first ? 1 : 
             (square || mul) && done_mul? mul_out: 
             0;

assign i_y =   first?                1:
               (square && done_mul)? mul_out:
                                     r_reg[T*32 - 1: T*32 -32];                                


wire done_from_mul32;
wire [31:0] mul_out_mul32;

`ifdef GF32_MUL_SHARED
    assign o_start_mul = start_mul;
    assign o_x_mul = i_x;
    assign o_y_mul = i_y;
    assign mul_out_mul32 = o_o_mul;
    assign done_from_mul32 = i_done_mul;
//    assign done_mul = i_done_mul;
    
`endif 

`ifndef GF32_MUL_SHARED
    if (FIELD == "GF256") begin
        gf_mul_32
        GF32_MUL
        (
            .i_clk(i_clk),
            .i_x(i_x),
            .i_y(i_y),
            .i_start(start_mul),
            .o_o(mul_out_mul32),
            .o_done(done_from_mul32)
        );
     end
     else begin
        gf251_mul_32
        GF32_MUL
        (
            .i_clk(i_clk),
            .i_x(i_x),
            .i_y(i_y),
            .i_start(start_mul),
            .o_o(mul_out_mul32),
            .o_done(done_from_mul32)
        );
     
     end
`endif 

generate
//    if (FIELD == "GF256") begin
        if (T > 3 && FIELD == "GF256") begin
            pipeline_reg_gen #(.WIDTH(1), .REG_STAGES(T-3))
            INC_PIPELINE_STAGES_DONE_MUL
            (
            .i_clk(i_clk),
            .i_data_in(done_from_mul32),
            .o_data_out(done_mul)
            );
            
             pipeline_reg_gen #(.WIDTH(1), .REG_STAGES(T-3))
            INC_PIPELINE_STAGES_MUL_RESULT
            (
            .i_clk(i_clk),
            .i_data_in(mul_out_mul32),
            .o_data_out(mul_out)
            );
        end
        else begin
            assign done_mul = done_from_mul32;
            assign mul_out = mul_out_mul32;
        end
//    end
endgenerate

reg [32*T-1:0] mul_out_concat;
always@(posedge i_clk)
begin
    if (i_start) begin
        mul_out_concat <= 0;
    end
    else if (done_mul) begin
        mul_out_concat <= {mul_out_concat[32*T-32-1:0], mul_out};
    end
end 

assign o_r_pow_exp = mul_out_concat;

reg [3:0] state;
parameter s_wait_start      = 0;
parameter s_stall_0         = 1;
parameter s_first_sq        = 2;
parameter s_proc_mul        = 3;
parameter s_sq              = 4;
parameter s_done            = 5;

parameter s_stall_when_t4_0 = 6;

reg [`CLOG2(T):0] count;
reg [`CLOG2(M):0] shift_count;

always@(posedge i_clk)
begin
    if (i_start) begin
        shift_count <= 0;
    end
    else if (shift) begin
        shift_count <= shift_count+1;
    end
end

always@(posedge i_clk)
begin
    if (i_rst) begin
        state <= s_wait_start;
        o_done <= 0;
    end
    else begin
        count <= 0;
        o_done <= 0;
        if (state == s_wait_start) begin
            if (i_start) begin
                state <= s_stall_0;
            end
        end

        else if (state == s_stall_0) begin
            state <= s_first_sq;
        end

        else if (state == s_first_sq) begin
            if (count == T-1) begin
                    count <= 0;
                        state <= s_proc_mul;
            end
            else begin
                count <= count + 1;
            end
        end

//        else if (s_stall_when_t4_0) begin
//            state <= s_proc_mul;
//        end
        
        else if (state == s_proc_mul) begin
            if (l_minus_1) begin
                if (done_mul) begin
                    if (count == T-1) begin
                        count <= 0;
                        state <= s_sq;
                    end
                    else begin
                        count <= count + 1;
                    end
                end
            end
            else begin
                state <= s_sq;
            end
        end


        else if (state == s_sq) begin
            if (shift_count == `CLOG2(M)) begin
                state <= s_done;
            end
            else begin
                if (count == T-1) begin
                        count <= 0;
                        state <= s_proc_mul;
                end
                else begin
                    if (done_mul) begin
                        count <= count + 1;
                    end
                end
            end
        end
        
        else if (state == s_done) begin 
            if (count == T-1) begin
                    count <= 0;
                    state <= s_wait_start;
                    o_done <= 1;
            end
            else begin
                if (done_mul) begin //test
                    count <= count + 1;
                end //test
                o_done <= 0;
            end 
        end
       
    end
end

always@(*)
begin

    case(state)
        
        s_wait_start: begin
            shift <= 0;
            first <= 0;
            square <= 0;
            mul <= 0;
            if (i_start) begin
                load <= 1;
            end
            else begin
                load <= 0;
            end
        end

        s_stall_0: begin
            load <= 0;
            shift <= 0;
            first <= 1;
            square <= 0;
            mul <= 0;
        end

        s_first_sq: begin
            load <= 0;
            shift <= 0;
            first <= 1;
            start_mul <= 1;
            square <= 0;
            mul <= 0;
        end
        
        
        s_proc_mul: begin
            load <= 0;
            first <= 0;
            square <= 0;
            mul <= 1;
            if (l_minus_1) begin
                if (done_mul) begin
                    start_mul <= 1;
                end
                else begin
                    start_mul <= 0;
                end
            end
            else begin
                start_mul <= 0;
            end

//            if ((count == 2) || (~l_minus_1)) begin
            if ((count == T-1) || (~l_minus_1)) begin
                shift <= 1;
            end
            else begin
                shift <= 0;
            end
        end
        s_stall_when_t4_0:begin
            load <= 0;
            shift <= 0;
            first <= 0;
            start_mul <= 0;
            square <= 0;
            mul <= 0;
        end
        
        s_sq: begin
            load <= 0;
            first <= 0;
            shift <= 0;
            square <= 1;
            mul <= 0;
            if (done_mul) begin
                    if (shift_count < 8) begin
                        start_mul <= 1;
                    end 
                    else begin
                        start_mul <= 0;
                    end
            end
            else begin
                start_mul <= 0;
            end
        end

                    
        s_done: begin
            load <= 0;
            shift <= 0;
            start_mul <= 0;
            first <= 0;
            square <= 0;
            mul <= 0;
        end
        
        default: begin
            load <= 0;
            start_mul <= 0;
            shift <= 0;
            first <= 0;
            square <= 0;
            mul <= 0;
        end
    
    endcase
    
end

endmodule