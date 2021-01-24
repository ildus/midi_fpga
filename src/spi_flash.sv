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
    output logic spi_do,
    output logic spi_clk,
    output logic spi_cs,
    output logic spi_di
);

localparam IDLE             = 0;
localparam READ             = 1;
localparam WRITE            = 2;

localparam CMD_STATUS       = 8'h05;
localparam CMD_READ         = 8'h05;
localparam CMD_WRITE        = 8'h05;

logic [3:0] state = IDLE;
logic [7:0] cmd = 0;
logic [5:0] bits_cnt = 0;

logic spi_clk_int = 0;
logic spi_clk_en = 0;
logic spi_clk_cnt = 0; // just one bit, for 50Mhz

// termination signals
logic ack, rty;

assign ack_o = stb_i && ack;
assign rty_o = stb_i && rty;

always @(posedge clk_i) begin
    if (rst_i) begin
        spi_clk_cnt <= 0;
        spi_clk_int <= 0;
        spi_clk <= 0;
    end
    else if (!spi_clk_cnt) begin
        spi_clk_int <= 1;
        spi_clk <= spi_clk_en;
        spi_clk_cnt <= ~spi_clk_cnt;
    end
    else begin
        spi_clk <= 0;
        spi_clk_int <= 0;
        spi_clk_cnt <= ~spi_clk_cnt;
    end
end

always @(*) begin
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

/* spi_cs control */
assign spi_cs = (state == IDLE);

logic [2:0] inner_state = 0;

assign busy = dat_o[0];
assign write_enabled = dat_o[1];

`ifdef COCOTB_SIM
always @(posedge clk_i) begin
    if (rst_i) begin
        spi_do <= 1;
    end
end
`endif

always @(posedge spi_clk_int) begin
    if (state == READ) begin
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
        end
        else if (inner_state == 2) begin
            rty <= busy;
            ack <= !busy;
            spi_clk_en <= 0;
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
