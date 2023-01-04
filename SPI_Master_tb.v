`timescale 1ns/1ps

module SPI_Master_tb();

reg clk, reset, data_valid;
wire transmit_ready;
reg [1:0] num_bytes;
wire [1:0] num_bytes_rx;
reg [7:0] data_TX;
wire [7:0] data_RX;

wire data_valid_RX; ////
wire SPI_CLK, SPI_MOSI, SPI_CS;
reg SPI_MISO;

reg [1:0] counter = 2'b10;

SPI_Master_With_Single_CS #(.SPI_MODE(3),
    .CLKS_PER_HALF_BIT(2),
    .MAX_BYTES_PER_CS(3),
    .CS_INACTIVE_CLKS(0)) 
    SPIMASTER (reset, clk, num_bytes, data_TX, data_valid, transmit_ready,
                num_bytes_rx, data_valid_RX, data_RX, 
                SPI_CLK, SPI_MISO, SPI_MOSI, SPI_CS);

always @ (posedge clk) begin
    if (data_valid == 1'b1) begin
        if (counter == 2'b00) begin
            data_valid <= 1'b0;
            counter <= 2'b10;
        end
        else counter <= counter - 1;
    end
end

initial begin
    $dumpfile("SPI_Master_tb.vcd");
    $dumpvars(0, SPI_Master_tb);
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
    num_bytes = 2'b10;
    data_valid = 1'b0;
    reset = 1'b1;
    #200;
    reset = 1'b0;
    #200;
    reset = 1'b1;
    #200;
    data_TX = 8'hfd;
    #200;
    data_valid = 1'b1;
    #2000;
    data_valid = 1'b1;
    #2000;
    reset = 1'b0;
    #200;
    reset = 1'b1;
    #200;
    data_TX = 8'hfd;
    #200;
    data_valid = 1'b1;
    #1000;
    data_TX = 8'h12;
    #200;
    data_valid = 1'b1;
end

endmodule