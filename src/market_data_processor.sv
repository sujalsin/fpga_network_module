module market_data_processor #(
    parameter DATA_WIDTH = 64,
    parameter MAX_PACKET_SIZE = 1500,  // Maximum Ethernet frame size
    parameter SYMBOL_WIDTH = 32,
    parameter PRICE_WIDTH = 32
) (
    // Clock and reset
    input  logic                     clk,
    input  logic                     rst_n,
    
    // Input interface
    input  logic                     data_valid,
    input  logic [DATA_WIDTH-1:0]    data_in,
    input  logic                     sop,        // Start of packet
    input  logic                     eop,        // End of packet
    output logic                     ready,
    
    // Output interface
    output logic                     data_valid_out,
    output logic [DATA_WIDTH-1:0]    data_out,
    output logic                     data_ready_out,
    
    // Market data specific outputs
    output logic [SYMBOL_WIDTH-1:0]  symbol,
    output logic [PRICE_WIDTH-1:0]   price,
    output logic                     price_valid,
    
    // Status and control
    output logic [15:0]              processed_messages,
    output logic                     parser_error
);

    // Market data packet format states
    typedef enum logic [2:0] {
        HEADER,
        SYMBOL_FIELD,
        PRICE_FIELD,
        QUANTITY_FIELD,
        CHECKSUM
    } parser_state_t;
    
    parser_state_t current_state;
    
    // Internal registers
    logic [15:0] packet_length;
    logic [31:0] checksum;
    logic [7:0]  message_type;
    
    // Market data processing logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= HEADER;
            processed_messages <= '0;
            parser_error <= 1'b0;
            price_valid <= 1'b0;
        end else begin
            if (data_valid) begin
                case (current_state)
                    HEADER: begin
                        if (sop) begin
                            message_type <= data_in[7:0];
                            packet_length <= data_in[23:8];
                            current_state <= SYMBOL_FIELD;
                        end
                    end
                    
                    SYMBOL_FIELD: begin
                        symbol <= data_in[SYMBOL_WIDTH-1:0];
                        current_state <= PRICE_FIELD;
                    end
                    
                    PRICE_FIELD: begin
                        price <= data_in[PRICE_WIDTH-1:0];
                        price_valid <= 1'b1;
                        current_state <= QUANTITY_FIELD;
                    end
                    
                    QUANTITY_FIELD: begin
                        // Process quantity if needed
                        current_state <= CHECKSUM;
                    end
                    
                    CHECKSUM: begin
                        if (eop) begin
                            if (checksum == data_in[31:0]) begin
                                processed_messages <= processed_messages + 1'b1;
                            end else begin
                                parser_error <= 1'b1;
                            end
                            current_state <= HEADER;
                            price_valid <= 1'b0;
                        end
                    end
                    
                    default: begin
                        current_state <= HEADER;
                        parser_error <= 1'b1;
                    end
                endcase
            end
        end
    end
    
    // Checksum calculation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            checksum <= '0;
        end else if (sop) begin
            checksum <= '0;
        end else if (data_valid && !eop) begin
            checksum <= checksum + data_in;  // Simple additive checksum
        end
    end
    
    // Output control
    assign ready = !parser_error;
    assign data_valid_out = data_valid && !parser_error;
    assign data_out = data_in;  // Pass-through for now, can be modified for specific processing
    assign data_ready_out = current_state != CHECKSUM;

endmodule
