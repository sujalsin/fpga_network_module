module network_interface #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 16,
    parameter FIFO_DEPTH = 512
) (
    // Clock and reset
    input  logic                     clk,
    input  logic                     rst_n,
    
    // XGMII interface (10G Ethernet)
    input  logic [DATA_WIDTH-1:0]    xgmii_rxd,
    input  logic [DATA_WIDTH/8-1:0]  xgmii_rxc,
    output logic [DATA_WIDTH-1:0]    xgmii_txd,
    output logic [DATA_WIDTH/8-1:0]  xgmii_txc,
    
    // User interface
    output logic                     rx_valid,
    output logic [DATA_WIDTH-1:0]    rx_data,
    output logic                     rx_sop,    // Start of packet
    output logic                     rx_eop,    // End of packet
    input  logic                     rx_ready,
    
    input  logic                     tx_valid,
    input  logic [DATA_WIDTH-1:0]    tx_data,
    input  logic                     tx_sop,
    input  logic                     tx_eop,
    output logic                     tx_ready,
    
    // Status signals
    output logic [15:0]              rx_packet_count,
    output logic [15:0]              tx_packet_count,
    output logic                     rx_overflow,
    output logic                     tx_underflow
);

    // Internal signals
    logic rx_fifo_full, rx_fifo_empty;
    logic tx_fifo_full, tx_fifo_empty;
    logic [DATA_WIDTH-1:0] rx_fifo_data, tx_fifo_data;
    
    // Packet processing state machines
    typedef enum logic [2:0] {
        IDLE,
        PACKET_START,
        PACKET_DATA,
        PACKET_END,
        ERROR
    } state_t;
    
    state_t rx_state, tx_state;
    
    // Receive path logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= IDLE;
            rx_packet_count <= '0;
            rx_overflow <= 1'b0;
        end else begin
            case (rx_state)
                IDLE: begin
                    if (xgmii_rxc[0] && xgmii_rxd[7:0] == 8'hFB) begin
                        rx_state <= PACKET_START;
                        rx_valid <= 1'b1;
                        rx_sop <= 1'b1;
                    end
                end
                
                PACKET_START: begin
                    rx_state <= PACKET_DATA;
                    rx_sop <= 1'b0;
                end
                
                PACKET_DATA: begin
                    if (xgmii_rxc[0] && xgmii_rxd[7:0] == 8'hFD) begin
                        rx_state <= PACKET_END;
                        rx_eop <= 1'b1;
                        rx_packet_count <= rx_packet_count + 1'b1;
                    end
                end
                
                PACKET_END: begin
                    rx_state <= IDLE;
                    rx_valid <= 1'b0;
                    rx_eop <= 1'b0;
                end
                
                ERROR: begin
                    rx_state <= IDLE;
                    rx_overflow <= 1'b1;
                end
            endcase
        end
    end
    
    // Transmit path logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= IDLE;
            tx_packet_count <= '0;
            tx_underflow <= 1'b0;
        end else begin
            case (tx_state)
                IDLE: begin
                    if (tx_valid && !tx_fifo_full) begin
                        tx_state <= PACKET_START;
                        xgmii_txd <= {56'h0, 8'hFB};  // Start frame delimiter
                        xgmii_txc <= 8'h01;
                    end
                end
                
                PACKET_START: begin
                    tx_state <= PACKET_DATA;
                    xgmii_txd <= tx_data;
                    xgmii_txc <= 8'h00;
                end
                
                PACKET_DATA: begin
                    if (tx_eop) begin
                        tx_state <= PACKET_END;
                        xgmii_txd <= {56'h0, 8'hFD};  // End frame delimiter
                        xgmii_txc <= 8'h01;
                        tx_packet_count <= tx_packet_count + 1'b1;
                    end else begin
                        xgmii_txd <= tx_data;
                        xgmii_txc <= 8'h00;
                    end
                end
                
                PACKET_END: begin
                    tx_state <= IDLE;
                end
                
                ERROR: begin
                    tx_state <= IDLE;
                    tx_underflow <= 1'b1;
                end
            endcase
        end
    end
    
    // Flow control logic
    assign tx_ready = !tx_fifo_full;
    
    // Error handling
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_overflow <= 1'b0;
            tx_underflow <= 1'b0;
        end else begin
            if (rx_valid && !rx_ready) rx_overflow <= 1'b1;
            if (tx_valid && !tx_ready) tx_underflow <= 1'b1;
        end
    end

endmodule
