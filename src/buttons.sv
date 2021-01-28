module buttons #(parameter DEBOUNCE_CNT=21) (
    input logic clk,
    input logic rst,
    input logic board_btn,
    input logic btn2_pin_1,
    input logic btn2_pin_2,
    input logic btn3_pin_1,
    input logic btn3_pin_2,
    input logic btn4_pin_1,
    input logic btn4_pin_2,
    input logic btn5_pin_1,
    input logic btn5_pin_2,
    input logic [1:0] midi_in_state,

    output logic save_mode,
    output logic [1:0] btn_index
);

// raise will appear once
logic btn1_raise = 0;
logic btn2_raise;
logic btn3_raise;
logic btn4_raise;
logic btn5_raise;

//debounce_short #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) d1 (clk, rst, board_btn, btn1_raise);
debounce_3pin spdt1(clk, btn2_pin_1, btn2_pin_2, btn2_raise);
debounce_3pin spdt2(clk, btn3_pin_1, btn3_pin_2, btn3_raise);
debounce_3pin spdt3(clk, btn4_pin_1, btn4_pin_2, btn4_raise);
debounce_3pin spdt4(clk, btn5_pin_1, btn5_pin_2, btn5_raise);

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        btn_index <= 0;
        save_mode <= 0;
    end
    else begin
        case ({btn5_raise, btn4_raise, btn3_raise, btn2_raise, btn1_raise})
            5'b00010, 5'b00001: begin
                btn_index <= 1;
                save_mode <= (midi_in_state == 1);
            end
            5'b00100: begin
                btn_index <= 2;
                save_mode <= (midi_in_state == 1);
            end
            5'b01000: begin
                btn_index <= 3;
                save_mode <= (midi_in_state == 1);
            end
            5'b10000: begin
                btn_index <= 4;
                save_mode <= (midi_in_state == 1);
            end
            default: begin
                btn_index <= 0;
                save_mode <= 0;
            end
        endcase
    end
end

endmodule
