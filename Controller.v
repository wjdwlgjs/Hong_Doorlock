// We can expect the hardware to look something like this:
//                        _________________      ___________
//                       |                 |    |           |        
//                       |  counter        |    |           |
//     cur_state-------->|  enable/reset   |----|  clk      |____
//     confirm_in------->|  combinational  |----|  counter  |    |
//     shuffle_in------->|  circuit        |    |           |    |
//                       |_________________|    |___________|    | clk_count   
//                                                     |         |
//                                                     |clk      |
//                                                               |
//                                                               |
//                             __________________________________|__________
//                            |                                             |-----------> seed
//                            |              cur state                      |
//                            |              to counter enable circuit      |
//                            |                        ^                    |
//                            |    ____________________|                    |
//                            |   |                    | cur, prev          |
//                        ____v___v________      ______|_____      _________v_______
//     confirm_released->|                 |    |            |    |                 |
//     shuffle_released->|  next state     |    |  mode      |    |                 |---> decision
//     same------------->|  combinational  |    |  state     |    |  output         |---> shuffle_init
//     master_same------>|  circuit        |--->|  register  |--->|  combinational  |---> mem_rst
//     input_valid------>|                 |    | (cur, prev,|    |  circuit        |---> buff_rst
//     buff_limit------->|                 |    |  output)   |    |                 |---> buff_sl
//     mem_limit-------->|_________________|    |____________|    |_________________|---> mem_sl
//                                                        |            
//                                                        |clk         


module Controller(
    input clk, 
    input rstn, 
    input confirm_in, 
    input shuffle_in, 
    input same, 
    input master_same,
    input input_valid, 
    input error_num, 
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

    reg [2:0] cur_state;
    reg [2:0] output_state;
    reg [2:0] prev_state;
    reg [31:0] clk_count;

    wire confirm_released, shuffle_released;

    button_1bit_neg confirm_out(
        .out(confirm_released),
        .in(confirm_in),
        .clk(clk)
    );
    button_1bit_neg shuffle_out(
        .out(shuffle_released),
        .in(shuffle_in),
        .clk(clk)
    );


    // next state comb circuit + state register
    always @(negedge clk or negedge rstn) begin 
        if (~rstn) cur_state <= noop_mode; 
        else begin
            case(cur_state)
                noop_mode: begin
                    cur_state <= set_psw_mode;
                    prev_state <= set_psw_mode;
                    output_state <= mem_rst_outpu;
                end

                set_psw_mode: begin
                    if (shuffle_released) begin // shuffle == 1, others: x
                        cur_state <= shuffle_mode;
                        prev_state <= cur_state;
                        // It is recommended that we always use '<='(non-blocking) instead of '='(blocking) when making sequential logic circuits
                        // these two lines will result in cur_state == shuffle_mode, prev_state == set_psw_mode, which is what we expect.
                        // If we use blocking statements like these:
                        //     cur_state = shuffle_mode;
                        //     prev_state = cur_state;
                        // we get a result of cur_state == shuffle_mode, prev_state == shuffle_mode.
                        // Not only is this far from what we expect, it is more difficult to realize into hardware, because this isn't a software in which we have our 'variable's stored in RAMs. 
                        output_state <= shuffle_init_output;
                    end

                    else if (confirm_released) begin // shuffle == 0, confirm_released == 1, others: x (confirm_released has more priority than input_valid)
                        cur_state <= confirm_psw_mode;
                        prev_state <= cur_state;
                        output_state <= buff_reset_output;
                    end

                    else begin // shuffle == 0, confirm_released == 0, others: x
                        cur_state <= cur_state;
                        prev_state <= prev_state;
                        output_state <= {input_valid & ~mem_limit, input_valid & mem_limit, 0};
                    end
                end

                confirm_psw_mode: begin
                    if (shuffle_released) begin // shuffle_released == 1, others: x
                        cur_state <= shuffle_mode;
                        prev_state <= cur_state;
                        output_state <= shuffle_init_output;
                    end

                    else if (confirm_released) begin // shuffle_released == 0, confirm_released == 1, others: x
                        if (same) begin // shuffle_released == 0, confirm_released == 1, same == 1, others: x
                            cur_state <= locked_mode;
                            prev_state <= cur_state;
                            output_state <= allzero_outputs;
                        end
                        else begin // shuffle_released == 0, confirm_released == 1, same == 0, others: x
                            cur_state <= set_psw_mode;
                            prev_state <= cur_state;
                            output_state <= mem_rst_output;
                        end
                    end

                    else begin // shuffle_released ==0, confirm_released == 0, others: x
                        cur_state <= cur_state;
                        prev_state <= prev_state;
                        output_state <= {input_valid & ~mem_limit, input_valid & mem_limit, 1};
                    end
                end

                shuffle_mode: begin
                    if (clk_count == 32'b1010) begin // clk_count == 10, others: x
                        prev_state <= cur_state;
                        cur_state <= prev_state;
                        output_state <= allzero_outputs;
                    end
                    else begin // clk_count != 0, others: x
                        prev_state <= prev_state;
                        cur_state <= cur_state;
                        output_state <= allzero_outputs;
                    end
                end

                locked_mode: begin
                    if (confirm_released) begin // confirm_released == 1, others: x
                        cur_state <= challenge_mode;
                        prev_state <= cur_state;
                        output_state <= buff_rst_state;
                    end
                    else begin // confirm_released == 0, others: x
                        cur_state <= cur_state;
                        prev_state <= prev_state;
                        output_state <= allzero_outputs;
                    end
                end

                challenge_mode: begin
                    if (shuffle_released) begin // shuffle_released == 1, others: x
                        cur_state <= shuffle_mode;
                        prev_state <= cur_state;
                        output_state <= allzero_outputs;
                    end
                    else if (confirm_released) begin // shuffle_released == 0, confirm_released == 1, others: x
                        if ((same & (error_num < 4'b1010)) | master_same) begin 
                            cur_state <= unlocked_mode;
                            prev_state <= cur_state;
                            output_state <= allzero_outputs;
                        end
                        else begin
                            cur_state <= locked_mode;
                            prev_state <= cur_state;
                            output_state <= allzero_outputs;
                        end
                    end
                    else if (input_valid) begin // shuffle_released == 0, confirm_released == 0, input_valid == 1, others: x
                        if (limit) begin // shuffle_released == 0, confirm_released == 0, input_valid == 1, limit == 1, others: x
                            cur_state <= locked_mode;
                            prev_state <= cur_state;
                            output_state <= allzero_outputs;
                        end
                        else begin // shuffle_released == 0, confirm_released == 0, input_valid == 1, limit == 0, others: x
                            cur_state <= cur_state;
                            prev_state <= prev_state;
                            output_state <= buff_sl_output;
                        end
                    end
                    else begin // shuffle_released == 0, confirm_released == 0, input_valid == 0, others: x
                        cur_state <= cur_state;
                        prev_state <= prev_state;
                        output_state <= allzero_outputs;
                    end
                end
                unlocked_mode: begin
                    if (confirm_released) begin
                        if (clk_count < 32'b1011011100011011000000) begin // confirm_released == 1, clk_count <= 3seconds, others: x
                            cur_state <= locked_mode;
                            prev_state <= cur_state;
                            output_state <= allzero_outputs;
                        end
                        else begin // confirm_released == 0, clk_count > 3seconds, others: x
                            cur_state <= set_psw_mode;
                            prev_state <= cur_state;
                            output_state <= mem_rst_output;
                        end
                    end
                    else begin
                        cur_state <= cur_state;
                        prev_state <= prev_state;
                        output_state <= allzero_outputs;
                    end
                end
            endcase
        end
    end

    // output combinational circuit
    assign seed = clk_count;
    assign decision = cur_state == set_psw_mode;
    assign shuffle_init = output_state == shuffle_init_output;
    assign mem_rst = output_state == mem_rst_output;
    assign buff_rst = output_state == buff_rst_output;
    assign buff_sl = output_state == buff_sl_output;
    assign mem_sl = output_state == mem_sl_output;

    // counter enable/reset circuit + counter

    always @(negedge clk or negedge rstn) begin
        if (~rstn) clk_count <= 32'b0;
        else begin
            case (cur_state) 
                noop_mode: clk_count <= 32'b0;
                set_pw_mode: clk_count <= clk_count + {31'b0, shuffle_in};
                confirm_pw_mode: clk_count <= clk_count + {31'b0, shuffle_in};
                shuffle_mode: clk_count <= clk_count + 1;
                locked_mode: clk_count <= 32'b0;
                challenge_mode: clk_count <= clk_count + {31'b0, shuffle_in};
                unlocked_mode: clk_count <= clk_count + {31'b0, confirm_in};
            endcase
        end
    end

endmodule




                    



                    




                        
                        
                        

