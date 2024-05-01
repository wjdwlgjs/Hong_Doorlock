`timescale 1ns/1ns
`include "display_reg.v"

module tb_display_reg();

    reg tb_clk;
    reg tb_rstn;
    reg [3:0] tb_button_index;
    reg tb_shuffle_init;
    reg [31:0] tb_clk_count;
    wire [3:0] tb_data_out;

    display_reg TestReg(
        .clk(tb_clk),
        .rstn(tb_rstn),
        .button_index(tb_button_index),
        .shuffle_init(tb_shuffle_init),
        .clk_count(tb_clk_count),
        .data_out(tb_data_out)
    );

    always @(posedge tb_clk) begin
        if (tb_shuffle_init) tb_clk_count <= 0;
        else tb_clk_count <= tb_clk_count + 1;
    end
    always @(posedge tb_shuffle_init) #10 tb_shuffle_init <= 0;

    always #5 tb_clk <= ~tb_clk;

    initial begin 
        $dumpfile("BuildFiles/tb_display_reg.vcd");
        $dumpvars(0, tb_display_reg);
        tb_clk = 0;
        tb_rstn = 0;
        tb_button_index = 4'b0;
        tb_shuffle_init = 0;
        tb_clk_count = 0;


        #10 tb_rstn = 1;

        #10 tb_shuffle_init = 1;

        #500
        $finish;
    end

endmodule