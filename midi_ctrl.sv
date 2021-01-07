/* MIDI Controller.
*
* Timing details:
   We should send one bit each 32 usec (1 sec  / 31250 ).
   in 32 usec - 32000 nsec - (32000nsec / 10nsec) - 3200 ticks,
   which gives us 320usec for 10 bits per packet,
   16 usec for baud_clk going up and 16 usec for going down.
*/
module top #(parameter BAUD_CNT_HALF = 3200 / 2, parameter DEBOUNCE_CNT = 21)
(
    input logic rst,
    input logic clk,
    input logic btn1,
    input logic btn2,
    input logic btn3,
    input logic btn4,
    output logic led1 = 1,
    output logic led2 = 0,
    output logic midi_tx = 1
);

localparam STATUS = 4'hB; // CC message
localparam CHANNEL = 4'h0; // channel 0
localparam FIRST_CC_MSG = 8'd46;
localparam CC_VALUE = 8'b0111_1111;

// protocol
logic baud_clk = 0;
logic [5:0] bits_cnt;
logic [12:0] clk_cnt = 0;
logic [29:0] midi_out = 0;

//midi
logic [7:0] status = 0;
logic [7:0] data1 = 0;
logic [7:0] data2 = 0;
logic [7:0] cc_msg = 0;

// buttons
logic cmd_set = 0;
logic cmd_reset = 0;
logic btn1_raise;
logic btn2_raise;
logic btn3_raise;
logic btn4_raise;

debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) d1 (clk, rst, btn1, btn1_raise);
debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) d2 (clk, rst, btn2, btn2_raise);
debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) d3 (clk, rst, btn3, btn3_raise);
debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) d4 (clk, rst, btn4, btn4_raise);

always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
        clk_cnt <= 0;
        baud_clk <= 0;
    end
    else if (clk_cnt == BAUD_CNT_HALF - 1) begin
        clk_cnt <= 0;
        baud_clk <= ~baud_clk;
    end
    else begin
        clk_cnt <= clk_cnt + 1;
    end
end

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        cc_msg <= 0;
    end
    else begin
        case ({btn4_raise, btn3_raise, btn2_raise, btn1_raise})
            4'b0001:
                cc_msg <= FIRST_CC_MSG + 0;
            4'b0010:
                cc_msg <= FIRST_CC_MSG + 1;
            4'b0100:
                cc_msg <= FIRST_CC_MSG + 2;
            4'b1000:
                cc_msg <= FIRST_CC_MSG + 3;
            default:
                cc_msg <= 0;
        endcase
    end
end

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        cmd_set <= 0;
    end
    else begin
        if (cmd_reset)
            cmd_set <= 0;
        else if (cc_msg != 0) begin
            status <= {STATUS, CHANNEL};
            data1 <= cc_msg;
            data2 <= CC_VALUE;
            cmd_set <= 1;
        end
    end
end

always_ff @(posedge baud_clk or negedge rst) begin
    if (!rst) begin
        led1 <= 0;
        led2 <= 1;
        bits_cnt <= 0;
        midi_tx <= 1;
        midi_out <= 0;
        cmd_reset <= 0;
    end
    else if (bits_cnt != 0) begin
        midi_tx <= midi_out[0];
        midi_out <= {1'b0, midi_out[29:1]};
        bits_cnt <= bits_cnt - 1;
        cmd_reset <= 0;
    end
    else if (cmd_set && bits_cnt == 0) begin
        led1 <= led2;
        led2 <= led1;

        // we're sending bits from LSB, so the structure constructed backwards
        midi_out <= {1'b1, data2, 1'b0,
                     1'b1, data1, 1'b0,
                     1'b1, status, 1'b0};
        bits_cnt <= 5'd30;
        cmd_reset <= 1;
    end
    else begin
        cmd_reset <= 0;
        midi_tx <= 1;
    end
end

endmodule
