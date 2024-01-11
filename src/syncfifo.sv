/***********************************************************************************
 * Copyright (C) 2024 Kirill Turintsev <billiscreezo228@gmail.com>
 * See LICENSE file for licensing details.
 *
 * This file contains syncfifo
 *
 ***********************************************************************************/

module syncfifo 
    #(
        parameter DATA_WIDTH = 32,
        parameter FIFO_DEPTH = 8,
        parameter FWFT_READ = 0		// First-word fall-through
    )(
        input clk,
        input rst_n,
        
        input wr_en,
        input [DATA_WIDTH-1:0] din,
        output logic full = 1'b1,
        
        input rd_en,
        output logic [DATA_WIDTH-1:0] dout = {DATA_WIDTH{1'b0}},
        output logic empty = 1'b1
    );

	localparam ADDR_WIDTH = $clog2(FIFO_DEPTH);
	
	logic [ADDR_WIDTH:0] wptr = 0;
	wire [ADDR_WIDTH:0] wptr_next = wptr + (wr_en & ~full);

	logic [ADDR_WIDTH:0] rptr = 0;
	wire [ADDR_WIDTH:0] rptr_next = rptr + (rd_en & ~empty);

	always_ff @(posedge clk) begin : fifo_flag_op
		if (!rst_n) begin
			wptr <= {(ADDR_WIDTH+1){1'b0}};
			rptr <= {(ADDR_WIDTH+1){1'b0}};
			full <= 1'b1;
			empty <= 1'b1;
		end else begin
			wptr <= wptr_next;
			rptr <= rptr_next;

			full <= (wptr_next == {~rptr_next[ADDR_WIDTH], rptr_next[ADDR_WIDTH-1:0]});

			if (FWFT_READ == 0) begin
				empty <= (rptr_next == wptr_next);
			end else begin
				empty <= (rptr_next == wptr);
			end
		end
	end : fifo_flag_op
	

	logic [DATA_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];

	wire [ADDR_WIDTH-1:0] waddr, raddr;
	
	assign waddr = wptr[ADDR_WIDTH-1:0];
	assign raddr = (FWFT_READ == 0) ?
		rptr[ADDR_WIDTH-1:0] :
		rptr_next[ADDR_WIDTH-1:0];

	always_ff @(posedge clk) begin : fifo_wr_op
		if (wr_en & ~full)
			fifo_mem[waddr] <= din;
	    else
	        fifo_mem[waddr] <= fifo_mem[waddr];
    end : fifo_wr_op
    
    
    always_ff @(posedge clk) begin : fifo_rd_op
		if (!rst_n)
			dout <= {DATA_WIDTH{1'b0}};
		else if (FWFT_READ == 0) begin
			if (rd_en & ~empty)
				dout <= fifo_mem[raddr];
		end else begin
			dout <= fifo_mem[raddr];
		end
	end : fifo_rd_op

endmodule
