module spi_flash
(
    input logic clk_i,  /* 100 MHz */
    input logic rst_i,

    input logic [23:0] adr_i,
    input logic [31:0] dat_i,
    input logic we_i,
    input logic stb_i,
    input logic tga_i,  /* we_i & tga_i - erase sector by address */

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

// main state
localparam IDLE             = 0;
localparam STROBE           = 1;

logic state = IDLE;

// inner
localparam SND = 1;
localparam RCV = 2;
localparam DLY = 3;
localparam NEXTOP = 3'b111;
localparam FINISH = 3'b111;

logic [2:0] inner_state = IDLE;
logic [2:0] next_inner_state = IDLE;

// commands
localparam CMD_STATUS       = 8'h05;
localparam CMD_READ         = 8'h03;
localparam CMD_DEVICEID     = 8'h90;
localparam CMD_READJEDEC    = 8'h9F;
localparam CMD_POWERUP      = 8'hAB;
localparam CMD_POWERDOWN    = 8'hB9;
localparam CMD_WRITEENABLE  = 8'h06;
localparam CMD_SECTORERASE  = 8'h20;
localparam CMD_WRITE        = 8'h02;

// only for FSM, actually we use CMD_WRITEENABLE
localparam CMD_PSEUDO_ENABLE_WRITE = 8'h10;
localparam CMD_PSEUDO_ENABLE_ERASE = 8'h11;

// termination signals
logic ack = 0, rty = 0;

assign ack_o = stb_i && ack;
assign rty_o = stb_i && rty;
assign busy = dat_o[0];
assign write_enabled = dat_o[1];

always_comb begin
    if (rst_i)
        state = IDLE;
    else if (ack || rty)
        state = IDLE;
    else if (stb_i)
        state = STROBE;
    else
        state = IDLE;
end

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
logic [31:0] next_cmd = 0;
logic [5:0] bits_cnt = 0;
logic [5:0] bits_to_read = 0;
logic is_status = 0;

always @(posedge clk_i) begin
    if (inner_state == DLY) begin
        if (spi_baud)
            dly_cnt <= dly_cnt + 1;

        if (dly_cnt[3] == 1) begin
            dly_cnt <= 0;
            inner_state <= next_inner_state;
        end
    end
    else if (inner_state == IDLE && state == STROBE) begin
        // always starting with RELEASE POWER DOWN

        inner_state <= NEXTOP;
        next_cmd <= CMD_POWERUP;
    end
    else if (inner_state == NEXTOP && next_cmd != 0) begin
        spi_cs <= 0;
        spi_clk <= 1;

        cmd <= {next_cmd, adr_i};
        inner_state <= DLY;
        next_inner_state <= SND;
        is_status <= (next_cmd == CMD_STATUS);

        case (next_cmd)
            CMD_POWERUP: begin
                bits_cnt <= 8;
                bits_to_read <= 0;
                next_cmd <= CMD_STATUS;
            end
            CMD_POWERDOWN: begin
                bits_cnt <= 8;
                bits_to_read <= 0;
                next_cmd <= 0;
            end
            CMD_STATUS: begin
                bits_cnt <= 8;
                bits_to_read <= 8;

                if (tga_i && we_i)
                    next_cmd <= CMD_PSEUDO_ENABLE_ERASE;
                else if (we_i)
                    next_cmd <= CMD_PSEUDO_ENABLE_WRITE;
                else
                    next_cmd <= CMD_READ;
            end
            CMD_PSEUDO_ENABLE_ERASE: begin
                cmd <= {CMD_WRITEENABLE, adr_i};
                bits_cnt <= 8;
                bits_to_read <= 0;
                next_cmd <= CMD_SECTORERASE;
            end
            CMD_PSEUDO_ENABLE_WRITE: begin
                cmd <= {CMD_WRITEENABLE, adr_i};
                bits_cnt <= 8;
                bits_to_read <= 0;
                next_cmd <= CMD_WRITE;
            end
            CMD_READJEDEC: begin
                bits_cnt <= 8;
                bits_to_read <= 24;
                next_cmd <= 0;
            end
            CMD_READ: begin
                bits_cnt <= 32;
                bits_to_read <= 32;
                next_cmd <= CMD_POWERDOWN;
            end
            CMD_SECTORERASE: begin
                bits_cnt <= 32;
                bits_to_read <= 0;
                next_cmd <= CMD_POWERDOWN;
            end
            CMD_WRITE: begin
                bits_cnt <= 64;
                bits_to_read <= 0;
                next_cmd <= CMD_POWERDOWN;
            end
            default: begin
                bits_cnt <= 8;
                bits_to_read <= 0;
                next_cmd <= 0;
            end
        endcase
    end
    else if (state != IDLE) begin
        if (spi_baud && spi_clk) begin  // falling edge
            spi_clk <= ~spi_clk;

            if (inner_state == SND) begin
                if (bits_cnt != 0) begin
                    // sending bits
                    spi_di <= cmd[31];
                    cmd <= {cmd[30:0], 1'b0};
                    bits_cnt <= bits_cnt - 1;
                end
                else if (bits_to_read != 0) begin
                    // we have something to read
                    bits_cnt <= bits_to_read;
                    inner_state <= DLY;
                    next_inner_state <= RCV;
                end
                else begin
                    // temporary CS up, so we can start new operation or
                    // finish
                    spi_cs <= 1;
                    spi_clk <= 1;
                    inner_state <= DLY;

                    if (next_cmd)
                        next_inner_state <= NEXTOP;
                    else
                        next_inner_state <= FINISH;
                end
            end
            else if (inner_state == FINISH) begin
                ack <= 1;
                spi_cs <= 1;
                spi_clk <= 1;
            end
            else if (inner_state == RCV && bits_cnt == 0) begin
                inner_state <= DLY;

                if (is_status && busy) begin
                    rty <= 1;
                    next_inner_state <= FINISH;
                end
                else if (next_cmd != 0) begin
                    spi_clk <= 1;
                    spi_cs <= 1;
                    next_inner_state <= NEXTOP;
                end
                else begin
                    inner_state <= FINISH;
                    ack <= 1;
                    spi_clk <= 1;
                    spi_cs <= 1;
                end
            end
        end
        else if (spi_baud && !spi_clk) begin    // raising edge
            spi_clk <= ~spi_clk;

            if (inner_state == RCV) begin
                bits_cnt <= bits_cnt - 1;
                dat_o <= {dat_o[30:0], spi_do};
            end
        end
    end
    else begin
        if (spi_baud) begin
            spi_cs <= 1;
            ack <= 0;
            rty <= 0;
            inner_state <= IDLE;
            spi_clk <= 1;
        end
    end
end

endmodule
