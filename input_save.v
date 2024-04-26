// the input buffer. 

module input_save(/*AUTOWIRE*/);
    input wire clk;
    input wire buff_rst;
    input wire input_v;
    input wire decision;
    input wire [3:0] data;
    output reg [127:0] data_out;
    output reg [3:0] msb;

    reg [127:0] saver;

    always @ (posedge clk) begin
        if (buff_rst) begin
            saver <= 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        end

        else begin
            if (input_v && decision) begin
                msb <= saver[127:124];
                saver <= (saver << 4) | data;
            end
        end
    end

    always @ (*) begin
        data_out <= saver;
    end

endmodule