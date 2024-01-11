/***********************************************************************************
 * Copyright (C) 2024 Kirill Turintsev <billiscreezo228@gmail.com>
 * See LICENSE file for licensing details.
 *
 * This file contains APB interface
 *
 ***********************************************************************************/

interface apb_if (input clk);  

// APB master outputs
	logic 			psel; 	    // slave select (0..NAPBSLV-1)
	logic 			penable;	// strobe
	logic [31:0] 	paddr;		// address bus (byte)
	logic 			pwrite;		// write enable (W/R_n)
	logic [31:0] 	pwdata;		// write data bus

// APB slave outputs
	logic [31:0]	prdata;		// read data bus

    clocking cbm @(posedge clk);
        output psel,penable,paddr,pwrite,pwdata;
        input prdata;
    endclocking
    
    clocking cbs @(posedge clk);
        input psel,penable,paddr,pwrite,pwdata;
        output prdata;
    endclocking
    
    modport master_tb (clocking cbm);
    modport slave_tb (clocking cbs);

	modport slave 
	(
		input psel,
		input penable,
		input paddr,
		input pwrite,
		input pwdata,

		output prdata
	);

		modport master
	(
		output psel,
		output penable,
		output paddr,
		output pwrite,
		output pwdata,

		input prdata
	);

endinterface
