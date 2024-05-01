module reged_pw(
    input wire clk,
    input rstn,
    input wire mem_rst,
    input wire mem_sl,
    // input wire decision,
    input wire [3:0] data_in,
    output reg [127:0] data_out1, // =128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, does this work?
    // output reg [3:0] msb1=4'hf
    output mem_limit
);

// 128-bit register to store the data
reg [127:0] register; // =128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

always @(posedge clk or negedge rstn) begin
    if (~rstn) begin
        // Asynchronous reset: Set all bits to 1s
        register <= 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    end 

    else if (mem_rst)  begin // synchronous reset 
        register <= 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    end
    
    else if (mem_sl) begin
        // Operate only when both A and B are 1
        register <= {register[123:0], data_in};
    
    end

    else register <= register;
end

always @(*) begin
    data_out1 = register; // Continuously output the current state of the register
end

assign mem_limit = (register[127:124] != 4'b1111);

endmodule
