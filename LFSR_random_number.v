module LFSR_random_number(clock, reset_n, ran_num);
	output reg [15:0] ran_num;
	input clock, reset_n;
	
	wire feedback;
	
	assign feedback = !(ran_num[2] ^ ran_num[10] ^ ran_num[13] ^ ran_num[15]);
	
	always @(posedge clock)
	begin
		if (!reset_n)
			ran_num <= 15'd0;
		else
		begin
			ran_num <= {ran_num[14],
						ran_num[13],
						ran_num[12],
						ran_num[11],
						ran_num[10],
						ran_num[9],
						ran_num[8],
						ran_num[7],
						ran_num[6],
						ran_num[5],
						ran_num[4],
						ran_num[3],
						ran_num[2],
						ran_num[1],
						ran_num[0],
						feedback};
		end
	
	end
endmodule