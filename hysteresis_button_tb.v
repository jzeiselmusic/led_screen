`timescale 10ns/1ps

module testbench();

reg clk, button_in, active;
wire button_out;

hysteresis_button hb(clk, button_in, active, button_out);

initial begin
forever #1 clk = !clk;
end

initial begin
    active = 1'b1; // active high
    clk = 1'b0;
    button_in = 1'b0;
    #150;
    button_in = 1'b1;
    #300;
    button_in = 1'b0;
    #100;
    button_in = 1'b1;
    #400;
    button_in = 1'b0;
    #100;
    button_in = 1'b1;
    #800;
    button_in = 1'b0;
    #300;
    button_in = 1'b1;
    #50;
    button_in = 1'b0;
    #100;
    button_in = 1'b1;
    #100;
    button_in = 1'b0;
    #50;
    button_in = 1'b1;
    #2000;
    button_in = 1'b0;
    #200;
    button_in = 1'b1;
    #300;
    button_in = 1'b0;
    #100;
    button_in = 1'b1;
    #500;
    button_in = 1'b0;
end

initial begin
    $dumpfile("my_dumpfile.vcd");
    $dumpvars(0, testbench);
end


endmodule