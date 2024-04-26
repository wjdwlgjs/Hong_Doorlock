module RandomShuffler(
    input clk,
    input shuffle_init,
    input [31:0] seed,
    input [3:0] limit,
    input rstn,
    
    output [3:0] prn4
    );

    wire [31:0] prn32;

    XorShift32 XorShiftInst(
        .seed_i(seed),
        .collect_seed_i(shuffle_init),
        .clk_i(clk),
        .nreset_i(rstn),

        .prn_o(prn32)
    );

    reg [3:0] limit_plusone;

    always @(*) begin
        case(limit)
            4'b0: limit_plusone <= 4'b1;
            4'b1: limit_plusone <= 4'b10;
            4'b10: limit_plusone <= 4'b11;
            4'b11: limit_plusone <= 4'b100;
            4'b100: limit_plusone <= 4'b101;
            4'b101: limit_plusone <= 4'b110;
            4'b110: limit_plusone <= 4'b111;
            4'b111: limit_plusone <= 4'b1000;
            4'b1000: limit_plusone <= 4'b1001;
            4'b1001: limit_plusone <= 4'b1010;
            default: limit_plusone <= 4'b0001;
        endcase
    end

    Modulo32to4Bit RemainderCalculator(
        .target_i(prn32),
        .modular_i(limit_plusone),

        .result_o(prn4)
    );

endmodule

// pseudorandom number generator based on xorshift-32 algorithm
module XorShift32( 
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
    assign third_stage = second_stage ^ {second_stage[14:0], 17'b0}; // state ^= state << 17;

    always @(posedge clk_i or negedge nreset_i) begin
        if (~nreset_i) state <= 31'b0;
        else if (collect_seed_i) state <= seed_i;
        else state <= third_stage;
    end

    assign prn_o = third_stage;
endmodule

module ModuloAdder(
    input [3:0] first_operand_i,
    input [3:0] second_operand_i, // these operands must be smaller than the modular
    input [3:0] modular_i,

    output [3:0] sum_o
    );

    wire [4:0] temp_sum;
    assign temp_sum = {1'b0, first_operand_i} + {1'b0, second_operand_i}; // a + b;
    wire [4:0] mod_sum;
    assign mod_sum = temp_sum - {1'b0, modular_i}; // a + b - m; this is always smaller than 13. If this is a negative number (first bit is 1), then a + b is between 0 abd m-1. So we output a + b. Else, a + b is m or larger, and this is between 0 and m-2. so we output this one.

    assign sum_o = {4{mod_sum[4]}} & temp_sum | ~{4{mod_sum[4]}} & mod_sum[3:0];

endmodule


module Modulo32to4Bit(
    input [31:0] target_i,
    input [3:0] modular_i,

    output [3:0] result_o
    );

    // Doing '%' operation to large-size PRNs achives limiting the range of the generated PRN without introducing too much bias to the probabilities of all possible outputs.
    // A divider circuit can do it, but I belive it must be much simpler (more complex to code, but simpler in hardware level) to make use of the fact that ((a % m) + (b % m)) % m == (a + b) % m

    // For example, if we want to operate 8'b01100110 % 4'd10, we can do it by calculating 2^6 % 10 + 2^5 % 10 + 2^2 % 10 + 2^1 % 10
    // or, in a more general form, (2^7 % 10) & 4'b0000 + (2^6 % 10) & 4'b1111 + (2^5 % 10) & 4'b1111 + (2^4 % 10) & 4'b0000 + (2^3 % 10) & 4'b0000 + (2^2 % 10) & 4'b1111 + (2^1 % 10) & 4'b1111 + (2^0 % 10) & 4'b0000
    // or, by following the pseudocode below:
    
    //     sum = 0
    //     for i in 0..31
    //         sum = (sum + target[i] * (2^i % m)) % m

    // This can be done more efficiently with less gate delays with the following binary-tree-like structure, than adding them one by one
    //     
    //      (2^7 % 10) & 4'b0000        (2^6 % 10) & 4'b1111        (2^5 % 10) & 4'b1111        (2^4 % 10) & 4'b0000        (2^3 % 10) & 4'b0000        (2^2 % 10) & 4'b1111        (2^1 % 10) & 4'b1111        (2^0 % 10) & 4'b0000  
    //                \                          /                            \                          /                            \                          /                            \                          /
    //                 \________        ________/                              \________        ________/                              \________        ________/                              \________        ________/
    //                          \      /                                                \      /                                                \      /                                                \      /
    //                           \    /                                                  \    /                                                  \    /                                                  \    /  
    //                        Modulo Adder                                            Modulo Adder                                            Modulo Adder                                            Modulo Adder  
    //                              \                                                      /                                                        \                                                      /
    //                               \______________________        ______________________/                                                          \______________________        ______________________/
    //                                                      \      /                                                                                                        \      /
    //                                                       \    /                                                                                                          \    /
    //                                                    Modulo Adder                                                                                                    Modulo Adder  
    //                                                          \                                                                                                              /
    //                                                           \__________________________________________________        __________________________________________________/    
    //                                                                                                              \      /
    //                                                                                                               \    /
    //                                                                                                            Modulo Adder  
    //                                                                                                                  |
    //                                                                                                                  |
    //                                                                                                          final modulo sum

    // In our case in which the input is 32-bit, adding-one-by-one method requires 31 modulo adders, and 32 times the gate delay of a single modulo adder to generate the result, 
    // while my binary tree method requires 31 modulo adders, and only 5 times the gate delay of a single modulo adder to generate the result.

    // in predefined, {2^31 % m, 2^30 % m, 2^29 % m, ... 2 % m, 1 % m} is stored. 
    reg [127:0] predefined;

    always @(*) begin
        case({modular_i})
            4'b1: predefined <= {4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0};
            4'b10: predefined <= {4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b1};
            4'b11: predefined <= {4'b10, 4'b1, 4'b10, 4'b1, 4'b10, 4'b1, 4'b10, 4'b1, 4'b10, 4'b1, 4'b10, 4'b1, 4'b10, 4'b1, 4'b10, 4'b1, 4'b10, 4'b1, 4'b10, 4'b1, 4'b10, 4'b1, 4'b10, 4'b1, 4'b10, 4'b1, 4'b10, 4'b1, 4'b10, 4'b1, 4'b10, 4'b1};
            4'b100: predefined <= {4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b10, 4'b1};
            4'b101: predefined <= {4'b11, 4'b100, 4'b10, 4'b1, 4'b11, 4'b100, 4'b10, 4'b1, 4'b11, 4'b100, 4'b10, 4'b1, 4'b11, 4'b100, 4'b10, 4'b1, 4'b11, 4'b100, 4'b10, 4'b1, 4'b11, 4'b100, 4'b10, 4'b1, 4'b11, 4'b100, 4'b10, 4'b1, 4'b11, 4'b100, 4'b10, 4'b1};
            4'b110: predefined <= {4'b10, 4'b100, 4'b10, 4'b100, 4'b10, 4'b100, 4'b10, 4'b100, 4'b10, 4'b100, 4'b10, 4'b100, 4'b10, 4'b100, 4'b10, 4'b100, 4'b10, 4'b100, 4'b10, 4'b100, 4'b10, 4'b100, 4'b10, 4'b100, 4'b10, 4'b100, 4'b10, 4'b100, 4'b10, 4'b100, 4'b10, 4'b1};
            4'b111: predefined <= {4'b10, 4'b1, 4'b100, 4'b10, 4'b1, 4'b100, 4'b10, 4'b1, 4'b100, 4'b10, 4'b1, 4'b100, 4'b10, 4'b1, 4'b100, 4'b10, 4'b1, 4'b100, 4'b10, 4'b1, 4'b100, 4'b10, 4'b1, 4'b100, 4'b10, 4'b1, 4'b100, 4'b10, 4'b1, 4'b100, 4'b10, 4'b1};
            4'b1000: predefined <= {4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b100, 4'b10, 4'b1};
            4'b1001: predefined <= {4'b10, 4'b1, 4'b101, 4'b111, 4'b1000, 4'b100, 4'b10, 4'b1, 4'b101, 4'b111, 4'b1000, 4'b100, 4'b10, 4'b1, 4'b101, 4'b111, 4'b1000, 4'b100, 4'b10, 4'b1, 4'b101, 4'b111, 4'b1000, 4'b100, 4'b10, 4'b1, 4'b101, 4'b111, 4'b1000, 4'b100, 4'b10, 4'b1};
            4'b1010: predefined <= {4'b1000, 4'b100, 4'b10, 4'b110, 4'b1000, 4'b100, 4'b10, 4'b110, 4'b1000, 4'b100, 4'b10, 4'b110, 4'b1000, 4'b100, 4'b10, 4'b110, 4'b1000, 4'b100, 4'b10, 4'b110, 4'b1000, 4'b100, 4'b10, 4'b110, 4'b1000, 4'b100, 4'b10, 4'b110, 4'b1000, 4'b100, 4'b10, 4'b1};       
            4'b1011: predefined <= {4'b10, 4'b1, 4'b110, 4'b11, 4'b111, 4'b1001, 4'b1010, 4'b101, 4'b1000, 4'b100, 4'b10, 4'b1, 4'b110, 4'b11, 4'b111, 4'b1001, 4'b1010, 4'b101, 4'b1000, 4'b100, 4'b10, 4'b1, 4'b110, 4'b11, 4'b111, 4'b1001, 4'b1010, 4'b101, 4'b1000, 4'b100, 4'b10, 4'b1};
            4'b1100: predefined <= {4'b1000, 4'b100, 4'b1000, 4'b100, 4'b1000, 4'b100, 4'b1000, 4'b100, 4'b1000, 4'b100, 4'b1000, 4'b100, 4'b1000, 4'b100, 4'b1000, 4'b100, 4'b1000, 4'b100, 4'b1000, 4'b100, 4'b1000, 4'b100, 4'b1000, 4'b100, 4'b1000, 4'b100, 4'b1000, 4'b100, 4'b1000, 4'b100, 4'b10, 4'b1};
            4'b1101: predefined <= {4'b1011, 4'b1100, 4'b110, 4'b11, 4'b1000, 4'b100, 4'b10, 4'b1, 4'b111, 4'b1010, 4'b101, 4'b1001, 4'b1011, 4'b1100, 4'b110, 4'b11, 4'b1000, 4'b100, 4'b10, 4'b1, 4'b111, 4'b1010, 4'b101, 4'b1001, 4'b1011, 4'b1100, 4'b110, 4'b11, 4'b1000, 4'b100, 4'b10, 4'b1};    
            4'b1110: predefined <= {4'b10, 4'b1000, 4'b100, 4'b10, 4'b1000, 4'b100, 4'b10, 4'b1000, 4'b100, 4'b10, 4'b1000, 4'b100, 4'b10, 4'b1000, 4'b100, 4'b10, 4'b1000, 4'b100, 4'b10, 4'b1000, 4'b100, 4'b10, 4'b1000, 4'b100, 4'b10, 4'b1000, 4'b100, 4'b10, 4'b1000, 4'b100, 4'b10, 4'b1};        
            4'b1111: predefined <= {4'b1000, 4'b100, 4'b10, 4'b1, 4'b1000, 4'b100, 4'b10, 4'b1, 4'b1000, 4'b100, 4'b10, 4'b1, 4'b1000, 4'b100, 4'b10, 4'b1, 4'b1000, 4'b100, 4'b10, 4'b1, 4'b1000, 4'b100, 4'b10, 4'b1, 4'b1000, 4'b100, 4'b10, 4'b1, 4'b1000, 4'b100, 4'b10, 4'b1};
            4'b0000: predefined <= {4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b1000, 4'b100, 4'b10, 4'b1};
            // assume 4'b0000 input is actually 5'b10000
        endcase
    end

    // filtered layer stores predefined values times target[i]
    wire [127:0] filtered;
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin: predefined_filter
            assign filtered[4*i+3 : 4*i] = {4{target_i[i]}} & predefined[4*i+3 : 4*i];
        end
    endgenerate

    wire [63:0] first_layer;
    generate
        for (i = 0; i < 16; i = i + 1) begin: first_layer_connection
            ModuloAdder ModAdderInst1(
                .first_operand_i(filtered[i*8+7 : i*8+4]),
                .second_operand_i(filtered[i*8+3 : i*8]),
                .modular_i(modular_i),

                .sum_o(first_layer[4*i+3 : 4*i])
            );
        end
    endgenerate

    wire [31:0] second_layer;
    generate
        for (i = 0; i < 8; i = i + 1) begin: second_layer_connection
            ModuloAdder ModAdderInst2(
                .first_operand_i(first_layer[i*8+7 : i*8+4]),
                .second_operand_i(first_layer[i*8+3 : i*8]),
                .modular_i(modular_i),
                
                .sum_o(second_layer[4*i+3 : 4*i])
            );
        end
    endgenerate

    wire [15:0] third_layer;
    generate
        for (i = 0; i < 4; i = i + 1) begin: third_layer_connection
            ModuloAdder ModAdderInst3(
                .first_operand_i(second_layer[i*8+7 : i*8+4]),
                .second_operand_i(second_layer[i*8+3 : i*8]),
                .modular_i(modular_i),

                .sum_o(third_layer[i*4+3 : i*4])
            );
        end
    endgenerate

    wire [7:0] fourth_layer;
    generate 
        for (i = 0; i < 2; i = i + 1) begin: fouurth_layer_connection
            ModuloAdder ModAdderInst4(
                .first_operand_i(third_layer[i*8+7 : i*8+4]),
                .second_operand_i(third_layer[i*8+3 : i*8]),
                .modular_i(modular_i),

                .sum_o(fourth_layer[i*4+3 : i*4])
            );
        end
    endgenerate

    ModuloAdder ModAdderInstFinal(
        .first_operand_i(fourth_layer[7:4]),
        .second_operand_i(fourth_layer[3:0]),
        .modular_i(modular_i),

        .sum_o(result_o)
    );      

endmodule

module ReverseNineCounter(
    input rstn,
    input clk,
    input enable,
    output reg [3:0] count
    );

    always @(posedge clk or negedge rstn) begin
        if (~rstn) count <= 0;
        else begin
            if (~enable) count <= count;
            else begin
                case(count)
                    4'b1001: count <= 4'b1000;
                    4'b1000: count <= 4'b111;
                    4'b111: count <= 4'b110;
                    4'b110: count <= 4'b101;
                    4'b101: count <= 4'b100;
                    4'b100: count <= 4'b11;
                    4'b11: count <= 4'b10;
                    4'b10: count <= 4'b1;
                    4'b1: count <= 4'b0;
                    4'b0: count <= 4'b1001;
                    default: count <= 4'b1001;
                endcase
            end
        end
    end

endmodule