# Implementation Examples and Usage Scenarios

This document provides practical examples and common usage scenarios for the FPGA networking module.

## 1. Basic Market Data Feed Implementation

### Configuration
```systemverilog
// Example configuration parameters
parameter DATA_WIDTH = 64;
parameter SYMBOL_WIDTH = 32;
parameter PRICE_WIDTH = 32;

// Clock configuration
parameter CLOCK_FREQ = 156_250_000; // 156.25 MHz
parameter CLOCK_PERIOD = 6.4; // ns
```

### Usage Example
```systemverilog
// Instantiate the network interface
network_interface #(
    .DATA_WIDTH(64)
) network_if (
    .clk(system_clk),
    .rst_n(system_rst_n),
    // Connect XGMII interface
    .xgmii_rxd(xgmii_rx_data),
    .xgmii_rxc(xgmii_rx_ctrl),
    .xgmii_txd(xgmii_tx_data),
    .xgmii_txc(xgmii_tx_ctrl),
    // User interface
    .rx_valid(rx_valid),
    .rx_data(rx_data),
    .rx_sop(rx_sop),
    .rx_eop(rx_eop)
);

// Instantiate market data processor
market_data_processor #(
    .DATA_WIDTH(64),
    .SYMBOL_WIDTH(32),
    .PRICE_WIDTH(32)
) mdp (
    .clk(system_clk),
    .rst_n(system_rst_n),
    .data_valid(rx_valid),
    .data_in(rx_data),
    .symbol(symbol_out),
    .price(price_out)
);
```

## 2. Common Usage Scenarios

### Scenario 1: High-Frequency Trading Setup
```
Market Data Feed → FPGA Module → Trading Algorithm
                                      │
                                      ▼
                                Order Generation
```

#### Implementation Notes:
```systemverilog
// Example: Fast path for specific symbols
always_ff @(posedge clk) begin
    if (symbol_match && price_valid) begin
        // Fast-path processing
        case (symbol)
            "AAPL": begin
                if (price < threshold_price) begin
                    generate_buy_order();
                end
            end
            // Add more symbols
        endcase
    end
end
```

### Scenario 2: Market Data Aggregation
```
Multiple Feeds → FPGA Module → Consolidated Feed
                                    │
                                    ▼
                              Best Bid/Offer
```

#### Implementation Example:
```systemverilog
// Price aggregation logic
typedef struct packed {
    logic [PRICE_WIDTH-1:0] price;
    logic [31:0] quantity;
    logic [7:0] venue_id;
} price_level_t;

// Maintain best prices
price_level_t best_bid, best_ask;

always_ff @(posedge clk) begin
    if (price_valid) begin
        if (is_bid && price > best_bid.price) begin
            best_bid.price <= price;
            best_bid.quantity <= quantity;
            best_bid.venue_id <= venue_id;
        end
        else if (!is_bid && price < best_ask.price) begin
            best_ask.price <= price;
            best_ask.quantity <= quantity;
            best_ask.venue_id <= venue_id;
        end
    end
end
```

### Scenario 3: Market Data Filtering
```
Raw Feed → FPGA Filter → Filtered Feed
                             │
                             ▼
                      Specific Instruments
```

#### Implementation Example:
```systemverilog
// Symbol filtering logic
module symbol_filter #(
    parameter NUM_SYMBOLS = 16,
    parameter SYMBOL_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,
    input  logic [SYMBOL_WIDTH-1:0] symbol_in,
    input  logic [SYMBOL_WIDTH-1:0] symbol_list [NUM_SYMBOLS-1:0],
    output logic symbol_match
);

    always_ff @(posedge clk) begin
        symbol_match <= 0;
        for (int i = 0; i < NUM_SYMBOLS; i++) begin
            if (symbol_in == symbol_list[i]) begin
                symbol_match <= 1;
                break;
            end
        end
    end
endmodule
```

## 3. Performance Optimization Examples

### Example 1: Minimizing Latency
```systemverilog
// Use parallel processing for different packet fields
always_ff @(posedge clk) begin
    // Stage 1: Header processing
    if (sop) begin
        header_process();
    end
    
    // Parallel Stage: Payload processing
    if (valid_payload) begin
        payload_process();
    end
    
    // Parallel Stage: Checksum calculation
    if (valid_data) begin
        update_checksum();
    end
end
```

### Example 2: Handling Burst Traffic
```systemverilog
// Implement burst buffer
module burst_buffer #(
    parameter DEPTH = 16,
    parameter WIDTH = 64
)(
    input  logic clk,
    input  logic rst_n,
    input  logic [WIDTH-1:0] data_in,
    input  logic write_en,
    output logic [WIDTH-1:0] data_out,
    output logic read_en,
    output logic full,
    output logic empty
);
    // Buffer implementation
    logic [WIDTH-1:0] buffer [DEPTH-1:0];
    logic [$clog2(DEPTH)-1:0] write_ptr, read_ptr;
    logic [$clog2(DEPTH):0] count;
    
    // Buffer control logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 0;
            read_ptr <= 0;
            count <= 0;
        end else begin
            if (write_en && !full) begin
                buffer[write_ptr] <= data_in;
                write_ptr <= write_ptr + 1;
                count <= count + 1;
            end
            if (read_en && !empty) begin
                read_ptr <= read_ptr + 1;
                count <= count - 1;
            end
        end
    end
    
    assign full = (count == DEPTH);
    assign empty = (count == 0);
    assign data_out = buffer[read_ptr];
endmodule
```

## 4. Error Handling Examples

### Example 1: CRC Error Detection
```systemverilog
// CRC-32 implementation
module crc32_checker (
    input  logic clk,
    input  logic rst_n,
    input  logic [7:0] data_in,
    input  logic data_valid,
    output logic [31:0] crc_out,
    output logic crc_valid
);
    logic [31:0] crc_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crc_reg <= 32'hFFFFFFFF;
        end else if (data_valid) begin
            // CRC-32 polynomial: x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 + 
            // x^10 + x^8 + x^7 + x^5 + x^4 + x^2 + x + 1
            crc_reg <= {crc_reg[30:0], 1'b0} ^ 
                      (crc_reg[31] ? 32'h04C11DB7 : 32'h0);
        end
    end
    
    assign crc_out = ~crc_reg;
    assign crc_valid = data_valid;
endmodule
```

### Example 2: Packet Recovery
```systemverilog
// Implement packet recovery logic
always_ff @(posedge clk) begin
    case (state)
        ERROR_DETECTED: begin
            if (can_recover) begin
                // Try to resync with next valid packet
                if (find_sync_pattern()) begin
                    state <= RESYNCING;
                end
            end else begin
                // Report unrecoverable error
                error_code <= ERROR_UNRECOVERABLE;
                state <= IDLE;
            end
        end
        
        RESYNCING: begin
            if (valid_packet_found) begin
                state <= NORMAL_OPERATION;
                error_recovered <= 1'b1;
            end
        end
    endcase
end
```

## 5. Monitoring and Debug Features

### Example 1: Performance Counters
```systemverilog
// Implement performance monitoring
module performance_monitor (
    input  logic clk,
    input  logic rst_n,
    input  logic packet_valid,
    input  logic packet_error,
    output logic [31:0] total_packets,
    output logic [31:0] error_packets,
    output logic [31:0] throughput
);
    // Counter implementation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_packets <= 0;
            error_packets <= 0;
        end else begin
            if (packet_valid) begin
                total_packets <= total_packets + 1;
            end
            if (packet_error) begin
                error_packets <= error_packets + 1;
            end
        end
    end
    
    // Calculate throughput (packets per second)
    always_ff @(posedge clk) begin
        if (second_tick) begin
            throughput <= total_packets - last_total_packets;
            last_total_packets <= total_packets;
        end
    end
endmodule
```

### Example 2: Debug Interface
```systemverilog
// Debug interface implementation
module debug_interface (
    input  logic clk,
    input  logic rst_n,
    input  logic [63:0] debug_data,
    input  logic debug_valid,
    output logic [7:0] debug_port,
    output logic debug_strobe
);
    // JTAG or other debug protocol implementation
    always_ff @(posedge clk) begin
        if (debug_valid) begin
            case (debug_state)
                IDLE: begin
                    if (debug_request) begin
                        debug_state <= SENDING;
                        debug_index <= 0;
                    end
                end
                
                SENDING: begin
                    debug_port <= debug_data[debug_index+:8];
                    debug_strobe <= 1'b1;
                    if (debug_index == 56) begin
                        debug_state <= IDLE;
                    end else begin
                        debug_index <= debug_index + 8;
                    end
                end
            endcase
        end
    end
endmodule
```

These examples demonstrate practical implementations and common usage scenarios. Each example includes:
- Detailed code snippets
- Implementation notes
- Configuration options
- Error handling
- Performance optimization techniques

Would you like me to:
1. Add more specific examples for any particular scenario?
2. Include additional error handling cases?
3. Add more debugging features?
