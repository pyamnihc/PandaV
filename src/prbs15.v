module prbs15 (
    input clk_i,
    input rst_ni,
    input [14:0] prbs_init_i,
    input load_prbs_i,
    input freeze_i,
    output [14:0]  prbs_frame_o
);
    reg load_prbs_reg;
    always @(posedge clk_i) begin
        if (!rst_ni) begin
            load_prbs_reg <= 'b0;
        end else begin
            load_prbs_reg <= load_prbs_i;
        end
    end
    wire load_prbs_pulse;
    assign load_prbs_pulse = !load_prbs_reg && load_prbs_i;

    reg [14:0] lfsr_reg;
    always @(posedge clk_i) begin
        if (!rst_ni) begin
            lfsr_reg <= 15'h7fff;
        end else if (load_prbs_pulse == 1) begin
            lfsr_reg <= prbs_init_i;
        end else if (freeze_i == 1) begin
            lfsr_reg <= lfsr_reg;
        end else begin
            lfsr_reg <= {lfsr_reg[13:0], lfsr_reg[14] ^ lfsr_reg[13]};
        end
    end
    
    assign prbs_frame_o = lfsr_reg;

endmodule
