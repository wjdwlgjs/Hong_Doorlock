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
