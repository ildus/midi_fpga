module buttons #(parameter DEBOUNCE_CNT=21) (
    input logic clk,
    input logic rst,
    input logic btn1,
    input logic btn2,
    input logic [1:0] midi_in_state,

    output logic save_mode = 0,
    output logic [1:0] btn_index = 0
);

// raise will appear once
logic btn1_raise;
logic btn2_raise;
//logic btn3_raise = 0;
//logic btn4_raise = 0;

debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) d1 (clk, rst, btn1, btn1_raise);
debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) d2 (clk, rst, btn2, btn2_raise);
//debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) d3 (clk, rst, btn3, btn3_raise);
//debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) d4 (clk, rst, btn4, btn4_raise);

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        btn_index <= 0;
        save_mode <= 0;
    end
    else begin
        case ({btn2_raise, btn1_raise})
            4'b01: begin
                btn_index <= 1;
                save_mode <= (midi_in_state == 1);
            end
            4'b10: begin
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
