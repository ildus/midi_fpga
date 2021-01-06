// Version 1.0 04/11/2013 Tony Storey
// Initial Public Release
// Small Footprint Button Debouncer

`timescale 1 ns / 100 ps
module  debounce
	(
	input       clk, n_reset, button_in,    // inputs
	output reg 	button_out = 0					// output
	);
	parameter N = 21 ;      // counter should fill in 10ms in 100Mhz

	reg  [N-1 : 0]	q_reg;  // timing regs
	reg  [N-1 : 0]	q_next;
	reg DFF1, DFF2;			// input flip-flops
	wire q_add;				// control flags
	wire q_reset;

    // contenious assignment for counter control
	assign q_reset = (DFF1  ^ DFF2);    // xor input flip flops to look for level chage to reset counter
	assign  q_add = ~(q_reg[N-1]);	    // add to counter when q_reg msb is equal to 0

    // combo counter to manage q_next
	always @ ( q_reset, q_add, q_reg)
		begin
			case( {q_reset , q_add})
				2'b00 :
						q_next <= q_reg;
				2'b01 :
						q_next <= q_reg + 1;
				default :
						q_next <= { N {1'b0} };
			endcase
		end

    // Flip flop inputs and q_reg update
	always @ ( posedge clk )
		begin
			if(n_reset ==  1'b0)
				begin
					DFF1 <= 1'b0;
					DFF2 <= 1'b0;
					q_reg <= { N {1'b0} };
				end
			else
				begin
					DFF1 <= button_in;
					DFF2 <= DFF1;
					q_reg <= q_next;
				end
		end

    // counter control
	always @ ( posedge clk )
		begin
			if(q_reg[N-1] == 1'b1)
					button_out <= DFF2;
			else
					button_out <= button_out;
		end

endmodule
