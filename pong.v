/*
Modified by: SAKIB REZA and DHARAK VERMA, October 2019
Copyright by Henry Ko and Nicola Nicolici, 
Developed for the Digital Systems Design course (COE3DQ4)
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps
`default_nettype none

module pong (
		/////// board clocks                      ////////////
		input logic CLOCK_50_I,                   // 50 MHz clock

		/////// pushbuttons/switches              ////////////
		input logic[3:0] PUSH_BUTTON_I,           // pushbuttons
		input logic[17:0] SWITCH_I,               // toggle switches

		/////// 7 segment displays/LEDs           ////////////
		output logic[6:0] SEVEN_SEGMENT_N_O[7:0], // 8 seven segment displays
		output logic[8:0] LED_GREEN_O,            // 9 green LEDs
		output logic[17:0] LED_RED_O,             // 18 red LEDs

		/////// VGA interface                     ////////////
		output logic VGA_CLOCK_O,                 // VGA clock
		output logic VGA_HSYNC_O,                 // VGA H_SYNC
		output logic VGA_VSYNC_O,                 // VGA V_SYNC
		output logic VGA_BLANK_O,                 // VGA BLANK
		output logic VGA_SYNC_O,                  // VGA SYNC
		output logic[7:0] VGA_RED_O,              // VGA red
		output logic[7:0] VGA_GREEN_O,            // VGA green
		output logic[7:0] VGA_BLUE_O,              // VGA blue
		
		//////////////////////////////////////////////////////////////////////////
		
		/////// PS2                               ////////////
		input logic PS2_DATA_I,                   // PS2 data
		input logic PS2_CLOCK_I                 // PS2 clock
		
		//////////////////////////////////////////////////////////////////////////
);

`include "VGA_Param.h"

logic system_resetn;

logic Clock_50, Clock_25, Clock_25_locked;

// For Push button
logic [3:0] PB_pushed;

// For VGA
logic [9:0] VGA_red, VGA_green, VGA_blue;
logic [9:0] pixel_X_pos;
logic [9:0] pixel_Y_pos;
logic VGA_vsync_buf;

// For Character ROM
logic [6:0] character_address;
logic rom_mux_output;

logic [7:0] lives_character_address;
logic [7:0] lives_character_address_2;
logic [7:0] score_character_address;
logic [7:0] score_character_address_2;

logic [3:0] lives_LSB;
logic [3:0] lives_MSB;
logic [3:0] score_LSB;
logic [3:0] score_MSB;

logic [7:0] prev_score_LSB;
logic [7:0] prev_score_MSB;

logic [7:0] prev_score_character_address;
logic [7:0] prev_score_character_address_2;

logic [7:0] time_left_MSB;
logic [7:0] time_left_LSB;

 
/////////////////////////////////////////////////////////////////////////////////////////////

// Welcome screen
logic welcome_screen;
logic flag_here; 
logic h_or_v;
logic [5:0] frame_count;

// ps2 shit
logic [7:0] PS2_code;
logic PS2_code_ready, PS2_code_ready_buf;
logic PS2_make_code;

// game over
logic [3:0] counter;


/////////////////////////////////////////////////////////////////////////////////////////////

// For the Pong game
parameter OBJECT_SIZE = 10,
		  BAR_X_SIZE = 60,
		  BAR_Y_SIZE = 5,
		  BAR_SPEED = 5,
		  SCREEN_BOTTOM = 50;

typedef struct {
	logic [9:0] X_pos;
	logic [9:0] Y_pos;	
} coordinate_struct;

coordinate_struct object_coordinate, bar_coordinate;

logic object_X_direction, object_Y_direction;

logic object_on, bar_on, screen_bottom_on;

logic [7:0] lives;
logic [7:0] score;
logic game_over;

logic [9:0] object_speed;

// For 7 segment displays
logic [6:0] value_7_segment [7:0];

// For end game text display
logic [7:0] highest_score_character_address;
logic [7:0] highest_score_character_address_2;

logic [7:0] game_id_address;
logic [7:0] game_id_address_2;

logic [7:0] game_id_LSB;
logic [7:0] game_id_MSB;

logic [7:0] highest_score_LSB;
logic [7:0] highest_score_MSB;

logic [7:0] time_left_address;
logic [7:0] time_left_address_2;




assign system_resetn = ~(SWITCH_I[17] || ~Clock_25_locked);

// PLL for clock generation
CLOCK_25_PLL CLOCK_25_PLL_inst (
	.areset(SWITCH_I[17]),
	.inclk0(CLOCK_50_I),
	.c0(Clock_50),
	.c1(Clock_25),
	.locked(Clock_25_locked)
);

// Push Button unit
PB_Controller PB_unit (
	.Clock_25(Clock_25),
	.Resetn(system_resetn),
	.PB_signal(PUSH_BUTTON_I),	
	.PB_pushed(PB_pushed)
);

// VGA unit
logic [9:0] VGA_RED_O_long, VGA_GREEN_O_long, VGA_BLUE_O_long;
VGA_Controller VGA_unit(
	.Clock(Clock_25),
	.Resetn(system_resetn),

	.iRed(VGA_red),
	.iGreen(VGA_green),
	.iBlue(VGA_blue),
	.oCoord_X(pixel_X_pos),
	.oCoord_Y(pixel_Y_pos),
	
	//	VGA Side
	.oVGA_R(VGA_RED_O_long),
	.oVGA_G(VGA_GREEN_O_long),
	.oVGA_B(VGA_BLUE_O_long),
	.oVGA_H_SYNC(VGA_HSYNC_O),
	.oVGA_V_SYNC(VGA_VSYNC_O),
	.oVGA_SYNC(VGA_SYNC_O),
	.oVGA_BLANK(VGA_BLANK_O),
	.oVGA_CLOCK(VGA_CLOCK_O)
);

assign VGA_RED_O = VGA_RED_O_long[9:2];
assign VGA_GREEN_O = VGA_GREEN_O_long[9:2];
assign VGA_BLUE_O = VGA_BLUE_O_long[9:2];

/////////////////////////////////////////////////////////////////////////////////////////////////
//assign VGA_red = (screen_bottom_on) ? 10'h3FF : ((object_on) ? 10'h3FF : ((welcome_screen) ? (h_or_v ? {10{~pixel_Y_pos[8]}} : {10{~pixel_X_pos[8]}}) : 10'd0)); // signal concatenation through replication:
//assign VGA_green = (rom_mux_output) ? 10'h3FF : ((object_on) ? 10'h3FF : ((welcome_screen) ? (h_or_v ? {10{~pixel_Y_pos[7]}}: {10{~pixel_X_pos[7]}}) : 10'd0)); // ~pixel_X_pos[i] is replicated 10 times
//assign VGA_blue = (rom_mux_output) ? 10'h3FF : ((bar_on) ? 10'h3FF: ((welcome_screen) ? (h_or_v ? {10{~pixel_Y_pos[6]}} : {10{~pixel_X_pos[6]}}) : 10'd0)); // to create a 10 bit signal 

/////////////////////////////////////////////////////////////////////////////////////////////////

// Character ROM
char_rom char_rom_unit (
	.Clock(VGA_CLOCK_O),
	.Character_address(character_address),
	.Font_row(pixel_Y_pos[2:0]),
	.Font_col(pixel_X_pos[2:0]-2'd1),	
	.Rom_mux_output(rom_mux_output)
);

// Convert hex to character address
convert_hex_to_char_rom_address convert_lives_to_char_rom_address (
	.hex_value(lives_MSB),
	.char_rom_address(lives_character_address)
);

convert_hex_to_char_rom_address convert_lives_to_char_rom_address_1 (
	.hex_value(lives_LSB),
	.char_rom_address(lives_character_address_2)
);

convert_hex_to_char_rom_address convert_score_to_char_rom_address_2 (
	.hex_value(score_MSB),
	.char_rom_address(score_character_address)
);

convert_hex_to_char_rom_address convert_score_to_char_rom_address_9 (
	.hex_value(score_LSB),
	.char_rom_address(score_character_address_2)
);

convert_hex_to_char_rom_address convert_score_to_char_rom_address_3 (
	.hex_value(prev_score_MSB),
	.char_rom_address(prev_score_character_address)
);

convert_hex_to_char_rom_address convert_score_to_char_rom_address_4 (
	.hex_value(prev_score_LSB),
	.char_rom_address(prev_score_character_address_2)
);

convert_hex_to_char_rom_address convert_score_to_char_rom_address_5 (
	.hex_value(game_id_MSB),
	.char_rom_address(game_id_address)
);

convert_hex_to_char_rom_address convert_score_to_char_rom_address_6 (
	.hex_value(game_id_LSB),
	.char_rom_address(game_id_address_2)
);

convert_hex_to_char_rom_address convert_score_to_char_rom_address_7 (
	.hex_value(highest_score_MSB),
	.char_rom_address(highest_score_character_address)
);

convert_hex_to_char_rom_address convert_score_to_char_rom_address_8 (
	.hex_value(highest_score_LSB),
	.char_rom_address(highest_score_character_address_2)
);

convert_hex_to_char_rom_address convert_score_to_char_rom_address_11 (
	.hex_value(time_left_MSB),
	.char_rom_address(time_left_address)
);

convert_hex_to_char_rom_address convert_score_to_char_rom_address_10 (
	.hex_value(time_left_LSB),
	.char_rom_address(time_left_address_2)
);

/////////////////////////////////////////////////////////////////////////////////////

PS2_controller PS2_unit (
	.Clock_50(Clock_25),
	.Resetn(system_resetn),
	
	.PS2_clock(PS2_CLOCK_I),
	.PS2_data(PS2_DATA_I),
	
	.PS2_code(PS2_code),
	.PS2_code_ready(PS2_code_ready),
	.PS2_make_code(PS2_make_code)
);

////////////////////////////////////////////////////////////////////////////////////

assign object_speed = {7'd0, SWITCH_I[2:0]};

// RGB signals 
/* commented out for nested assign statements
always_comb begin
		VGA_red = 10'd0;
		VGA_green = 10'd0;
		VGA_blue = 10'd0;
		if (object_on) begin
			// Yellow object
			VGA_red = 10'h3FF;
			VGA_green = 10'h3FF;
		end
		
		if (bar_on) begin
			// Blue bar
			VGA_blue = 10'h3FF;
		end
		
		if (screen_bottom_on) begin
			// Red border
			VGA_red = 10'h3FF;
		end
		
		if (rom_mux_output) begin
			// Display text
			VGA_blue = 10'h3FF;
			VGA_green = 10'h3FF;
		end
end
*/

always_ff @ (posedge Clock_25 or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		VGA_vsync_buf <= 1'b0;
	end else begin
		VGA_vsync_buf <= VGA_VSYNC_O;
	end
end

/////////////////////////////////////////////////////////////////////////////////////////////
always_ff @ (posedge Clock_25 or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		VGA_red <= 10'd0;
		VGA_blue <= 10'd0;
		VGA_green <= 10'd0;
		
	end else begin
		if (game_over == 1'b1) begin
			VGA_red <= 10'h0;
			VGA_green <= 10'h0;
			VGA_blue <= 10'h0;
			
		end
	
		if (welcome_screen == 1'b1) begin
			if (h_or_v ==1'b0) begin
				if (pixel_X_pos >= 10'd0 && pixel_X_pos <= 10'd80) begin
					VGA_red <= 10'h3ff;
					VGA_green <= 10'h3ff;
					VGA_blue <= 10'h3ff;
					
				end else if (pixel_X_pos > 10'd80 && pixel_X_pos <= 10'd160) begin
					VGA_red <= 10'h3ff;
					VGA_green <= 10'h3ff;
					VGA_blue <= 10'h0;
					
				end else if (pixel_X_pos > 10'd160 && pixel_X_pos <= 10'd240) begin
					VGA_red <= 10'h3ff;
					VGA_green <= 10'h0;
					VGA_blue <= 10'h3ff;
					
				end else if (pixel_X_pos > 10'd240 && pixel_X_pos <= 10'd320) begin
					VGA_red <= 10'h3ff;
					VGA_green <= 10'h0;
					VGA_blue <= 10'h0;
					
				end else if (pixel_X_pos > 10'd320 && pixel_X_pos <= 10'd400) begin
					VGA_red <= 10'h0;
					VGA_green <= 10'h3ff;
					VGA_blue <= 10'h3ff;
					
				end else if (pixel_X_pos > 10'd400 && pixel_X_pos <= 10'd480) begin
					VGA_red <= 10'h0;
					VGA_green <= 10'h3ff;
					VGA_blue <= 10'h0;
					
				end else if (pixel_X_pos > 10'd480 && pixel_X_pos <= 10'd560) begin
					VGA_red <= 10'h0;
					VGA_green <= 10'h0;
					VGA_blue <= 10'h3ff;
					
				end else if (pixel_X_pos > 10'd560 && pixel_X_pos <= 10'd640) begin
					VGA_red <= 10'h0;
					VGA_green <= 10'h0;
					VGA_blue <= 10'h0;
					
				end 
			end else if (h_or_v ==1'b1) begin
			
				if (pixel_Y_pos >= 10'd0 && pixel_Y_pos <= 10'd60) begin
					VGA_red <= 10'h3ff;
					VGA_green <= 10'h3ff;
					VGA_blue <= 10'h3ff;
					
				end else if (pixel_Y_pos > 10'd60 && pixel_Y_pos <= 10'd120) begin
					VGA_red <= 10'h3ff;
					VGA_green <= 10'h3ff;
					VGA_blue <= 10'h0;
					
				end else if (pixel_Y_pos > 10'd120 && pixel_Y_pos <= 10'd180) begin
					VGA_red <= 10'h3ff;
					VGA_green <= 10'h0;
					VGA_blue <= 10'h3ff;
					
				end else if (pixel_Y_pos > 10'd180 && pixel_Y_pos <= 10'd240) begin
					VGA_red <= 10'h3ff;
					VGA_green <= 10'h0;
					VGA_blue <= 10'h0;
					
				end else if (pixel_Y_pos > 10'd240 && pixel_Y_pos <= 10'd300) begin
					VGA_red <= 10'h0;
					VGA_green <= 10'h3ff;
					VGA_blue <= 10'h3ff;
					
				end else if (pixel_Y_pos > 10'd300 && pixel_Y_pos <= 10'd360) begin
					VGA_red <= 10'h0;
					VGA_green <= 10'h3ff;
					VGA_blue <= 10'h0;
					
				end else if (pixel_Y_pos > 10'd360 && pixel_Y_pos <= 10'd420) begin
					VGA_red <= 10'h0;
					VGA_green <= 10'h0;
					VGA_blue <= 10'h3ff;
					
				end else if (pixel_Y_pos > 10'd420 && pixel_Y_pos <= 10'd480) begin
					VGA_red <= 10'h0;
					VGA_green <= 10'h0;
					VGA_blue <= 10'h0;
					
				end 
			end
			
		end else begin
			VGA_red <= 10'h0;
			VGA_green <= 10'h0;
			VGA_blue <= 10'h0;
			if (object_on || bar_on) begin
				if (object_on) begin
					VGA_red <= 10'h3ff;
					VGA_green <= 10'h3ff;
				end
				
				if (bar_on) begin
					VGA_blue <= 10'h3ff;
				end

			end else if (screen_bottom_on || rom_mux_output) begin
				if (screen_bottom_on) begin
					VGA_red <= 10'h3ff;
				end
				
				if (rom_mux_output) begin
					VGA_green <= 10'h3ff;
					VGA_blue <= 10'h3ff;
				end
			end 
		end
	end
end

//assign VGA_red = (screen_bottom_on) ? 10'h3FF : ((object_on) ? 10'h3FF : ((welcome_screen) ? (h_or_v ? {10{~pixel_Y_pos[8]}} : {10{~pixel_X_pos[8]}}) : 10'd0)); // signal concatenation through replication:
//assign VGA_green = (rom_mux_output) ? 10'h3FF : ((object_on) ? 10'h3FF : ((welcome_screen) ? (h_or_v ? {10{~pixel_Y_pos[7]}}: {10{~pixel_X_pos[7]}}) : 10'd0)); // ~pixel_X_pos[i] is replicated 10 times
//assign VGA_blue = (rom_mux_output) ? 10'h3FF : ((bar_on) ? 10'h3FF: ((welcome_screen) ? (h_or_v ? {10{~pixel_Y_pos[6]}} : {10{~pixel_X_pos[6]}}) : 10'd0)); // to create a 10 bit signal 

// Welcome screen code
always_ff @ (posedge Clock_25 or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		welcome_screen <= 1'b1;
		flag_here <= 1'b0;
		h_or_v <= 1'b0;
		frame_count <= 1'b0;
		
	end else begin
		if (PS2_code_ready && ~PS2_code_ready_buf && PS2_make_code == 1'b1) begin
			welcome_screen <= 1'b0;

		end
		if (~VGA_VSYNC_O && VGA_vsync_buf) begin
			frame_count <= frame_count + 1'd1;
			
		end
		
		if (frame_count == 6'd60) begin
			h_or_v <= ~h_or_v; //0 is for horizontal 1 is for vertical
			frame_count <= 6'd0;
			
		end	
	end
end


//gameover code


/////////////////////////////////////////////////////////////////////////////////////////////

// Updating location of the object (Ball)
always_ff @ (posedge Clock_25 or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		object_coordinate.X_pos <= 10'd200;
		object_coordinate.Y_pos <= 10'd50;
		
		object_X_direction <= 1'b1;	
		object_Y_direction <= 1'b1;	

		score_LSB <= 8'd0;		
		score_MSB <= 8'd0;
		lives_LSB <= 8'h3; 
		lives_MSB <= 8'h0;
		game_over <= 1'b0;
				
		game_id_LSB <= 8'd0;
		game_id_MSB <= 8'd0;
		
		highest_score_LSB <= 8'd0;
		highest_score_MSB <= 8'd0;
		
		counter <= 4'd14;
		
		time_left_LSB <= 4'd5;
		time_left_MSB <= 4'd1;
		

	end else begin
		
		if (welcome_screen != 1'b1) begin
			
			if (game_over == 1'b1) begin
				if (frame_count == 6'd60) begin
					counter <= counter - 4'd1;
					if (counter >= 4'd10) begin
						time_left_LSB <= counter - 4'd10;
						time_left_MSB <= 4'd1;
					end else begin
						time_left_LSB <= counter;
						time_left_MSB <= 4'd0;
					end
					
					
					if (counter <= 4'd0) begin
						object_coordinate.X_pos <= 10'd200;
						object_coordinate.Y_pos <= 10'd50;
						
						object_X_direction <= 1'b1;	
						object_Y_direction <= 1'b1;	

						score_LSB <= 8'd0;		
						score_MSB <= 8'd0;
						lives_LSB <= 8'h3; 
						lives_MSB <= 8'h0;
						game_over <= 1'b0;
						
						counter <= 4'd14;
						
						time_left_LSB <= 4'd5;
						time_left_MSB <= 4'd1;
					end
				end
			end
				
			// Update movement during vertical blanking
			if (VGA_vsync_buf && ~VGA_VSYNC_O && game_over == 1'b0) begin
				if (object_X_direction == 1'b1) begin
					// Moving right
					if (object_coordinate.X_pos < H_SYNC_ACT - OBJECT_SIZE - object_speed) 
						object_coordinate.X_pos <= object_coordinate.X_pos + object_speed;
					else
						object_X_direction <= 1'b0;
				end else begin
					// Moving left
					if (object_coordinate.X_pos >= object_speed) 		
						object_coordinate.X_pos <= object_coordinate.X_pos - object_speed;		
					else
						object_X_direction <= 1'b1;
				end
				
				if (object_Y_direction == 1'b1) begin
					// Moving down
					if (object_coordinate.Y_pos <= bar_coordinate.Y_pos - OBJECT_SIZE - object_speed)
						object_coordinate.Y_pos <= object_coordinate.Y_pos + object_speed;
					else begin
						if (object_coordinate.X_pos >= bar_coordinate.X_pos 							// Left edge of object is within bar
						 && object_coordinate.X_pos + OBJECT_SIZE <= bar_coordinate.X_pos + BAR_X_SIZE 	// Right edge of object is within bar
						) begin
							// Hit the bar
							object_Y_direction <= 1'b0;
		
							score_LSB <= score_LSB + 8'd1;	
							
								if (score_LSB == 8'd9) begin
									score_MSB <= score_MSB + 8'd1;
									score_LSB <= 8'd0;
								end
								
						end else begin
							// Hit the bottom of screen 
							
							if (lives_MSB >= 8'd0 && lives_LSB > 8'd0) begin
								lives_LSB <= lives_LSB - 8'd1;

							end
							
							if (lives_MSB >= 8'd0 && lives_LSB == 8'd0) begin
									lives_LSB <= 8'd9;
									lives_MSB <= lives_MSB - 8'd1;
								
							end	


							
							
							if (lives_LSB == 8'd1 && lives_MSB == 8'd0) begin
							
								
								prev_score_LSB <= score_LSB;
								prev_score_MSB <= score_MSB;
								
								if ((score_MSB > highest_score_MSB) || (score_MSB == highest_score_MSB && score_LSB >= highest_score_LSB)) begin
									highest_score_LSB <= score_LSB;
									highest_score_MSB <= score_MSB;
								end
								
								game_id_LSB <= game_id_LSB + 8'd1;
			
								if (game_id_LSB == 8'd9 && game_id_MSB < 8'd9) begin
									game_id_LSB <= 8'd0;
									game_id_MSB <= game_id_MSB + 8'd1;
								end
								
								game_over <= 1'b1;
							

							end else begin
								// Game over
								object_X_direction <= SWITCH_I[16];	
								object_Y_direction <= SWITCH_I[15];
								
								object_coordinate.X_pos <= 10'd200;
								object_coordinate.Y_pos <= 10'd50;

							end
								
							
						end
					end
				end else begin
					// Moving up
					if (object_coordinate.Y_pos >= object_speed) 				
						object_coordinate.Y_pos <= object_coordinate.Y_pos - object_speed;		
					else
						object_Y_direction <= 1'b1;
				end		
			end
		end//
	end
end

// Update the location of bar
always_ff @ (posedge Clock_25 or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		bar_coordinate.X_pos <= 10'd200;
		bar_coordinate.Y_pos <= 10'd0;
	end else begin
		if (welcome_screen != 1'b1) begin 
			bar_coordinate.Y_pos <= V_SYNC_ACT-BAR_Y_SIZE-SCREEN_BOTTOM;
		
			
			// Update the movement during vertical blanking
			if (VGA_vsync_buf && ~VGA_VSYNC_O) begin
				if (PS2_make_code == 1'b1 && PS2_code == 8'h1B) begin //slight delay due to how the ps2 keyboard works
					// Move bar right
					if (bar_coordinate.X_pos < H_SYNC_ACT - BAR_X_SIZE - BAR_SPEED) 		
						bar_coordinate.X_pos <= bar_coordinate.X_pos + BAR_SPEED;
				end else begin
					if (PS2_make_code == 1'b1 && PS2_code == 8'h1C) begin
						// Move bar left
						if (bar_coordinate.X_pos > BAR_SPEED) 		
							bar_coordinate.X_pos <= bar_coordinate.X_pos - BAR_SPEED;
					end 	
				end
			end
		end//
	end
end

// Check if the ball should be displayed or not
always_comb begin
	
	if (pixel_X_pos >= object_coordinate.X_pos && pixel_X_pos < object_coordinate.X_pos + OBJECT_SIZE
	 && pixel_Y_pos >= object_coordinate.Y_pos && pixel_Y_pos < object_coordinate.Y_pos + OBJECT_SIZE
	 && game_over == 1'b0 && welcome_screen == 1'b0) 
		object_on = 1'b1;
	else 
		object_on = 1'b0;
end

// Check if the bar should be displayed or not
always_comb begin
	if (pixel_X_pos >= bar_coordinate.X_pos && pixel_X_pos < bar_coordinate.X_pos + BAR_X_SIZE
	 && pixel_Y_pos >= bar_coordinate.Y_pos && pixel_Y_pos < bar_coordinate.Y_pos + BAR_Y_SIZE && welcome_screen == 1'b0 && game_over == 1'b0) 
		bar_on = 1'b1;
	else 
		bar_on = 1'b0;
end

// Check if the line on the bottom of the screen should be displayed or not
always_comb begin
	if (pixel_Y_pos == V_SYNC_ACT - SCREEN_BOTTOM + 1 && welcome_screen == 1'b0 && game_over == 1'b0) 
		screen_bottom_on = 1'b1;
	else 
		screen_bottom_on = 1'b0;
end


// Display text
always_comb begin
	character_address = 6'o40; // Show space by default
	
	// 8 x 8
	if (pixel_Y_pos[9:3] == ((V_SYNC_ACT - SCREEN_BOTTOM + 20) >> 3) && welcome_screen == 1'b0 && game_over == 1'b0) begin
		// Reach the section where the text is displayed
		case (pixel_X_pos[9:3])
			7'd0: character_address = 6'o14; // L
			7'd1: character_address = 6'o11; // I
			7'd2: character_address = 6'o26; // V
			7'd3: character_address = 6'o05; // E
			7'd4: character_address = 6'o23; // S
			7'd5: character_address = 6'o40; // space
			7'd6: character_address = lives_character_address;
			7'd7: character_address = lives_character_address_2;
			
			7'd71: character_address = 6'o23; // S
			7'd72: character_address = 6'o03; // C
			7'd73: character_address = 6'o17; // O
			7'd74: character_address = 6'o22; // R
			7'd75: character_address = 6'o05; // E
			7'd76: character_address = 6'o40; // space
			7'd77: character_address = score_character_address; 	
			7'd78: character_address = score_character_address_2; 
		endcase
	end
	
	if (game_over == 1'b1 && pixel_Y_pos[9:3] == ((V_SYNC_ACT - SCREEN_BOTTOM - 300) >> 3) && welcome_screen == 1'b0 && game_over == 1'b1) begin
		case (pixel_X_pos[9:3])
		
			7'd0: character_address = 6'o14; // L
			7'd1: character_address = 6'o01; // A
			7'd2: character_address = 6'o23; // S
			7'd3: character_address = 6'o24; // T
			7'd4: character_address = 6'o40; // space
			
			7'd5: character_address = 6'o07; // G
			7'd6: character_address = 6'o01; // A
			7'd7: character_address = 6'o15; // M
			7'd8: character_address = 6'o05; // E
			7'd9: character_address = 6'o47; // '
			7'd10: character_address = 6'o23; // s
			7'd11: character_address = 6'o40; // space

			7'd12: character_address = 6'o23; // s
			7'd13: character_address = 6'o03; // c
			7'd14: character_address = 6'o17; // o
			7'd15: character_address = 6'o22; // r
			7'd16: character_address = 6'o05; // e
			7'd17: character_address = 6'o40; // space
			
			7'd18: character_address = 6'o27; // w
			7'd19: character_address = 6'o01; // a
			7'd20: character_address = 6'o23; // s
			7'd21: character_address = 6'o40; // space
			7'd22: character_address = prev_score_character_address; // MSB of previous score
			7'd23: character_address = prev_score_character_address_2; // LSB of previous score
		endcase
		
	end
		if (game_over == 1'b1 && pixel_Y_pos[9:3] == ((V_SYNC_ACT - SCREEN_BOTTOM - 200) >> 3) && welcome_screen == 1'b0 && game_over == 1'b1) begin
		case (pixel_X_pos[9:3])
				
			7'd0: character_address = 6'o07; // G
			7'd1: character_address = 6'o01; // A
			7'd2: character_address = 6'o15; // M
			7'd3: character_address = 6'o05; // E
			7'd4: character_address = 6'o40; // space

			7'd5: character_address = game_id_address; // MSB of game id
			7'd6: character_address = game_id_address_2; // LSB of game id
			7'd7: character_address = 6'o40; // space

			7'd8: character_address = 6'o23; // s
			7'd9: character_address = 6'o03; // c
			7'd10: character_address = 6'o17; // o
			7'd11: character_address = 6'o22; // r
			7'd12: character_address = 6'o05; // e
			7'd13: character_address = 6'o40; // space

			7'd14: character_address = highest_score_character_address; // MSB of previous score
			7'd15: character_address = highest_score_character_address_2; // LSB of previous score
		endcase
		
	end 
	
		if (game_over == 1'b1 && pixel_Y_pos[9:3] == ((V_SYNC_ACT - SCREEN_BOTTOM - 100) >> 3) && welcome_screen == 1'b0 && game_over == 1'b1) begin
		case (pixel_X_pos[9:3])
				
			7'd0: character_address = 6'o24; // t
			7'd1: character_address = 6'o11; // i
			7'd2: character_address = 6'o15; // M
			7'd3: character_address = 6'o05; // E
			7'd4: character_address = 6'o40; // space

			7'd5: character_address = 6'o14; // L
			7'd6: character_address = 6'o05; // E
			7'd7: character_address = 6'o06; // f
			7'd8: character_address = 6'o24; // t
			7'd9: character_address = 6'o40; // space

			7'd10: character_address = time_left_address; // MSB of time
			7'd11: character_address = time_left_address_2; // LSB of time
		endcase
		
	end 
end

convert_hex_to_seven_segment unit3 (
	.hex_value(welcome_screen), 
	.converted_value(value_7_segment[7])
);

convert_hex_to_seven_segment unit4 (
	.hex_value(h_or_v), 
	.converted_value(value_7_segment[6])
);



convert_hex_to_seven_segment unit6 (
	.hex_value({8'h00, score_LSB}), 
	.converted_value(value_7_segment[0])
);



convert_hex_to_seven_segment unit7 (
	.hex_value({8'h00, score_MSB}), 
	.converted_value(value_7_segment[1])
);


convert_hex_to_seven_segment unit5 (
	.hex_value({8'h00, lives_MSB}), 
	.converted_value(value_7_segment[3])
);

convert_hex_to_seven_segment unit2 (
	.hex_value({8'h00, lives_LSB}), 
	.converted_value(value_7_segment[2])
);


assign	SEVEN_SEGMENT_N_O[0] = value_7_segment[0],
		SEVEN_SEGMENT_N_O[1] = value_7_segment[2],
		SEVEN_SEGMENT_N_O[2] = value_7_segment[1],
		SEVEN_SEGMENT_N_O[3] = value_7_segment[3],
		SEVEN_SEGMENT_N_O[4] = value_7_segment[4],
		SEVEN_SEGMENT_N_O[5] = value_7_segment[5],
		SEVEN_SEGMENT_N_O[6] = value_7_segment[6],
		SEVEN_SEGMENT_N_O[7] = value_7_segment[7];

assign LED_RED_O = {system_resetn, 15'd0, object_X_direction, object_Y_direction};
assign LED_GREEN_O = {game_over, 4'd0, PB_pushed};

endmodule
