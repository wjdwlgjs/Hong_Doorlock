`include "button_1bit.v"
`include "button_1bit_neg.v"
`include "num_button.v"
`include "Error_control.v"
`include "clk_control.v"

module confirm_clk_counter(
    input wire clk,
    input wire star,
    output reg long_valid
    );

    // Counter variable
    reg [5:0] count = 0; // Is this possible?
   
   // Count logic
   always @(posedge clk) begin      
      if (star) begin
    if (count < 30) begin
            count = count + 1; // Increment counter if below maximum
    end
    else begin
       long_valid = 1;
    end
      end      
      else begin
    count = 0;
    long_valid = 0;
      end // else: !if(star)
   end
endmodule


module confirm(
    input wire clk,
    input wire star,
    output reg confirm=0,
    output reg long_confirm=0
    );

    reg prev = 0;

    confirm_clk_counter i0 (/*AUTOINST*/
        // Outputs
        .long_valid      (long_valid),
        // Inputs
        .clk(clk),
        .star(star)
    );

   always @ (posedge clk) begin
      if (prev == 1) begin
    if (star == 0) begin
       if (long_valid == 0) begin
          confirm <= 1;
          long_confirm <=0;
       end
       else begin
          confirm <= 0;
          long_confirm <= 1;
       end
    end
    
    else begin
       confirm <= 0;
       long_confirm <= 0;
    end
      end
      else begin
    confirm <= 0;
    long_confirm <= 0;
      end
      prev <= star;
   end

endmodule // confirm
