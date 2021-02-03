module midi_in #(parameter BAUD_CNT_HALF = 3200 / 2) (
    input logic clk,    // 100 MHz
    input logic rst,
    input logic midi_rx,

    output logic completed,
    output logic [7:0] status_in,
    output logic [7:0] data1_in,
    output logic [7:0] data2_in,
    output logic [1:0] bytes_cnt_in
);

logic [5:0] midi_reading_pos = 0;
logic [5:0] midi_in_bits = 0;
logic [7:0] midi_in = 0;

logic read_full_command = 0;
logic baud_clk_en = 0;
logic baud_clk;
logic [10:0] clk_cnt = 0;

always_ff @(posedge clk) begin
    if (midi_rx && read_full_command)
        baud_clk_en <= 0;
    else if (midi_rx == 0)
        baud_clk_en <= 1;
end

always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
        clk_cnt <= 0;
        baud_clk <= 0;
    end
    else if (baud_clk_en) begin
        if (clk_cnt == BAUD_CNT_HALF - 1) begin
            clk_cnt <= 0;
            baud_clk <= ~baud_clk;
        end
        else begin
            clk_cnt <= clk_cnt + 1;
        end
    end
    else begin
        clk_cnt <= 0;
        baud_clk <= 0;
    end
end

always_ff @(posedge baud_clk or negedge rst) begin
    if (!rst) begin
        read_full_command <= 0;
        completed <= 0;
        midi_reading_pos <= 0;
        midi_in_bits <= 0;
    end
    else if (midi_reading_pos != 0) begin
        // continue reading other bits

        midi_in <= {midi_rx, midi_in[7:1]};
        midi_in_bits <= midi_in_bits + 1;

        // move current byte to destination
        if (midi_reading_pos == 9 && midi_rx == 1) begin
            if (midi_in[7]) begin
                // MSB == 1 means status byte
                status_in <= midi_in;
                bytes_cnt_in <= 1;

                // status byte cleans all running data bytes
                data1_in <= 0;
                data2_in <= 0;
                completed <= 0;
            end
            else if (bytes_cnt_in == 1) begin
                data1_in <= midi_in;
                bytes_cnt_in <= 2;
            end
            else if (bytes_cnt_in == 2) begin
                data2_in <= midi_in;
                bytes_cnt_in <= 3;
            end
        end

        // that was stop bit, finish reading
        if (midi_reading_pos == 9)
            midi_reading_pos <= 0;
        else
            midi_reading_pos <= midi_reading_pos + 1;
    end
    else if (midi_rx == 0) begin
        // start reading one byte
        midi_in <= 0;
        midi_reading_pos <= 1;
        completed <= 0;
        read_full_command <= 0;

        // we give ourselves 30 baud ticks after each byte starts
        midi_in_bits <= 0;
    end
    else begin
        // this will count to 31 and stop
        if (midi_in_bits == 30) begin
            read_full_command <= 1;
            completed <= bytes_cnt_in != 0;
        end
        else if (midi_in_bits != 0)
            midi_in_bits <= midi_in_bits + 1;
    end
end

endmodule
