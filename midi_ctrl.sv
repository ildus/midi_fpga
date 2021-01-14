/* MIDI Controller.
*
* Timing details:
   We should send one bit each 32 usec (1 sec  / 31250 ).
   in 32 usec - 32000 nsec - (32000nsec / 10nsec) - 3200 ticks,
   which gives us 320usec for 10 bits per packet,
   16 usec for baud_clk going up and 16 usec for going down.
*/
module midi_ctrl #(parameter BAUD_CNT_HALF = 3200 / 2, parameter DEBOUNCE_CNT = 21)
(
    input logic rst,
    input logic clk,
    input logic btn1,
    input logic btn2,
    input logic midi_rx,
    output logic midi_tx,
    output logic led1,
    output logic led2
);

localparam STATUS = 4'hB; // CC message
localparam CHANNEL = 4'h0; // channel 0
localparam FIRST_CC_MSG = 8'd46;
localparam CC_VALUE = 8'b0111_1111;

// protocol
logic [5:0] bits_cnt;
logic [12:0] clk_cnt = 0;
logic [29:0] midi_out = 0;

logic [7:0] btn1_status;
logic [7:0] btn1_data1;
logic [7:0] btn1_data2;
logic [7:0] btn1_bits_cnt;

logic [7:0] btn2_status;
logic [7:0] btn2_data1;
logic [7:0] btn2_data2;
logic [7:0] btn2_bits_cnt;

// midi in
logic [7:0] status_in = 0;
logic [7:0] data1_in = 0;
logic [7:0] data2_in = 0;
logic [5:0] midi_reading_pos = 0;
logic [5:0] bits_cnt_in = 0;
logic [7:0] midi_in = 0;

// raise will appear once
logic btn1_raise;
logic btn2_raise;
logic btn3_raise = 0;
logic btn4_raise = 0;

debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) d1 (clk, rst, btn1, btn1_raise);
debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) d2 (clk, rst, btn2, btn2_raise);
//debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) d3 (clk, rst, btn3, btn3_raise);
//debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) d4 (clk, rst, btn4, btn4_raise);

// default values for buttons
initial begin
    btn1_status = {STATUS, CHANNEL};
    btn1_data1 = FIRST_CC_MSG;
    btn1_data2 = CC_VALUE;
    btn1_bits_cnt = 30;

    btn2_status = {STATUS, CHANNEL};
    btn2_data1 = FIRST_CC_MSG + 1;
    btn2_data2 = CC_VALUE;
    btn2_bits_cnt = 30;
end

// current values for MIDI OUT
logic [7:0] status;
logic [7:0] data1;
logic [7:0] data2;
logic [7:0] cmd_bits_cnt;

initial begin
    status = 0;
    data1 = 0;
    data2 = 0;
    cmd_bits_cnt = 0;
end

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        status <= 0;
        data1 <= 0;
        data2 <= 0;
        cmd_bits_cnt <= 0;
    end
    else begin
        case ({btn4_raise, btn3_raise, btn2_raise, btn1_raise})
            4'b0001: begin
                status <= btn1_status;
                data1 <= btn1_data1;
                data2 <= btn1_data2;
                cmd_bits_cnt <= btn1_bits_cnt;
            end
            4'b0010: begin
                status <= btn2_status;
                data1 <= btn2_data1;
                data2 <= btn2_data2;
                cmd_bits_cnt <= btn2_bits_cnt;
            end
            4'b0100: begin
                status <= btn1_status;
                data1 <= btn1_data1;
                data2 <= btn1_data2;
                cmd_bits_cnt <= btn1_bits_cnt;
            end
            4'b1000: begin
                status <= btn1_status;
                data1 <= btn1_data1;
                data2 <= btn1_data2;
                cmd_bits_cnt <= btn1_bits_cnt;
            end
            default:
                cmd_bits_cnt <= 0;
        endcase
    end
end

// buttons
logic cmd_set;
logic cmd_reset;

initial begin
    cmd_set <= 0;
    cmd_reset <= 0;
end

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        cmd_set <= 0;
    end
    else begin
        if (cmd_reset)
            cmd_set <= 0;
        else if (cmd_bits_cnt != 0) begin
            cmd_set <= 1;
        end
    end
end

logic baud_clk;

initial begin
    led1 = 0;
    midi_tx = 1;
    baud_clk = 0;
end

// MIDI out logic
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

always_ff @(posedge baud_clk or negedge rst) begin
    if (!rst) begin
        led1 <= 0;
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
        led1 <= 1;

        // we're sending bits from LSB, so the structure constructed backwards
        midi_out <= {1'b1, data2, 1'b0,
                     1'b1, data1, 1'b0,
                     1'b1, status, 1'b0};
        bits_cnt <= cmd_bits_cnt;
        cmd_reset <= 1;
    end
    else begin
        led1 <= 1;
        cmd_reset <= 0;
        midi_tx <= 1;
    end
end

logic [5:0] midi_in_bits = 0;
logic midi_cmd_completed = 0;
logic [1:0] midi_in_state;
logic btn_assigned = 0;

assign led2 = (midi_in_state == 1);

always @(*) begin
    if (!rst)
        midi_in_state = 0;
    else if (midi_cmd_completed && !btn_assigned)
        midi_in_state = 1;
    else if (midi_cmd_completed && btn_assigned)
        midi_in_state = 2;
    else
        midi_in_state = 0;
end


// MIDI in logic
always_ff @(posedge baud_clk or negedge rst) begin
    if (!rst) begin
        midi_cmd_completed <= 0;
        midi_reading_pos <= 0;
        midi_in_bits <= 0;
    end
    else if (midi_reading_pos != 0) begin
        // continue reading other bits

        midi_in <= {midi_rx, midi_in[7:1]};

        // in midi_in_bits we actually count ticks, and in 30 ticks we suppose
        // that we got the command, and we don't care it was 3 bytes or only 1.
        midi_in_bits <= midi_in_bits + 1;

        // move current byte to destination
        if (midi_reading_pos == 9 && midi_rx == 1) begin
            if (midi_in[7]) begin
                // MSB == 1 means status byte
                status_in <= midi_in;
                bits_cnt_in <= 10;
            end
            else if (data1_in == 0) begin
                data1_in <= midi_in;
                bits_cnt_in <= 20;
            end
            else begin
                data2_in <= midi_in;
                bits_cnt_in <= 30;
                midi_cmd_completed <= 1;
            end
        end

        // that was stop bit, finish reading
        if (midi_reading_pos == 9)
            midi_reading_pos <= 0;
        else
            midi_reading_pos <= midi_reading_pos + 1;
    end
    else if (midi_rx != 0) begin
        // start reading one byte
        midi_in <= 0;
        midi_in_bits <= 1;
        midi_reading_pos <= 1;
        midi_cmd_completed <= 0;

        // reset all the data, so they will not affect future value
        status_in <= 0;
        data1_in <= 0;
        data2_in <= 0;
        bits_cnt_in <= 0;
    end
    else begin
        // this will count to 31 and stop
        if (midi_in_bits != 0)
            midi_in_bits <= midi_in_bits + 1;
        else if (bits_cnt_in != 0 && midi_in_bits == 30)
            midi_cmd_completed <= 1;
        else if (midi_in_state == 2)
            midi_cmd_completed <= 0;
    end
end

always_ff @(posedge clk) begin
    if (midi_in_state == 0)
        btn_assigned <= 0;
    else if (midi_in_state == 1 && btn1_raise) begin
        btn1_status <= status_in;
        btn1_data1 <= data1_in;
        btn1_data2 <= data2_in;
        btn1_bits_cnt <= bits_cnt_in;
        btn_assigned <= 1;
    end
    else if (midi_in_state == 1 && btn2_raise) begin
        btn2_status <= status_in;
        btn2_data1 <= data1_in;
        btn2_data2 <= data2_in;
        btn2_bits_cnt <= bits_cnt_in;
        btn_assigned <= 1;
    end
end

endmodule
