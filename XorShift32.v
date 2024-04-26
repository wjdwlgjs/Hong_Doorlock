module XorShift32( // pseudorandom number generator based on xorshift-32 algorithm
    input [31:0] seed_i,
    input collect_seed_i,
    input clk_i,
    input nreset_i,

    output [31:0] prn_o
    );

    reg [31:0] state;

    wire [31:0] first_stage;
    wire [31:0] second_stage;
    wire [31:0] third_stage;

    assign first_stage = state ^ {state[18:0], 13'b0}; // state ^= state << 13;
    assign second_stage = first_stage ^ {7'b0, first_stage[31:7]}; // state ^= state >> 7;
    assign third_stage = second_stage ^ {state[14:0], 17'b0}; // state ^= state << 17;

    always @(posedge clk_i or negedge nreset_i) begin
        if (~nreset_i) state <= 31'b0;
        else if (collect_seed_i) state <= seed_i;
        else state <= third_stage;
    end

    assign prn_o = third_stage;
endmodule

