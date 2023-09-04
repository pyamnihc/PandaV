module ks_string #(
    parameter MAX_LENGTH = 256,
    parameter DATA_WIDTH = 8,
    parameter PRBS_WIDTH = 2,
    parameter EXTN_BITS = 4,
    parameter FRAC_BITS = 4
    ) (
    input clk_i,
    input rst_ni,
    input freeze_i,
    input round_en_i,
    input pluck_i,
    input toggle_pattern_prbs_ni, 
    input drum_string_ni,
    input fine_tune_en_i,
    input signed [DATA_WIDTH-1:0] fine_tune_C_i,
    input dynamics_en_i,
    input [DATA_WIDTH-1:0] dynamics_R_i,
    input [PRBS_WIDTH-1:0] prbs_data_i,
    input [DATA_WIDTH-1:0] period_i,
    output [DATA_WIDTH-1:0] ks_sample_o
);

// referenced from, papers at   https://doi.org/10.2307/3680062
//                              https://doi.org/10.2307/3680063

localparam EXTENDED_WIDTH = DATA_WIDTH+EXTN_BITS;

wire [DATA_WIDTH-1:0] clamped_period = period_i < MAX_LENGTH ? period_i : MAX_LENGTH;
wire [DATA_WIDTH-1:0] period_idx;
assign period_idx = clamped_period - 8'h01;

// pluck sync and detect
reg [3:0] pluck_shift_reg;
always @(posedge clk_i) begin
    if (!rst_ni) begin
        pluck_shift_reg = 'b0;
    end else begin
        pluck_shift_reg = {pluck_shift_reg[6:0], pluck_i};
    end
end

wire pluck_rise_pulse;
assign pluck_rise_pulse = !pluck_shift_reg[3] && pluck_shift_reg[2];

// noise burst capture
reg signed [EXTENDED_WIDTH+FRAC_BITS-1:0] noise_reg;
reg [$clog2(MAX_LENGTH)-1:0] prbs_burst_counter;
reg prbs_burst_en;
wire signed [EXTENDED_WIDTH+FRAC_BITS-1:0] noise_burst;
// three level noise, 0 MID HIGH
assign noise_burst = prbs_data_i[1]   ? (prbs_data_i[0]   ? ({{(EXTN_BITS+1){1'b0}}, {((DATA_WIDTH+FRAC_BITS)-1){1'b1}}}) 
                                                            : ({{(EXTN_BITS+1){1'b1}}, {((DATA_WIDTH+FRAC_BITS)-1){1'b0}}})) 
                                        : ({(EXTENDED_WIDTH+FRAC_BITS){1'b0}});

// dynamics filter
wire signed [EXTENDED_WIDTH+FRAC_BITS-1:0] yd_0;
assign yd_0 = noise_burst_dyn;
reg signed [EXTENDED_WIDTH+FRAC_BITS-1:0] yd_1;

always @(posedge clk_i) begin
    if (!rst_ni) yd_1 <= 'b0;
    else yd_1 <= yd_0;
end

wire signed [EXTENDED_WIDTH+FRAC_BITS-1:0] R_diff, noise_burst_dyn;
wire signed [DATA_WIDTH+EXTENDED_WIDTH+FRAC_BITS-1:0] scaled_R_diff;
assign R_diff = yd_1 - noise_burst;
assign scaled_R_diff = (dynamics_R_i * R_diff) >>> DATA_WIDTH;
assign noise_burst_dyn = noise_burst + scaled_R_diff;

wire signed [EXTENDED_WIDTH+FRAC_BITS-1:0] noise_burst_w;
assign noise_burst_w = dynamics_en_i ? noise_burst_dyn : noise_burst;

reg toggle_bit;
always @(posedge clk_i) begin
    if (!rst_ni) toggle_bit <= 'b0;
    else toggle_bit <= ~toggle_bit;
end

wire [EXTENDED_WIDTH+FRAC_BITS-1:0] toggle_clamp;
assign toggle_clamp = {{EXTN_BITS{toggle_bit}}, {toggle_bit, {DATA_WIDTH-1{~toggle_bit}}}, {FRAC_BITS{~toggle_bit}}};

always @(posedge clk_i) begin
    if (!rst_ni) begin
        prbs_burst_counter <= 'b0;
        noise_reg <= 'b0;
        prbs_burst_en <= 'b0;
    end else begin
        if (pluck_rise_pulse == 1'b1) begin
            prbs_burst_counter <= 'b0;
            noise_reg <= prbs_data_i;
            prbs_burst_en <= 'b1;
        end else if (prbs_burst_en == 1'b1) begin
            if (prbs_burst_counter < clamped_period) begin
                prbs_burst_counter <= prbs_burst_counter + 1;
                noise_reg <= toggle_pattern_prbs_ni ? toggle_clamp : noise_burst_w;
                prbs_burst_en <= 1'b1;
            end else begin
                prbs_burst_counter <= 'b0;
                noise_reg <= 'b0;
                prbs_burst_en <= 1'b0;
            end
        end else begin
            prbs_burst_counter <= 'b0;
            noise_reg <= 'b0;
            prbs_burst_en <= 'b0;
        end
    end
end

// filter taps
wire signed [DATA_WIDTH-1:0] x_p;
assign x_p = string_reg[period_idx];
wire signed [DATA_WIDTH-1:0] x_p_1;
assign x_p_1 = delay_reg;

// Strong filter
wire signed [EXTENDED_WIDTH+FRAC_BITS-1:0] strong_string_avg;
assign strong_string_avg = (((x_p <<< FRAC_BITS) + (x_p_1 <<< FRAC_BITS)) >>> 1);

wire signed [EXTENDED_WIDTH+FRAC_BITS-1:0] strong_drum_avg;
assign strong_drum_avg = prbs_data_i[0] ? strong_string_avg : -strong_string_avg;

wire signed [EXTENDED_WIDTH+FRAC_BITS-1:0] strong_filter_w;
assign strong_filter_w = drum_string_ni ? strong_drum_avg : strong_string_avg; 

wire signed [EXTENDED_WIDTH+FRAC_BITS-1:0] ks_sample_w;
assign ks_sample_w = noise_reg + strong_filter_w + (round_en_i ? (1 << (FRAC_BITS-1)) : 0);                        

// overflow detect
wire ks_sign_bit;
assign ks_sign_bit = ks_sample_w[EXTENDED_WIDTH+FRAC_BITS-1];
wire ks_data_msb;
assign ks_data_msb = ks_sample_w[DATA_WIDTH+FRAC_BITS-1];

wire ks_ovf;
assign ks_ovf = ks_sign_bit ^ ks_data_msb;

wire [EXTENDED_WIDTH+FRAC_BITS-1:0] ks_clamped_val;
assign ks_clamped_val = {{EXTN_BITS{ks_sign_bit}}, {ks_sign_bit, {DATA_WIDTH-1{ks_data_msb}}}, {FRAC_BITS{ks_data_msb}}};

wire signed [EXTENDED_WIDTH+FRAC_BITS-1:0] ks_sample_clamped_w;
assign ks_sample_clamped_w = ks_ovf ? ks_clamped_val : ks_sample_w;

wire [DATA_WIDTH-1:0] ks_sample;
assign ks_sample = ks_sample_clamped_w[DATA_WIDTH+FRAC_BITS-1:FRAC_BITS];

reg signed [EXTENDED_WIDTH+FRAC_BITS-1:0] strong_filter_1;
always @(posedge clk_i) begin
    if (!rst_ni) strong_filter_1 <= 'b0;
    else strong_filter_1 <= strong_filter_w;
end

// Fine Tune
reg signed [EXTENDED_WIDTH+FRAC_BITS-1:0] y_1;
wire signed [EXTENDED_WIDTH+FRAC_BITS-1:0] y_0, C_diff;
wire signed [DATA_WIDTH+EXTENDED_WIDTH+FRAC_BITS-1:0] scaled_C_diff;

assign C_diff = strong_filter_w - y_1;
assign scaled_C_diff = ((fine_tune_C_i * C_diff) >>> (DATA_WIDTH-1));
assign y_0 = strong_filter_1 + scaled_C_diff;

always @(posedge clk_i) begin
    if (!rst_ni) y_1 <= 'b0;
    else y_1 <= y_0;
end

wire signed [EXTENDED_WIDTH+FRAC_BITS-1:0] ks_sample_ft_w;
assign ks_sample_ft_w = noise_reg + y_0 + (round_en_i ? (1 << (FRAC_BITS-1)) : 0);

// overflow detect
wire ft_sign_bit;
assign ft_sign_bit = ks_sample_ft_w[EXTENDED_WIDTH+FRAC_BITS-1];
wire ft_data_msb;
assign ft_data_msb = ks_sample_ft_w[DATA_WIDTH+FRAC_BITS-1];

wire ft_ovf;
assign ft_ovf = ft_sign_bit ^ ft_data_msb;

wire [EXTENDED_WIDTH+FRAC_BITS-1:0] ft_clamped_val;
assign ft_clamped_val = {{EXTN_BITS{ft_sign_bit}}, {ft_sign_bit, {DATA_WIDTH-1{ft_data_msb}}}, {FRAC_BITS{ft_data_msb}}};

wire signed [EXTENDED_WIDTH+FRAC_BITS-1:0] ks_sample_ft_clamped_w;
assign ks_sample_ft_clamped_w = ft_ovf ? ft_clamped_val : ks_sample_ft_w;

wire [DATA_WIDTH-1:0] ks_sample_ft;
assign ks_sample_ft = ks_sample_ft_clamped_w[DATA_WIDTH+FRAC_BITS-1:FRAC_BITS];

wire [DATA_WIDTH-1:0] ks_sample_loop_o;
assign ks_sample_loop_o = fine_tune_en_i ? ks_sample_ft : ks_sample;

assign ks_sample_o = ks_sample_loop_o;

// wavetable
reg [DATA_WIDTH-1:0] string_reg [MAX_LENGTH-1:0];
// reg [MAX_LENGTH-1:0] [DATA_WIDTH-1:0] string_reg;
wire [DATA_WIDTH-1:0] w1, w2, w3, w4;
assign w1 = string_reg[0];
assign w2 = string_reg[1];
assign w3 = string_reg[2];
assign w4 = string_reg[3];

always @(posedge clk_i) begin
    if (!rst_ni) begin
        string_reg[0] <= 'b0;
    end else if (freeze_i) begin
        string_reg[0] <= string_reg[0];
    end else begin
        string_reg[0] <= ks_sample_loop_o;
    end
end

genvar i;
generate 
    for (i = 1; i < MAX_LENGTH; i = i + 1) begin
        always @(posedge clk_i) begin
            if (!rst_ni) begin
                string_reg[i] <= 'b0;
            end else if (freeze_i) begin
                string_reg[i] <= string_reg[i];
            end else begin
                string_reg[i] <= string_reg[i-1];
            end
        end
    end
endgenerate

reg [DATA_WIDTH-1:0] delay_reg;
always @(posedge clk_i) begin
    if (!rst_ni) begin
        delay_reg <= 'b0;
    end else begin
        delay_reg <= string_reg[period_idx]; 
    end
end

endmodule
