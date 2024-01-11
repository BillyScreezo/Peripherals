/***********************************************************************************
 * Copyright (C) 2024 Kirill Turintsev <billiscreezo228@gmail.com>
 * See LICENSE file for licensing details.
 *
 * This file contains Ad7811 SPI controller module
 *
 ***********************************************************************************/

package adc_ad7811_p;
    
    typedef enum logic {
        M_FAST = 1'b0,
        M_SLOW = 1'b1
    } spi_md;

    typedef struct packed {
        spi_md spi_mode;
    } reg_ctrl_t;

    typedef struct packed {
        logic rxstat_empty;
        logic rxstat_full;
        logic txstat_empty;
        logic txstat_full;
    } reg_stat_t;

endpackage 

module adc_ad7811 #(
        int SYS_CLK        = 80,    // MHz   
        int FIFO_DEPTH     = 4, 
        int CLK_PRESCALE   = 4,     // clk->sclk
        int CS_DELAY       = 8,     // = delay_time/clk_period
        int APB_ADDR_WIDTH = 8,
        int APB_DATA_WIDTH = 32
     )(
        input   logic   clk,
        input   logic   rst_n,
        apb_if.slave    apb,
        spi_if.master   spi);
   
// ============================================================================
// ================================ REGISTERS =================================
// ============================================================================

    import adc_ad7811_p::*;
    
    localparam int DATA_WIDTH = 10; 

    typedef logic [APB_ADDR_WIDTH-1:0] addr_t;
    
    logic [DATA_WIDTH-1:0] rxfifo_wr_data;
    logic [DATA_WIDTH-1:0] rxfifo_rd_data;
    logic rxfifo_full;
    logic rxfifo_empty;
    logic txfifo_full;
    logic txfifo_empty;

    typedef enum addr_t {
        C_CTRL_REG  = 8'h00,
        C_STAT_REG  = 8'h04,
        C_TXFIFO    = 8'h08,
        C_RXFIFO    = 8'h0c
    } regs_t;

    reg_ctrl_t r_ctrl;
    reg_stat_t r_stat;

    assign r_stat.rxstat_empty = rxfifo_empty;
    assign r_stat.rxstat_full  = rxfifo_full;

    assign r_stat.txstat_empty = txfifo_empty;
    assign r_stat.txstat_full  = txfifo_full;
    
    addr_t prwaddr;
      
    logic [APB_DATA_WIDTH-1:0] prdata;
    logic prd_en;
    
    logic [APB_DATA_WIDTH-1:0] pwdata;
    logic pwr_en;
    
    apb_slave #(.BUS_ADDR_WIDTH(APB_ADDR_WIDTH),.BUS_DATA_WIDTH(APB_DATA_WIDTH)) apb_slv (.*);

    always_ff @(posedge clk) begin : write_decoder
        if(~rst_n)
            r_ctrl.spi_mode <= M_SLOW;
        
        else if(pwr_en)
            unique case (prwaddr)
                C_CTRL_REG: r_ctrl <= pwdata;           
            endcase
    end

    always_ff @(posedge clk) begin : read_decoder
        if(prd_en)
            unique case (prwaddr)
                C_CTRL_REG: prdata <= r_ctrl;
                C_STAT_REG: prdata <= r_stat;
                C_RXFIFO:
                    if(~rxfifo_empty)
                        prdata <= rxfifo_rd_data;
            endcase
    end

// ============================================================================
// ================================ FIFO'S ====================================
// ============================================================================

    logic txfifo_wr_en;
    logic txfifo_rd_en;
    logic [DATA_WIDTH-1:0] txfifo_wr_data;
    logic [DATA_WIDTH-1:0] txfifo_rd_data;

    assign txfifo_wr_en = pwr_en & (~txfifo_full) & (prwaddr == C_TXFIFO);
    assign txfifo_wr_data = pwdata;

    syncfifo #(.DATA_WIDTH(DATA_WIDTH),.FIFO_DEPTH(FIFO_DEPTH),.FWFT_READ(1))
        tx_fifo (
            .clk(clk), .rst_n(rst_n),
            .wr_en(txfifo_wr_en), .din(txfifo_wr_data), .full(txfifo_full),
            .rd_en(txfifo_rd_en), .dout(txfifo_rd_data), .empty(txfifo_empty)
        );

    logic rxfifo_wr_en;
    logic rxfifo_rd_en;

    assign rxfifo_rd_en = prd_en & apb.penable & (~rxfifo_empty) & (prwaddr == C_RXFIFO);

    syncfifo #(.DATA_WIDTH(DATA_WIDTH),.FIFO_DEPTH(FIFO_DEPTH),.FWFT_READ(1)) 
        rx_fifo (
            .clk(clk), .rst_n(rst_n),
            .wr_en(rxfifo_wr_en), .din(rxfifo_wr_data), .full(rxfifo_full),
            .rd_en(rxfifo_rd_en), .dout(rxfifo_rd_data), .empty(rxfifo_empty)
        );
        
// ============================================================================
// ================================ TIME ======================================
// ============================================================================

    localparam real T_PU  = 1.5; // power_up us
    localparam real T_CNV = 2.3; // convert  us
    
    localparam int PU_SET = $ceil(SYS_CLK * T_PU);
    localparam int CNV_SET = $ceil(SYS_CLK * T_CNV);

    localparam int SET_DELAY = PU_SET + CNV_SET;
    localparam int SET_DELAY_WIDTH = $clog2(SET_DELAY);

    logic [SET_DELAY_WIDTH-1:0] delay_cnt;
    
    localparam int TRANSFER_WIDTH = 13; // data_width+additional_sclk
    localparam int SCLK_CNT = TRANSFER_WIDTH - DATA_WIDTH;

// ============================================================================
// ================================ SPI =======================================
// ============================================================================

    localparam int SCALE_WIDTH   = $clog2(CLK_PRESCALE);
    localparam int COUNTER_WIDTH = $clog2(DATA_WIDTH+2); // ? +2

    typedef enum {
        S_IDLE,
        S_SET_DELAY,
        S_RUN,
        S_CS_DELAY
    } state_t;

    state_t state;
    
    // Counters
    logic [SCALE_WIDTH-1:0] scaler;
    logic [COUNTER_WIDTH-1:0] bit_counter;

    logic spi_negedge; // prescale clk
    logic spi_posedge; // prescale clk

    assign spi_negedge = (scaler == CLK_PRESCALE-1);
    assign spi_posedge = (scaler == CLK_PRESCALE/2-1);

    logic [DATA_WIDTH-1:0] tx_sreg, rx_sreg;

    always_ff @(posedge clk) begin : FSM_AND_SPI
        if(~rst_n) begin
            state           <= S_IDLE;
            spi.cs_n        <= ~r_ctrl.spi_mode;
            spi.sclk        <= '0;


            scaler          <= '0;
            bit_counter     <= '0;
            txfifo_rd_en    <= '0;
            rxfifo_wr_en    <= '0;

            delay_cnt       <= '0;
        end else begin
            unique case(state)
                S_IDLE: begin

                    state       <= S_IDLE;

                    spi.cs_n    <= ~r_ctrl.spi_mode;
                    spi.sclk    <= '0;

                        if((!txfifo_empty) && (!rxfifo_full)) begin

                            state       <= S_SET_DELAY;
                            scaler      <= '0;
                            spi.cs_n    <= r_ctrl.spi_mode;
                            tx_sreg     <= txfifo_rd_data;
                            bit_counter <= '0;

                            delay_cnt   <= '0;
                        end
                end
                S_SET_DELAY: begin

                    state       <= S_SET_DELAY;
                    delay_cnt   <= delay_cnt + 1'b1;

                    if(delay_cnt == 'd1)
                        spi.cs_n    <= ~r_ctrl.spi_mode;
                
                    unique case(r_ctrl.spi_mode)
                        M_FAST: if(delay_cnt == CNV_SET)   state <= S_RUN;  // fast-mode
                        M_SLOW: if(delay_cnt == SET_DELAY) state <= S_RUN;  // slow-mode
                    endcase

                end
                
                S_RUN: begin

                    state  <= S_RUN;

                    scaler <= scaler + 1'b1;

                    if(spi_posedge) begin
                        bit_counter <= bit_counter + 1'b1;
                        
                        if(bit_counter <= DATA_WIDTH - 1) begin
                            spi.dq_o[0] <= tx_sreg[DATA_WIDTH-1];
                            tx_sreg     <= {tx_sreg[DATA_WIDTH-2:0], 1'b0};
                        end          
                    end

                    if(spi_negedge && (bit_counter <= DATA_WIDTH))
                            rx_sreg <= {rx_sreg[DATA_WIDTH-2:0], spi.dq_i[0]};

                    if(spi_negedge || spi_posedge)
                        spi.sclk    <= ~spi.sclk;

                    if((bit_counter == DATA_WIDTH) && spi_negedge) begin
                        state       <= S_CS_DELAY;
                        delay_cnt   <= '0;

                        txfifo_rd_en <= '1;
                        rxfifo_wr_en <= '1;
                    end
                end
                S_CS_DELAY: begin
                
                    txfifo_rd_en    <= '0;
                    rxfifo_wr_en    <= '0;
        
                    state           <= S_CS_DELAY;
                    scaler          <= scaler + 1'b1;
                    
                    if(spi_negedge) begin
                        delay_cnt   <= delay_cnt + 1'b1;
                        
                        if(delay_cnt == (SCLK_CNT - 1 + CS_DELAY / CLK_PRESCALE))
                            state   <= S_IDLE;
                    end
                    
                    if((spi_negedge || spi_posedge) && (delay_cnt <= SCLK_CNT - 1))
                        spi.sclk    <= ~spi.sclk;
                    
                end

            endcase 
        end
    end : FSM_AND_SPI

    assign rxfifo_wr_data = rx_sreg;
    
endmodule : adc_ad7811
