`timescale 1ns/1ps

module LED_controller_tb();

reg clk, reset, power_on;

wire SPI_CLK, SPI_MOSI, SPI_CS, data_command, VCCen, PMODen, RESET;

LED_controller led(clk, reset, power_on,
    SPI_CLK, SPI_MOSI, SPI_CS, data_command,
    VCCen, PMODen, RESET
);

initial begin
    $dumpfile("LED_controller_tb.vcd");
    $dumpvars(0, LED_controller_tb);
end

initial begin
    forever begin
        clk = 1'b1;
        #5;
        clk = 1'b0;
        #5;
    end
end

initial begin
power_on = 1'b0;
reset = 1'b1;
#100;
reset = 1'b0;
#100;
reset = 1'b1;
#100;
power_on = 1'b1;
#200000000;
power_on = 1'b0;
#10000;
power_on = 1'b1;
#500000000;
$finish;
end


endmodule