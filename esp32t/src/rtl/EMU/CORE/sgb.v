// sgb.v - Super GameBoy palette support for Chromatic FPGA
// Adapted from MiSTer Gameboy_MiSTer/rtl/sgb.v
// Border rendering and attribute mapping removed; SGB palette colorisation retained.
// Original copyright applies — GPL-3.0 license.

module sgb (
	input        reset,
	input        clk_sys,
	input        ce,

	input        sgb_en,
	input        tint,
	input        isGBC_game,

	input        lcd_clkena,
	input [14:0] lcd_data,
	input [1:0]  lcd_data_gb,
	input [1:0]  lcd_mode,
	input        lcd_on,
	input        lcd_vsync,

	input [7:0]  joystick_0,
	input [7:0]  joystick_1,
	input [7:0]  joystick_2,
	input [7:0]  joystick_3,

	input [1:0]  joy_p54,
	output [3:0] joy_do,

	// External palette read port (for combinational overlay outside the module)
	output [14:0] sgb_pal_out,
	input  [1:0]  pal_read_idx,

	output reg        sgb_pal_en,
	output reg [14:0] sgb_lcd_data,
	output reg        sgb_lcd_clkena,
	output reg [1:0]  sgb_lcd_mode,
	output reg        sgb_lcd_on,
	output reg        sgb_lcd_freeze,
	output reg        sgb_lcd_vsync
);

localparam CMD_PAL01    = 5'h00;
localparam CMD_PAL23    = 5'h01;
localparam CMD_PAL03    = 5'h02;
localparam CMD_PAL12    = 5'h03;
localparam CMD_PAL_SET  = 5'h0A;
localparam CMD_PAL_TRN  = 5'h0B;
localparam CMD_MLT_REQ  = 5'h11;
localparam CMD_MASK_EN  = 5'h17;


wire p14 = joy_p54[0];
wire p15 = joy_p54[1];

reg old_p15, old_p14;
reg [7:0] data;
reg [3:0] byte_cnt;
reg [2:0] cnt, packet_cnt;
reg [2:0] length;
reg byte_done, packet_end;
reg [4:0] cmd;

reg [1:0] mlt_ctrl;
reg trn_start, pal_set;

reg [1:0] pal0123_no, pal0123_col_no;
reg [14:0] pal_color;
reg pal0123_wr;

// SGB packet detection state machine (SameBoy-style 3-step handshake)
reg ready_for_pulse, ready_for_write, ready_for_stop;

reg [8:0] sys_pal_no[4];
reg [1:0] mask_en;
reg cancel_mask;

always @(posedge clk_sys) begin
	 if (reset) begin
		packet_cnt <= 0;
		cnt <= 0;
		byte_cnt <= 0;
		byte_done <= 0;
		mask_en <= 0;
		packet_end <= 1'b1;
 		mlt_ctrl <= 0;
 		ready_for_pulse <= 0;
 		ready_for_write <= 0;
 		ready_for_stop <= 0;
	 end else if (ce) begin
		old_p15 <= p15;
		old_p14 <= p14;

		if (sgb_en) begin
			// SameBoy-style state machine: requires 3-step handshake
			// ($30 pulse → $00 write → $10/$20 bit) to accept each bit.
			// Normal joypad scanning never writes $00, so no false bits.
			case ({p15, p14})
				2'b11: begin // $30 — idle/pulse
					ready_for_pulse <= 1;
				end

				2'b00: begin // $00 — packet start (requires preceding pulse)
					if (ready_for_pulse) begin
						ready_for_write <= 1;
						ready_for_pulse <= 0;
						ready_for_stop <= 0;
						cnt <= 0;
						byte_cnt <= 0;
						packet_end <= 0;
					end
				end

				2'b01, 2'b10: begin // $10 (bit 1) or $20 (bit 0)
					if (ready_for_pulse && ready_for_write) begin
						if (ready_for_stop) begin
							ready_for_write <= 0;
							ready_for_stop <= 0;
							ready_for_pulse <= 0;
						end else begin
							data <= {~p15, data[7:1]};
							cnt <= cnt + 1'b1;
							ready_for_pulse <= 0;
							if (&cnt) byte_done <= 1'b1;
							if (&cnt && &byte_cnt) ready_for_stop <= 1;
						end
					end
				end
			endcase
		end

		trn_start <= 0;
		pal_set <= 0;
		pal0123_wr <= 0;

		if (pal_cancel_mask) mask_en <= 0;

		if (byte_done) begin
			byte_done <= 0;
			byte_cnt <= byte_cnt + 1'b1;

			if (!packet_cnt && !byte_cnt) begin
				{cmd,length} <= data;
			end

			case (cmd)
				CMD_MLT_REQ: begin
					if (byte_cnt == 5'd1)
						mlt_ctrl <= (data[1:0] == 2'd2) ? 2'd3 : data[1:0];
				end
				CMD_PAL_TRN: begin
					if (byte_cnt == 5'd1) trn_start <= 1'b1;
				end
				CMD_PAL01,
				CMD_PAL23,
				CMD_PAL03,
				CMD_PAL12: begin
					if (byte_cnt >= 4'd1 && byte_cnt <= 4'd14) begin
						if (byte_cnt[0]) pal_color[7:0] <= data;
						else begin
							pal_color[14:8] <= data[6:0];
							pal0123_wr <= 1'b1;
						end
					end

					case (byte_cnt)
						1:    pal0123_col_no <= 2'd0;
						3,9:  pal0123_col_no <= 2'd1;
						5,11: pal0123_col_no <= 2'd2;
						7,13: pal0123_col_no <= 2'd3;
					endcase

					// color 0 always goes to palette 0
					case ({cmd,byte_cnt})
						{CMD_PAL01,4'd1},
						{CMD_PAL23,4'd1},
						{CMD_PAL03,4'd1},
						{CMD_PAL12,4'd1}: pal0123_no <= 2'd0;

						{CMD_PAL01,4'd9},
						{CMD_PAL12,4'd3}: pal0123_no <= 2'd1;

						{CMD_PAL12,4'd9},
						{CMD_PAL23,4'd3}: pal0123_no <= 2'd2;

						{CMD_PAL23,4'd9},
						{CMD_PAL03,4'd9}: pal0123_no <= 2'd3;
					endcase

				end
				CMD_PAL_SET:
					case (byte_cnt)
						1: sys_pal_no[0][7:0] <= data;
						2: sys_pal_no[0][8]   <= data[0];
						3: sys_pal_no[1][7:0] <= data;
						4: sys_pal_no[1][8]   <= data[0];
						5: sys_pal_no[2][7:0] <= data;
						6: sys_pal_no[2][8]   <= data[0];
						7: sys_pal_no[3][7:0] <= data;
						8: sys_pal_no[3][8]   <= data[0];
						9: begin
							cancel_mask <= data[6];
							pal_set <= 1'b1;
						end
					endcase
				CMD_MASK_EN: begin
					if (byte_cnt == 5'd1) mask_en <= data[1:0];
				end
			endcase

			// End of packet
			if (&byte_cnt) begin
				packet_cnt <= packet_cnt + 1'b1;
				if (packet_cnt + 1'b1 >= length) begin
					packet_cnt <= 0;
					packet_end <= 1'b1;
				end
			end
		end
	end

end


// Joypad multiplexer (SGB multi-player protocol)
reg [1:0] joypad_id;

always @(posedge clk_sys) begin
	if (reset) begin
		joypad_id <= 0;
	end else if (ce) begin
		joypad_id <= (joypad_id & mlt_ctrl);
		if (sgb_en & ~old_p15 & p15) begin
			joypad_id <= (joypad_id + 1'b1);
		end
	end
end

assign joy_do = (sgb_en & p15 & p14) ? ~{2'b00, joypad_id} : joy_data;

wire [3:0] joy_dir     = ~{ joystick[0], joystick[1], joystick[2], joystick[3] } | {4{p14}};
wire [3:0] joy_buttons = ~{ joystick[7], joystick[6], joystick[5], joystick[4] } | {4{p15}};
wire [3:0] joy_data = joy_dir & joy_buttons;

wire [7:0] joystick =
				(~sgb_en | ~mlt_ctrl[0]) ? (joystick_0 | joystick_1) :
				(joypad_id == 2'd0) ? joystick_0 :
				(joypad_id == 2'd1) ? joystick_1 :
				(joypad_id == 2'd2) ? joystick_2 :
				                      joystick_3;

wire lcd_off = !lcd_on || (lcd_mode == 2'd01);
reg old_lcd_off;

// LCD frame scanner — tracks pixel position and collects pixel data
// for PAL_TRN transfers.
reg trn_en, trn_wait, frame_end;
reg [7:0] pix_x, pix_y;
reg [8:0] tile_offset;
reg [6:0] trn_data_h, trn_data_l;

wire [8:0] tile_number = {tile_offset+pix_x[7:3]};
wire [13:0] pixel_wr_addr = {tile_number[7:0], pix_y[2:0], pix_x[2:0]};
wire [15:0] trn_data = {trn_data_h, lcd_data_gb[1], trn_data_l, lcd_data_gb[0]};

always @(posedge clk_sys) begin
	if (ce) begin
		frame_end <= 0;

		old_lcd_off <= lcd_off;
		if(~old_lcd_off & lcd_off) begin
			trn_en <= 0;
			pix_x <= 0;
			pix_y <= 0;
			tile_offset <= 0;
			frame_end <= 1'b1;
		end

		if(lcd_clkena & ~lcd_off) begin
			pix_x <= pix_x + 1'b1;
			if (pix_x == 8'd159) begin
				pix_x <= 0;
				pix_y <= pix_y + 1'b1;
				if(&pix_y[2:0]) tile_offset <= tile_offset + 9'd20;
			end

			if (trn_en) begin
				trn_data_h <= {trn_data_h[5:0],lcd_data_gb[1]};
				trn_data_l <= {trn_data_l[5:0],lcd_data_gb[0]};
			end

			if (pix_x == 8'd159 && pix_y == 8'd103) begin // 256 tiles
				trn_en <= 0;
			end
		end

		// Wait until start of frame before enabling transfer
		if (trn_start) trn_wait <= 1'b1;

		if (old_lcd_off & ~lcd_off) begin
			trn_wait <= 0;
			if (trn_wait) begin
				trn_en <= 1'b1;
			end
		end
	end

end

wire trn_data_wr = (ce && lcd_clkena && trn_en && &pix_x[2:0] && !tile_number[8]);

// System palette RAM (for PAL_TRN / PAL_SET)
(* ramstyle="block" *) reg [14:0] sys_pal_ram[2048];

always @(posedge clk_sys) begin
	if (trn_data_wr && cmd == CMD_PAL_TRN) begin
		sys_pal_ram[pixel_wr_addr[13:3]] <= trn_data[14:0];
	end
end

// Palette storage
reg [14:0] sys_pal_data, pal_wr_data;
reg [1:0] pal_wr_no, pal_wr_col_no;
reg [0:59] palette[4];
reg pal_set_wait, pal_set_busy, pal_wr, pal_cancel_mask, pal_clear;
reg [3:0] pal_set_cnt, pal_set_cnt_r;
reg output_sgb_pal;

always @(posedge clk_sys) begin
	if (reset) begin
		output_sgb_pal <= 0;
		pal_set_busy <= 0;
		pal_set_wait <= 0;
		pal_clear <= 1'b1;
		pal_set_cnt <= 0;
	end else if (ce) begin

		pal_cancel_mask <= 0;
		pal_wr <= 0;

		if (pal_set) pal_set_wait <= 1'b1;

		if (pal_set_wait & frame_end) begin
			pal_set_wait <= 0;
			pal_set_busy <= 1'b1;
			pal_set_cnt <= 0;
			pal_set_cnt_r <= 0;
		end

		sys_pal_data <= sys_pal_ram[{sys_pal_no[pal_set_cnt[3:2]], pal_set_cnt[1:0]}];

		if (pal_set_busy) begin
			pal_set_cnt <= pal_set_cnt + 1'b1;
			pal_set_cnt_r <= pal_set_cnt;

			if (&pal_set_cnt_r) begin
				pal_set_busy <= 0;
				output_sgb_pal <= 1'b1;
				if (cancel_mask) pal_cancel_mask <= 1'b1;
			end

			pal_wr <= 1'b1;
			pal_wr_data <= sys_pal_data;
			{pal_wr_no, pal_wr_col_no} <= pal_set_cnt_r;
		end

		// Direct palette write (PAL01/PAL23/PAL03/PAL12)
		if (pal0123_wr) begin
			output_sgb_pal <= 1'b1;
			pal_wr <= 1'b1;
			pal_wr_data <= pal_color;
			pal_wr_no <= pal0123_no;
			pal_wr_col_no <= pal0123_col_no;
		end

		if (pal_clear) begin
			pal_set_cnt <= pal_set_cnt + 1'b1;
			pal_wr <= 1'b1;
			pal_wr_data <= 0;
			{pal_wr_no, pal_wr_col_no} <= pal_set_cnt;
			if (&pal_set_cnt) pal_clear <= 0;
		end

		if (pal_wr) begin
			palette[pal_wr_no][pal_wr_col_no*15 +: 15] <= pal_wr_data;
		end

	end

end

// LCD palette output — no attribute files, all tiles use palette 0
reg [14:0] lcd_data_r;
reg [1:0]  lcd_data_gb_r;
reg lcd_clkena_r, lcd_on_r, lcd_vsync_r;
reg [1:0]  lcd_mode_r;
reg [1:0]  mask_en_r;

always @(posedge clk_sys) begin
	if (ce) begin

		if (lcd_off) begin
			mask_en_r <= mask_en;
		end

		lcd_data_r <= lcd_data;
		lcd_data_gb_r <= lcd_data_gb;
		lcd_clkena_r <= lcd_clkena;
		lcd_mode_r <= lcd_mode;
		lcd_on_r <= lcd_on;
		lcd_vsync_r <= lcd_vsync;

		if (~sgb_en | ((~output_sgb_pal | tint | isGBC_game) & !mask_en_r) ) begin
			sgb_lcd_data <= lcd_data_r;
		end else if (mask_en_r == 2'd2) begin
			sgb_lcd_data <= 0;
		end else if (!lcd_data_gb_r || mask_en_r == 2'd3) begin
			sgb_lcd_data <= palette[0][0:14];
		end else begin
			sgb_lcd_data <= palette[0][lcd_data_gb_r*15 +: 15];
		end

		sgb_lcd_clkena <= lcd_clkena_r;
		sgb_lcd_mode <= lcd_mode_r;
		sgb_lcd_on <= lcd_on_r;
		sgb_lcd_freeze <= sgb_en && mask_en_r == 2'd1;
		sgb_pal_en <= sgb_en & ( (output_sgb_pal & ~tint & ~isGBC_game) || |mask_en_r);
		sgb_lcd_vsync <= lcd_vsync_r;
	end
end

// External palette read port — combinational lookup with R/B swap for BGR555
wire [14:0] _pal_raw = palette[0][pal_read_idx*15 +: 15];
assign sgb_pal_out = {_pal_raw[4:0], _pal_raw[9:5], _pal_raw[14:10]};

endmodule