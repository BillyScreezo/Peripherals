/***********************************************************************************
 * Copyright (C) 2024 Kirill Turintsev <billiscreezo228@gmail.com>
 * See LICENSE file for licensing details.
 *
 * This file contains APB interface
 *
 ***********************************************************************************/

interface spi_if #(DWIDTH = 4) ();

	logic cs_n;
	logic sclk;
	logic [DWIDTH-1:0] dq_i;
	logic [DWIDTH-1:0] dq_o;
	logic [DWIDTH-1:0] dq_oen;
	
//	clocking cbs @(negedge sclk);
//	   input cs_n, mosi_oen, mosi_o;
//	   output mosi_i, miso;
//	endclocking

	modport master 
	(
		output cs_n,
		output sclk,
		input  dq_i,
		output dq_o,
		output dq_oen
	);
	
//	modport slave(clocking cbs);
	
	modport slave
	(
		input  cs_n,
		input  sclk,
		output dq_i,
		input  dq_o,
		input  dq_oen
	);

endinterface