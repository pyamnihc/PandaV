`default_nettype none

module tt_um_spi_register_map (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    parameter INST_WIDTH = 1;
    parameter ADDR_WIDTH = 7;
    parameter DATA_WIDTH = 8;
    parameter NUM_CONFIG_REG = 12;
    parameter NUM_STATUS_REG = 4;

    wire sck_i;
    assign sck_i = uio_in[0];
    wire sdi_i;
    assign sdi_i = uio_in[1];
    wire sdo_o;
    assign uio_out[2] = sdo_o;
    wire cs_ni;
    assign cs_ni = uio_in[3];
    
    assign uio_out[0] = 1'b1;
    assign uio_out[1] = 1'b1;
    assign uio_out[3] = 1'b1;
    assign uio_out[4] = 1'b1;
    assign uio_out[5] = 1'b1;
    assign uio_oe = 8'b1100_0100;
    assign uo_out = 8'hff;

    wire [DATA_WIDTH*NUM_CONFIG_REG-1:0] config_bus_o;
    wire [DATA_WIDTH*NUM_STATUS_REG-1:0] status_bus_i;

    wire [DATA_WIDTH-1:0] config_arr [NUM_CONFIG_REG-1:0];
    genvar i;
    generate
        for (i = 0; i < NUM_CONFIG_REG - 1; i = i + 1) begin
            assign config_arr[i] = config_bus_o[DATA_WIDTH*(i+1)-1:DATA_WIDTH*i];
        end
    endgenerate

    assign uio_out[7] = prbs_frame[0];
    assign uio_out[6] = |config_bus_o;
    assign status_bus_i[DATA_WIDTH*(NUM_STATUS_REG/2)-1:0] = {(DATA_WIDTH*(NUM_STATUS_REG/2)){uio_in[5]}};
    assign status_bus_i[DATA_WIDTH*NUM_STATUS_REG-1:DATA_WIDTH*(NUM_STATUS_REG/2)] = {(DATA_WIDTH*(NUM_STATUS_REG/2)){uio_in[4]}};

    wire [ADDR_WIDTH-1:0] spi_addr;
    wire [DATA_WIDTH-1:0] spi_write_data, spi_read_data;
    wire spi_write_en, spi_read_en;

    spi_slave_mem_interface #(.INST_WIDTH(INST_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH)
    ) spi_slave_mem_interface_0 (
        .sck_i(sck_i),
        .sdi_i(sdi_i),
        .sdo_o(sdo_o),
        .cs_ni(cs_ni && rst_n),
        .addr_o(spi_addr),
        .write_data_o(spi_write_data),
        .write_en_o(spi_write_en),
        .read_data_i(spi_read_data),
        .read_en_o(spi_read_en)
    );

    register_map #( .ADDR_WIDTH(ADDR_WIDTH),
                    .DATA_WIDTH(DATA_WIDTH),
                    .NUM_CONFIG_REG(NUM_CONFIG_REG),
                    .NUM_STATUS_REG(NUM_STATUS_REG)
    ) register_map_0 (
        .clk_i(clk),
        .rstn_n(rst_n),
        .addr_i(spi_addr),
        .write_data_i(spi_write_data),
        .write_en_i(spi_write_en),
        .read_data_o(spi_read_data),
        .read_en_i(spi_read_en),
        .config_bus_o(config_bus_o),
        .status_bus_i(status_bus_i)
    );
    
    wire rst_n_prbs;
    assign rst_n_prbs = config_arr[0][0];
    wire [14:0] prbs_init;
    assign prbs_init = {config_arr[2][6:0], config_arr[1][7:0]};
    wire load_prbs;
    assign load_prbs = config_arr[2][7];
    wire freeze_prbs;
    assign freeze_prbs = config_arr[3][0];
    wire [14:0] prbs_frame;
    prbs15 UUT_prbs15 (
        .clk_i(clk),
        .rst_ni(rst_n && rst_n_prbs),
        .prbs_init_i(prbs_init),
        .load_prbs_i(load_prbs),
        .freeze_i(freeze_prbs),
        .prbs_frame_o(prbs_frame)
    );

endmodule
