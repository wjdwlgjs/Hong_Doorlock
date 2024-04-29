// We can expect the hardware to look something like this:
//                        _________________      ___________
//                       |                 |    |           |        
//                       |  counter        |    |           |
//     cur_state-------->|  enable/reset   |----|  clk      |____
//     confirm_in------->|  combinational  |----|  counter  |    |
//     shuffle_in------->|  circuit        |    |           |    |
//                       |_________________|    |___________|    | clk_count   
//                                                     |         |
//                                            clk, rstn|         |
//                                                               |
//                                                               |
//                             __________________________________|__________
//                            |                                             |-----------> seed
//                            |              cur_state                      |
//                            |              to counter enable circuit      |
//                            |                        ^                    |
//                            |    ____________________|                    |
//                            |   |                    | cur, prev          |
//                        ____v___v________      ______|_____      _________v_______
//     confirm_released->|                 |    |  state     |    |                 |
//     shuffle_released->|  next state     |    |  register  |    |                 |---> decision
//     same------------->|  combinational  |    | (cur, prev,|    |  output         |---> shuffle_init
//     master_same------>|  circuit        |--->| output,    |--->|  combinational  |---> mem_rst
//     input_valid------>|                 |    | err_num)   |    |  circuit        |---> buff_rst
//     buff_limit------->|                 |    |            |    |                 |---> buff_sl
//     mem_limit-------->|_________________|    |____________|    |_________________|---> mem_sl
//                                                       |            
//                                                       |~clk, rstn         


`include "button_release_detector.v"

module Controller(
    input clk, 
    input rstn, 
    input confirm_in, 
    input shuffle_in, 
    input same, 
    input master_same,
    input input_valid, 
    input buff_limit,
    input mem_limit,

    output shuffle_init, 
    output [31:0] seed, 
    output decision, 
    output mem_sl, 
    output buff_sl, 
    output mem_rst,
    output buff_rst
    );

    wire [2:0] cur_state;
    wire [2:0] output_state;
    wire [31:0] clk_count;

    wire confirm_released, shuffle_released;

    button_release_detector ConfirmDetector(
        .clk(clk),
        .rstn(rstn),
        .in(confirm_in),
        .out(confirm_released)
    );
    button_release_detector ShuffleDetector(
        .clk(clk),
        .rstn(rstn),
        .in(shuffle_in),
        .out(shuffle_released)
    );

    ControllerStateManager StateManager(
        .clk(clk),
        .rstn(rstn),
        .confirm_released(confirm_released),
        .shuffle_released(shuffle_released),
        .same(same),
        .master_same(master_same),
        .input_valid(input_valid),
        .buff_limit(buff_limit),
        .mem_limit(mem_limit),
        .clk_count(clk_count),

        .cur_state(cur_state),
        .output_state(output_state)
    );

    ControllerClkCounter ClkCounter(
        .clk(clk),
        .rstn(rstn),
        .cur_state(cur_state),
        .shuffle_in(shuffle_in),
        .confirm_in(confirm_in),

        .clk_count(clk_count)
    );

    ControllerOutputDecoder OutputDecoder(
        .output_state(output_state),
        .clk_count(clk_count),
        .cur_state(cur_state),
        .shuffle_init(shuffle_init),
        .seed(seed),
        .decision(decision),
        .mem_sl(mem_sl),
        .buff_sl(buff_sl),
        .mem_rst(mem_rst),
        .buff_rst(buff_rst)
    );
    
endmodule


module ControllerStateManager( // next state comb circuit + state register
    input clk, 
    input rstn, 
    input confirm_released,
    input shuffle_released,
    input same, 
    input master_same,
    input input_valid, 
    input buff_limit,
    input mem_limit,
    input [31:0] clk_count,

    output reg [2:0] cur_state,
    output reg [2:0] output_state
    ); 

    reg [2:0] prev_state;
    reg [3:0] error_num;

    localparam [2:0] noop_mode = 3'b000;
    localparam [2:0] set_psw_mode = 3'b001;
    localparam [2:0] confirm_psw_mode = 3'b010;
    localparam [2:0] shuffle_mode = 3'b011;
    localparam [2:0] locked_mode = 3'b100;
    localparam [2:0] challenge_mode = 3'b101;
    localparam [2:0] unlocked_mode = 3'b110;

    localparam [2:0] allzero_outputs = 3'b000;
    localparam [2:0] shuffle_init_output = 3'b111;
    localparam [2:0] mem_rst_output = 3'b010;
    localparam [2:0] buff_rst_output = 3'b011;
    localparam [2:0] mem_sl_output = 3'b100;
    localparam [2:0] buff_sl_output = 3'b101;

    localparam [3:0] error_limit = 4'b1010;

    always @(negedge clk or negedge rstn) begin 
        if (~rstn) cur_state <= noop_mode; 
        else begin
            case(cur_state)
                noop_mode: begin
                    cur_state <= set_psw_mode;
                    prev_state <= set_psw_mode;
                    output_state <= mem_rst_output;
                    error_num <= 4'b0000;
                end

                set_psw_mode: begin
                    if (shuffle_released) begin // shuffle == 1, others: x
                        // transition to shuffle mode, shuffle_init
                        cur_state <= shuffle_mode;
                        prev_state <= cur_state;
                        // It is recommended that we always use '<='(non-blocking) instead of '='(blocking) when making sequential logic circuits
                        // these two lines will result in cur_state == shuffle_mode, prev_state == set_psw_mode, which is what we expect.
                        // If we use blocking statements like these:
                        //     cur_state = shuffle_mode;
                        //     prev_state = cur_state;
                        // we get a result of cur_state == shuffle_mode, prev_state == shuffle_mode.
                        // Not only is this far from what we expect, it is more difficult to realize, because this isn't a software in which we have our 'variable's stored in RAMs. 
                        output_state <= shuffle_init_output;
                        error_num <= 4'b0000;
                    end

                    else if (confirm_released) begin // shuffle == 0, confirm_released == 1, others: x (confirm_released has more priority than input_valid)
                        // transition to confirm_psw mode, reset buffer
                        cur_state <= confirm_psw_mode;
                        prev_state <= cur_state;
                        output_state <= buff_rst_output;
                        error_num <= 4'b0000;
                    end

                    else begin // shuffle == 0, confirm_released == 0, others: x
                        // stay in current (set_psw) mode, reset memory if i.v. and mem_limit, sl memeory if i.v. and !mem_limit
                        cur_state <= cur_state;
                        prev_state <= prev_state;
                        output_state <= {input_valid & ~mem_limit, input_valid & mem_limit, 1'b0};
                        error_num <= 4'b0000;
                    end
                end

                confirm_psw_mode: begin
                    if (shuffle_released) begin // shuffle_released == 1, others: x
                        // transition to shuffle mode, shuffle_init
                        cur_state <= shuffle_mode;
                        prev_state <= cur_state;
                        output_state <= shuffle_init_output;
                        error_num <= 4'b0000;
                    end

                    else if (confirm_released) begin // shuffle_released == 0, confirm_released == 1, others: x
                        if (same) begin // shuffle_released == 0, confirm_released == 1, same == 1, others: x
                            // transition to locked mode, no output
                            cur_state <= locked_mode;
                            prev_state <= cur_state;
                            output_state <= allzero_outputs;
                            error_num <= 4'b0000;
                        end
                        else begin // shuffle_released == 0, confirm_released == 1, same == 0, others: x
                            // transition to set_psw mode, reset memory
                            cur_state <= set_psw_mode;
                            prev_state <= cur_state;
                            output_state <= mem_rst_output;
                            error_num <= 4'b0000;
                        end
                    end

                    else begin // shuffle_released ==0, confirm_released == 0, others: x
                        // stay in current(confirm_psw) mode, reset buffer if i.v. & buff_limit, sl buffer if i.v. & !buff_limit
                        cur_state <= cur_state;
                        prev_state <= prev_state;
                        output_state <= {input_valid & ~buff_limit, input_valid & buff_limit, 1'b1};
                        error_num <= 4'b0000;
                    end
                end

                shuffle_mode: begin
                    if (clk_count == 32'b1010) begin // clk_count == 10, others: x
                        // transition to previous mode, no output
                        prev_state <= cur_state;
                        cur_state <= prev_state;
                        output_state <= allzero_outputs;
                        error_num <= error_num;
                    end
                    else begin // clk_count != 0, others: x
                        // stay in current(shuffle) mode, no output
                        prev_state <= prev_state;
                        cur_state <= cur_state;
                        output_state <= allzero_outputs;
                        error_num <= error_num;
                    end
                end

                locked_mode: begin
                    if (confirm_released) begin // confirm_released == 1, others: x
                        // transition to challenge_mode, reset buffer
                        cur_state <= challenge_mode;
                        prev_state <= cur_state;
                        output_state <= buff_rst_output;
                        error_num <= error_num;
                    end
                    else begin // confirm_released == 0, others: x
                        // stay in current (locked) mode, no output
                        cur_state <= cur_state;
                        prev_state <= prev_state;
                        output_state <= allzero_outputs;
                        error_num <= error_num;
                    end
                end

                challenge_mode: begin
                    if (shuffle_released) begin // shuffle_released == 1, others: x
                        // transition to shuffle mode, shuffle init
                        cur_state <= shuffle_mode;
                        prev_state <= cur_state;
                        output_state <= shuffle_init_output;
                        error_num <= error_num;
                    end
                    else if (confirm_released) begin // shuffle_released == 0, confirm_released == 1, others: x
                        if ((same & (error_num != error_limit)) | master_same) begin 
                            // transition to unlocked mode, no output
                            cur_state <= unlocked_mode;
                            prev_state <= cur_state;
                            output_state <= allzero_outputs;
                            error_num <= 4'b0000;
                        end
                        else begin
                            // transition to locked mode, no output
                            cur_state <= locked_mode;
                            prev_state <= cur_state;
                            output_state <= allzero_outputs;
                            if (error_num == error_limit) error_num <= error_num;
                            else error_num <= error_num + 1;
                        end
                    end
                    else if (input_valid) begin // shuffle_released == 0, confirm_released == 0, input_valid == 1, others: x
                        if (buff_limit) begin // shuffle_released == 0, confirm_released == 0, input_valid == 1, limit == 1, others: x
                            // transition to locked mode, no output
                            cur_state <= locked_mode;
                            prev_state <= cur_state;
                            output_state <= allzero_outputs;
                            if (error_num == error_limit) error_num <= error_num;
                            else error_num <= error_num + 1;
                        end
                        else begin // shuffle_released == 0, confirm_released == 0, input_valid == 1, limit == 0, others: x
                            // stay in current (challenge) mode, shift left buffer
                            cur_state <= cur_state;
                            prev_state <= prev_state;
                            output_state <= buff_sl_output;
                            error_num <= error_num;
                        end
                    end
                    else begin // shuffle_released == 0, confirm_released == 0, input_valid == 0, others: x
                        // stay in current (challenge) mode, no output
                        cur_state <= cur_state;
                        prev_state <= prev_state;
                        output_state <= allzero_outputs;
                        error_num <= error_num;
                    end
                end
                unlocked_mode: begin
                    if (confirm_released) begin
                        if (clk_count < 32'b1011011100011011000000) begin // confirm_released == 1, clk_count < 3seconds, others: x
                            // transition to locked mode, no output
                            cur_state <= locked_mode;
                            prev_state <= cur_state;
                            output_state <= allzero_outputs;
                            error_num <= 4'b0000;
                        end
                        else begin // confirm_released == 0, clk_count > 3seconds, others: x
                            // transition to set_psw mode, reset memory
                            cur_state <= set_psw_mode;
                            prev_state <= cur_state;
                            output_state <= mem_rst_output;
                            error_num <= 4'b0000;
                        end
                    end
                    else begin
                        // stay in current (unlocked) mode, no output
                        cur_state <= cur_state;
                        prev_state <= prev_state;
                        output_state <= allzero_outputs;
                        error_num <= 4'b0000;
                    end
                end
            endcase
        end
    end
endmodule

module ControllerClkCounter(
    input clk, 
    input rstn,
    input [2:0] cur_state,
    input shuffle_in,
    input confirm_in,
    
    output reg [31:0] clk_count
    );

    // counter enable/reset circuit + counter

    localparam [2:0] noop_mode = 3'b000;
    localparam [2:0] set_psw_mode = 3'b001;
    localparam [2:0] confirm_psw_mode = 3'b010;
    localparam [2:0] shuffle_mode = 3'b011;
    localparam [2:0] locked_mode = 3'b100;
    localparam [2:0] challenge_mode = 3'b101;
    localparam [2:0] unlocked_mode = 3'b110;

    always @(posedge clk or negedge rstn) begin
        if (~rstn) clk_count <= 32'b0;
        else begin
            case (cur_state) 
                noop_mode: clk_count <= 32'b0;
                set_psw_mode: clk_count <= clk_count + {31'b0, shuffle_in};
                confirm_psw_mode: clk_count <= clk_count + {31'b0, shuffle_in};
                shuffle_mode: clk_count <= clk_count + 1;
                locked_mode: clk_count <= 32'b0;
                challenge_mode: clk_count <= clk_count + {31'b0, shuffle_in};
                unlocked_mode: clk_count <= clk_count + {31'b0, confirm_in};
            endcase
        end
    end

endmodule
    
module ControllerOutputDecoder(
    input [2:0] output_state,
    input [31:0] clk_count,
    input [2:0] cur_state,

    output shuffle_init, 
    output [31:0] seed, 
    output decision, 
    output mem_sl, 
    output buff_sl, 
    output mem_rst,
    output buff_rst
    );

    localparam [2:0] allzero_outputs = 3'b000;
    localparam [2:0] shuffle_init_output = 3'b111;
    localparam [2:0] mem_rst_output = 3'b010;
    localparam [2:0] buff_rst_output = 3'b011;
    localparam [2:0] mem_sl_output = 3'b100;
    localparam [2:0] buff_sl_output = 3'b101;

    localparam [2:0] set_psw_mode = 3'b001;

    // output combinational circuit
    assign seed = clk_count;
    assign decision = cur_state == set_psw_mode;
    assign shuffle_init = output_state == shuffle_init_output;
    assign mem_rst = output_state == mem_rst_output;
    assign buff_rst = output_state == buff_rst_output;
    assign buff_sl = output_state == buff_sl_output;
    assign mem_sl = output_state == mem_sl_output;

endmodule


                    




                        
                        
                        

