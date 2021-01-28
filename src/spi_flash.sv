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
    output logic spi_clk,
    output logic spi_cs,
    output logic spi_di,

`ifdef COCOTB_SIM
    output logic spi_do
`else
    input logic spi_do
`endif
);

logic spi_baud;
divide_by_n #(5) div_n(clk_i, rst_i, spi_baud);

localparam IDLE             = 0;
localparam READ_STATUS      = 1;
localparam READ             = 2;
localparam WRITE            = 3;

localparam CMD_STATUS       = 8'h05;
localparam CMD_READ         = 8'h03;
localparam CMD_WRITE        = 8'h05;
localparam CMD_DEVICEID     = 8'h90;
localparam CMD_WRITEENABLE  = 8'h06;
localparam CMD_READJEDEC    = 8'h9F;
localparam CMD_RELEASE      = 8'hAB;

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

localparam PAUSE2 = 3'b111;
logic [2:0] inner_state = 0;
logic [2:0] next_inner_state = 0;

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

logic [3:0] dly_cnt = 0;
logic [31:0] cmd = 0;
logic [5:0] bits_cnt = 0;
logic [5:0] bits_to_read = 0;
logic is_status = 0;

localparam IDL = 0;
localparam SND = 1;
localparam RCV = 2;
localparam DLY = 3;
localparam SWITCHING_MODE = 3'b110;
localparam FINISH = 4;

always @(posedge clk_i) begin
    if (inner_state == DLY) begin
        if (spi_baud)
            dly_cnt <= dly_cnt + 1;

        if (dly_cnt[3] == 1) begin
            dly_cnt <= 0;
            inner_state <= next_inner_state;
        end
    end
    else if (inner_state == 0 && state == READ_STATUS) begin
        spi_cs <= 0;
        spi_clk <= 1;

        cmd <= {CMD_RELEASE, 24'b0};
        bits_cnt <= 8;
        bits_to_read <= 0;
        inner_state <= DLY;
        next_inner_state <= SND;
        is_status <= 0;
    end
    else if (inner_state == SWITCHING_MODE && state == READ) begin
        spi_cs <= 0;
        spi_clk <= 1;

        cmd <= {CMD_READJEDEC, adr_i};
        bits_cnt <= 8;
        bits_to_read <= 24;
        inner_state <= DLY;
        next_inner_state <= SND;
        is_status <= 0;
    end
    else if (state != IDLE) begin
        if (spi_baud && spi_clk) begin  // falling edge
            spi_clk <= ~spi_clk;

            if (inner_state == SND && bits_cnt != 0) begin
                spi_di <= cmd[31];
                cmd <= {cmd[30:0], 1'b0};
                bits_cnt <= bits_cnt - 1;
            end
            else if (inner_state == SND && bits_to_read != 0) begin
                bits_cnt <= bits_to_read;
                inner_state <= DLY;
                next_inner_state <= RCV;
            end
            else if (inner_state == SND) begin
                spi_cs <= 1;
                spi_clk <= 1;
                inner_state <= DLY;
                next_inner_state <= SWITCHING_MODE;
            end
            else if (inner_state == FINISH) begin
                inner_state <= IDLE;
                ack <= 1;
                spi_cs <= 1;
                spi_clk <= 1;
            end
        end
        else if (spi_baud && !spi_clk) begin    // raising edge
            spi_clk <= ~spi_clk;

            if (inner_state == RCV) begin
                bits_cnt <= bits_cnt - 1;
                dat_o <= {dat_o[30:0], spi_do};

                if (bits_cnt == 1) begin
                    if (is_status) begin
                        rty <= busy;
                        if (!busy) begin
                            inner_state <= SWITCHING_MODE;
                        end
                    end begin
                        ack <= 1;
                        inner_state <= IDLE;
                    end
                end
            end
        end
    end
    else begin
        if (spi_baud) begin
            spi_cs <= 1;
            ack <= 0;
            rty <= 0;
            inner_state <= 0;
        end

        spi_clk <= 1;
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
