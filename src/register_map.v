module register_map #(
    parameter ADDR_WIDTH = 7,
    parameter DATA_WIDTH = 8,
    parameter NUM_CONFIG_REG = 12,
    parameter NUM_STATUS_REG = 4
) (
    input clk_i,
    input rstn_n,
    input [ADDR_WIDTH-1:0] addr_i,
    input [DATA_WIDTH-1:0] write_data_i,
    input write_en_i,
    output [DATA_WIDTH-1:0] read_data_o,
    input read_en_i,
    output [DATA_WIDTH*NUM_CONFIG_REG-1:0] config_bus_o,
    input [DATA_WIDTH*NUM_STATUS_REG-1:0] status_bus_i
);

    // packed to unpacked conversion
    reg [DATA_WIDTH-1:0] register_map_mem [NUM_CONFIG_REG-1:0];
    genvar i;
    generate 
        for (i = 0; i < NUM_CONFIG_REG; i = i + 1) begin
            assign config_bus_o[DATA_WIDTH*(i+1)-1: DATA_WIDTH*i] = register_map_mem[i];
        end
    endgenerate

    wire [DATA_WIDTH*(NUM_CONFIG_REG+NUM_STATUS_REG)-1:0] csr_read_bus;
    assign csr_read_bus = {status_bus_i, config_bus_o};
    
    wire [DATA_WIDTH-1:0] csr_read_arr [NUM_CONFIG_REG+NUM_STATUS_REG-1:0];
    generate
        for (i = 0; i < (NUM_CONFIG_REG + NUM_STATUS_REG); i = i + 1) begin
            assign csr_read_arr[i] = csr_read_bus[DATA_WIDTH*(i+1)-1:DATA_WIDTH*i];
        end
    endgenerate
    
    // synchronize to clk_i domain
    reg [DATA_WIDTH-1:0] write_data_sync, write_data_reg;
    always @(posedge clk_i) begin
        if (!rstn_n) begin
            write_data_sync <= 'b0;
            write_data_reg <= 'b0;
        end else if (write_en_i == 1) begin
            write_data_sync <= write_data_i;
            write_data_reg <= write_data_sync;
        end
    end

    reg [DATA_WIDTH-1:0] read_data_sync, read_data_reg;
    always @(posedge clk_i) begin
        if (!rstn_n) begin
            read_data_sync <= 'b0;
            read_data_reg <= 'b0;
        end else if (read_en_i == 1) begin
            if (addr_i < (NUM_CONFIG_REG + NUM_STATUS_REG)) begin
                read_data_sync <= csr_read_arr[addr_i];
                read_data_reg <= read_data_sync;
            end
            else begin
                read_data_reg <= 8'hff;
            end
        end
    end
    assign read_data_o = read_data_reg; 

    // attempt to non-zero init. can't make it work with skywater-pdk
    always @(posedge clk_i) begin
        if (!rstn_n) begin
            register_map_mem[0] <= 8'hCC;
        end else if ((addr_i == 0) && (addr_i < NUM_CONFIG_REG)) begin
            if (write_en_i) register_map_mem[0] <= write_data_reg;
        end
    end
    
    generate 
        for (i = 1; i < NUM_CONFIG_REG; i = i + 1) begin
            always @(posedge clk_i) begin
                if (!rstn_n) begin
                    register_map_mem[i] <= 'b0;
                end else if ((addr_i == i) && (addr_i < NUM_CONFIG_REG)) begin
                    if (write_en_i) register_map_mem[i] <= write_data_reg;
                end
            end
        end
    endgenerate

endmodule
    

