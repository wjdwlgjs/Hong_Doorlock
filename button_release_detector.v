module button_release_detector(/*autoarg*/
   // Outputs
   out,
   // Inputs
   clk, in, rstn
   );
   input clk;
   input in;
   input rstn; // master asynchronous reset
   output out;

   reg	r1;
   reg	r2;
   reg	r3;

   always @(posedge clk or negedge rstn) begin
      if (~rstn) {r1, r2, r3} <= 3'b000;
      else begin
         r1 <= in;
         r2 <= r1;
         r3 <= r2;
      end
   end

   assign out = ~r1 & r2;

endmodule // button
