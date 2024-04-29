`include "Controller.v"
`timescale 1ns/1ns

module tb_Controller();

    reg tb_clk; 
    reg tb_rstn; 
    reg tb_confirm_in; 
    reg tb_shuffle_in; 
    reg tb_same; 
    reg tb_master_same;
    reg tb_input_valid; 
    reg tb_buff_limit;
    reg tb_mem_limit;

    wire tb_shuffle_init; 
    wire [31:0] tb_seed; 
    wire tb_decision; 
    wire tb_mem_sl; 
    wire tb_buff_sl; 
    wire tb_mem_rst;
    wire tb_buff_rst;

    always #5 tb_clk <= ~tb_clk;
    //    __    __    __    __    __    __
    // __|  |__|  |__|  |__|  |__|  |__|
    //      ^        ^
    // (10n)ns    (10n + 5)ns 
    always @(posedge tb_confirm_in) #48 tb_confirm_in <= 0;
    always @(posedge tb_shuffle_in) #48 tb_shuffle_in <= 0;
    always @(posedge (tb_input_valid | tb_same | tb_master_same | tb_buff_limit | tb_mem_limit)) #10 {tb_input_valid, tb_same, tb_master_same, tb_buff_limit, tb_mem_limit} <= 5'b00000;
    
    //        __    __    __    __    __    __    __    __    __    __    __    __
    // clk __|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|
    //            ___________________________
    // in   _____|                           |_______________________________
    //                                            _____
    // released _________________________________|     |_____________________
    //              _____
    // i.v. _______|     |___________________________________________________

    
    initial begin
        $dumpfile("BuildFiles/tb_Controller.vcd");
        $dumpvars(0, tb_Controller);

        tb_rstn = 0; 
        tb_clk = 0; 
        tb_confirm_in = 0; 
        tb_shuffle_in = 0; 
        tb_same = 0; 
        tb_master_same = 0;
        tb_input_valid = 0; 
        tb_error_num = 0; 
        tb_buff_limit = 0;
        tb_mem_limit = 0;

        // scenario 1: staying in noop mode while rstn == 0, then switching to set_psw when rstn == 1
        //        __    __    __    __    __    __    __    __    __    __    __    __
        // clk __|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|
        //                   ___________________________________________________________
        // rstn ____________|
        //                       ______________________________________________________
        // cur_state | 000      | 001                              

        #15 // 15
        rstn <= 1;

        #30 // 45 shuffle_in == 1, others: x
        tb_shuffle_in <= 1; 
        #50 // 95 shuffle_released == 1, others: x
        // 100 set_psw->shuffle, shuffle_init
        {tb_same, tb_master_same, tb_input_valid, tb_buff_limit, tb_mem_limit} <= $random;

        #150 // 245 shuffle_in == 0, i.v. == 1, mem_limit == 1, others: x
        // 250 set_psw->set_psw, reset memory
        tb_input_valid <= 1;
        tb_mem_limit <= 1;
        {tb_same, tb_master_same, tb_buff_limit} <= $random;

        #50 // 295 shuffle_in == 0, i.v. == 1, mem_limit == 0, others: x
        // 300 set_psw->set_psw, sl memory
        tb_input_valid <= 1;
        {tb_same, tb_master_same, tb_buff_limit} <= $random;

        #50 // 345 
        tb_confirm_in <= 1;
        #50 // 395 shuffle_in == 0, confirm_released == 1, others: x
        // 400 set_psw->confirm_psw, reset buff
        {tb_same, tb_master_same, tb_input_valid, tb_buff_limit, tb_mem_limit} <= $random;

        #50 // 445 shuffle_in == 1, 
        tb_shuffle_in <= 1; 
        #50 // 495 shuffle_released == 1, others: x
        // 500 confirm_psw -> shuffle, shuffle_init 
        {tb_same, tb_master_same, tb_input_valid, tb_buff_limit, tb_mem_limit} <= $random;

        #150 // 645 shuffle == 0, i.v. == 1, buff_limit == 1, others: x
        // 650 confirm_psw->confirm_psw, buff reset
        tb_input_valid <= 1;
        tb_buff_limit <= 1;
        {tb_same, tb_master_same, tb_mem_limit} <= $random;

        #50 // 695 shuffle == 0, i.v. == 1, buff_limit == 0, others: x
        // 700 confirm_psw->confirm_psw, buff sl
        tb_input_valid <= 1;
        {tb_same, tb_master_same, tb_mem_limit} <= $random;
        
        #50 // 745 confirm_in == 1
        tb_confirm_in <= 1;
        #50 // 795 shuffle == 0, confirm_released == 1, same == 0, others: x
        // 800 confirm_psw->set_psw, reset mem
        {tb_master_same, tb_input_valid, tb_buff_limit, tb_mem_limit} <= $random;
        
        #50 // 845 confirm_in == 1
        tb_confirm_in <= 1;
        #50 // 895 shuffle_in == 0, confirm_released == 1, others: x
        // 900 set_psw->confirm_psw, reset buff
        {tb_same, tb_master_same, tb_input_valid, tb_buff_limit, tb_mem_limit} <= $random;

        #50 // 945 confirm_in == 1
        tb_confirm_in <= 1;
        #50 // 995 shuffle == 0, confirm_released == 1, same == 1, others: x
        // 1000 confirm_psw->locked
        tb_same <= 1;
        {tb_master_same, tb_input_valid, tb_buff_limit, tb_mem_limit} <= $random;
        
        #50 // 1045 confirm_in == 1
        tb_confirm_in <= 1;
        #50 // 1095 confirm_released == 1, others: x
        // 1100 locked->challenge
        {tb_same, tb_master_same, tb_input_valid, tb_buff_limit, tb_mem_limit} <= $random;

        #50 // 1145 shuffle_in == 1
        tb_shuffle_in <= 1;
        #50 // 1195 shuffle_released == 1, others: x
        // 1200 challenge->shuffle, shuffle_init
        {tb_same, tb_master_same, tb_input_valid, tb_buff_limit, tb_mem_limit} <= $random;

        #150 // 1345 

        #150
        // work in progress
        





        


