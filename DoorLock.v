`include "button_reg.v"
`include "reged_pw.v"
`include "display_reg.v"
`include "Comparators.v"
`include "Head.v"
`include "input_save.v"

module DoorLock(
    input [9:0] digit_buttons,
    input confirm_button,
    input shuffle_button,

    input clk,
    input rstn,
    
    output locked
    );

    wire same, master_same, input_valid, buff_limit, mem_limit;
    // outputs of control unit
    wire [31:0] clk_count;
    wire shuffle_init, mem_rst, mem_sl, buff_rst, buff_sl;
    wire [3:0] digit_button_input_index;
    wire [127:0] master_psw, input_buffer, psw_memory;
    wire [3:0] actual_button_input;
    
    assign master_psw = 128'hffffffffffffffffffffffffffff2718;

    button_reg ButtonsEncoder(
        .index(digit_button_input_index),
        .input_v(input_valid),
        .button(digit_buttons),
        .clk(clk),
        .rstn(rstn)
    );

    display_reg ButtonsInterPreter(
        .clk(clk),
        .rstn(rstn),
        .button_index(digit_button_input_index),
        .shuffle_init(shuffle_init),
        .clk_count(clk_count),
        .data_out(actual_button_input)
    );

    input_save InputBuffer( 
        .clk(clk),
        .buff_rst(buff_rst),
        .rstn(rstn), // master asynchronous reset
        .data(actual_button_input),
        .buff_sl(buff_sl),
        .data_out(input_buffer),
        .buff_limit(buff_limit)
    );

    // basically the same thing actually
    reged_pw PWMemory(
        .clk(clk),
        .rstn(rstn),
        .mem_rst(mem_rst),
        .mem_sl(mem_sl),
        .data_in(actual_button_input),
        .data_out1(psw_memory), 
        .mem_limit(mem_limit)
    );

    Comparators EqualDetector(
        .master_same(master_same),
        .same(same),
        .input_value(input_buffer),
        .ans(psw_memory),
        .master_ans(master_psw)
    );

    ControlUnit Brain(
        .confirm_i(confirm_button),
        .shuffle_i(shuffle_button),
        .same_i(same),
        .master_same_i(master_same),
        .input_valid_i(input_valid),
        .buff_limit_i(buff_limit),
        .mem_limit_i(mem_limit),

        .clk_i(clk),
        .nreset_i(rstn),

        .clk_count_o(clk_count),
        .shuffle_init_o(shuffle_init),
        .mem_rst_o(mem_rst),
        .mem_sl_o(mem_sl),
        .buff_rst_o(buff_rst),
        .buff_sl_o(buff_sl),
        .locked_o(locked)
    );

endmodule

    