module audio_filter
(
	input        reset,
	input        clk,

	input [15:0] core_l,
	input [15:0] core_r,

	output [15:0] filter_l,
	output [15:0] filter_r
);

// ----------------------------------------------------------------
// Shift-only replacement for the 3-tap IIR + DC_blocker.
// Saves 7 MULT27X36 DSPs and ~1300 CLS vs. the original.
//
// Signal chain (per channel, at ~65.5 kHz sample rate):
//   1. 2-stage cascaded 1-pole IIR low-pass   y = (x + y) >>> 1
//      → 2-pole, fc ≈ 7 kHz, 12 dB/oct
//   2. 1-pole DC blocker                      y += x − x_prev − (y >>> 8)
//      → high-pass, fc ≈ 41 Hz
// ----------------------------------------------------------------

// Capture stable input (same as original)
reg [15:0] cl, cr;
reg [15:0] cl1, cl2, cr1, cr2;
always @(posedge clk) begin
	cl1 <= core_l; cl2 <= cl1;
	if(cl2 == cl1) cl <= cl2;

	cr1 <= core_r; cr2 <= cr1;
	if(cr2 == cr1) cr <= cr2;
end

// Output sample rate ≈ 65.5 kHz (CLK_RATE / 256)
reg sample_ce;
reg [7:0] div = 0;
always @(posedge clk) begin
	div <= div + 1'd1;
	if(!div) div <= 2'd1;
	sample_ce <= !div;
end

// Startup mute (~125 ms)
reg [14:0] dly = 0;
reg a_en = 0;
always @(posedge clk or posedge reset) begin
	if (reset) begin
		dly  <= 0;
		a_en <= 0;
	end else if (sample_ce) begin
		if (!dly[13]) dly <= dly + 1'd1;
		else a_en <= 1;
	end
end

// 2-stage cascaded 1-pole IIR low-pass (no multipliers)
reg signed [15:0] lp1_l, lp2_l;
reg signed [15:0] lp1_r, lp2_r;

// DC blocker with 24-bit accumulator
reg signed [23:0] dc_l, dc_r;
reg signed [15:0] dc_x_l, dc_x_r;

always @(posedge clk) begin
	if (reset) begin
		lp1_l <= 0; lp2_l <= 0;
		lp1_r <= 0; lp2_r <= 0;
		dc_l  <= 0; dc_r  <= 0;
		dc_x_l <= 0; dc_x_r <= 0;
	end else if (sample_ce) begin
		// Low-pass stage 1: y = (x + y) / 2
		lp1_l <= ($signed(cl) + $signed(lp1_l)) >>> 1;
		lp1_r <= ($signed(cr) + $signed(lp1_r)) >>> 1;
		// Low-pass stage 2: y = (x + y) / 2
		lp2_l <= ($signed(lp1_l) + $signed(lp2_l)) >>> 1;
		lp2_r <= ($signed(lp1_r) + $signed(lp2_r)) >>> 1;
		// DC blocker: y += x − x_prev − y/256
		dc_l <= dc_l + $signed(lp2_l) - $signed(dc_x_l) - (dc_l >>> 8);
		dc_r <= dc_r + $signed(lp2_r) - $signed(dc_x_r) - (dc_r >>> 8);
		dc_x_l <= lp2_l;
		dc_x_r <= lp2_r;
	end
end

assign filter_l = a_en ? dc_l[15:0] : 16'd0;
assign filter_r = a_en ? dc_r[15:0] : 16'd0;

endmodule