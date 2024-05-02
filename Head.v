// We can expect the realized hardware to look something like this:
//
//                                 ____________________________ all current states
//                                |                            |
//                        ________v________             _______|________              ________________
//                       |                 |           |                |            |                |
//       all inputs      |   next state    |---------->|   state,       |----------->|   output       |
//              -------->|  combinational  |---------->|   prev_state,  |            | combinational  |----> (almost)
//                       |     circuit     |---------->|   error_num,   |            |     circuit    |       all outputs
//                       |                 |---------->|   additional_  |----------->|                |
//                       |                 |   next    |   state        |    state,  |                |
//                       |_________________|  states   |________________| additional |________________|
//                                                             |
//                                                             | state,
//                                                             | additional
//                                                      _______v________              ________________
//                                                     |                |            |                |
//                                                     |                |            |                |--->clk_count
//                                                     |    counter     |----------->|   clk          |
//                                                     |    enable      |  enable    |   counter      |
//                                                     | combinational  |----------->|                |
//                                                     |     circuit    | reset      |                |
//                                                     |________________|            |________________|
//


`include "button_release_detector.v"

module ControlUnit(
    input confirm_i,
    input shuffle_i,
    input same_i,
    input master_same_i,
    input input_valid_i,
    input buff_limit_i,
    input mem_limit_i,

    input clk_i,
    input nreset_i,

    output [31:0] clk_count_o,
    output shuffle_init_o,
    output mem_rst_o,
    output mem_sl_o,
    output buff_rst_o,
    output buff_sl_o, 
    output locked_o
    );

    wire [2:0] cur_state, next_state;
    wire [2:0] cur_additional_state, next_additional_state;
    wire [3:0] cur_error_num, next_error_num;
    
    wire confirm_released, shuffle_released;
    wire count_en, count_rst;

    button_release_detector ConfirmDetector(
        .out(confirm_released),
        .clk(clk_i),
        .in(confirm_i),
        .rstn(nreset_i)
    );

    button_release_detector ShuffleDetector(
        .out(shuffle_released),
        .clk(clk_i),
        .in(shuffle_i),
        .rstn(nreset_i)
    );

    NextStateComb NextStateCombUnit(
        .confirm_released_i(confirm_released),
        .shuffle_released_i(shuffle_released),
        .same_i(same_i),
        .master_same_i(master_same_i), 
        .input_valid_i(input_valid_i),
        .buff_limit_i(buff_limit_i),
        .mem_limit_i(mem_limit_i),
        .clk_count_i(clk_count_o),

        .cur_state_i(cur_state),
        .cur_additional_state_i(cur_additional_state),
        .cur_error_num_i(cur_error_num),
        
        .next_state_o(next_state),
        .next_additional_state_o(next_additional_state), 
        .next_error_num_o(next_error_num)
    );

    CurStateRegisters States(
        .next_state_i(next_state),
        .next_additional_state_i(next_additional_state),
        .next_error_num_i(next_error_num),
        
        .clk_i(clk_i),
        .nreset_i(nreset_i),

        .state_o(cur_state),
        .additional_state_o(cur_additional_state),
        .error_num_o(cur_error_num)
    );

    OutputComb OutputCombUnit(
        .state_i(cur_state),
        .additional_state_i(cur_additional_state),

        .shuffle_init_o(shuffle_init_o),
        .mem_rst_o(mem_rst_o),
        .mem_sl_o(mem_sl_o),
        .buff_rst_o(buff_rst_o),
        .buff_sl_o(buff_sl_o),
        .locked_o(locked_o)
    );

    ClkCounterEnableComb CounterEnCombUnit(
        .state_i(cur_state),
        .additional_state_i(cur_additional_state),
        .confirm_in_i(confirm_i),
        .shuffle_in_i(shuffle_i),

        .count_en_o(count_en),
        .count_rst_o(count_rst)
    );

    ClkCounter CounterUnit(
        .clk_num(clk_count_o),
        .clk(clk_i),
        .enable(count_en),
        .clk_num_rst(count_rst),
        .rstn(nreset_i)
    );

endmodule

module NextStateComb(
    // seperating the comb circuit and state register makes simulation easier
    input confirm_released_i,
    input shuffle_released_i,
    input same_i,
    input master_same_i, 
    input input_valid_i,
    input buff_limit_i,
    input mem_limit_i,
    input [31:0] clk_count_i,

    input [2:0] cur_state_i,
    input [2:0] cur_additional_state_i,
    input [3:0] cur_error_num_i,
    
    output reg [2:0] next_state_o,
    output reg [2:0] next_additional_state_o, // [2] means whether state transition just happened or not. 
    // [1:0] means which of set_psw, confirm_psw, challenge the previous state was in shuffle_mode. [0] means to shift left, [1] means to reset the selected buff/mem in confirm_psw, challenge, set_psw mode
    // this is some sort of minimizing the number of flip-flops, which can lead to minimizing power consumption
    output reg [3:0] next_error_num_o
    );    

    localparam [2:0] noop_mode = 3'b000;
    localparam [2:0] set_psw_mode = 3'b001;
    localparam [2:0] confirm_psw_mode = 3'b010;
    localparam [2:0] challenge_mode = 3'b011;
    localparam [2:0] shuffle_mode = 3'b100;
    localparam [2:0] locked_mode = 3'b101;
    localparam [2:0] unlocked_mode = 3'b110;

    localparam [31:0] long_confirm_threshold = 32'd80; // for simulation. This gotta be something like 3e6 or something in real life
    localparam [31:0] shuffle_sequence_duration = 32'd9;

    always @(*) begin
        case(cur_state_i) 
            noop_mode: begin
                next_state_o = set_psw_mode;
                next_additional_state_o = 3'b100;
                next_error_num_o = 3'b000;
            end
            set_psw_mode: begin
                if (shuffle_released_i) begin
                    next_state_o = shuffle_mode;
                    next_additional_state_o = {1'b1, set_psw_mode[1:0]};
                    next_error_num_o = 3'b000;
                end
                else if (confirm_released_i) begin // shuffle_released == 0 & confirm_released == 1. transition to confirm_psw_mode
                    next_state_o = confirm_psw_mode;
                    next_additional_state_o = 3'b110; // reset buffer
                    next_error_num_o = 3'b000;
                end
                else begin // shuffle_released == 0, confirm_released  == 0, reset mem if i.v. & limit, sl mem if i.v. & ~limit
                    next_state_o = set_psw_mode;
                    next_additional_state_o = {1'b0, mem_limit_i & input_valid_i, ~mem_limit_i & input_valid_i};
                    next_error_num_o = 3'b000;
                end
            end
            confirm_psw_mode: begin
                if (shuffle_released_i) begin // shuffle_released == 1. transition to shuffle mode
                    next_state_o = shuffle_mode; 
                    next_additional_state_o = {1'b1, confirm_psw_mode[1:0]};
                    next_error_num_o = 3'b000;
                end
                else if (confirm_released_i) begin 
                    if (same_i) begin // shuffle_released == 0, confirm_released == 1, same == 1. transition to locked mode
                        next_state_o = locked_mode; 
                        next_additional_state_o = 3'b100;
                        next_error_num_o = 3'b000;
                    end
                    else begin // shuffle_released == 0, confirm_released == 1, same == 0. transition to set_psw mode, reset mem
                        next_state_o = set_psw_mode; 
                        next_additional_state_o = 3'b110;
                        next_error_num_o = 3'b000;
                    end
                end
                else if (input_valid_i) begin
                    if (buff_limit_i) begin // shuffle_released == 0, confirm_released == 0, i.v. == 1, limit == 1: reset mem and transition to set_psw
                        next_state_o = set_psw_mode; 
                        next_additional_state_o = 3'b110;
                        next_error_num_o = 3'b000;
                    end
                    else begin // shuffle_released == 0, confirm_released == 0, i.v. == 1, limit == 0: shift left buffer
                        next_state_o = confirm_psw_mode; 
                        next_additional_state_o = 3'b001;
                        next_error_num_o = 3'b000;
                    end
                end
                else begin // shuffle_released == 0, confirm_released == 0, i.v. == 0. 
                    next_state_o = confirm_psw_mode; 
                    next_additional_state_o = 3'b000;
                    next_error_num_o = 3'b000;
                end
            end
            locked_mode: begin
                if (confirm_released_i) begin
                    next_state_o = challenge_mode; 
                    next_additional_state_o = 3'b110;
                    next_error_num_o = cur_error_num_i;
                end
                else begin
                    next_state_o = locked_mode; 
                    next_additional_state_o = 3'b000;
                    next_error_num_o = cur_error_num_i;
                end
            end
            challenge_mode: begin
                if (shuffle_released_i) begin // shuffle_released == 1. transition to shuffle mode
                    next_state_o = shuffle_mode; 
                    next_additional_state_o = {1'b1, challenge_mode[1:0]};
                    next_error_num_o = cur_error_num_i;
                end
                else if (confirm_released_i) begin
                    if ((same_i & (cur_error_num_i != 4'b1010)) | master_same_i) begin // shuffle_released == 0, confirm_released == 1, same == 1. transition to unlocked mode
                        next_state_o = unlocked_mode; 
                        next_additional_state_o = 3'b100;
                        next_error_num_o = 3'b000;
                    end
                    else begin // shuffle_released == 0, confirm_released == 1, wrong. transition to locked mode and increment error count
                        next_state_o = locked_mode; 
                        next_additional_state_o = 3'b100;
                        if (cur_error_num_i != 4'b1010) next_error_num_o = cur_error_num_i + 1;
                        else next_error_num_o = 4'b1010;
                    end
                end
                else if (input_valid_i) begin
                    if (buff_limit_i) begin // shuffle == 0, confirm == 0, i.v. == 1, limit == 1. transition to locked mode and increment error count
                        next_state_o = locked_mode; 
                        next_additional_state_o = 3'b100;
                        if (cur_error_num_i != 4'b1010) next_error_num_o = cur_error_num_i + 1;
                        else next_error_num_o = 4'b1010;
                    end
                    else begin // shuffle == 0, confirm == 0, i.i. == 1, limit == 0. stay in challenge mode and shift left buffer
                        next_state_o = challenge_mode;
                        next_additional_state_o = 3'b001;
                        next_error_num_o = cur_error_num_i;
                    end
                end
                else begin // shuffle == 0, confirm == 0, i.v. == 0. stay in challenge mode
                    next_state_o = challenge_mode;
                    next_additional_state_o = 3'b000;
                    next_error_num_o = cur_error_num_i;
                end
            end
            unlocked_mode: begin
                if (confirm_released_i) begin 
                    if (clk_count_i < 32'b1010) begin
                        next_state_o = locked_mode; // confirm_released == 1, clk_count (confirm hold time) < long_confirm_threshold. transition to locked mode
                        next_additional_state_o = 3'b100;
                        next_error_num_o = 3'b000;
                    end
                    else begin
                        next_state_o = set_psw_mode; // confirm_released == 1, clk_count >=10 transition to set_psw mode, reset mem
                        next_additional_state_o = 3'b110;
                        next_error_num_o = 3'b000;
                    end
                end
                else begin // confirm_released == 0. stay in unlocked mode
                    next_state_o = unlocked_mode;
                    next_additional_state_o = 3'b000;
                    next_error_num_o = 3'b000;
                end
            end

            shuffle_mode: begin
                if (clk_count_i == shuffle_sequence_duration) begin
                    next_state_o = {1'b0, next_additional_state_o[1:0]};
                    next_additional_state_o = 3'b100;
                    next_error_num_o = cur_error_num_i;
                end
                else begin
                    next_state_o = next_state_o;
                    next_additional_state_o = {1'b0, next_additional_state_o[1:0]};
                    next_error_num_o = cur_error_num_i;
                end
            end
            default: begin
                next_state_o = 3'b000;
                next_additional_state_o = 3'b000;
                next_error_num_o = 4'b0000;
            end
        endcase
    end
endmodule

module CurStateRegisters(
    input [2:0] next_state_i,
    input [2:0] next_additional_state_i,
    input [3:0] next_error_num_i,
    
    input clk_i,
    input nreset_i,

    output reg [2:0] state_o,
    output reg [2:0] additional_state_o,
    output reg [3:0] error_num_o
    );

    always @(negedge clk_i or negedge nreset_i) begin
        if (~nreset_i) begin
            state_o <= 3'b000;
            additional_state_o <= 3'b000;
            error_num_o <= 4'b0000;
        end
        else begin
            state_o <= next_state_i;
            additional_state_o <= next_additional_state_i;
            error_num_o <= next_error_num_i;
        end
    end
endmodule

module OutputComb(
    input [2:0] state_i,
    input [2:0] additional_state_i,

    output shuffle_init_o,
    output mem_rst_o,
    output mem_sl_o,
    output buff_rst_o,
    output buff_sl_o,
    output reg locked_o
    );

    localparam [2:0] noop_mode = 3'b000;
    localparam [2:0] set_psw_mode = 3'b001;
    localparam [2:0] confirm_psw_mode = 3'b010;
    localparam [2:0] challenge_mode = 3'b011;
    localparam [2:0] shuffle_mode = 3'b100;
    localparam [2:0] locked_mode = 3'b101;
    localparam [2:0] unlocked_mode = 3'b110;

    wire mem_write, buff_write;

    assign mem_write = state_i == set_psw_mode;
    assign buff_write = state_i[2:1] == 2'b01;
    
    assign shuffle_init_o = (state_i == shuffle_mode) & additional_state_i[2];
    assign mem_rst_o = mem_write & additional_state_i[1];
    assign mem_sl_o = mem_write & additional_state_i[0];
    assign buff_rst_o = buff_write & additional_state_i[1];
    assign buff_sl_o = buff_write & additional_state_i[0];
    
    always @(*) begin
        case(state_i) 
            shuffle_mode: begin
                if (additional_state_i[1:0] == 2'b11) locked_o = 1;
                else locked_o = 0;
            end
            locked_mode: locked_o = 1;
            default: locked_o = 0;
        endcase
    end


endmodule
    
module ClkCounterEnableComb(
    input [2:0] state_i,
    input [2:0] additional_state_i,
    input confirm_in_i,
    input shuffle_in_i,

    output reg count_en_o,
    output count_rst_o
    );

    localparam [2:0] noop_mode = 3'b000;
    localparam [2:0] set_psw_mode = 3'b001;
    localparam [2:0] confirm_psw_mode = 3'b010;
    localparam [2:0] challenge_mode = 3'b011;
    localparam [2:0] shuffle_mode = 3'b100;
    localparam [2:0] locked_mode = 3'b101;
    localparam [2:0] unlocked_mode = 3'b110;

    assign count_rst_o = additional_state_i[2];
    always @(*) begin
        case (state_i)
            shuffle_mode: count_en_o = 1;
            confirm_psw_mode: count_en_o = shuffle_in_i;
            challenge_mode: count_en_o = shuffle_in_i;
            set_psw_mode: count_en_o = shuffle_in_i;
            unlocked_mode: count_en_o = confirm_in_i;
            default: count_en_o = 0;
        endcase
    end
endmodule


module ClkCounter(/*AUTOARG*/ // former 'clk_control'
    // Outputs
    clk_num,
    // Inputs
    clk, clk_num_rst, enable, rstn
    );
    input clk;
    input clk_num_rst; // synchronous reset at 1
    input enable;
    input rstn; // asynchronous reset at 0
    output reg [31:0] clk_num; // = 0; 

    always @(posedge clk or negedge rstn) begin
        if (~rstn) clk_num <= 32'b0; // priority: rstn > clk_num_rst > enable
        else if (clk_num_rst) clk_num <= 32'b0;
        else if (enable & clk_num != 32'hffffffff) clk_num <= clk_num + 1;
        else clk_num <= clk_num;
    end

   
endmodule // clk_control 

