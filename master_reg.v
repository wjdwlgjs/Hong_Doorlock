// Holds the master passcode

module master_reg(/*AUTOARG*/
    // Outputs
    master_pw
    );
    output [127:0] master_pw;

    assign master_pw = 128'hDDDDFFFFEEEEAAAABBBBDADAEFEFBBBB;
endmodule