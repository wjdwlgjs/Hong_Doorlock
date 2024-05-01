// Holds the numbers that each display segment should represent.

`include "PRNG.v"

module display_reg(
    input wire clk,
    input rstn,
    input wire [3:0] button_index,
    input wire shuffle_init,
    input [31:0] clk_count,
    output reg [3:0] data_out
    );

    reg shuffle_enable;
    reg [39:0] register;
    reg [39:0] register_next_state;
    reg [3:0] value_at_si;
    reg [3:0] value_at_ci;
    wire [3:0] shuffle_index;

    PRNG RandomNumberGenerator(
        .clk_i(clk),
        .nreset_i(rstn),
        .collect_seed_i((~shuffle_init) & (~shuffle_enable)),
        .modular_i(4'b1010 - clk_count[3:0]), // 10, 9, 8, ... 1
        .seed_i(clk_count),
        .prn4_o(shuffle_index)
    );

    always @(*) begin 
        case(shuffle_index)
            4'b0000: value_at_si = register[3:0];
            4'b0001: value_at_si = register[7:4];
            4'b0010: value_at_si = register[11:8];
            4'b0011: value_at_si = register[15:12];
            4'b0100: value_at_si = register[19:16];
            4'b0101: value_at_si = register[23:20];
            4'b0110: value_at_si = register[27:24];
            4'b0111: value_at_si = register[31:28];
            4'b1000: value_at_si = register[35:32];
            4'b1001: value_at_si = register[39:36];
            default: value_at_si = 4'b0000;
        endcase

        case(clk_count[3:0])
            4'd9: value_at_ci = register[3:0];
            4'd8: value_at_ci = register[7:4]; // clk count == 8 corresponds to 
            4'd7: value_at_ci = register[11:8];
            4'd6: value_at_ci = register[15:12];
            4'd5: value_at_ci = register[19:16];
            4'd4: value_at_ci = register[23:20];
            4'd3: value_at_ci = register[27:24];
            4'd2: value_at_ci = register[31:28];
            4'd1: value_at_ci = register[35:32];
            4'd0: value_at_ci = register[39:36];
            default: value_at_ci = 4'b0000;
        endcase
    end

    always @(*) begin
        case({clk_count[3:0] == 4'd9, shuffle_index == 4'd0})
            2'b10: register_next_state[3:0] = value_at_si;
            2'b01: register_next_state[3:0] = value_at_ci;
            default: register_next_state[3:0] = register[3:0];
        endcase

        case({clk_count[3:0] == 4'd8, shuffle_index == 4'd1})
            2'b10: register_next_state[7:4] = value_at_si;
            2'b01: register_next_state[7:4] = value_at_ci;
            default: register_next_state[7:4] = register[7:4];
        endcase

        case({clk_count[3:0] == 4'd7, shuffle_index == 4'd2})
            2'b10: register_next_state[11:8] = value_at_si;
            2'b01: register_next_state[11:8] = value_at_ci;
            default: register_next_state[11:8] = register[11:8];
        endcase

        case({clk_count[3:0] == 4'd6, shuffle_index == 4'd3})
            2'b10: register_next_state[15:12] = value_at_si;
            2'b01: register_next_state[15:12] = value_at_ci;
            default: register_next_state[15:12] = register[15:12];
        endcase

        case({clk_count[3:0] == 4'd5, shuffle_index == 4'd4})
            2'b10: register_next_state[19:16] = value_at_si;
            2'b01: register_next_state[19:16] = value_at_ci;
            default: register_next_state[19:16] = register[19:16];
        endcase

        case({clk_count[3:0] == 4'd4, shuffle_index == 4'd5})
            2'b10: register_next_state[23:20] = value_at_si;
            2'b01: register_next_state[23:20] = value_at_ci;
            default: register_next_state[23:20] = register[23:20];
        endcase

        case({clk_count[3:0] == 4'd3, shuffle_index == 4'd6})
            2'b10: register_next_state[27:24] = value_at_si;
            2'b01: register_next_state[27:24] = value_at_ci;
            default: register_next_state[27:24] = register[27:24];
        endcase

        case({clk_count[3:0] == 4'd2, shuffle_index == 4'd7})
            2'b10: register_next_state[31:28] = value_at_si;
            2'b01: register_next_state[31:28] = value_at_ci;
            default: register_next_state[31:28] = register[31:28];
        endcase

        case({clk_count[3:0] == 4'd1, shuffle_index == 4'd8})
            2'b10: register_next_state[35:32] = value_at_si;
            2'b01: register_next_state[35:32] = value_at_ci;
            default: register_next_state[35:32] = register[35:32];
        endcase

        case({clk_count[3:0] == 4'd0, shuffle_index == 4'd9})
            2'b10: register_next_state[39:36] = value_at_si;
            2'b01: register_next_state[39:36] = value_at_ci;
            default: register_next_state[39:36] = register[39:36];
        endcase
    end

    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin 
            register <= 40'b0;
            shuffle_enable <= 0;
        end
        else if (shuffle_init) begin
            shuffle_enable <= 1;
            register <= {4'd9, 4'd8, 4'd7, 4'd6, 4'd5, 4'd4, 4'd3, 4'd2, 4'd1, 4'd0};
        end
        else if (shuffle_enable) begin
            register <= register_next_state;
            if (clk_count[3]) shuffle_enable <= 0;
            else shuffle_enable <= 1;
        end
        else begin
            register <= register;
            shuffle_enable <= 0;
        end
    end

    always @(*) begin 
        case(button_index) 
            4'b0000: data_out = register[3:0];
            4'b0001: data_out = register[7:4];
            4'b0010: data_out = register[11:8];
            4'b0011: data_out = register[15:12];
            4'b0100: data_out = register[19:16];
            4'b0101: data_out = register[23:20];
            4'b0110: data_out = register[27:24];
            4'b0111: data_out = register[31:28];
            4'b1000: data_out = register[35:32];
            4'b1001: data_out = register[39:36];
            default: data_out = 4'b0000;
        endcase
    end

   
    /* // Initialize and shuffle logic
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
      
        if (index_A < 10) begin // why?
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
    */
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
   display_reg i0 (
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
