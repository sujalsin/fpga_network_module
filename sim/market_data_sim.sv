// Market data simulation environment
module market_data_sim;

    // Parameters
    parameter CLK_PERIOD = 6.4; // 156.25 MHz
    parameter SIM_CYCLES = 1000;
    parameter DATA_WIDTH = 64;
    
    // Signals
    logic clk;
    logic rst_n;
    
    // Network interface signals
    logic [DATA_WIDTH-1:0] xgmii_rxd;
    logic [DATA_WIDTH/8-1:0] xgmii_rxc;
    logic [DATA_WIDTH-1:0] xgmii_txd;
    logic [DATA_WIDTH/8-1:0] xgmii_txc;
    
    // Market data signals
    logic [31:0] symbol;
    logic [31:0] price;
    logic price_valid;
    logic [15:0] processed_messages;
    
    // Performance monitoring
    logic [31:0] total_packets;
    logic [31:0] error_packets;
    logic [31:0] throughput;
    
    // Instantiate DUT
    network_interface #(
        .DATA_WIDTH(DATA_WIDTH)
    ) network_if (
        .clk(clk),
        .rst_n(rst_n),
        .xgmii_rxd(xgmii_rxd),
        .xgmii_rxc(xgmii_rxc),
        .xgmii_txd(xgmii_txd),
        .xgmii_txc(xgmii_txc)
    );
    
    market_data_processor #(
        .DATA_WIDTH(DATA_WIDTH)
    ) mdp (
        .clk(clk),
        .rst_n(rst_n),
        .symbol(symbol),
        .price(price),
        .price_valid(price_valid),
        .processed_messages(processed_messages)
    );
    
    performance_monitor perf_mon (
        .clk(clk),
        .rst_n(rst_n),
        .total_packets(total_packets),
        .error_packets(error_packets),
        .throughput(throughput)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test stimulus
    initial begin
        // Initialize
        rst_n = 0;
        xgmii_rxd = '0;
        xgmii_rxc = '0;
        
        // Reset sequence
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 2);
        
        // Test Case 1: Normal Market Data Packet
        send_market_data_packet(
            .symbol("AAPL"),
            .price(32'h000186A0),  // 100000 (1000.00)
            .quantity(32'h000000C8) // 200
        );
        
        // Wait for processing
        #(CLK_PERIOD * 10);
        
        // Test Case 2: Rapid Succession of Packets
        for (int i = 0; i < 5; i++) begin
            send_market_data_packet(
                .symbol("MSFT"),
                .price(32'h00019A28), // 105000 (1050.00)
                .quantity(32'h00000064) // 100
            );
            #(CLK_PERIOD * 2);
        end
        
        // Test Case 3: Error Injection
        send_corrupted_packet();
        
        // Wait for error handling
        #(CLK_PERIOD * 20);
        
        // Test Case 4: Maximum Throughput Test
        stress_test_throughput();
        
        // End simulation
        #(CLK_PERIOD * 100);
        $display("Simulation completed");
        $display("Total packets: %d", total_packets);
        $display("Error packets: %d", error_packets);
        $display("Throughput: %d packets/sec", throughput);
        $finish;
    end
    
    // Task to send a market data packet
    task automatic send_market_data_packet(
        input [31:0] symbol,
        input [31:0] price,
        input [31:0] quantity
    );
        // Start frame delimiter
        @(posedge clk);
        xgmii_rxc = 8'h01;
        xgmii_rxd = {56'h0, 8'hFB};
        
        // Header
        @(posedge clk);
        xgmii_rxc = 8'h00;
        xgmii_rxd = {40'h0, 8'h01, 16'h0020}; // Type = 1, Length = 32 bytes
        
        // Symbol
        @(posedge clk);
        xgmii_rxd = symbol;
        
        // Price
        @(posedge clk);
        xgmii_rxd = price;
        
        // Quantity
        @(posedge clk);
        xgmii_rxd = quantity;
        
        // Checksum (simple example)
        @(posedge clk);
        xgmii_rxd = symbol ^ price ^ quantity;
        
        // End frame delimiter
        @(posedge clk);
        xgmii_rxc = 8'h01;
        xgmii_rxd = {56'h0, 8'hFD};
        
        // Inter-frame gap
        @(posedge clk);
        xgmii_rxc = 8'h00;
        xgmii_rxd = '0;
    endtask
    
    // Task to send a corrupted packet
    task automatic send_corrupted_packet();
        // Similar to normal packet but with invalid checksum
        send_market_data_packet(
            .symbol("GOOG"),
            .price(32'h000186A0),
            .quantity(32'h00000064)
        );
        // Corrupt the last byte
        @(posedge clk);
        xgmii_rxd[7:0] = 8'hFF;
    endtask
    
    // Task to test maximum throughput
    task automatic stress_test_throughput();
        for (int i = 0; i < 100; i++) begin
            send_market_data_packet(
                .symbol("TEST"),
                .price(32'h00010000 + i),
                .quantity(32'h00000064)
            );
            #(CLK_PERIOD); // Minimum inter-packet gap
        end
    endtask
    
    // Monitor process
    initial begin
        $monitor("Time=%0t symbol=%s price=%h valid=%b processed=%d",
                 $time, symbol, price, price_valid, processed_messages);
    end

endmodule
