module doorlock(/*AUTOARG*/
    // Outputs
    master_same, same, limit, long_confirm,
    // Inputs
    clk, mem_rst, input_v, decision, buff_rst, shuffle_init, star,
    index_A, index_B
    );

    input  clk, mem_rst, input_v, decision, buff_rst, shuffle_init, star;
    input [3:0] index_A, index_B;
    output   master_same, same, limit, long_confirm;

    /*AUTOREG*/
    /*AUTOWIRE*/
    // Beginning of automatic wires (for undeclared instantiated-module outputs)
    wire         confirm;      // From i8 of confirm.v
    // End of automatics
    // Beginning of automatic wires (for undeclared instantiated-module outputs)
    wire [3:0]      data_in;      // From i7 of display_reg.v
    wire [127:0]      data_out1;      // From i2 of reged_pw.v
    wire [127:0]      data_out2;      // From i6 of input_save.v
    wire [127:0]      master_pw;      // From i1 of master_reg.v
    wire [3:0]      msb1;         // From i2 of reged_pw.v
    wire [3:0]      msb2;         // From i6 of input_save.v
    wire   [3:0]      mux_out;      // From i4 of decision_mux.v

    master_comparator i0(/*AUTOINST*/
        // Outputs
        .master_same   (master_same),
        // Inputs
        .master_pw   (master_pw[127:0]),
        .data_out2   (data_out2[127:0]),
        .confirm   (confirm)
    );
    master_reg i1(/*AUTOINST*/
        // Outputs
        .master_pw      (master_pw[127:0])
    );
    reged_pw i2(/*AUTOINST*/
        // Outputs
        .data_out1      (data_out1[127:0]),
        .msb1         (msb1[3:0]),
        // Inputs
        .clk         (clk),
        .mem_rst         (mem_rst),
        .input_v         (input_v),
        .decision      (decision),
        .data_in         (data_in[3:0])
    );
    same_or_not i3(/*AUTOINST*/
        // Outputs
        .same         (same),
        // Inputs
        .confirm      (confirm),
        .data_out1      (data_out1[127:0]),
        .data_out2      (data_out2[127:0])
    );
    decision_mux i4(/*AUTOINST*/
          // Outputs
          .mux_out      (mux_out[3:0]),
          // Inputs
          .msb1      (msb1[3:0]),
          .msb2      (msb2[3:0]),
          .decision      (decision)
    );
    carry_same i5(/*AUTOINST*/
        // Outputs
        .limit         (limit),
        // Inputs
        .confirm      (confirm),
        .mux_out      (mux_out[3:0])
    );
    input_save i6(/*AUTOINST*/
        // Outputs
        .data_out2      (data_out2[127:0]),
        .msb2         (msb2[3:0]),
        // Inputs
        .clk         (clk),
        .buff_rst      (buff_rst),
        .input_v      (input_v),
        .decision      (decision),
        .data_in      (data_in[3:0])
    );
    display_reg i7(/*AUTOINST*/
        // Outputs
        .data_in      (data_in[3:0]),
        // Inputs
        .clk         (clk),
        .index_A      (index_A[3:0]),
        .index_B      (index_B[3:0]),
        .shuffle_init      (shuffle_init)
    );
    confirm i8(/*AUTOINST*/
        // Outputs
        .confirm         (confirm),
        .long_confirm      (long_confirm),
        // Inputs
        .clk         (clk),
        .star         (star)
    );
   
endmodule // doorlock
