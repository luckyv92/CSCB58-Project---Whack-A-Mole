module high_score_tracker(clock, score, high_score);
	output reg [7:0] high_score;
	input clock;
	input [7:0] score;
	
	always @(posedge clock)
	begin
		if (score > high_score)
		begin
			high_score <= score;
		end
	end
endmodule
