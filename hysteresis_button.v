module hysteresis_button
(
    input wire clk,
    input wire button_in, // 1 bit - signal to be debounced
    input wire active,    // 1 bit - high if input is active high signal
    output reg button_out // 1 bit - output debounced signal
);

reg [11:0] count = 12'h000; // debounce counter

always @ (posedge clk) begin
    if (button_in==active) begin
        if (count >= 12'h0ff) begin
            count <= 12'hfff;
            button_out <= 1'b1;
        end
        else begin
            count <= count+1;
            button_out <= 1'b0;
        end
    end
    else if (button_in == !active) begin
        if (count == 12'h000) begin
            count <= count;
            button_out <= 1'b0;
        end
        else begin
            if (count <= 12'hf00) begin
                button_out <= 1'b0;
                count <= 12'h000;
            end
            else begin
                count <= count-1;
                button_out <= 1'b1;
            end
        end
    end
    else begin
        count <= count;
        button_out <= 1'b0;
    end
    end

endmodule 
