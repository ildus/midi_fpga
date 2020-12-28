`timescale 1ns/1ns

module test();
	logic rst, clk, btn, led1, led2, midi_tx;

	initial begin
		$printtimescale(test);
		$dumpfile("test.vcd");
		$dumpvars(0, test);
        #0 clk = 0;
		#10 rst = 0;
        #20 rst = 1;
		#1000 btn = 1;
		#200000 $finish;
	end
	always #10 clk = ~clk;

	midi_ctrl #(.BAUD_CNT_HALF(32)) ctrl (rst, clk, btn, led1, led2, midi_tx);
endmodule
