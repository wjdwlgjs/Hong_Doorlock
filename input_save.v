// the input buffer. 

module input_save(/*AUTOWIRE*/);
    input wire clk;
    input wire buff_rst;
    input wire rstn; // master asynchronous reset
    input wire input_v;
    input wire decision;
    input wire [3:0] data;
    output reg [127:0] data_out;
    output reg [3:0] msb;

    reg [127:0] saver;

    always @ (posedge clk or negedge rstn) begin
        if (~rstn) saver <= 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

        else if (buff_rst) begin
            saver <= 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        end

        else if (input_v && decision) begin
            saver <= (saver << 4) | data;
            
        end

        else saver <= saver;
    end

    always @ (*) begin
        msb <= saver[127:124];
        data_out <= saver;
    end

endmodule