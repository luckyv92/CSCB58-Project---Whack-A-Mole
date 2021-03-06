module whack_a_mole(
	SW, 
	KEY, 
	CLOCK_50, 
	LEDR, 
	HEX0, 
	HEX1, 
	HEX4,
	HEX5,
	HEX6, 
	HEX7,
	// The ports below are for the VGA output.  Do not change.
	VGA_CLK,   						//	VGA Clock
	VGA_HS,							//	VGA H_SYNC
	VGA_VS,							//	VGA V_SYNC
	VGA_BLANK_N,						//	VGA BLANK
	VGA_SYNC_N,						//	VGA SYNC
	VGA_R,   						//	VGA Red[9:0]
	VGA_G,	 						//	VGA Green[9:0]
	VGA_B   						   //	VGA Blue[9:0])
	);
	input CLOCK_50;
	input [17:0] SW;
	input [3:0] KEY;
	output [17:0] LEDR;
	output [6:0] HEX0, HEX1, HEX4, HEX5, HEX6, HEX7;


	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	
	wire [7:0] x;
	wire [6:0] y;
	wire [2:0] colour;
	
	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(1'b1), 
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "background.mif";
	

	// ----------------- ALL USER INPUTS -----------------//
	
	wire resetn;
	wire go;
	wire restart_game;
	wire [1:0] game_speed;
	wire [3:0] hammer_position;
	wire [3:0] moles;

	assign go = SW[17];
	assign restart_game = SW[16];
	assign resetn = SW[15];
	assign game_speed[1:0] = SW[7:6];
	assign hammer_position[3:0] = KEY[3:0];
	assign LEDR[3:0] = moles[3:0];

	
	// ----------------- ALL GAME SIGNALS -----------------//
	
	// Outputs of score
	wire [7:0] score;
	wire [7:0] high_score;
	
	// Output from DisplayCounter
	wire [7:0] gametimer;
	
	// Set to high when countdown reaches 0
	wire end_game_signal;
	
	// Outputs from FSM
	wire start_game, stand_by, end_game, current_state;
	
	control FSM(
		.clk(CLOCK_50),
		.resetn(resetn),
		.go(go),
		.restart_game(restart_game),
		.end_game_signal(end_game_signal),
		.start_game(start_game),
		.stand_by(stand_by),
		.end_game(end_game)
	);
	
	datapath gameModule(
		.clk(CLOCK_50),
		.resetn(resetn),
		.keys(hammer_position),
		.start_game_state(start_game),
		.stand_by_state(stand_by),
		.end_game_state(end_game),
		.rate(game_speed),
		.score(score[7:0]),
		.moles(moles)
	);
	
	// Game countdown pulse (one second)
	wire one_sec_pulse;
	
	RateDivider RD(
		.clock(CLOCK_50),
		.rate(2'b01),
		.reset_n(resetn),
		.pulse(one_sec_pulse)
	);
	
	GameTimer gametime(
		.counter(gametimer[7:0]),
		.reset(start_game),
		.enable(one_sec_pulse),
		.clock(CLOCK_50)
	);
	
	// High score tracker
	high_score_tracker highscore(
		.clock(CLOCK_50),
		.score(score),
		.high_score(high_score)
	);

	// Send end game signal when timer hits 0
	assign end_game_signal = (gametimer[7:0] == 8'd0) ? 1'b1 : 1'b0;

	//------------------VGA DISPLAY CONTROLLER----------------------------
	display_mole display(
		.clock(CLOCK_50),
		.moles(moles),
		.x(x),
		.y(y),
		.color(colour)
	);

	// Display the score
    hex_decoder H0(
        .hex_digit(score[3:0]), 
        .segments(HEX0[6:0])
        );
        
    hex_decoder H1(
        .hex_digit(score[7:4]), 
        .segments(HEX1[6:0])
        );
		
	// Display the hish score
	hex_decoder H4(
        .hex_digit(high_score[3:0]), 
        .segments(HEX4[6:0])
        );
		
    hex_decoder H5(
        .hex_digit(high_score[7:4]), 
        .segments(HEX5[6:0])
        );
	
	// Display the game timer
	hex_decoder H7(
        .hex_digit(gametimer[7:4]), 
        .segments(HEX7[6:0])
        );
    hex_decoder H6(
        .hex_digit(gametimer[3:0]), 
        .segments(HEX6[6:0])
        );
		
endmodule

module control(
	input clk,
	input resetn,
	input go, // Start game signal from user
	input restart_game, // Restart game signal from user
	input end_game_signal, // Signal to inform the control game is over (countdown reached 0)

	output reg start_game, // Start game state signal from FSM
	output reg stand_by,// Stand by state signal from FSM
	output reg end_game // end game state signal from FSM
	);

	reg [1:0] next_state,current_state; 
    
	localparam  S_stand_by        = 2'd0,
                S_start_game      = 2'd1,
				S_end_game		  = 2'd2;
	
	// Next state logic aka our state table
	always@(*)
	begin: state_table 
		case (current_state)
			 S_stand_by:    next_state = go ? S_start_game : S_stand_by;
			 S_start_game:  next_state = end_game_signal ? S_end_game : S_start_game;
		    S_end_game:    next_state = restart_game ? S_stand_by : S_end_game;
		    default:       next_state = S_stand_by;
		endcase
	end // state_table
   

	// Output logic aka all of our datapath control signals
	always @(*)
	begin: enable_signals
		start_game <= 1'b0;
		stand_by <= 1'b0;
		end_game <= 1'b0;
		
      case (current_state)
         S_stand_by: begin
            stand_by <= 1'b1;
         end
         S_start_game: begin
            start_game <= 1'b1;
         end
         S_end_game: begin
            end_game <= 1'b1;
         end
         default: stand_by <= 1'b1;
		endcase
	end // enable_signals
   
	// current_state registersstart_game_state
	always@(posedge clk)
	begin: state_FFs
		if(!resetn)
			current_state <= S_stand_by;
		else
			current_state <= next_state;
	end // state_FFS

endmodule

module datapath(
	input clk,
	input resetn,
	input [3:0] keys, // The holes the player picks
	input start_game_state, // Start game signal from FSM
	input stand_by_state, // Stand by signal from FSM 
	input end_game_state, // End game signal from FSM
	input [1:0] rate, // Rate the moles pop upfrom user input
	
	output reg [7:0] score, // Score of player
	output reg [3:0] moles
);
	
	// Clock signal for the rate the moles appear and disappear
	wire mole_clock;
	wire [27:0] c;
	RateDivider RD(.clock(clk), .rate(rate), .reset_n(resetn), .pulse(mole_clock), .count(c));
	
	// Random number to determine which hole the mole pop out of
	wire [15:0] random_num;
	LFSR_random_number r(.clock(clk), .reset_n(resetn), .ran_num(random_num));
	
	// 2 bit random number from 0-3
	reg [1:0] random_mole;
	reg [1023:0] ran;
	
	// Temp score count
	reg [7:0] temp_score;
	
	// Boolean value to make sure a player doesn't click the button twice for the same mole
	reg mole_cycle;

	always @(posedge mole_clock)
	begin
	
		if (mole_cycle)
			mole_cycle = 1'b0;
		else
			mole_cycle = 1'b1;
			
		// Set all the holes off, so that a new hole can be selected
		if (!mole_cycle)
			moles[3:0] <= 4'b0000;

		else if (start_game_state) begin
			random_mole <= random_num%4;
			if (random_mole == 2'd0)
				moles[0] <= 1'b1;
			else if (random_mole == 2'd1)
				moles[1] <= 1'b1;
			else if (random_mole == 2'd2)
				moles[2] <= 1'b1;
			else
				moles[3] <= 1'b1;
		end
	end
	
	reg clicked;
	
	// The user hammer selection, Determend_game_signaline if the hole that was selected had a mole in it
	always @(posedge clk)
	begin
		// Once the mole clock turns positive that means a new mole has appeared
		// so reset the clicked boolean
		if (mole_clock)
			clicked <= 1'b0;
		// Refresh the score while we are in the stand-by state
		if (stand_by_state) begin
			// No moles will pop out at this stage
			score <= 8'd0;
		end
		else
		begin
			// Increment point only once per mole
			if (!clicked) 
			begin
				if (!keys[0])
				begin
					if (moles[0])
					begin
						if (score[3:0] == 4'd9)
						begin
							score[7:4] <= score[7:4] + 1'b1;
							score[3:0] <= 4'b0000;
						end
						else
						begin
							score <= score + 1'b1;
						end
						clicked <= 1'b1;
					end
				end
				else if (!keys[1])
				begin
					if (moles[1])
					begin
						if (score[3:0] == 4'd9)
						begin
							score[7:4] <= score[7:4] + 1'b1;
							score[3:0] <= 4'b0000;
						end
						else
						begin
							score <= score + 1'b1;
						end
						clicked <= 1'b1;
					end
				end
				else if (!keys[2])
				begin
					if (moles[2])
					begin
						if (score[3:0] == 4'd9)
						begin
							score[7:4] <= score[7:4] + 1'b1;
							score[3:0] <= 4'b0000;
						end
						else
						begin
							score <= score + 1'b1;
						end
						clicked <= 1'b1;
					end
				end
				else if (!keys[3])
				begin
					if (moles[3])
					begin
						if (score[3:0] == 4'd9)
						begin
							score[7:4] <= score[7:4] + 1'b1;
							score[3:0] <= 4'b0000;
						end
						else
						begin
							score <= score + 1'b1;
						end
						clicked <= 1'b1;
					end
				end
			end
		end
	end
	
endmodule

module display_mole(
	input clock,
	input [3:0] moles, 
	output reg [7:0] x,
	output reg [6:0] y, 
	output reg [2:0] color
	);
	
	reg [3:0] refresh_moles;
	
	wire [7:0]  x_start, x_temp;
	wire [6:0]  y_start, y_temp;
	
	mole_to_vga_LUT vga1(moles, x_start, y_start);
	mole_to_vga_LUT vga2(refresh_moles, x_temp, y_temp);
	
	reg [5:0] counter_x;
	reg [4:0] counter_y;
	
	always @(posedge clock)
	begin
		if (counter_y == 5'd26) begin
			counter_y <= 5'b00000;
			counter_x <= 6'b000000;
			if (refresh_moles == 4'b0000 || refresh_moles == 4'b1000)
				refresh_moles <= 4'b0001;
			else if (refresh_moles == 4'b0001)
				refresh_moles <= 4'b0010;
			else if (refresh_moles == 4'b0010)
				refresh_moles <= 4'b0100;
			else if (refresh_moles == 4'b0100)
				refresh_moles <= 4'b1000;
		end
		else if (counter_x == 6'd44) begin
			counter_x <= 6'b000000;
			counter_y <= counter_y + 1'b1;
		end
		else begin
			if (x_start == 8'd0 && y_start == 7'd0) begin
				if (x_temp != 8'd0 || y_temp != 7'd0) begin
					color <= 3'b000;
					x <= x_temp + counter_x;
					y <= y_temp + counter_y;
					counter_x <= counter_x + 1'b1;
				end
			end
			else begin
				if (counter_y == 2'd3 && (counter_x > 4'd14 && counter_x < 5'd20)) begin
					color <= 3'b111;
				end
				else if (counter_y == 3'd4 && 
				((counter_x > 4'd12 && counter_x <= 4'd14) || 
				(counter_x == 5'd20))
				) begin
					color <= 3'b111;
				end
				else if (counter_y == 3'd5 && 
				((counter_x == 4'd12) || 
				(counter_x > 5'd20 && counter_x < 5'd22)) 
				) begin
					color <= 3'b111;
				end
				else if (counter_y == 3'd6 && 
				((counter_x >= 4'd10 && counter_x <= 4'd11) || 
				(counter_x >= 5'd22 && counter_x <= 6'd34) )
				) begin
					color <= 3'b111;
				end
				else if (counter_y == 3'd7 && 
				((counter_x >= 4'd7 && counter_x <= 4'd9) || 
				(counter_x >= 5'd16 && counter_x <= 5'd17)||
				(counter_x == 5'd25) ||
				(counter_x == 6'd35))) begin
					color <= 3'b111;
				end
				else if (counter_y == 6'd8 && 
				((counter_x >= 4'd5 && counter_x <= 4'd7) || 
				(counter_x == 5'd15)||
				(counter_x == 5'd18) ||
				(counter_x == 6'd26) ||
				(counter_x == 6'd36)))  begin
					color <= 3'b111;
				end
				else if (counter_y == 6'd9 && 
				((counter_x >= 4'd4 && counter_x <= 4'd8) || 
				(counter_x == 5'd15)||
				(counter_x == 6'd18) ||
				(counter_x == 6'd27) ||
				(counter_x == 6'd37))
				) begin
					color <= 3'b111;
				end
				else if (counter_y == 6'd10 && 
				((counter_x >= 4'd4 && counter_x <= 4'd9) || 
				(counter_x >= 5'd16 && counter_x <= 5'd17)||
				(counter_x == 6'd38))
				) begin
					color <= 3'b111;
				end	
				else if (counter_y == 6'd11 && 
				((counter_x >= 4'd5 && counter_x <= 4'd9) || 
				(counter_x == 6'd39))
				) begin
					color <= 3'b111;
				end			
				else if (counter_y == 6'd12 && 
				((counter_x == 4'd6)|| 
				(counter_x == 5'd7)||
				(counter_x == 6'd39))
				) begin
					color <= 3'b111;
				end		
				else if (counter_y == 6'd13 && 
				((counter_x == 4'd7) || 
				(counter_x >= 5'd15 && counter_x <= 5'd20)||
				(counter_x == 6'd39))
				) begin
					color <= 3'b111;
				end		
				else if (counter_y == 6'd14 && 
				((counter_x >= 4'd8 && counter_x <= 4'd9) || 
				(counter_x >= 5'd13 && counter_x <= 5'd14)||
				(counter_x == 6'd21) ||
				(counter_x >= 6'd39 && counter_x <= 6'd41))
				) begin
					color <= 3'b111;
				end	
				else if (counter_y == 6'd15 && 
				((counter_x == 4'd7) || 
				(counter_x >= 5'd10 && counter_x <= 5'd12)||
				(counter_x == 6'd22) ||
				(counter_x == 6'd39) ||
				(counter_x == 6'd42))
				) begin
					color <= 3'b111;
				end
				else if (counter_y == 6'd16 && 
				((counter_x == 4'd6) || 
				(counter_x == 5'd9)||
				(counter_x == 6'd22) ||
				(counter_x >= 6'd27 && counter_x <= 6'd34) ||
				(counter_x >= 6'd39 && counter_x <= 6'd40) ||
				(counter_x == 6'd43))
				) begin
					color <= 3'b111;
				end
				else if (counter_y == 6'd17 && 
				((counter_x >= 4'd6 && counter_x <= 4'd8) ||
				(counter_x == 6'd22) ||
				(counter_x == 6'd26) ||
				(counter_x == 6'd35) ||
				(counter_x == 6'd39) ||
				(counter_x >= 6'd41 && counter_x <= 6'd42))
				) begin
					color <= 3'b111;
				end	
				else if (counter_y == 6'd18 && 
				((counter_x >= 4'd9 && counter_x <= 4'd10) ||
				(counter_x == 6'd12) ||
				(counter_x == 6'd15) ||
				(counter_x == 6'd22) ||
				(counter_x == 6'd25) ||
				(counter_x >= 6'd36 && counter_x <= 6'd38))
				) begin
					color <= 3'b111;
				end	
				else if (counter_y == 6'd19 && 
				((counter_x == 6'd11) ||
				(counter_x == 6'd14) ||
				(counter_x == 6'd18) ||
				(counter_x >= 6'd21 && counter_x <= 6'd25) ||
				(counter_x == 6'd28) ||
				(counter_x == 6'd36))
				) begin
					color <= 3'b111;
				end	
				else if (counter_y == 6'd20 && 
				((counter_x == 6'd10) ||
				(counter_x == 6'd13) ||
				(counter_x == 6'd17) ||
				(counter_x == 6'd20) ||
				(counter_x == 6'd25) ||
				(counter_x == 6'd27) ||
				(counter_x == 6'd35))
				) begin
					color <= 3'b111;
				end	
				else if (counter_y == 6'd21 && 
				((counter_x == 6'd9) ||
				(counter_x == 6'd12) ||
				(counter_x == 6'd15) ||
				(counter_x == 6'd16) ||
				(counter_x == 6'd26) ||
				(counter_x >= 6'd29 && counter_x <= 6'd30) ||
				(counter_x == 6'd34))
				) begin
					color <= 3'b111;
				end	
				else if (counter_y == 6'd22 && 
				((counter_x >= 6'd10 && counter_x <= 6'd14) ||
				(counter_x >= 6'd16 && counter_x <= 6'd18) ||
				(counter_x >= 6'd27 && counter_x <= 6'd28) ||
				(counter_x >= 6'd30 && counter_x <= 6'd33))
				) begin
					color <= 3'b111;
				end
				else
					color <= 3'b000;
				
				
				x <= x_start + counter_x;
				y <= y_start + counter_y;
				counter_x <= counter_x + 1'b1;
			end
		end
	end
endmodule

module mole_to_vga_LUT(moles, x, y);
	input [3:0] moles;
	output reg [7:0] x;
	output reg [6:0] y;
	
	always @(*)
	begin
		case (moles)
			4'b0001: begin
					x<= 8'd92;	
					y <= 7'd74;
				end
			4'b0010: begin
					x<= 8'd25;	
					y <= 7'd74;
				end
			4'b0100: begin
					x<= 8'd92;
					y <= 7'd36;
				end
			4'b1000: begin
					x<= 8'd25;	
					y <= 7'd36;
				end
			default: begin
					x<= 8'd0;	
					y <= 7'd0;
				end
		endcase
	end

endmodule

module RateDivider(clock, rate, reset_n, pulse, count);
	input clock, reset_n;
	input [1:0] rate;
	output pulse;
	output [27:0] count;
	
	reg [27:0] countDown;
	
	always @(posedge clock)
	begin
		if (reset_n == 1'b0)
			countDown <= 28'b00000_00000_00000_00000_00000_000;
		else
		begin
			// If countdown is 0 then re-initialize it
			if (countDown == 28'b00000_00000_00000_00000_00000_000)
				begin
					if (rate == 2'b00)
						countDown <= (28'd25_000_000 - 28'd1);
					else if (rate == 2'b01)
						countDown <= (28'd50_000_000 - 28'd1);
					else if (rate == 2'b10)
						countDown <= (28'd100_000_000 - 28'd1);
					else if (rate == 2'b11)
						countDown <= (28'd200_000_000 - 28'd1);
				end
			// Count down by 1
			else
				countDown <= countDown - 1'b1;
		end
	end
	
	assign pulse = (countDown == 28'b00000_00000_00000_00000_00000_000) ? 1 : 0;
	assign count = countDown;
endmodule


// Game timer counts from 30 -> 0 in decimal
module GameTimer (counter, reset, enable, clock);
    wire [7:0] initial_val;
    assign initial_val = 8'b0011_0000;
    output reg [7:0] counter;
    input reset;
    input enable;
    input clock;
   
    always @ (posedge clock)
    begin
		if (!reset)
			 counter <= initial_val; // Reset counter to 30
		else if (enable)
		begin
			if (counter == 8'b00000000)
				counter <= 8'b00000000;
			 
			else
			begin
				// Case one: need to count down from 0, so set last 4 bits to 9
				if (counter[3:0] == 4'b0000)
				begin
					counter[7:4] <= counter[7:4] - 1'b1;
					counter[3:0] <= 4'd9;
				end
				else
				begin
					counter <= counter - 1'b1;
				end
			end
	 end
 end
endmodule


module hex_decoder(hex_digit, segments);
    input [3:0] hex_digit;
    output reg [6:0] segments;
   
    always @(*)
        case (hex_digit)
            4'h0: segments = 7'b100_0000;
            4'h1: segments = 7'b111_1001;
            4'h2: segments = 7'b010_0100;
            4'h3: segments = 7'b011_0000;
            4'h4: segments = 7'b001_1001;
            4'h5: segments = 7'b001_0010;
            4'h6: segments = 7'b000_0010;
            4'h7: segments = 7'b111_1000;
            4'h8: segments = 7'b000_0000;
            4'h9: segments = 7'b001_1000;
            4'hA: segments = 7'b000_1000;
            4'hB: segments = 7'b000_0011;
            4'hC: segments = 7'b100_0110;
            4'hD: segments = 7'b010_0001;
            4'hE: segments = 7'b000_0110;
            4'hF: segments = 7'b000_1110;   
            default: segments = 7'h7f;
        endcase
endmodule
