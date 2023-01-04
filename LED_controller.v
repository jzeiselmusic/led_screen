module LED_controller(
    input wire clk, reset, power_on,
    output wire SPI_CLK, SPI_MOSI, SPI_CS, data_command,
                VCCen, PMODen, RESET
);
//
reg [2:0] num_bytes;
wire [2:0] num_bytes_rx;

reg [7:0] data_TX;
wire [7:0] data_RX;

reg data_valid;
wire data_valid_RX;
wire transmit_ready;

reg [1:0] state = 2'b00;
reg [7:0] power_on_internal_state = 8'h00;
reg [7:0] power_off_internal_state = 8'h00;
reg [31:0] state_config = 32'h00000000; //

wire power_on_trigger;

// output registers
reg data_command_reg, VCCen_reg, PMODen_reg, RESET_reg;
assign data_command = data_command_reg;
assign VCCen = VCCen_reg;
assign PMODen = PMODen_reg;
assign RESET = RESET_reg;
//
//

reg [31:0] counter = 32'h00000000;

//
//
SPI_Master_With_Single_CS #(.SPI_MODE(3),
    .CLKS_PER_HALF_BIT(2),
    .MAX_BYTES_PER_CS(5),
    .CS_INACTIVE_CLKS(0)) 
    SPIMASTER (reset, clk, num_bytes, data_TX, data_valid, transmit_ready,
                num_bytes_rx, data_valid_RX, data_RX, 
                SPI_CLK, SPI_MISO, SPI_MOSI, SPI_CS);

hysteresis_button debouncer(clk, power_on, 1'b1, power_on_trigger);
//
//
localparam OFF_IDLE               = 2'b00;
localparam ON_IDLE                = 2'b01;
localparam POWER_ON_SEQUENCE      = 2'b10;
localparam POWER_OFF_SEQUENCE     = 2'b11;
//
//
always @(posedge power_on_trigger) begin
    case(state)
    OFF_IDLE:           state <= POWER_ON_SEQUENCE;
    ON_IDLE:            state <= POWER_OFF_SEQUENCE;
    POWER_ON_SEQUENCE:  state <= POWER_ON_SEQUENCE;
    POWER_OFF_SEQUENCE: state <= POWER_OFF_SEQUENCE;
    endcase
end

always @(posedge clk) begin
    case(state)

    POWER_ON_SEQUENCE: begin
        case(power_on_internal_state) // there are approx. 32 power on commands

        8'h00:  begin                                // 1. bring data/command logic high
            data_command_reg <= 1'b0;
            power_on_internal_state <= 8'h01;
        end

        8'h01:  begin                                // 2. bring reset pin logic high
            RESET_reg <= 1'b1;
            power_on_internal_state <= 8'h02;
        end

        8'h02:  begin                                // 3. bring vccen logic low
            VCCen_reg <= 1'b0;
            power_on_internal_state <= 8'h03;
        end

        8'h03:  begin                                // 4. bring pmoden logic high and wait 20 ms
            PMODen_reg <= 1'b1;
            counter <= counter + 1'b1;
            if (counter >= 32'h002625a0) begin
                counter <= 32'h00000000;
                power_on_internal_state <= 8'h04;
            end
        end

        8'h04:  begin                                // 5. bring res logic low, wait 3 microsecs, bring res logic high
            RESET_reg <= 1'b0;
            counter <= counter + 1'b1;
            if (counter >= 32'h00000190) begin
                counter <= 32'h00000000;
                RESET_reg <= 1'b1;
                power_on_internal_state <= 8'h05;
            end
        end

        8'h05:  begin                                // 6. wait 3 microsecs
            counter <= counter + 1'b1;
            if (counter >= 32'h00000190) begin
                counter <= 32'h00000000;
                power_on_internal_state <= 8'h06;    // jump to send 2 commands
                state_config <= 32'hfd120008;        // send FD, 12 and jump to 0x8
            end
        end

        8'h06: begin                                 // send 2 commands 
            if (counter == 32'h00000000) begin
                num_bytes <= 3'b010;
                data_TX <= state_config[31:24];
                data_valid <= 1'b0;
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h00000002) begin
                data_valid <= 1'b1;
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h00000004) begin
                data_valid <= 1'b0;
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h00000030) begin
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h00000032) begin
                data_TX <= state_config[23:16];
                data_valid <= 1'b1;
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h00000034) begin
                data_valid <= 1'b0;
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h0000005c) begin
                counter <= counter + 1'b1;
            end
            else begin
                counter <= 32'h00000000;
                power_on_internal_state <= state_config[7:0];
            end
        end

        8'h07:  begin                                // send 1 command 
            if (counter == 32'h00000000) begin
                num_bytes <= 3'b001;
                data_TX <= state_config[31:24];
                data_valid <= 1'b1;
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h00000002) begin
                data_valid <= 1'b0;
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h0000002f) begin
                counter <= counter + 1'b1;
            end
            else begin
                counter <= 32'h00000000;
                power_on_internal_state <= state_config[7:0];
            end
        end

        8'h08:  begin                               
            power_on_internal_state <= 8'h07;        // jump to 7- send 1 command- go to 8'h09
            state_config <= 32'hae000009;            // send AE 
        end

        8'h09:  begin
            power_on_internal_state <= 8'h06;        // jump to 6- send 2 command- go to 8'h0a
            state_config <= 32'ha072000a;            // send A0 72
        end

        8'h0a:  begin
            power_on_internal_state <= 8'h06;        // jump to 6- send 2 command- go to 8'h0b
            state_config <= 32'ha100000b;            // send A1 00
        end

        8'h0b:  begin
            power_on_internal_state <= 8'h06;        // jump to 6- send 2 command- go to 8'h0c
            state_config <= 32'ha200000c;            // send A2 00
        end

        8'h0c:  begin
            power_on_internal_state <= 8'h07;        // jump to 7- send 1 command- go to 8'h0d
            state_config <= 32'ha400000d;            // send A4
        end

        8'h0d:  begin               
            power_on_internal_state <= 8'h06;        // jump to 6- send 2 command- go to 8'h0e
            state_config <= 32'ha83f000e;            // send A8 3F
        end

        8'h0e:  begin
            power_on_internal_state <= 8'h06;        // jump to 6- send 2 command- go to 8'h0f
            state_config <= 32'had8e000f;            // send AD 8E
        end

        8'h0f:  begin
            power_on_internal_state <= 8'h06;        // jump to 6- send 2 command- go to 8'h10
            state_config <= 32'hb00b0010;            // send B0 0B
        end

        8'h10:  begin
            power_on_internal_state <= 8'h06;        // jump to 6- send 2 command- go to 8'h11
            state_config <= 32'hb1310011;            // send B1 31
        end

        8'h11:  begin
            power_on_internal_state <= 8'h06;        // jump to 6- send 2 command- go to 8'h12
            state_config <= 32'hb3f00012;            // send B3 F0
        end

        8'h12:  begin
            power_on_internal_state <= 8'h06;        // jump to 6- send 2 command- go to 8'h13
            state_config <= 32'h8a640013;            // send 8A 64
        end

        8'h13:  begin
            power_on_internal_state <= 8'h06;        // jump to 6- send 2 command- go to 8'h14
            state_config <= 32'h8b780014;            // send 8B 78
        end

        8'h14:  begin
            power_on_internal_state <= 8'h06;        // jump to 6- send 2 command- go to 8'h15
            state_config <= 32'h8c640015;            // send 8C 64
        end

        8'h15:  begin
            power_on_internal_state <= 8'h06;        // jump to 6- send 2 command- go to 8'h16
            state_config <= 32'hbb3a0016;            // send BB 3A
        end

        8'h16:  begin
            power_on_internal_state <= 8'h06;        // jump to 6- send 2 command- go to 8'h17
            state_config <= 32'hbe3e0017;            // send BE 3E
        end

        8'h17:  begin
            power_on_internal_state <= 8'h06;        // jump to 6- send 2 command- go to 8'h18
            state_config <= 32'h87060018;            // send 87 06
        end

        8'h18:  begin
            power_on_internal_state <= 8'h06;        // jump to 6- send 2 command- go to 8'h19
            state_config <= 32'h81910019;            // send 81 91
        end

        8'h19:  begin
            power_on_internal_state <= 8'h06;        // jump to 6- send 2 command- go to 8'h1a
            state_config <= 32'h8250001a;            // send 82 50
        end

        8'h1a:  begin
            power_on_internal_state <= 8'h06;        // jump to 6- send 2 command- go to 8'h1b
            state_config <= 32'h837d001b;            // send 83 7D
        end

        8'h1b:  begin
            power_on_internal_state <= 8'h07;        // jump to 7- send 1 command- go to 8'h1c
            state_config <= 32'h2e00001c;            // send 2E
        end

        8'h1c:  begin                                // send 5 bytes- 25 00 00 5F 3F to clear screen
            if (counter == 32'h00000000) begin
                num_bytes <= 3'b101;                 // set number of bytes to send to b101 (5)
                data_TX <= 8'h25;                    // first byte to send
                data_valid <= 1'b1;
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h00000002) begin
                data_valid <= 1'b0;
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h00000032) begin     // sending first byte
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h00000034) begin
                data_TX <= 8'h00;                    // second byte to send
                data_valid <= 1'b1;
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h00000036) begin
                data_valid <= 1'b0;
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h0000005c) begin     // sending second byte
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h0000005e) begin
                counter <= counter + 1'b1;
                data_TX <= 8'h00;                    // third byte to send
                data_valid <= 1'b1;
            end
            else if (counter < 32'h00000060) begin
                data_valid <= 1'b0;
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h00000088) begin     // sending third byte
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h0000008a) begin     
                counter <= counter + 1'b1;
                data_TX <= 8'h5f;                    // fourth byte to send
                data_valid <= 1'b1;
            end
            else if (counter < 32'h0000008c) begin
                data_valid <= 1'b0;
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h000000b4) begin     // sending fourth byte
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h000000b6) begin 
                counter <= counter + 1'b1;
                data_TX <= 8'h3f;                    // fifth and last byte to send
                data_valid <= 1'b1;
            end
            else if (counter < 32'h000000b8) begin
                data_valid <= 1'b0;
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h000000e0) begin
                counter <= counter + 1'b1;           // sending fifth and last byte
            end
            else begin
                counter <= 32'h00000000;               // sending finished. clear counter. go to next command
                power_on_internal_state <= 8'h1d;
            end
        end

        8'h1d:  begin                                // bring VCCen high and wait 25 ms
            VCCen_reg <= 1'b1;
            counter <= counter + 1'b1;
            if (counter >= 32'h0027ac40) begin
                counter <= 32'h00000000;
                power_on_internal_state <= 8'h1e;
            end
        end

        8'h1e:  begin                                // send 1 command. turn display on
            power_on_internal_state <= 8'h07;        // jump to 7- send 1 command- go to 8'h1c
            state_config <= 32'haf00001f;            // send 2E
        end

        8'h1f:  begin                                // delay 100 ms
            counter <= counter + 1'b1;
            if (counter >= 32'h00a7d8c0) begin
                counter <= 32'h00000000;
                power_on_internal_state <= 8'h00;
                state <= ON_IDLE;
            end
        end

        endcase
    end

    POWER_OFF_SEQUENCE:  begin
        case(power_off_internal_state)

        8'h00:  begin
            if (counter == 32'h00000000) begin
                num_bytes <= 3'b001;
                data_TX <= 8'hae;                     // send 1 byte to turn display off, 0xAE
                data_valid <= 1'b1;
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h00000002) begin
                data_valid <= 1'b0;
                counter <= counter + 1'b1;
            end
            else if (counter < 32'h0000002f) begin
                counter <= counter + 1'b1;
            end
            else begin
                counter <= 32'h00000000;
                power_off_internal_state <= 8'h01;
            end
        end

        8'h01:  begin                                // bring VCCen low and wait 400 ms
            VCCen_reg <= 1'b0;
            counter <= counter + 1'b1;
            if (counter >= 32'h02625a00) begin
                counter <= 32'h00000000;
                power_off_internal_state <= 8'h00;
                state <= OFF_IDLE;
            end
        end
        endcase
    end

    ON_IDLE:  begin
        power_on_internal_state <= 8'h00;
        power_off_internal_state <= 8'h00;
        VCCen_reg <= 1'b1;
        PMODen_reg <= 1'b1;
    end

    OFF_IDLE: begin
        power_on_internal_state <= 8'h00;
        power_off_internal_state <= 8'h00;
        VCCen_reg <= 1'b0;
        PMODen_reg <= 1'b0;
    end

    endcase

end



endmodule