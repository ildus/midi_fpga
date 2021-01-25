`timescale 1 ns / 100 ps
module debounce_3pin
	(
	input       clk, button_in_1, button_in_2,     // inputs
	output logic    raised = 0		                    // output
	);

    logic init = 0;
    logic old_pin1 = 0, old_pin2 = 0;
    logic pin1, pin2;
    logic out;

    assign out = button_in_1 ^ button_in_2;
    assign pinout = pin1 ^ pin2;

    always_ff @(posedge out) begin
        pin1 <= button_in_1;
        pin2 <= button_in_2;
    end

    always @(posedge clk) begin
        if (!init) begin
            old_pin1 = button_in_1;
            old_pin2 = button_in_2;
            init <= 1;
        end
        else begin
            if (pinout && pin1 != old_pin1 && pin2 != old_pin2) begin
                raised <= 1;
                old_pin1 <= pin1;
                old_pin2 <= pin2;
            end
            else
                raised <= 0;
        end
    end
endmodule
