// Holds the numbers that each display segment should represent.

module display_reg(
    input wire       clk,
    input wire [3:0] index_A,
    input wire [3:0] index_B,
    input wire       shuffle_init,
    output reg [3:0] data_out
    );

    reg [39:0]             register;
    reg [3:0]             temp;
    wire [3:0]             count;

    dis_clk_counter i0 (// Outputs
        .count_out(count[3:0]),
        // Inputs
        .clk(clk),
        .shuffle_init(shuffle_init)
    );

   
    // Initialize and shuffle logic
    always @(posedge clk) begin //1
        if (shuffle_init) begin //2-1
            if (count == 0) begin
                register[0 +: 4] = 4'd0;
                register[4 +: 4] = 4'd1;
                register[8 +: 4] = 4'd2;
                register[12 +: 4] = 4'd3;
                register[16 +: 4] = 4'd4;
                register[20 +: 4] = 4'd5;
                register[24 +: 4] = 4'd6;
                register[28 +: 4] = 4'd7;
                register[32 +: 4] = 4'd8;
                register[36 +: 4] = 4'd9;

                if (index_B <10) begin
                    register[4*count +: 4] <= register[4*index_B +: 4];
                    register[4*index_B +: 4] <= register[4*count +: 4];
                end
            end // if (count == 0)    
    
        else if (count < 10) begin // if count
            if (index_B < 10) begin
                register[4*count +: 4] <= register[4*index_B +: 4];
                register[4*index_B +: 4] <= register[4*count +: 4];
            end
        end
        end // if (shuffle_init)
      
        if (index_A < 10) begin
            case (index_A)
                0: data_out <= register[0 +: 4];
                1: data_out <= register[4 +: 4];
                2: data_out <= register[8 +: 4];
                3: data_out <= register[12 +: 4];
                4: data_out <= register[16 +: 4];
                5: data_out <= register[20 +: 4];
                6: data_out <= register[24 +: 4];
                7: data_out <= register[28 +: 4];
                8: data_out <= register[32 +: 4];
                9: data_out <= register[36 +: 4];
                default: data_out <= 40'bx;
            endcase // case (index_A)
        end // if (index_A < 10)
   end // always @ (posedge clk)
   
endmodule // display_reg

/* `timescale 1ns / 1ps
`include "display_reg.v"
`include "dis_clk_counter.v"
 */
/* module display_reg_tb;

   reg clk;
   reg [3:0] index_A;
   reg [3:0] index_B;
   reg        shuffle_init;
   wire [3:0] data_out;

   integer    i;



   // Instantiate the display module
   display_reg i0 (/*AUTOINST*/
         // Outputs
         .data_out      (data_out[3:0]),
         // Inputs
         .clk         (clk),
         .index_A      (index_A[3:0]),
         .index_B      (index_B[3:0]),
         .shuffle_init   (shuffle_init));

   // Clock generation
   always #5 clk = ~clk;

   // Test sequence
   initial begin
      $dumpfile("display_reg_tb.vcd");
      $dumpvars(0, display_reg_tb);
      // Initialize signals
      clk = 0;
      shuffle_init = 0;
      index_A = 0;
      index_B = 0;

      // Reset and initialize
      #10;
      shuffle_init = 1; // Trigger initialization
      index_B = 8;
      #10 index_B = 1;
      #10 index_B = 3;
      #10 index_B = 4;
      #10 index_B = 7;
      #10 index_B = 9;
      #10 index_B = 0;
      #10 index_B = 2;
      #10 index_B = 6;
      #10 index_B = 5;
      

      #10 index_A = 8;
      
      for (i=0; i<10; i=i+1) begin
    index_A = i;
      end
      

      // Begin shuffling
      index_B = 3; // Choose an index for shuffling
      for (i = 0; i < 10; i = i+1) begin
         index_A = i % 10; // Change index_A to see different outputs
         #10;
      end

      // Test stability after shuffle
      index_A = 5;
      #10;
      index_A = 2;
      #10;

      // Finish test
      $finish;
   end

endmodule */
