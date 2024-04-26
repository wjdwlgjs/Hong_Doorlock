module dis_clk_counter(
    input wire clk,
    input wire shuffle_init,
    output reg [3:0] count_out
    );

    // Counter variable
    reg [3:0] count = 0;

    // Count logic
    always @(posedge clk) begin
        if (shuffle_init) begin
            if (count < 10) begin
                count = count + 1; // Increment counter if below maximum
            end
        end 
        else begin
            count = 0; // Reset counter when A is low
        end
    end

    // Output assignment
    always @(negedge clk) begin
        count_out <= count; // Update output with current count
    end

endmodule