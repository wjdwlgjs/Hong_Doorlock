// compares the input and the master password

module master_comparator(/*AUTOARG*/
    // Outputs
    master_same,
    // Inputs
    A, B, confirm
    );
    
    input [127:0] A;
    input [127:0] B;
    input confirm;
    output reg master_same;

    always @ (*) begin
        if (confirm) begin
            master_same = (A == B) ? 1'b1 : 1'b0;
        end
        else begin
            master_same = 0;
        end
    end
endmodule