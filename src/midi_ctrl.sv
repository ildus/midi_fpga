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
    input logic rst,
    input logic clk,
    input logic btn1,
    input logic btn2,
    input logic midi_rx,
    output logic midi_tx,
    output logic led1,
    output logic led2,

    //spi flash
    input logic spi_do,
    output logic spi_clk,
    output logic spi_cs,
    output logic spi_di
);

localparam BUTTONS_CNT = 2;
localparam MEMSIZE = BUTTONS_CNT * 4;

logic we = 0;
logic [7:0] smem [MEMSIZE - 1:0];
logic mem_initialized[BUTTONS_CNT:1];
logic [1:0] btn_index = 0;

integer i;
initial begin
    for(i = 1; i <= BUTTONS_CNT; i++) begin
        mem_initialized[i] <= 0;
    end
end

/* just some sample commands */
localparam CC_MSG = 8'hB0; // CC message, channel 1
localparam PC_MSG = 8'hC0; // PC message, channel 1
localparam FIRST_CC_MSG = 8'd46;
localparam CC_VALUE = 8'b0111_1111;
localparam PC_VALUE1 = 8'h42;
localparam PC_VALUE2 = 8'h43;

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
logic btn_pressed = 0;

midi_out dout(clk, baud_clk, rst, midi_tx, status, data1, data2, cmd_bits_cnt, btn_pressed);
assign led1 = ~midi_tx;

// raise will appear once
logic btn1_raise;
logic btn2_raise;
logic btn3_raise = 0;
logic btn4_raise = 0;

debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) d1 (clk, rst, btn1, btn1_raise);
debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) d2 (clk, rst, btn2, btn2_raise);
//debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) d3 (clk, rst, btn3, btn3_raise);
//debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) d4 (clk, rst, btn4, btn4_raise);


logic [23:0] addr;
logic flash_we = 0;
logic [7:0] fifo_in;

logic [7:0] data_out;
logic data_ready;

spi_flash flash(clk, rst, addr, flash_we, fifo_in, spi_clk, spi_cs, spi_do, spi_di, data_out, data_ready);

// buttons
logic cmd_set = 0;
logic cmd_reset = 0;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        cmd_set <= 0;
    end
    else begin
        if (cmd_reset)
            cmd_set <= 0;
        else if (btn_pressed) begin
            cmd_set <= 1;
        end
    end
end

logic [12:0] clk_cnt = 0;
logic baud_clk = 0;

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

// MIDI out logic

logic [1:0] midi_in_state;
logic btn_assigned = 0;

assign led2 = (midi_in_state == 1);

always @(*) begin
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
        btn_index <= 0;
        we <= 0;
    end
    else begin
        case ({btn2_raise, btn1_raise})
            4'b01: begin
                btn_index <= 1;
                we <= (midi_in_state == 1);
            end
            4'b10: begin
                btn_index <= 2;
                we <= (midi_in_state == 1);
            end
            default: begin
                btn_index <= 0;
                we <= 0;
            end
        endcase
    end
end

always @(posedge clk or negedge rst) begin
    `define ADDR ((btn_index - 1) * 4)

    if (!rst) begin
        btn_pressed <= 0;
        for (i = 1; i <= BUTTONS_CNT; i++)
            mem_initialized[i] <= 0;
    end
    else if (btn_index != 0) begin
        if (we) begin
            smem[`ADDR] <= status_in;
            smem[`ADDR + 1] <= data1_in;
            smem[`ADDR + 2] <= data2_in;
            smem[`ADDR + 3] <= bytes_cnt_in * 10;
            btn_pressed <= 0;
            mem_initialized[btn_index] <= 1;
        end
        else begin
            if (!mem_initialized[btn_index]) begin
                status <= CC_MSG;
                data1 <= FIRST_CC_MSG + btn_index - 1;
                data2 <= CC_VALUE;
                cmd_bits_cnt <= 30;
                btn_pressed <= 1;
            end else begin
                status <= smem[`ADDR];
                data1 <= smem[`ADDR + 1];
                data2 <= smem[`ADDR + 2];
                cmd_bits_cnt <= smem[`ADDR + 3];
                btn_pressed <= 1;
            end
        end
    end
    else begin
        btn_pressed <= 0;
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
