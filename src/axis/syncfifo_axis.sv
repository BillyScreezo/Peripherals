/***********************************************************************************
 * Copyright (C) 2024 Kirill Turintsev <billiscreezo228@gmail.com>
 * See LICENSE file for licensing details.
 *
 * This file contains sync fifo with axis interface
 *
 ***********************************************************************************/

module syncfifo_axis 
    #(

    type                                    TDATA_TYPE      = logic [31:0],
	int                                     FIFO_DEPTH      = 8,              // must be power of two
	bit                                     ENABLE_TLAST    = 0,
    int                                     TUSER_WIDTH     = 0

    )(

	input  logic                            s_aclk,
	input  logic                            s_aresetn,

	axistream_if.slave                      s_axis,
    axistream_if.master                     m_axis

    );

    localparam int ADDR_WIDTH   = $clog2(FIFO_DEPTH);
	localparam int DATA_WIDTH   = $bits(TDATA_TYPE);
	localparam int BYTES_NUM    = DATA_WIDTH / 8;
	
    typedef logic [ADDR_WIDTH-1:0] addr_t;

    addr_t wraddr, rdaddr;
    addr_t nxtread, dblnext;
    logic write, read;
    logic pre_tvalid;

    logic [$bits(TDATA_TYPE) + ENABLE_TLAST + TUSER_WIDTH + BYTES_NUM-1:0] bram [FIFO_DEPTH];

    assign write = s_axis.tvalid & s_axis.tready;
    assign read  = pre_tvalid & (~m_axis.tvalid | m_axis.tready);

    assign dblnext = wraddr + 2'd2;
	assign nxtread = rdaddr + 1'd1;

    always_ff @(posedge s_aclk) begin
        if (~s_aresetn) begin

            s_axis.tready   <= '1;

            m_axis.tdata    <= '0;
            m_axis.tkeep    <= '1;

            pre_tvalid      <= '0;
            m_axis.tvalid   <= '0;
            
            wraddr          <= '0;
            rdaddr          <= '0;

            m_axis.tuser    <= '0;
            m_axis.tlast    <= '0;

        end else begin
            if (!write && read) begin            // A successful read

                s_axis.tready   <= '1;
                pre_tvalid      <= (nxtread != wraddr);

            end else if (write && !read) begin   // A successful write

                s_axis.tready   <= (dblnext != rdaddr);
                pre_tvalid      <= '1;

            end else begin                       // Idle or Successful read and write

                s_axis.tready   <= s_axis.tready;
                pre_tvalid      <= pre_tvalid;

            end

            if (write) begin

                wraddr          <= (wraddr + 1'b1);
                bram[wraddr]    <= {s_axis.tuser, s_axis.tlast, s_axis.tkeep, s_axis.tdata};

            end

            if (read) begin

                rdaddr          <= (rdaddr + 1'b1);
                {m_axis.tuser, m_axis.tlast, m_axis.tkeep, m_axis.tdata} <= bram[rdaddr];

            end

            m_axis.tvalid       <= pre_tvalid | (m_axis.tvalid & ~m_axis.tready);
        end
    end
    

    assign m_axis.tstrb = '1;
    assign m_axis.tid   = '0;
    assign m_axis.tdest = '0;

endmodule
