/***********************************************************************************
 * Copyright (C) 2024 Kirill Turintsev <billiscreezo228@gmail.com>
 * See LICENSE file for licensing details.
 *
 * This file contains APB slave bus converter module
 *
 ***********************************************************************************/

module apb_slave 
    #(
        int                                 BUS_ADDR_WIDTH = 8, 
        int                                 BUS_DATA_WIDTH = 32
        
    )(
        apb_if.slave                        apb,
        
        output  logic [BUS_ADDR_WIDTH-1:0]  prwaddr,
        
        input   logic [BUS_DATA_WIDTH-1:0]  prdata,
        output  logic                       prd_en,
        
        output  logic [BUS_DATA_WIDTH-1:0]  pwdata,
        output  logic                       pwr_en
    );
    
    assign prwaddr = {apb.paddr[BUS_ADDR_WIDTH-1:2], 2'b00};
    
    assign apb.prdata = prdata;
    assign prd_en = apb.psel & ~apb.pwrite; // read from slave
    
    assign pwdata = apb.pwdata;
    assign pwr_en = apb.psel & apb.penable & apb.pwrite; // write to slave
    
endmodule
