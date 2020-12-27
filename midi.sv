module midi
(
	input logic [7:0] note,
	input logic [7:0] velocity,
	output logic [7:0] status,
	output logic [7:0] data1,
	output logic [7:0] data2,
	output logic [1:0] bytes_cnt
);

always_comb begin
	status = 8'h90;
	data1 = note;
	data2 = velocity;
	bytes_cnt = 2'd3;
end

endmodule
