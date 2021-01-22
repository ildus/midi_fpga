module spi_flash
(
    input logic clk,
    input logic rst,
    input logic [23:0] addr,
    input logic we,
    input logic [7:0] fifo_in,

    output logic spi_clk = 0,
    output logic spi_cs = 0,
    output logic spi_do = 1,
    output logic spi_di = 0,

    output logic [7:0] data_out = 0,
    output logic data_ready = 0
);

localparam INITIAL          = 0;
localparam READING_STATUS   = 1;
localparam IDLE             = 2;

localparam CMD_UNSET        = 0;
localparam CMD_STATUS       = 8'h05;

logic [3:0] state = INITIAL;
logic [7:0] cmd = CMD_UNSET;
logic [7:0] status;
logic cmd_start = 0;
logic [7:0] instruction = CMD_UNSET;
logic [5:0] bits_to_read = 0;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        state <= INITIAL;
    end
    else if (spi_clk_en) begin
        state <= READING_STATUS;
    end
    else if (state == READING_STATUS && !spi_clk_en) begin
        state <= IDLE;
    end
end

logic spi_clk_en = 0;
logic spi_clk_cnt = 0; // just one bit, for 50Mhz

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        spi_clk_cnt <= 0;
        spi_clk <= 0;
    end
    else if (spi_clk_en && spi_clk_cnt) begin
        spi_clk <= ~spi_clk;
    end
    else begin
        spi_clk_cnt <= ~spi_clk_cnt;
    end
end

/* set current instruction */
always @(posedge clk) begin
    case (state)
        INITIAL: begin
            instruction <= CMD_STATUS;
        end
        default:
            instruction <= 0;
    endcase
end

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        spi_cs <= 1;
    end
    else if (instruction != 0) begin
        spi_cs <= 0;
    end
    else if (data_ready)
        spi_cs <= 1;
end

logic instruction_sending = 0;

always_ff @(negedge spi_cs or posedge spi_clk) begin
    if (!spi_cs && !spi_clk_en) begin
        // turn the spi clock, send MSB
        spi_di <= instruction[7];
        cmd <= {instruction[6:0], 1'b0};
        spi_clk_en <= 1;
        bits_to_read <= 0;
        instruction_sending <= 0;
        data_ready <= 0;
    end
    else begin
        if (cmd != 0) begin
            spi_di <= cmd[7];
            cmd <= {cmd[6:0], 1'b0};
            instruction_sending <= 1;
        end
        else if (instruction_sending) begin
            bits_to_read <= 8;
            spi_di <= 0;
            instruction_sending <= 0;
        end
        else if (bits_to_read != 0) begin
            data_out <= {data_out[6:0], spi_do};
            bits_to_read <= bits_to_read - 1;
        end
        else begin
            spi_clk_en <= 0;
            data_ready <= 1;
        end
    end
end

endmodule
