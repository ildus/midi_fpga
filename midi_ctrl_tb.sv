`timescale 1ns/1ns

module test();
	logic rst, clk, btn1, btn2, btn3, btn4, led1, led2, midi_tx, midi_rx;

	initial begin
		$printtimescale(test);
		$dumpfile("test.vcd");
		$dumpvars(0, test);
        #0 clk = 0;
        #0 midi_rx = 0;
		#10 rst = 0;
        #20 rst = 1;
		#1000 btn1 = 1;
		#1000 btn2 = 0;
        #100000 btn1 = 0;
        #100000 btn2 = 1;
        #150000 btn2 = 0;
		#200000 $finish;
	end
	always #10 clk = ~clk;

	midi_ctrl #(
        .BAUD_CNT_HALF(32),
        .DEBOUNCE_CNT(10)
    ) ctrl (rst, clk, btn1, btn2, btn3, btn4, midi_rx, midi_tx, led1, led2);
endmodule
