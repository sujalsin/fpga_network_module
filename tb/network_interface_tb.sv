module network_interface_tb;
    // Parameters
    parameter DATA_WIDTH = 64;
    parameter CLK_PERIOD = 10; // 100MHz clock
    
    // Signals
    logic                     clk;
    logic                     rst_n;
    logic [DATA_WIDTH-1:0]    xgmii_rxd;
    logic [DATA_WIDTH/8-1:0]  xgmii_rxc;
    logic [DATA_WIDTH-1:0]    xgmii_txd;
    logic [DATA_WIDTH/8-1:0]  xgmii_txc;
    logic                     rx_valid;
    logic [DATA_WIDTH-1:0]    rx_data;
    logic                     rx_sop;
    logic                     rx_eop;
    logic                     rx_ready;
    logic                     tx_valid;
    logic [DATA_WIDTH-1:0]    tx_data;
    logic                     tx_sop;
    logic                     tx_eop;
    logic                     tx_ready;
    logic [15:0]             rx_packet_count;
    logic [15:0]             tx_packet_count;
    logic                    rx_overflow;
    logic                    tx_underflow;
    
    // Market data processor signals
    logic [31:0]             symbol;
    logic [31:0]             price;
    logic                    price_valid;
    logic [15:0]             processed_messages;
    logic                    parser_error;
    
    // Instantiate network interface
    network_interface #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .xgmii_rxd(xgmii_rxd),
        .xgmii_rxc(xgmii_rxc),
        .xgmii_txd(xgmii_txd),
        .xgmii_txc(xgmii_txc),
        .rx_valid(rx_valid),
        .rx_data(rx_data),
        .rx_sop(rx_sop),
        .rx_eop(rx_eop),
        .rx_ready(rx_ready),
        .tx_valid(tx_valid),
        .tx_data(tx_data),
        .tx_sop(tx_sop),
        .tx_eop(tx_eop),
        .tx_ready(tx_ready),
        .rx_packet_count(rx_packet_count),
        .tx_packet_count(tx_packet_count),
        .rx_overflow(rx_overflow),
        .tx_underflow(tx_underflow)
    );
    
    // Instantiate market data processor
    market_data_processor #(
        .DATA_WIDTH(DATA_WIDTH)
    ) mdp (
        .clk(clk),
        .rst_n(rst_n),
        .data_valid(rx_valid),
        .data_in(rx_data),
        .sop(rx_sop),
        .eop(rx_eop),
        .ready(rx_ready),
        .symbol(symbol),
        .price(price),
        .price_valid(price_valid),
        .processed_messages(processed_messages),
        .parser_error(parser_error)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test stimulus
    initial begin
        // Initialize signals
        rst_n = 0;
        xgmii_rxd = '0;
        xgmii_rxc = '0;
        tx_valid = 0;
        tx_data = '0;
        tx_sop = 0;
        tx_eop = 0;
        
        // Reset sequence
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 5);
        
        // Test Case 1: Send a market data packet
        // Packet format: [START][TYPE][LENGTH][SYMBOL][PRICE][QUANTITY][CHECKSUM][END]
        @(posedge clk);
        xgmii_rxc = 8'h01;
        xgmii_rxd = {56'h0, 8'hFB};  // Start
        
        @(posedge clk);
        xgmii_rxc = 8'h00;
        xgmii_rxd = {40'h0, 8'h01, 16'h0020};  // Type = 1, Length = 32 bytes
        
        @(posedge clk);
        xgmii_rxd = "AAPL";  // Symbol
        
        @(posedge clk);
        xgmii_rxd = 32'h000186A0;  // Price = 100000 (1000.00)
        
        @(posedge clk);
        xgmii_rxd = 32'h000000C8;  // Quantity = 200
        
        @(posedge clk);
        xgmii_rxd = 32'h12345678;  // Checksum
        
        @(posedge clk);
        xgmii_rxc = 8'h01;
        xgmii_rxd = {56'h0, 8'hFD};  // End
        
        // Wait for processing
        #(CLK_PERIOD * 10);
        
        // Verify results
        if (processed_messages != 1) $error("Failed to process message");
        if (parser_error) $error("Parser error detected");
        if (price != 32'h000186A0) $error("Incorrect price value");
        
        // Test Case 2: Error handling - Invalid checksum
        // Similar packet but with wrong checksum
        // ... Add more test cases as needed
        
        #(CLK_PERIOD * 100);
        $display("Simulation completed");
        $finish;
    end
    
    // Monitor process
    initial begin
        $monitor("Time=%0t rx_valid=%b rx_data=%h processed_messages=%0d parser_error=%b",
                 $time, rx_valid, rx_data, processed_messages, parser_error);
    end

endmodule
