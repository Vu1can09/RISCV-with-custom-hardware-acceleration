`timescale 1ns / 1ps

module cnn_controller_tb;

    reg clk, rst_n;
    reg start, mac_done, image_done;
    
    wire load_window, enable_mac, write_output, next_pixel, done;

    cnn_controller uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .load_window(load_window),
        .enable_mac(enable_mac),
        .write_output(write_output),
        .next_pixel(next_pixel),
        .done(done),
        .mac_done(mac_done),
        .image_done(image_done)
    );

    parameter DEBUG_LEVEL = 1;

    always #5 clk = ~clk;

    initial begin
        // Configurable Waveform Dumping
        if (DEBUG_LEVEL > 0) begin
            $dumpfile("sim_out/waveforms/cnn_controller.fst");
            if (DEBUG_LEVEL == 1)      $dumpvars(1, cnn_controller_tb); // Top-level only
            else if (DEBUG_LEVEL == 2) $dumpvars(0, cnn_controller_tb.uut); // Accelerator/uut only
            else                       $dumpvars(0, cnn_controller_tb); // Full debug dump
        end
        
        clk = 0;
        rst_n = 0;
        start = 0;
        mac_done = 0;
        image_done = 0;
        
        #20 rst_n = 1;
        #10 start = 1;
        #10 start = 0;
        
        // Proceed through state machines
        #20 mac_done = 1; // Mac completes
        #10 mac_done = 0;
        
        #20 image_done = 1; // Just a quick cycle
        #10 image_done = 0;
        
        #30;
        if (done) $display("PASS: CNN Controller finished sequence.");
        else $display("FAIL: CNN Controller did not finish.");
        
        #10 $finish;
    end
endmodule
