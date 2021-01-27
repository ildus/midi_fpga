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
localparam READ_STATUS      = 1;
localparam READ             = 2;
localparam WRITE            = 3;

localparam CMD_STATUS       = 8'h05;
localparam CMD_READ         = 8'h03;
localparam CMD_WRITE        = 8'h05;

logic [3:0] state = IDLE;

logic spi_clk_en = 0;

// termination signals
logic ack = 0, rty = 0;

assign ack_o = stb_i && ack;
assign rty_o = stb_i && rty;

always_comb begin
    if (rst_i)
        state = IDLE;
    else if (ack || rty)
        state = IDLE;
    else if (inner_state == SWITCHING_MODE && !we_i)
        state = READ;
    else if (inner_state == SWITCHING_MODE && we_i)
        state = WRITE;
    else if (stb_i)
        state = READ_STATUS;
    else
        state = IDLE;
end

localparam SWITCHING_MODE = 3'b110;
localparam PAUSE2 = 3'b111;
logic [2:0] inner_state = 0;

assign busy = dat_o[0];
assign write_enabled = dat_o[1];

`ifdef COCOTB_SIM
logic [1:0]  do_cnt = 0;
always @(negedge clk_i) begin
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

/* comb outputs */
assign spi_cs = (state == IDLE || inner_state == SWITCHING_MODE || inner_state == PAUSE2);
assign spi_di = cmd[31];
assign spi_clk = clk_i & spi_clk_en & (~spi_cs);

always @(posedge spi_clk) begin
    dat_o <= {dat_o[30:0], spi_do};
end

logic [31:0] cmd = 0;
logic [5:0] bits_cnt = 0;
logic [5:0] bits_to_read = 0;
logic is_status = 0;

always @(negedge clk_i) begin
    if (inner_state == 0 && state == READ_STATUS) begin
        cmd <= {CMD_STATUS, 24'b0};
        bits_cnt <= 8;
        bits_to_read <= 7;
        inner_state <= 1;
        is_status <= 1;

        ack <= 0;
        rty <= 0;

        // start counting on the chip side
        spi_clk_en <= 1;
    end
    else if (inner_state == SWITCHING_MODE && state == READ) begin
        cmd <= {CMD_READ, adr_i};
        bits_cnt <= 32;
        bits_to_read <= 31;
        inner_state <= 1;
        is_status <= 0;

        ack <= 0;
        rty <= 0;

        // start counting on the chip side
        spi_clk_en <= 1;
    end
    else if (inner_state == 1 && bits_cnt != 0) begin
        cmd <= {cmd[30:0], 1'b0};
        bits_cnt <= bits_cnt - 1;
    end
    else if (inner_state == 1) begin
        bits_cnt <= bits_to_read;
        inner_state <= 2;
    end
    else if (inner_state == 2 && bits_cnt != 0) begin
        bits_cnt <= bits_cnt - 1;

        if (bits_cnt == 1) begin
            spi_clk_en <= 0;
            if (is_status) begin
                rty <= busy;
                if (!busy) begin
                    inner_state <= SWITCHING_MODE;
                end
            end
            else
                ack <= 1;
        end
    end
    else begin
        rty <= 0;
        ack <= 0;
        inner_state <= 0;
        spi_clk_en <= 0;
    end
end

/*
always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        ack <= 0;
        rty <= 0;
        inner_state <= 0;
    end
    else if (state == READ_STATUS) begin
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
                    inner_state = SWITCHING_MODE;
                end
            end
        end
        else if (inner_state == SWITCHING_MODE) begin
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
*/

endmodule
