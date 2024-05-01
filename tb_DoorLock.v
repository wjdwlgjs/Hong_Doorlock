`include "DoorLock.v"
`timescale 1ns/1ns

module tb_DoorLock();

    reg [9:0] tb_digit_buttons;
    reg tb_confirm_button;
    reg tb_shuffle_button;

    reg tb_clk;
    reg tb_rstn;
    
    wire tb_locked;

    always #5 tb_clk <= ~tb_clk;
    /* always @(posedge tb_confirm_button) #48 tb_confirm_button <= 0;
    always @(posedge tb_shuffle_button) #48 tb_shuffle_button <= 0; */
    always @(posedge tb_digit_buttons[0]) #48 tb_digit_buttons[0] <= 0;
    always @(posedge tb_digit_buttons[1]) #48 tb_digit_buttons[1] <= 0;
    always @(posedge tb_digit_buttons[2]) #48 tb_digit_buttons[2] <= 0;
    always @(posedge tb_digit_buttons[3]) #48 tb_digit_buttons[3] <= 0;
    always @(posedge tb_digit_buttons[4]) #48 tb_digit_buttons[4] <= 0;
    always @(posedge tb_digit_buttons[5]) #48 tb_digit_buttons[5] <= 0;
    always @(posedge tb_digit_buttons[6]) #48 tb_digit_buttons[6] <= 0;
    always @(posedge tb_digit_buttons[7]) #48 tb_digit_buttons[7] <= 0;
    always @(posedge tb_digit_buttons[8]) #48 tb_digit_buttons[8] <= 0;
    always @(posedge tb_digit_buttons[9]) #48 tb_digit_buttons[9] <= 0;

    DoorLock TestDoorLock(
        .digit_buttons(tb_digit_buttons),
        .confirm_button(tb_confirm_button),
        .shuffle_button(tb_shuffle_button),

        .clk(tb_clk),
        .rstn(tb_rstn),

        .locked(tb_locked)
    );

    initial begin
        $dumpfile("BuildFiles/tb_DoorLock.vcd");
        $dumpvars(0, tb_DoorLock);

        tb_digit_buttons <= 0;
        tb_confirm_button <= 0;
        tb_shuffle_button <= 0;

        tb_clk <= 0;
        tb_rstn <= 0;

        #42 
        tb_rstn <= 1;

        // reach limit in set psw

        #204

        for (integer i = 0; i < 33; i = i + 1) begin
            tb_digit_buttons[0] <= 1;
            #144;
        end
            
        // set psw to 6969
        #240
        tb_digit_buttons[6] <= 1;
        #144
        tb_digit_buttons[9] <= 1;
        #290
        tb_digit_buttons[6] <= 1;
        #216
        tb_digit_buttons[9] <= 1;
        #238
        tb_confirm_button <= 1;
        #116 
        tb_confirm_button <= 0;

        // wrong confirm psw
        #240
        tb_digit_buttons[6] <= 1;
        #144
        tb_digit_buttons[9] <= 1;
        #240
        tb_digit_buttons[6] <= 1;
        #144
        tb_digit_buttons[8] <= 1;
        #238
        tb_confirm_button <= 1;
        #116 
        tb_confirm_button <= 0;

        // set psw to 6969 again
        #240
        tb_digit_buttons[6] <= 1;
        #144
        tb_digit_buttons[9] <= 1;
        #290
        tb_digit_buttons[6] <= 1;
        #216
        tb_digit_buttons[9] <= 1;
        #238
        tb_confirm_button <= 1;
        #116 
        tb_confirm_button <= 0;

        // confirm psw 6969
        #240
        tb_digit_buttons[6] <= 1;
        #144
        tb_digit_buttons[9] <= 1;
        #290
        tb_digit_buttons[6] <= 1;
        #216
        tb_digit_buttons[9] <= 1;
        #238
        tb_confirm_button <= 1;
        #116 
        tb_confirm_button <= 0;

        // transition to challenge
        #175
        tb_confirm_button <= 1;
        #270 
        tb_confirm_button <= 0;
        
        // reach limit in challenge
        #204

        for (integer i = 0; i < 33; i = i + 1) begin
            tb_digit_buttons[0] <= 1;
            #144;
        end

        // wrong so many times
        for (integer i = 0; i < 10; i = i + 1) begin
            #267
            tb_confirm_button <= 1;
            #236 
            tb_confirm_button <= 0;
            #231
            tb_confirm_button <= 1;
            #275
            tb_confirm_button <= 0;
        end

        // now can't open with 6969
        #232
        tb_confirm_button <= 1;
        #296
        tb_confirm_button <= 0;
        #240
        tb_digit_buttons[6] <= 1;
        #144
        tb_digit_buttons[9] <= 1;
        #290
        tb_digit_buttons[6] <= 1;
        #216
        tb_digit_buttons[9] <= 1;
        #238
        tb_confirm_button <= 1;
        #116 
        tb_confirm_button <= 0;

        // master psw saves the day
        #232
        tb_confirm_button <= 1;
        #296
        tb_confirm_button <= 0;
        #240
        tb_digit_buttons[2] <= 1;
        #144
        tb_digit_buttons[7] <= 1;
        #290
        tb_digit_buttons[1] <= 1;
        #216
        tb_digit_buttons[8] <= 1;
        #232
        tb_confirm_button <= 1;
        #296
        tb_confirm_button <= 0;

        // now can open with 6969
        #232
        tb_confirm_button <= 1;
        #296
        tb_confirm_button <= 0;
        #240
        tb_digit_buttons[6] <= 1;
        #144
        tb_digit_buttons[9] <= 1;
        #290
        tb_digit_buttons[6] <= 1;
        #216
        tb_digit_buttons[9] <= 1;
        #238
        tb_confirm_button <= 1;
        #116 
        tb_confirm_button <= 0;

        // short confirm to lock
        #231
        tb_confirm_button <= 1;
        #275
        tb_confirm_button <= 0;

        // open with 6969 again
        #232
        tb_confirm_button <= 1;
        #296
        tb_confirm_button <= 0;
        #240
        tb_digit_buttons[6] <= 1;
        #144
        tb_digit_buttons[9] <= 1;
        #290
        tb_digit_buttons[6] <= 1;
        #216
        tb_digit_buttons[9] <= 1;
        #238
        tb_confirm_button <= 1;
        #116 
        tb_confirm_button <= 0;
        
        // long confirm to set psw
        #232
        tb_confirm_button <= 1;
        #1000
        tb_confirm_button <= 0;

        // enter shuffle mode
        #236
        tb_shuffle_button <= 1;
        #500
        tb_shuffle_button <= 0;

        #1200

        // 6969 isn't really 6969 anymore
        #240
        tb_digit_buttons[6] <= 1;
        #144
        tb_digit_buttons[9] <= 1;
        #290
        tb_digit_buttons[6] <= 1;
        #216
        tb_digit_buttons[9] <= 1;
        #238
        tb_confirm_button <= 1;
        #116 
        tb_confirm_button <= 0;

        #1000
        $finish;
    end
endmodule


        