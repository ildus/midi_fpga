module spi_flash
(
    input logic clk_i,  /* 100 MHz */
    input logic rst_i,

    input logic [23:0] adr_i,
    input logic [31:0] dat_i,
    input logic we_i,
    input logic stb_i,

    output logic [31:0] dat_o,
    output logic ack_o,
    output logic rty_o,

    /* spi pins */
`ifdef COCOTB_SIM
    output logic spi_do,
`else
    input logic spi_do,
`endif
    output logic spi_clk,
    output logic spi_cs,
    output logic spi_di
);

localparam IDLE             = 0;
localparam READ             = 1;
localparam WRITE            = 2;

localparam CMD_STATUS       = 8'h05;
localparam CMD_READ         = 8'h03;
localparam CMD_WRITE        = 8'h05;

logic [3:0] state = IDLE;
logic [7:0] cmd = 0;
logic [31:0] cmdadr = 0;
logic [6:0] bits_cnt = 0;

logic spi_clk_en = 0;

// termination signals
logic ack = 0, rty = 0;

assign ack_o = stb_i && ack;
assign rty_o = stb_i && rty;

// this is clock going to chip
assign spi_clk = clk_i && spi_clk_en && !spi_cs;

always_comb begin
    if (rst_i) begin
        state = IDLE;
    end
    else if (ack || rty) begin
        state = IDLE;
    end
    else if (stb_i) begin
        state = READ;
    end
    else
        state = IDLE;
end

localparam PAUSE1 = 3'b110;
localparam PAUSE2 = 3'b111;
logic [2:0] inner_state = 0;

assign busy = dat_o[0];
assign write_enabled = dat_o[1];

`ifdef COCOTB_SIM
logic [1:0]  do_cnt = 0;
always @(posedge clk_i) begin
    if (rst_i) begin
        do_cnt <= 0;
    end
    else begin
        if (do_cnt == 1)
            spi_do <= 1;
        else
            spi_do <= 0;

        do_cnt <= do_cnt + 1;
    end
end
`endif

/* spi_cs control */
assign spi_cs = (state == IDLE || inner_state == PAUSE1 || inner_state == PAUSE2);

always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        ack <= 0;
        rty <= 0;
        inner_state <= 0;
    end
    else if (state == READ) begin
        if (inner_state == 0) begin
            {spi_di, cmd} <= {CMD_STATUS, 1'b0};
            bits_cnt <= 7;
            inner_state <= 1;
            dat_o <= 0;

            ack <= 0;
            rty <= 0;

            // start counting on the chip side
            spi_clk_en <= 1;
        end
        else if (inner_state == 1 && bits_cnt != 0) begin
            {spi_di, cmd} <= {cmd, 1'b0};
            bits_cnt <= bits_cnt - 1;
        end
        else if (inner_state == 1) begin
            spi_di <= 0;
            bits_cnt <= 8;
            inner_state <= 2;
        end
        else if (inner_state == 2 && bits_cnt != 0) begin
            dat_o <= {dat_o[30:0], spi_do};
            bits_cnt <= bits_cnt - 1;

            if (bits_cnt == 1) begin
                // fail, stop reading
                rty <= busy;
                spi_clk_en <= 0;
                if (!busy) begin
                    inner_state = PAUSE1;
                end
            end
        end
        else if (inner_state == PAUSE1) begin
            // start actual reading
            inner_state <= PAUSE2;
            {spi_di, cmdadr} <= {CMD_READ, adr_i, 1'b0};
        end
        else if (inner_state == PAUSE2) begin
            // start actual reading
            inner_state <= 3;

            bits_cnt <= 31;
            dat_o <= 0;

            ack <= 0;
            rty <= 0;

            // start counting on the chip side
            spi_clk_en <= 1;
        end
        else if (inner_state == 3 && bits_cnt != 0) begin
            {spi_di, cmdadr} <= {cmdadr, 1'b0};
            bits_cnt <= bits_cnt - 1;
        end
        else if (inner_state == 3) begin
            spi_di <= 0;
            bits_cnt <= 4 * 8;  // read 4 bytes
            inner_state <= 4;
        end
        else if (inner_state == 4 && bits_cnt != 0) begin
            dat_o <= {dat_o[30:0], spi_do};
            bits_cnt <= bits_cnt - 1;

            if (bits_cnt == 1) begin
                // done, stop reading
                ack <= 1;
                spi_clk_en <= 0;
            end
        end
    end
    else begin
        rty <= 0;
        ack <= 0;
        inner_state <= 0;
        spi_clk_en <= 0;
    end
end

endmodule
