/***********************************************************************************
 * Copyright (C) 2024 Kirill Turintsev <billiscreezo228@gmail.com>
 * See LICENSE file for licensing details.
 *
 * This file contains Ad53x8 SPI controller module
 *
 ***********************************************************************************/

package dac_ad53x8_p;
    
    typedef enum logic {
        M_LOAD  = 1'b0,
        M_STORE = 1'b1
    } ldac_md;

    typedef struct packed {
        ldac_md ldac;
    } reg_ctrl_t;

    typedef struct packed {
        logic txstat_empty;
        logic txstat_full;
    } reg_stat_t;

endpackage

module dac_ad53x8 #(
        int DATA_WIDTH     = 16,
        int FIFO_DEPTH     = 4,
        int CLK_PRESCALE   = 4,
        int CS_DELAY       = 5,
        int APB_DATA_WIDTH = 32,
        int APB_ADDR_WIDTH = 8
    )(
        input   logic   clk,
        input   logic   rst_n,
        apb_if.slave    apb,
        spi_if.master   spi,
        output  logic   ldac_o
    );
    
// ============================================================================
// ================================ REGISTERS =================================
// ============================================================================
    import dac_ad53x8_p::*;

    typedef logic [APB_ADDR_WIDTH-1:0] addr_t;
    
    logic txfifo_full;
    logic txfifo_empty;

    typedef enum addr_t {
        C_CTRL_REG  = 8'h00,
        C_STAT_REG  = 8'h04,
        C_TXFIFO    = 8'h08
    } regs_t;

    reg_ctrl_t r_ctrl;
    reg_stat_t r_stat;
    
    assign ldac_o = r_ctrl.ldac;

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
            r_ctrl.ldac <= M_STORE;
        else if(pwr_en)
            unique case (prwaddr)
                C_CTRL_REG: r_ctrl  <= pwdata;
            endcase
    end

    always_ff @(posedge clk) begin : read_decoder
        if(prd_en)
            unique case (prwaddr)
                C_CTRL_REG: prdata  <= r_ctrl;
                C_STAT_REG: prdata  <= r_stat;
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
    

// ============================================================================
// ================================ SPI =======================================
// ============================================================================

    localparam int SCALE_WIDTH   = $clog2(CLK_PRESCALE);
    localparam int COUNTER_WIDTH = $clog2(DATA_WIDTH + 2); // ? +2

    // FSM_state
    typedef enum {
        S_IDLE,
        S_RUN,
        S_DELAY
    } state_t;

    state_t state;
    
    logic [SCALE_WIDTH-1:0]   scaler;
    logic [COUNTER_WIDTH-1:0] bit_counter;

    localparam int CS_DELAY_WIDTH = $clog2(CS_DELAY);

    logic [CS_DELAY_WIDTH-1:0] delay_cnt;

    logic [DATA_WIDTH-1:0] tx_sreg;
    
    // Counters
    logic spi_negedge;
    logic spi_posedge;

    assign spi_negedge = (scaler == CLK_PRESCALE-1);
    assign spi_posedge = (scaler == CLK_PRESCALE/2-1);

    always_ff @(posedge clk) begin : FSM_AND_SPI
        if(~rst_n) begin
            state           <= S_IDLE;
            spi.cs_n        <= '1;
            spi.sclk        <= '0;

            scaler          <= '0;
            bit_counter     <= '0;
            delay_cnt       <= '0;
            txfifo_rd_en    <= '0;
        end else begin
            unique case(state)
                S_IDLE: begin

                    state       <= S_IDLE;

                    spi.cs_n    <= '1;
                    spi.sclk    <= '0;

                        if(!txfifo_empty) begin
                            state       <= S_RUN;
                            scaler      <= '0;
                            spi.cs_n    <= '0;
                            tx_sreg     <= txfifo_rd_data;
                            bit_counter <= '0;
                        end
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

                    if(spi_negedge || spi_posedge)
                        spi.sclk    <= ~spi.sclk;

                    if((bit_counter == DATA_WIDTH) && spi_negedge) begin
                        state           <= S_DELAY;
                        delay_cnt       <= '0;
                        txfifo_rd_en    <= '1;
                    end
                end
                S_DELAY: begin
                    state           <= S_DELAY;
                    spi.cs_n        <= '1;
                    txfifo_rd_en    <= '0;
                   
                    delay_cnt       <= delay_cnt + 1'b1;
                    
                    if(delay_cnt == CS_DELAY)
                        state       <= S_IDLE;
                end
            endcase 
        end
    end : FSM_AND_SPI
// FSM BLOCK END   

endmodule : dac_ad53x8