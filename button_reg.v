module button_reg(/*AUTOARG*/
    // Outputs
    input_v, index,
    // Inputs
    button, clk, rstn
    );
    // + input clk_num; <= input_valid 시간 조절
    input [9:0] button;
    input clk;
    input rstn;
    output reg input_v;
    output reg [3:0] index;

    reg iv_output_done; // ff
    reg any_input_active; // comb

    always @(*) begin
        case (button)
            10'b00_0000_0001 : begin index = 4'b0000; any_input_active = 1; end
            10'b00_0000_0010 : begin index = 4'b0001; any_input_active = 1; end
            10'b00_0000_0100 : begin index = 4'b0010; any_input_active = 1; end
            10'b00_0000_1000 : begin index = 4'b0011; any_input_active = 1; end
            10'b00_0001_0000 : begin index = 4'b0100; any_input_active = 1; end
            10'b00_0010_0000 : begin index = 4'b0101; any_input_active = 1; end
            10'b00_0100_0000 : begin index = 4'b0110; any_input_active = 1; end
            10'b00_1000_0000 : begin index = 4'b0111; any_input_active = 1; end
            10'b01_0000_0000 : begin index = 4'b1000; any_input_active = 1; end
            10'b10_0000_0000 : begin index = 4'b1001; any_input_active = 1; end
            default : begin index = 4'b1111; any_input_active = 0; end
        endcase // case (button)
    end // always @ ()

    //        __    __    __    __    __    __    __    __    __    __    __    __
    // clk __|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|
    //            ___________________________
    // button ___|                           |_______________________________
    //              _____
    // i.v. _______|     |___________________________________________________
    
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            input_v <= 0;
            iv_output_done <= 0;
        end
        else if (any_input_active) begin
            if (~iv_output_done) begin
                input_v <= 1;
                iv_output_done <= 1;
            end
            else begin
                input_v <= 0;
                iv_output_done <= 1;
            end
        end
        else begin
            input_v <= 0;
            iv_output_done <= 0;
        end
    end
   
endmodule // button_reg
