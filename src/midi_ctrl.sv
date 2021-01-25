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
    input logic rst_i,
    input logic clk,
    input logic board_btn,
    input logic midi_rx,
    output logic midi_tx,
    output logic led1,
    output logic led2,

    //spi flash
    input logic spi_do,
    output logic spi_clk,
    output logic spi_cs,
    output logic spi_di,

    // debug
    output logic debug1,
    output logic debug2,
    output logic debug3,
    output logic debug4,

    // external buttons
    input logic btn2_pin_1,
    input logic btn2_pin_2
);

localparam BUTTONS_CNT = 4;
localparam MEMSIZE = BUTTONS_CNT * 4;

logic [7:0] memmap [1:MEMSIZE - 1];
logic [BUTTONS_CNT:1] mem_init;

/* just some sample commands */
localparam CC_MSG = 8'hB0; // CC message, channel 1
localparam PC_MSG = 8'hC0; // PC message, channel 1
localparam FIRST_CC_MSG = 8'd46;
localparam CC_VALUE = 8'b0111_1111;
localparam PC_VALUE1 = 8'h42;
localparam PC_VALUE2 = 8'h43;
localparam MEMADDR = 24'h1ffd80;

logic baud_clk = 0;

// debounce reset button (BUT2)
logic rst;
debounce #(.CNT(DEBOUNCE_CNT)) deby (clk, rst_i, rst);

// midi in
logic [7:0] status_in;
logic [7:0] data1_in;
logic [7:0] data2_in;
logic [1:0] bytes_cnt_in;
logic midi_cmd_completed;

midi_in din(baud_clk, rst, midi_rx, midi_cmd_completed, status_in, data1_in, data2_in, bytes_cnt_in);

// midi out
logic [7:0] status = 0;
logic [7:0] data1 = 0;
logic [7:0] data2 = 0;
logic [7:0] cmd_bits_cnt = 0;
logic cmd_trigger_out = 0;

midi_out dout(clk, baud_clk, rst, midi_tx, status, data1, data2, cmd_bits_cnt, cmd_trigger_out);
assign led1 = ~midi_tx;

// buttons
logic save_mode;
logic [1:0] btn_index;
logic [1:0] midi_in_state;
logic btn_assigned = 0;

buttons #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) but (
    clk, rst,
    board_btn, btn2_pin_1, btn2_pin_2,
    midi_in_state, save_mode, btn_index);

// spi flash
logic spi_clk_o;
logic [23:0] spi_adr_o = 0;
logic [31:0] spi_dat_o = 0;
logic spi_we_o = 0;
logic spi_stb_o = 0;

logic [31:0] spi_dat_i;
logic spi_ack_i;
logic spi_err_i;
logic spi_rty_i;

logic spi_init = 0;
logic spi_rst_o = 0;

assign debug2 = btn_index == 2;
assign debug3 = btn_index == 1;
assign debug4 = spi_init;

spi_flash flash(
    spi_clk_o, spi_rst_o,                                    // syscon
    spi_adr_o, spi_dat_o, spi_we_o, spi_stb_o,              // output
    spi_dat_i, spi_ack_i, spi_rty_i,                        // input
    spi_clk, spi_cs, spi_do, spi_di);                       // pins

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        spi_init <= 0;
        spi_rst_o <= 1;
    end
    else begin
        if (!spi_init) begin
            spi_rst_o <= 1;
            spi_init <= 1;
        end
        else begin
            spi_rst_o <= 0;
        end
    end
end

always @(posedge clk) begin
    if (!rst) begin
        spi_clk_o <= 1;
    end
    else begin
        spi_clk_o <= ~spi_clk_o;
    end
end

always_comb begin
    debug1 = spi_clk_o;
end

logic [2:0] memindex = 0;

integer i;
always @(posedge clk) begin
    `define ADDR(b) ((b - 1) * 4)
    if (memindex == 0) begin
        memindex <= 1;

        for (i = 1; i <= BUTTONS_CNT; i++) begin
            mem_init[i] <= 0;
        end
    end
    else if (spi_rst_o) begin
        spi_stb_o <= 0;
    end
    else if (spi_stb_o) begin
        if (spi_rty_i == 1) begin
            /* just cancel and read another time */
            spi_stb_o <= 0;
        end
        else if (spi_ack_i == 1) begin
            spi_stb_o <= 0;
            //mem_init[memindex] <= 1;
            memindex <= memindex + 1;

            // read from LSB to MSB
            memmap[`ADDR(memindex)] <= spi_dat_i[31:24];
            memmap[`ADDR(memindex) + 1] <= spi_dat_i[23:16];
            memmap[`ADDR(memindex) + 2] <= spi_dat_i[15:8];
            memmap[`ADDR(memindex) + 3] <= spi_dat_i[7:0];
        end
    end
    else if (btn_index != 0 && save_mode) begin
        // save new values, later this data will be pushed to flash
        memmap[`ADDR(btn_index)] <= status_in;
        memmap[`ADDR(btn_index) + 1] <= data1_in;
        memmap[`ADDR(btn_index) + 2] <= data2_in;
        memmap[`ADDR(btn_index) + 3] <= bytes_cnt_in * 10;
        //mem_init[btn_index] <= 1;
    end
    else if (spi_init && mem_init[memindex] == 0 && memindex <= BUTTONS_CNT) begin
        spi_stb_o <= 1;
        spi_adr_o <= MEMADDR;
        spi_we_o <= 0;  /* reading */
    end
    `undef ADDR
end

logic [12:0] clk_cnt = 0;

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

assign led2 = (midi_in_state == 1);
//assign led2 = spi_ack_i;

always_comb begin
    if (!rst)
        midi_in_state = 0;
    else if (midi_cmd_completed && !btn_assigned)
        midi_in_state = 1;
    else if (midi_cmd_completed && btn_assigned)
        midi_in_state = 2;
    else
        midi_in_state = 0;
end

always @(posedge clk) begin
    if (midi_in_state == 0) begin
        btn_assigned <= 0;
    end
    else if (midi_in_state == 1 && btn_index != 0) begin
        btn_assigned <= 1;
    end
end

always @(posedge clk or negedge rst) begin
    `define ADDR ((btn_index - 1) * 4)

    if (!rst) begin
        cmd_trigger_out <= 0;
    end
    else if (btn_index != 0 && !save_mode) begin
        if (!mem_init[btn_index]) begin
            status <= CC_MSG;
            data1 <= FIRST_CC_MSG + btn_index - 1;
            data2 <= CC_VALUE;
            cmd_bits_cnt <= 30;
            cmd_trigger_out <= 1;
        end else begin
            status <= memmap[`ADDR];
            data1 <= memmap[`ADDR + 1];
            data2 <= memmap[`ADDR + 2];
            cmd_bits_cnt <= memmap[`ADDR + 3];
            cmd_trigger_out <= 1;
        end
    end
    else begin
        cmd_trigger_out <= 0;
    end
    `undef ADDR
end

`ifdef COCOTB_SIM
initial begin
  $dumpfile ("midi_ctrl.vcd");
  $dumpvars (0, midi_ctrl);
  #1;
end
`endif

endmodule
