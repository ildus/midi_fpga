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
    output logic spi_clk,
    output logic spi_cs,
    output logic spi_di,
    input logic spi_do,

    // debug
    output logic [7:0] debug,

    // external buttons
    input logic btn2_pin_1,
    input logic btn2_pin_2,
    input logic btn3_pin_1,
    input logic btn3_pin_2,
    input logic btn4_pin_1,
    input logic btn4_pin_2,
    input logic btn5_pin_1,
    input logic btn5_pin_2
);

localparam BUTTONS_CNT = 4;
localparam MEMSIZE = BUTTONS_CNT * 4;

`define ADDR(b) ((b - 1) * 4)
logic [7:0] memmap [0:MEMSIZE - 1];
logic [BUTTONS_CNT:1] mem_init;

integer i;
initial begin
    for (i = 1; i <= BUTTONS_CNT; i++) begin
        mem_init[i] <= 0;
    end
end

/* just some sample commands */
localparam CC_MSG = 8'hB0; // CC message, channel 1
localparam PC_MSG = 8'hC0; // PC message, channel 1
localparam FIRST_CC_MSG = 8'd46;
localparam CC_VALUE = 8'b0111_1111;
localparam PC_VALUE1 = 8'h42;
localparam PC_VALUE2 = 8'h43;
localparam MEMADDR = 24'h1ffd80;
//localparam MEMADDR = 24'h000000;

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

midi_in din(baud_clk, rst, midi_rx, midi_cmd_completed, status_in, data1_in, data2_in, bytes_cnt_in, debug[7]);

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
    board_btn,
    btn2_pin_1, btn2_pin_2,
    btn3_pin_1, btn3_pin_2,
    btn4_pin_1, btn4_pin_2,
    btn5_pin_1, btn5_pin_2,
    midi_in_state, save_mode, btn_index);

// spi flash
logic spi_clk_o;
logic [23:0] spi_adr_o = 0;
logic [31:0] spi_dat_o = 0;
logic spi_we_o = 0;
logic spi_stb_o = 0;
logic spi_tga_o = 0;

logic [31:0] spi_dat_i;
logic spi_ack_i;
logic spi_rty_i;

logic spi_init = 0;
logic spi_rst_o = 0;

spi_flash flash(
    clk, spi_rst_o,                                         // syscon
    spi_adr_o, spi_dat_o, spi_we_o, spi_stb_o, spi_tga_o,   // output
    spi_dat_i, spi_ack_i, spi_rty_i,                        // input
    spi_clk, spi_cs, spi_di, spi_do);                       // pins

always @(posedge clk) begin
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

always_comb begin
    debug[0] = spi_rst_o;
    debug[1] = spi_stb_o;
    debug[2] = spi_cs;
    debug[3] = spi_clk;
    debug[4] = spi_do;
    debug[5] = spi_di;
    debug[6] = midi_tx;
end

logic fail = 0;
logic [2:0] memindex = 0;
logic [2:0] memsave = 0;
logic ack_processed = 0;

always @(posedge clk) begin
    if (spi_rst_o) begin
		spi_stb_o <= 0;
        memindex <= 1;
        fail <= 0;

        for (i = 1; i <= BUTTONS_CNT; i++) begin
            mem_init[i] <= 0;
        end
    end
    else if (spi_stb_o) begin
        if (ack_processed && !spi_ack_i)
            ack_processed <= 0;
        else if (spi_rty_i == 1) begin
            /* just cancel and read another time */
            fail <= 1;
            spi_stb_o <= 0;
        end
        else if (spi_ack_i && !ack_processed) begin
            ack_processed <= 1;
            spi_stb_o <= 0;
            mem_init[memindex] <= 1;
            memindex <= memindex + 1;

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
        //memsave <= btn_index;
    end
    else if (!spi_rst_o && !spi_stb_o && mem_init[memindex] == 0 && memindex <= BUTTONS_CNT && !fail) begin
        spi_stb_o <= 1;
        spi_adr_o <= MEMADDR + ((memindex - 1) * 4);
        spi_we_o <= 0;  /* reading */
        spi_tga_o <= 0;
    end
    else if (!spi_rst_o && !spi_stb_o && memsave != 0 && !fail) begin
        spi_stb_o <= 1;
        spi_adr_o <= MEMADDR;
        spi_we_o <= 1;  /* writing */
        spi_tga_o <= 1; /* erasing */
        memsave <= 0;
    end
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
    if (!rst) begin
        cmd_trigger_out <= 0;
    end
    else if (btn_index != 0 && !save_mode && mem_init[btn_index]) begin
        status <= memmap[`ADDR(btn_index)];
        data1 <= memmap[`ADDR(btn_index) + 1];
        data2 <= memmap[`ADDR(btn_index) + 2];
        cmd_bits_cnt <= memmap[`ADDR(btn_index) + 3];
        cmd_trigger_out <= 1;
    end
    else begin
        cmd_trigger_out <= 0;
    end
end

`ifdef COCOTB_SIM
initial begin
  $dumpfile ("midi_ctrl.vcd");
  $dumpvars (0, midi_ctrl);
  #1;
end
`endif

endmodule
