// the input buffer. 

module input_save(
    input wire clk,
    input wire buff_rst,
    input wire rstn, // master asynchronous reset
    input wire buff_sl,
    input wire [3:0] data,
    output wire [127:0] data_out,
    // output reg [127:0] data_out,
    // output reg [3:0] msb,
    output wire buff_limit
    );

    reg [127:0] saver;

    always @ (posedge clk or negedge rstn) begin
        if (~rstn) saver <= 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

        else if (buff_rst) begin
            saver <= 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        end

        else if (buff_sl) begin
            saver <= (saver << 4) | data;
            
        end

        else saver <= saver;
    end

    /* always @ (*) begin
        msb <= saver[127:124];
        data_out <= saver;
    end */

    assign buff_limit = saver[127:124] != 4'b1111;
    assign data_out = saver;

endmodule