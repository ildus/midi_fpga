module midi_out (
    input logic clk,        /* sysclk */
    input logic baud_clk,   /* midi clk, 31250 bits/sec */
    input logic rst,

    output logic midi_tx,

    input logic [7:0] status,
    input logic [7:0] data1,
    input logic [7:0] data2,
    input logic [7:0] cmd_bits_cnt,
    input logic cmd_set     /* this should be set only one clock period */
);

logic cmd_trigger_out = 0;
logic cmd_reset_trigger = 0;

logic [7:0] bits_cnt = 0;
logic [29:0] midi_out = 0;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        cmd_trigger_out <= 0;
    end
    else begin
        if (cmd_reset_trigger)
            cmd_trigger_out <= 0;
        else if (cmd_set) begin
            cmd_trigger_out <= 1;
        end
    end
end

always_ff @(posedge baud_clk or negedge rst) begin
    if (!rst) begin
        bits_cnt <= 0;
        midi_tx <= 1;
        midi_out <= 0;
        cmd_reset_trigger <= 0;
    end
    else if (bits_cnt != 0) begin
        midi_tx <= midi_out[0];
        midi_out <= {1'b0, midi_out[29:1]};
        bits_cnt <= bits_cnt - 1;
        cmd_reset_trigger <= 0;
    end
    else if (cmd_trigger_out && bits_cnt == 0) begin
        // we're sending bits from LSB, so the structure constructed backwards
        midi_out <= {1'b1, data2, 1'b0,
                     1'b1, data1, 1'b0,
                     1'b1, status, 1'b0};
        bits_cnt <= cmd_bits_cnt;
        cmd_reset_trigger <= 1;
    end
    else begin
        cmd_reset_trigger <= 0;
        midi_tx <= 1;
    end
end

endmodule
