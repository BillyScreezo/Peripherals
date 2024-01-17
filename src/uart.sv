/***********************************************************************************
 * Copyright (C) 2024 Kirill Turintsev <billiscreezo228@gmail.com>
 * See LICENSE file for licensing details.
 *
 * This file contains uart with axis interface module
 *
 ***********************************************************************************/

package uart_p;

	localparam int APB_DBITS  = 8;
	typedef logic [APB_DBITS-1:0] apb_addr_t;

    enum apb_addr_t {
        RX_FIFO = 8'h00,
        TX_FIFO = 8'h04,
        STAT_RG = 8'h08,
        CTRL_RG = 8'h0C
    } ua_regs;

    typedef struct packed {
    	logic RST_TX_FIFO;  // Reset/clear the transmit FIFO
        logic RST_RX_FIFO;  // Reset/clear the receive FIFO
        logic IRQ_EN;       // Enable interrupt for the ...
    } r_ctrl_t;

    typedef struct packed {
    	logic RX_FIFO_VALID;    // Indicates if the receive FIFO has data.
        logic RX_FIFO_FULL;     // Indicates if the receive FIFO is full.
        logic TX_FIFO_EMPTY;    // Indicates if the transmit FIFO is empty.
        logic TX_FIFO_FULL;     // Indicates if the transmit FIFO is full.
        logic IRQ_EN;           // Indicates that interrupts is enabled
        logic OVERRUN_ERR;      // Indicates that a overrun error has occurred after the last time 
                                // the status register was read. Overrun is when a new character 
                                // has been received but the receive FIFO is full. The received 
                                // character is ignored and not written into the receive FIFO. This 
                                // bit is cleared when the ...
        logic FRAME_ERR;        // Indicates that a frame error has occurred after the last time the 
                                // status register was read. Frame error is defined as detection of 
                                // a stop bit with the value 0. The receive character is ignored and 
                                // not written to the receive FIFO.
        logic PARITY_ERR;       // Indicates that a parity error has occurred after the last time the 
                                //  status register was read. If the UART is configured without any 
                                //  parity handling, this bit is always 0.
                                //  The received character is written into the receive FIFO.
                                //  This bit is cleared when the
    } r_sts_t;

endpackage : uart_p

module uart #(
    int     SYS_CLK     = 100,      // CLK frequency in MHz
    int     BAUDRATE    = 9600,     // UART rx/tx baudrate
    int     FIFO_DEPTH  = 1024,     // rx/tx fifo depth
    int     DBITS       = 8,        // Data bits in UART transfer 
    string  PARITY      = "Odd",    // Odd or Even parity bits
    int     N_STOP_BITS = 1         // Number of stop bits
)(
    input   logic                               clk,
    input   logic                               rst_n,

    input   logic                               rx,
    output  logic                               tx,

    axistream_if.master                         rx_axis,
    axistream_if.slave                          tx_axis,

    output  logic                               irq,

    output  logic [DBITS-1:0]                   debug_rx
);

// ================================================================================================
// ============================================== DEFINES
// ================================================================================================

    typedef logic [DBITS-1:0] data_t;

    localparam int BAUDRATE_SCALE_VALUE = int'($ceil(SYS_CLK * 1e6 / BAUDRATE));
    logic [$clog2(BAUDRATE_SCALE_VALUE)-1:0] rx_baud_scaler, tx_baud_scaler;
    logic rx_baud_scaler_rst, rx_baud_period_start, rx_baud_period_end;
    logic tx_baud_scaler_rst, tx_baud_period_start, tx_baud_period_end;

    localparam RX_IN_FILTER_SIZE = 32;
    logic [RX_IN_FILTER_SIZE-1:0] rx_in_filter;

    logic [$clog2(DBITS)-1:0] rx_dbits_cnt, tx_dbits_cnt;
    data_t rx_shift_rg, tx_shift_rg;

    logic [$clog2(N_STOP_BITS):0] rx_sbits_cnt, tx_sbits_cnt;
    logic rx_parity_ok;
    logic tx_parity_bit;

    axistream_if #(.DWIDTH(DBITS)) axis_rx_fifo(clk);
    axistream_if #(.DWIDTH(DBITS)) axis_tx_fifo(clk);

    typedef enum {
        RS_IDLE,
        RS_START,
        RS_DATA,
        RS_PARITY,
        RS_STOP
    } rx_state_t;

    rx_state_t rx_state;

    typedef enum {
        TS_IDLE,
        TS_START,
        TS_DATA,
        TS_PARITY,
        TS_STOP
    } tx_state_t;

    tx_state_t tx_state;

// ================================================================================================
// ============================================== BAUD SCALERS
// ================================================================================================

    assign rx_baud_period_start    = (rx_baud_scaler == '0);
    assign rx_baud_period_end      = (rx_baud_scaler == BAUDRATE_SCALE_VALUE);
    assign rx_baud_scaler_rst      = (rx_state == RS_IDLE) & (rx_in_filter == '0);

    always_ff @(posedge clk) begin : rx_baudrate_generator
        if(!rst_n)
            rx_baud_scaler <= '0;
        else begin
            if(rx_baud_period_end || rx_baud_scaler_rst)
                rx_baud_scaler <= '0;
            else
                rx_baud_scaler <= rx_baud_scaler + 1'b1;
        end
    end

    assign tx_baud_period_start    = (tx_baud_scaler == '0);
    assign tx_baud_period_end      = (tx_baud_scaler == BAUDRATE_SCALE_VALUE);
    assign tx_baud_scaler_rst      = (tx_state == TS_IDLE) & (axis_tx_fifo.tvalid & axis_tx_fifo.tready);

    always_ff @(posedge clk) begin : tx_baudrate_generator
        if(!rst_n)
            tx_baud_scaler <= '0;
        else begin
            if(tx_baud_period_end || tx_baud_scaler_rst)
                tx_baud_scaler <= '0;
            else
                tx_baud_scaler <= tx_baud_scaler + 1'b1;
        end
    end

// ================================================================================================
// ============================================== RX FSM
// ================================================================================================

    always_ff @(posedge clk)
        rx_in_filter <= {rx_in_filter[RX_IN_FILTER_SIZE-2:0], rx};

    generate
        if(PARITY == "Odd") begin
            always_ff @(posedge clk) begin
                if(rx_baud_period_start && (rx_state == RS_PARITY))
                    rx_parity_ok <= (rx_in_filter == '0) ? ^rx_shift_rg : ~^rx_shift_rg;
            end
        end else if(PARITY == "Even") begin
            always_ff @(posedge clk) begin
                if(rx_baud_period_start && (rx_state == RS_PARITY))
                    rx_parity_ok <= (rx_in_filter == '0) ? ~^rx_shift_rg : ^rx_shift_rg;
            end
        end else begin
            assign rx_parity_ok = '0;
        end
    endgenerate

    always_ff @(posedge clk)
        if(!rst_n) begin
            rx_state        <= RS_IDLE;
            rx_dbits_cnt    <= '0;
            rx_sbits_cnt    <= '0;
        end else if (rx_baud_period_start)
            case(rx_state)
                RS_IDLE: begin

                    rx_dbits_cnt <= '0;
                    rx_sbits_cnt <= '0;

                    if(rx_in_filter == '0) // all zeros is a start bit
                        rx_state <= RS_START;
                end

                RS_START: begin
                    rx_state <= RS_DATA;
                end

                RS_DATA: begin
                    rx_shift_rg     <= (rx_in_filter == '0) ? {1'b0, rx_shift_rg[DBITS-1:1]} : {1'b1, rx_shift_rg[DBITS-1:1]};
                    rx_dbits_cnt    <= rx_dbits_cnt + 1'b1;

                    if(rx_dbits_cnt == (DBITS - 1))
                        rx_state <= RS_PARITY;
                end

                RS_PARITY: begin
                    rx_state <= RS_STOP;
                end

                RS_STOP: begin

                    rx_sbits_cnt <= rx_sbits_cnt + 1'b1;

                    if(rx_sbits_cnt == (N_STOP_BITS - 1))
                        rx_state <= RS_IDLE;
                end
            endcase

    assign axis_rx_fifo.tdata  = rx_shift_rg;
    assign axis_rx_fifo.tvalid = rx_baud_period_start & (rx_state == RS_STOP) & (rx_sbits_cnt == (N_STOP_BITS - 1));

    assign axis_rx_fifo.tlast = '1;
    assign axis_rx_fifo.tkeep = '1;
    assign axis_rx_fifo.tstrb = '1;
    assign axis_rx_fifo.tuser = '0;
    assign axis_rx_fifo.tid   = '0;
    assign axis_rx_fifo.tdest = '0;

    syncfifo_axis #(.TDATA_TYPE(data_t), .FIFO_DEPTH(FIFO_DEPTH), .ENABLE_TLAST(0), .TUSER_WIDTH(0))
        rx_fifo (.s_aclk(clk),           .s_aresetn(rst_n),
                 .s_axis(axis_rx_fifo),  .m_axis(rx_axis));

// ================================================================================================
// ============================================== TX FSM
// ================================================================================================

    generate
        if(PARITY == "Odd") begin
            always_ff @(posedge clk) begin
                if(tx_baud_period_start && (tx_state == TS_START))
                    tx_parity_bit <= ~^tx_shift_rg;
            end
        end else if(PARITY == "Even") begin
            always_ff @(posedge clk) begin
                if(tx_baud_period_start && (tx_state == TS_START))
                    tx_parity_bit <= ^tx_shift_rg;
            end
        end else begin
            assign tx_parity_bit = '0;
        end
    endgenerate

    always_ff @(posedge clk)
        if(!rst_n) begin
            tx_state            <= TS_IDLE;
            tx_dbits_cnt        <= '0;
            tx_sbits_cnt        <= '0;
            axis_tx_fifo.tready <= '0;

            tx                  <= '1;
        end else
            case(tx_state)
                TS_IDLE: begin

                    tx_dbits_cnt        <= '0;
                    tx_sbits_cnt        <= '0;
                    axis_tx_fifo.tready <= '1;

                    if(axis_tx_fifo.tready && axis_tx_fifo.tvalid) begin
                        tx_state            <= TS_START;
                        axis_tx_fifo.tready <= '0;
                        tx_shift_rg         <= axis_tx_fifo.tdata;
                    end
                end

                TS_START: begin
                    if(tx_baud_period_start) begin
                        tx_state    <= TS_DATA;
                        tx          <= '0;
                    end
                end

                TS_DATA: begin
                    if(tx_baud_period_start) begin
                        tx_shift_rg <= tx_shift_rg >> 1;
                        tx          <= tx_shift_rg[0];

                        tx_dbits_cnt <= tx_dbits_cnt + 1'b1;

                        if(tx_dbits_cnt == (DBITS - 1))
                            tx_state <= TS_PARITY;
                    end
                end

                TS_PARITY: begin
                    if(tx_baud_period_start) begin
                        tx_state    <= TS_STOP;
                        tx          <= tx_parity_bit;
                    end
                end

                TS_STOP: begin
                    if(tx_baud_period_start) begin
                        tx <= '1;

                        tx_sbits_cnt <= tx_sbits_cnt + 1'b1;

                        if(tx_sbits_cnt == (N_STOP_BITS))
                            tx_state <= TS_IDLE;
                    end
                end
            endcase

    syncfifo_axis #(.TDATA_TYPE(data_t), .FIFO_DEPTH(FIFO_DEPTH), .ENABLE_TLAST(0), .TUSER_WIDTH(0))
        tx_fifo (.s_aclk(clk),      .s_aresetn(rst_n),
                 .s_axis(tx_axis),  .m_axis(axis_tx_fifo));

// ================================================================================================
// ============================================== IRQ
// ================================================================================================

    assign irq  = tx_baud_period_start & (tx_state == TS_STOP) & (tx_sbits_cnt == (N_STOP_BITS));

    assign debug_rx = rx_shift_rg;

endmodule : uart