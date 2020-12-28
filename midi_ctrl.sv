module midi_ctrl #(parameter BAUD_CNT_HALF = 3200 / 2)
(
    input logic rst,
    input logic clk,
    input logic btn,
    output logic led,
    output logic midi_tx
);

/* we should send one bit each 32 usec (1 sec  / 31250 ).
   in 32 usec - 32000 nsec - (32000nsec / 10nsec) - 3200 ticks,
   which gives us 320usec for 10 bits per packet,
   16 usec for baud_clk going up and 16 usec for going down
*/

logic baud_clk;
logic [2:0] command; // upper 4 bits of status, MSB is always 1
logic [3:0] channel; // lower 4 bits of status
logic [7:0] bits_cnt;
logic [1:0] bytes_cnt;
logic [7:0] status;
logic [7:0] data1;
logic [7:0] data2;
logic [12:0] clk_cnt;
logic [29:0] midi_out;

logic btn_pressed = 0;
logic btn_reset;

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

always_ff @(posedge btn or posedge btn_reset) begin
    if (btn_reset)
        btn_pressed <= 0;
    else
        btn_pressed <= 1;
end

always_ff @(posedge baud_clk or negedge rst) begin
    if (!rst) begin
        led <= 0;
        bits_cnt <= 0;
        midi_tx <= 0;
        btn_wait <= 1; // wait for btn click
    end
    else if (bits_cnt != 0) begin
        led <= 1;
        midi_tx <= midi_out[29];
        midi_out <= midi_out << 1;
        bits_cnt <= bits_cnt - 1;
        btn_reset <= 0;
    end
    else if (btn_pressed && bits_cnt == 0) begin
        status <= 8'b0001_0001;
        data1  <= 8'b0011_0011;
        data2  <= 8'b0111_0111;
        midi_out <= {1'b1, status, 1'b0,
                     1'b1, data1,  1'b0,
                     1'b1, data2,  1'b0};
        bits_cnt <= 30;
        btn_reset <= 1; // we got the data, time to reset button
    end
    else begin
        led <= 0;
        midi_tx <= 0;
    end
end

endmodule
