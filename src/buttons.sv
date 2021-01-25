module buttons #(parameter DEBOUNCE_CNT=21) (
    input logic clk,
    input logic rst,
    input logic board_btn,
    input logic btn2_pin_1,
    input logic btn2_pin_2,
    input logic [1:0] midi_in_state,

    output logic save_mode,
    output logic [1:0] btn_index
);

// raise will appear once
logic btn1_raise;
logic btn2_raise;

debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) d1 (clk, rst, board_btn, btn1_raise);
debounce_3pin spdt1(clk, btn2_pin_1, btn2_pin_2, btn2_raise);

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        btn_index <= 0;
        save_mode <= 0;
    end
    else begin
        case ({btn2_raise, btn1_raise})
            2'b01: begin
                btn_index <= 1;
                save_mode <= (midi_in_state == 1);
            end
            2'b10: begin
                btn_index <= 2;
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
