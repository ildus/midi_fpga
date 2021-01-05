/* MIDI Controller.
*
* Timing details:
   We should send one bit each 32 usec (1 sec  / 31250 ).
   in 32 usec - 32000 nsec - (32000nsec / 10nsec) - 3200 ticks,
   which gives us 320usec for 10 bits per packet,
   16 usec for baud_clk going up and 16 usec for going down.
*/
module top #(parameter BAUD_CNT_HALF = 3200 / 2)
(
    input logic rst,
    input logic clk,
    input logic btn1,
    input logic btn2,
    (* clock_buffer_type="none" *) input logic btn3,
    (* clock_buffer_type="none" *) input logic btn4,
    output logic led1 = 1,
    output logic led2 = 0,
    output logic midi_tx = 0
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

// buttons
logic btn_pressed = 0;
logic btn1_pressed = 0;
logic btn2_pressed = 0;
logic btn3_pressed = 0;
logic btn4_pressed = 0;
logic btn_reset = 0;
logic [3:0] btn;

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

always_ff @(posedge clk) begin
    if (btn1) begin
        btn <= 4'b1000;
    end
    else if (btn2) begin
        btn <= 4'b0100;
    end
    else if (btn3) begin
        btn <= 4'b0010;
    end
    else if (btn4) begin
        btn <= 4'b0001;
    end
end

always @(*) begin
    if (btn_reset)
        btn_pressed = 0;
    else begin
        case (btn)
            4'b1000: begin
                status = {STATUS, CHANNEL};
                data1 = FIRST_CC_MSG + 0;
                data2 = CC_VALUE;
                btn_pressed = 1;
            end
            4'b0100: begin
                status = {STATUS, CHANNEL};
                data1 = FIRST_CC_MSG + 0;
                data2 = CC_VALUE + 1;
                btn_pressed = 1;
            end
            4'b0010: begin
                status = {STATUS, CHANNEL};
                data1 = FIRST_CC_MSG + 0;
                data2 = CC_VALUE + 2;
                btn_pressed = 1;
            end
            4'b0001: begin
                status = {STATUS, CHANNEL};
                data1 = FIRST_CC_MSG + 0;
                data2 = CC_VALUE + 3;
                btn_pressed = 1;
            end
        endcase
    end
end

always_ff @(posedge baud_clk or negedge rst) begin
    if (!rst) begin
        led1 <= 0;
        led2 <= 1;
        bits_cnt <= 0;
        midi_tx <= 1;
        midi_out <= 0;
    end
    else if (bits_cnt != 0) begin
        midi_tx <= midi_out[0];
        midi_out <= {1'b0, midi_out[29:1]};
        bits_cnt <= bits_cnt - 1;
        btn_reset <= btn_pressed ? 1 : 0;
    end
    else if (btn_pressed && bits_cnt == 0) begin
        led1 <= led2;
        led2 <= led1;

        midi_out <= {1'b1, data2, 1'b0,
                     1'b1, data1, 1'b0,
                     1'b1, status, 1'b0};
        bits_cnt <= 5'd30;
    end
    else begin
        midi_tx <= 1;
    end
end

endmodule
