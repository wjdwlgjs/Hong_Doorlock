`timescale 1ns/1ns
`include "DoorLock/PRNG.v"

module tb_PRNG();
    reg [31:0] tb_seed;
    reg tb_shuffle_init;
    reg tb_clk;
    reg tb_nreset;
    reg [3:0] tb_limit;
    wire [3:0] tb_prn;

    RandomShuffler TestPRNG(
        .clk(tb_clk),
        .shuffle_init(tb_shuffle_init),
        .seed(tb_seed),
        .limit(tb_limit),
        .rstn(tb_nreset),
    
        .prn4(tb_prn)
    );
    
    always #5 tb_clk <= ~tb_clk;
    always #100 tb_shuffle_init <= 1;
    always @(posedge tb_clk) #4 tb_shuffle_init <= 0;

    always @(posedge tb_clk) #1 begin
        if (tb_limit == 4'b1001) tb_limit <= 4'b0000;
        else tb_limit <= tb_limit +1;
    end

    initial begin
        $dumpfile("DoorLock/BuildFiles/tb_PRNG.vcd");
        $dumpvars(0, tb_PRNG);

        tb_seed <= $random;
        tb_shuffle_init <= 0;
        tb_clk <= 0;
        tb_nreset <= 0;
        tb_limit <= 0;
        #1
        tb_nreset <= 1;

        #2000
        $finish;
    end
endmodule

        




/* module tb_PRNG();

    reg [31:0] tb_seed;
    reg tb_collect_seed;
    reg tb_clk;
    reg tb_nreset;
    wire [31:0] tb_prn;

    XorShift32 PRNGInst(
        .seed_i(tb_seed),
        .collect_seed_i(tb_collect_seed),
        .clk_i(tb_clk),
        .nreset_i(tb_nreset),

        .prn_o(tb_prn)
    );

    // always @(negedge tb_clk) tb_seed <= $random;
    always #5 tb_clk <= ~tb_clk;
    always #100 begin 
        #1 tb_collect_seed <= 1;
        #9 tb_collect_seed <= 0;
    end


    initial begin
        $dumpfile("DoorLock/BuildFiles/tb_PRNG.vcd");
        $dumpvars(0, tb_PRNG);

        tb_seed <= 1;
        tb_collect_seed <= 0;
        tb_clk <= 0;
        tb_nreset <= 0;

        #1 tb_nreset <= 1;

        #999
        $finish;
    end
endmodule */


/* module tb_PRNG();

    reg [31:0] tb_target;
    reg [3:0] tb_modular;
    wire [3:0] tb_result;
    reg [3:0] tb_verify;
    wire verification_bit;

    always @(*) begin 
        if (tb_modular == 4'b0000) tb_verify <= 4'b0000;
        else tb_verify <= tb_target % {28'b0, tb_modular};
    end
    always #10 begin
        tb_target <= $random;
        tb_modular <= $random;
    end

    assign verification_bit = (tb_verify == tb_result);

    Modulo32to4Bit TestMod(
        .target_i(tb_target),
        .modular_i(tb_modular),

        .result_o(tb_result)
    );

    initial begin 
        $dumpfile("DoorLock/BuildFiles/tb_PRNG.vcd");
        $dumpvars(0, tb_PRNG);
        tb_target <= 0;
        tb_modular <= 0;

        #1000
        $finish;
    end

endmodule */

        


/* module tb_PRNG();

    reg [3:0] a;
    reg [3:0] b;
    reg [3:0] m;
    wire [3:0] sum;
    wire verify;
    assign verify = ({1'b0, sum} == (({1'b0, a} + {1'b0, b}) % {1'b0, m}));

    ModuloAdder TestAdder(
        .first_operand_i(a),
        .second_operand_i(b),
        .modulus_i(m),
        .sum_o(sum)
    );

    initial begin
        $dumpfile("DoorLock/BuildFiles/tb_PRNG.vcd");
        $dumpvars(0, tb_PRNG);
        a = 4'b0;
        b = 4'b0;
        m = 4'b0;
    

        for (integer i = 0; i < 16; i = i + 1) begin
            for (integer j = 0; j < i; j = j + 1) begin
                for (integer k = 0; k < i; k = k + 1) begin
                    a <= k;
                    b <= j;
                    m <= i;
                    #10;
                end
            end
        end
    end


endmodule */

