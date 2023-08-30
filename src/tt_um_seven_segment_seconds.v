`default_nettype none

module tt_um_seven_segment_seconds #( parameter MAX_COUNT = 64'hffff_ffff_ffff_ffff ) (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    wire reset = ! rst_n;
    wire [6:0] led_out;
    // assign uo_out[6:0] = led_out;
    // assign uo_out[7] = 1'b0;
 
    // use bidirectionals as outputs
    assign uio_oe = 8'b11111111;

    // put bottom 8 bits of second counter out on the bidirectional gpio
    // assign uio_out = second_counter[7:0];   

    // external clock is 10MHz, so need 24 bit counter
    reg [63:0] second_counter;
    reg [3:0] digit;

    // if external inputs are set then use that as compare count
    // otherwise use the hard coded MAX_COUNT
    wire [63:0] compare = ui_in == 0 ? MAX_COUNT: {46'b0, ui_in[7:0], 10'b0};

    always @(posedge clk) begin
        // if reset, set counter to 0
        if (reset) begin
            second_counter <= 0;
            digit <= 0;
        end else begin
            // if up to 16e6
            if (second_counter == compare) begin
                // reset
                second_counter <= 0;

                // increment digit
                digit <= digit + 1'b1;

                // only count from 0 to 9
                if (digit == 9)
                    digit <= 0;

            end else
                // increment counter
                second_counter <= second_counter + 1'b1;
        end
    end

    // instantiate segment display
    seg7 seg7(.counter(digit), .segments(led_out));

    localparam IW=16;	// The number of bits in our inputs
    localparam OW=16;	// The number of output bits to produce
    localparam NSTAGES=20;
                        // XTRA= 4,// Extra bits for internal precision
    localparam WW=20;	// Our working bit-width
    localparam PW=24;	// Bits in our phase variables
    
    wire [IW-1:0] x_in, y_in;
    assign x_in = {2{uio_in}};
    assign y_in = {2{ui_in}};
    wire [PW-1:0] ph;
    assign ph = {3{uio_in}};
    wire [OW-1:0] x_o, y_o;
    assign x_o = uio_out;
    assign y_o = uo_out;

    cordic_nco cordic_nco0 (
		// {{{
	.i_clk(clk), .i_reset(!rst_n), .i_ce(ena),
	.i_xval(x_in), .i_yval(y_in),
	.i_phase(ph),
	.o_xval(x_o), .o_yval(y_o)
		// }}}
	);


endmodule
