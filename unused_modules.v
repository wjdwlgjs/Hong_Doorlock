module button(/*autoarg*/
   // Outputs
   out,
   // Inputs
   clk, in
   );
   input clk;
   input [9:0] in;
   output reg [9:0] out;

   reg		prev = 0;
   wire		total;

   assign total = in[0]|in[1]|in[2]|in[3]|in[4]|in[5]|in[6]|in[7]|in[8]|in[9];
   
   always @(posedge clk) begin
      if (prev==0) begin
	 if (total == 1) begin
	    out <= in;
	 end
	 else begin
	    out <= 10'd0;
	 end
      end
      else begin
	 out <= 10'd0;
      end // else: !if(prev==0)
      prev <= total;
      
   end


endmodule // button

module confirm(
    input wire clk,
    input wire star,
    output reg confirm=0,
    output reg long_confirm=0
    );

    reg prev = 0;

    confirm_clk_counter i0 (/*AUTOINST*/
        // Outputs
        .long_valid(long_valid),
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

module control_test(/*autoarg*/
    // Outputs
    shuffle_init, seed, decision, mem_sl, buff_sl, mem_rst,
    buff_rst, state, clk_num_rst,
    // Inputs
    clk, rst, confirm_in, shuffle_in, same, master_same,
    input_valid, clk_num, error_num, limit
    );

    input clk, rst;

    input confirm_in, shuffle_in, same, master_same, limit;
    input input_valid;
    input [3:0] error_num;
    input [31:0]  clk_num;
    output reg shuffle_init, decision, mem_rst, buff_rst, mem_sl, buff_sl, clk_num_rst;
    output reg [31:0] seed;
    output reg [2:0]       state;

    reg [2:0] prev_state;
    reg [2:0] current_state;

    wire confirm, shuffle;
   
    parameter [2:0] set_psw = 3'b000;
    parameter [2:0] confirm_psw = 3'b001;
    parameter [2:0] suffle_mode = 3'b010;
    parameter [2:0] locked = 3'b011;
    parameter [2:0] challenge = 3'b100;
    parameter [2:0] unlocked = 3'b101;


    button_1bit_neg confirm_out(.out(confirm),
                 .in(confirm_in),
                 .clk(clk));
    button_1bit_neg shuffle_out(.out(shuffle),
                 .in(shuffle_in),
                 .clk(clk));
   

   
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state = set_psw;
            decision = 1;
            shuffle_init = 0;
        end
        else begin
            case(current_state) 
                set_psw : begin
                    mem_rst = 0;
                    decision = 1;
                    if (shuffle == 1) begin
                        shuffle_init = 1;
                        seed = clk_num;
                        prev_state = current_state;
                        current_state = suffle_mode;
                    end
                    else if(~confirm & ~shuffle == 1) begin
                        mem_sl = input_valid & ~limit;
                        mem_rst = limit & input_valid;
                    end
                    else if(confirm == 1) begin
                        buff_rst = 1;
                        current_state = confirm_psw;
                    end
                end
                confirm_psw : begin
                    buff_rst = 0;
                    decision = 0;
                    if (shuffle == 1) begin
                    shuffle_init = 1;
                    seed = clk_num;
                    prev_state = current_state;
                    current_state = suffle_mode;
                    end
                    else if (~confirm & ~shuffle == 1) begin
                        buff_sl = input_valid & (~limit);
                    end
                    else if ((limit & input_valid)|(confirm &(~same)) == 1) begin
                        mem_rst = 1;
                        current_state = set_psw;
                    end
                    else if (confirm & same == 1) begin
                        current_state = locked;
                    end
                end
                suffle_mode : begin
                    if (clk_num != 10) begin

                    end
                    else if(clk_num == 10) begin
                        shuffle_init = 0;
                        current_state = prev_state;
                    end
                end
                locked : begin
                    if (confirm) begin
                        buff_rst = 1;
                        current_state = challenge;
                    end
                end
                challenge : begin
                    buff_rst = 0;
                    decision <= 0;
                    if (shuffle == 1) begin
                        shuffle_init = 1;
                        seed = clk_num;
                        prev_state = current_state;
                        current_state = suffle_mode;
                    end
                    else if (~confirm & ~shuffle == 1) begin
                        buff_sl = input_valid & ~limit;
                    end
                    else if (confirm & (((error_num<10)&same)|master_same) == 1) begin
                        current_state = unlocked;
                    end
                    else if (~(confirm & (((error_num<10)&same)|master_same)) | (limit & input_valid) == 1) begin
                        current_state = locked;
                    end       
                end
                unlocked : begin
                    if (confirm &(clk_num <15*10^6) == 1) begin
                        current_state = locked;
                    end
                    else if (confirm & (clk_num >= 15*10^6) == 1) begin //mem_psw를 초기화할 것인가?
                        current_state = set_psw;
                    end
                end
            endcase // case (state)
        end // else: !if(rst)

        state = current_state;
    end   

endmodule // control_test

module DigitsButtons(/*autoarg*/
   // Outputs
   out,
   // Inputs
   clk, in
   );
   input clk;
   input [9:0] in;
   output reg [9:0] out;

   reg		prev = 0;
   wire		total;

   assign total = in[0]|in[1]|in[2]|in[3]|in[4]|in[5]|in[6]|in[7]|in[8]|in[9];
   
   always @(posedge clk) begin
      if (prev==0) begin
	 if (total == 1) begin
	    out <= in;
	 end
	 else begin
	    out <= 10'd0;
	 end
      end
      else begin
	 out <= 10'd0;
      end // else: !if(prev==0)
      prev <= total;
      
   end


endmodule // button

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

