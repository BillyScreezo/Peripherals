/***********************************************************************************
 * Copyright (C) 2024 Kirill Turintsev <billiscreezo228@gmail.com>
 * See LICENSE file for licensing details.
 *
 * This file contains Ad7811 tb
 *
 ***********************************************************************************/

`timescale 1ns / 1ps

program automatic adc_ad7811_test();

    import adc_ad7811_p::*;

    localparam DATA_WIDTH = 10;

    typedef virtual apb_if.master_tb vapb_if;
    typedef virtual spi_if.slave vspi_if;

    typedef class Transaction;
    typedef class APBDriver;
//    typedef class APBDriver_cbs;
//    typedef class APBDriver_cbs_delay;
    typedef class Generator;
    typedef class Scoreboard;
    typedef class Monitor;
    typedef class Monitor_cbs;
    typedef class Monitor_cbs_scoreboard;
    typedef class Configuration;
    typedef class Agent;

// =======================================================
// ======================= Environment ===================
// =======================================================
    class Environment;

        Generator gen;
        mailbox gen2agt;
        APBDriver drv;
        Monitor mon;
        Scoreboard scb;
        Configuration cfg;
        Agent agt;
        // Coverage
        vapb_if apb;
        vspi_if spi;

        function new(input vapb_if apb, vspi_if spi);
            this.apb = apb;
            this.spi = spi;
            
            cfg = new(10);

        endfunction : new

        function void build();

        gen2agt = new(1);
        gen = new(gen2agt);
        drv = new(apb);
        scb = new(cfg);
        agt = new(scb, drv, gen2agt);
        mon = new(spi);
        
        
//        begin : connect_delay_to_driver
//            int max_delay = 5;
//            APBDriver_cbs_delay dcd = new(max_delay);
//            drv.cbsq.push_back(dcd);
//        end

        begin : connect_monitor_to_scoreboard
            Monitor_cbs_scoreboard mcs = new(scb);
            mon.cbsq.push_back(mcs);
        end

         // Connect coverage to monitor with callbacks
         // begin
         // Cov_Monitor_cbs smc = new(cov);
         // foreach (mon[i]) 
         // mon[i].cbsq.push_back(smc);
         // end

        endfunction : build

        task run();
        
            fork : runs
                
                gen.run();
                agt.run();
                mon.run();
                
            join_any : runs
 
            $display("Ends run task");

        endtask : run

        function void wrap_up();
            scb.wrap_up();
        endfunction : wrap_up



    endclass : Environment
    
// =======================================================
// ===================== Transaction =====================
// =======================================================
class Transaction #(parameter DATA_WIDTH = 10);
    rand bit [DATA_WIDTH-1:0] data;
    rand bit [DATA_WIDTH-1:0] ctrl_word;
    
    function Transaction copy();
        copy = new();
        copy.data = data;
        copy.ctrl_word = ctrl_word;
    endfunction : copy
    
endclass

// =======================================================
// ======================= Generator =====================
// =======================================================
    class Generator #(type BTYPE = Transaction);
        BTYPE blueprint;
        mailbox gen2agt;

        function new(input mailbox gen2agt);
            this.gen2agt = gen2agt;
            blueprint = new();
        endfunction : new

        task run();
             BTYPE tr;
             forever begin
                 assert(blueprint.randomize());
                 tr = blueprint.copy();
                 gen2agt.put(tr);
             end    

        endtask : run
    endclass : Generator
    
// =======================================================
// ======================= Agent =========================
// =======================================================


    class Agent;
        Scoreboard scb;
        APBDriver drv;
        mailbox gen2agt;
        
        function new(input Scoreboard scb, input APBDriver drv, input mailbox gen2agt);
            this.scb = scb;
            this.gen2agt = gen2agt;
            this.drv = drv;
        endfunction : new
        
        task run();
        
            Transaction t, t_tmp;
            
            bit [31:0] paddr;
            bit [31:0] pwdata;
            logic [31:0] prdata;
            reg_stat_t rstat;
            
            bit config_transfer = 1'b1;

            forever begin
            
                gen2agt.get(t);
                scb.save_expected(t);
                
                paddr = C_STAT_REG;
                do begin
                    drv.read(paddr,prdata);
                    rstat = prdata;
                end while(rstat.txstat_full==1'b1); 
                
                paddr    = C_TXFIFO;
                pwdata   = {22'b0,t.ctrl_word};            
                drv.write(paddr,pwdata);
                
                paddr    = C_STAT_REG;
                do begin
                    drv.read(paddr,prdata);
                    rstat = prdata;
                end while(rstat.rxstat_empty==1'b1);
                
                paddr    = C_RXFIFO;
                drv.read(paddr,prdata);
                
                if(!config_transfer)
                    scb.check_miso(prdata[DATA_WIDTH-1:0],t_tmp);
                else
                    config_transfer = 1'b0;
                    
                t_tmp = t;

            end
        
        endtask : run

    endclass : Agent
    

// =======================================================
// ======================= Driver ========================
// =======================================================

    class APBDriver;
        vapb_if apb;

        function new (input vapb_if apb);
            this.apb = apb;
        endfunction : new
        
        task read(input bit [31:0] addr, output logic [31:0] rdata);
            @(apb.cbm);
            apb.cbm.psel    <= 1'b1;
            apb.cbm.paddr   <= addr;
            apb.cbm.pwrite  <= 1'b0;
//            apb.cbm.pwdata  <= tr.pwdata;
            @(apb.cbm);
            apb.cbm.penable <= 1'b1;
            @(apb.cbm);
            //$display("Read time: @%0t",$time);
            rdata       = apb.cbm.prdata;
            apb.cbm.penable <= 1'b0;
        endtask : read

        task write(input bit [31:0] addr, input bit [31:0] wdata);
            @(apb.cbm);
            apb.cbm.psel    <= 1'b1;
            apb.cbm.paddr   <= addr;
            apb.cbm.pwrite  <= 1'b1;
            apb.cbm.pwdata  <= wdata;
            @(apb.cbm);
            apb.cbm.penable <= 1'b1;
            @(apb.cbm);
            apb.cbm.penable <= 1'b0;
        endtask : write

    endclass : APBDriver

//    virtual class APBDriver_cbs;
    
//        virtual task pre_tx(ref APBTransaction tr, ref int delay);
//        endtask
        
//        virtual task post_tx(ref APBTransaction tr);
//        endtask

//    endclass : APBDriver_cbs
    
//    class APBDriver_cbs_delay extends APBDriver_cbs;
    
//        int max_delay;
//        int delay;
        
//        function new(input int max_delay);
//            this.max_delay = max_delay;
//        endfunction : new
    
//        virtual task pre_tx(ref APBTransaction tr, ref int delay);
//            delay = $urandom_range(0,max_delay);
//            delay = 0;
//            $display("Delay for tr: %d",delay);
//            tr.display();
//        endtask

//    endclass : APBDriver_cbs_delay

// =======================================================
// ======================= Monitor =======================
// =======================================================
    class Monitor;
        vspi_if spi;
        Monitor_cbs cbsq[$];

        function new(input vspi_if spi);
            this.spi = spi;
        endfunction : new

        task run();

            Transaction t;
            
            bit [9:0] data_miso;
            logic [9:0] data_mosi = 10'bx;

            forever begin

                recieve(data_mosi,data_miso);
                
                foreach (cbsq[i]) cbsq[i].pre_rx(t);

                foreach (cbsq[i]) cbsq[i].post_rx(data_mosi,t);
                
                data_miso = t.data;

            end

        endtask : run

        task recieve(output logic [DATA_WIDTH-1:0] data_mosi, input bit [DATA_WIDTH-1:0] data_miso);

            @(negedge spi.cs_n)

            for(int i = (DATA_WIDTH-1); i >= 0; i--) begin
                @(posedge spi.sclk);
                spi.miso = data_miso[i];
                
                @(negedge spi.sclk);
                data_mosi[i] = spi.mosi_o;
            end

        endtask : recieve


    endclass : Monitor


    virtual class Monitor_cbs;
    
        virtual task pre_rx(output Transaction t);
        endtask
        
        virtual task post_rx(input logic [DATA_WIDTH-1:0] data_mosi, input Transaction t);
        endtask
    endclass

    class Monitor_cbs_scoreboard extends Monitor_cbs;
        Scoreboard scb;

        function new(input Scoreboard scb);
            this.scb = scb;
        endfunction : new
        
        virtual task pre_rx(output Transaction t);
            t = scb.queue_pop_front();
        endtask

        virtual task post_rx(input logic [DATA_WIDTH-1:0] data_mosi, input Transaction t);
            scb.check_mosi(data_mosi,t);
        endtask : post_rx

    endclass : Monitor_cbs_scoreboard

    // class Monitor_cbs_coverage extends Monitor_cbs;
    //     Coverage cov;

    //     function new(input Coverage cov);
    //         this.cov = cov;
    //     endfunction : new

    //     virtual task post_rx();
    //         cov.sample();
    //     endtask : post_rx

    // endclass : Monitor_cbs_coverage
  
// =======================================================
// ======================= Scoreboard ====================
// =======================================================

    class Scoreboard;
         Transaction queue[$];
         Configuration cfg;
         int nPackGet;  

         function new(ref Configuration cfg);
            this.cfg = cfg;
            nPackGet = 0;
         endfunction : new
         
         function void save_expected(input Transaction t);
             queue.push_back(t);
         endfunction : save_expected
         
         function Transaction queue_pop_front();
            queue_pop_front = queue.pop_front();
         endfunction
         
         function void check_mosi(input logic [DATA_WIDTH-1:0] data_mosi, input Transaction t);
         
         $display("@%0t: Channel get from SPI: %d, Channel get from queue: %d",$time,data_mosi[7:6],t.ctrl_word[7:6]);
         
            if(data_mosi[7:6]!=t.ctrl_word[7:6]) begin
                $display("BAD SPI transfer(MOSI)");
                ++cfg.nErrors;
            end else
                $display("GOOD SPI transfer(MOSI)");
            
         endfunction
         
         function void check_miso(input bit [DATA_WIDTH-1:0] data_send, input Transaction t);
         
         $display("@%0t: Data get from SPI: %d, Data get from queue: %d",$time,t.data,data_send);
         
            if(data_send!=t.data) begin
                $display("BAD SPI transfer(MISO)");
                ++cfg.nErrors;
            end else
                $display("GOOD SPI transfer(MISO)");
            
            ++nPackGet;
            if(cfg.nPack==nPackGet)
                    this.wrap_up();
                    
         endfunction

         
//         function void save_data(input logic [DATA_WIDTH-1:0] data_mosi, input bit [DATA_WIDTH-1:0] data_miso);
//            this.data_mosi.push_back(data_mosi);
//            this.data_miso.push_back(data_miso);
//         endfunction
         
//         task check_actual(input event done);
         
//             APBTransaction tr_mosi, tr_miso;
//             logic [DATA_WIDTH-1:0] data_mosi_t;
//             bit   [DATA_WIDTH-1:0] data_miso_t;
             
//             wait (done.triggered());
             
//             ++nPackGet;
             
//             // 
//             tr_mosi = scb.pop_front();
             
//             do
//             tr_miso = scb.pop_front();
//             while(tr_miso==null);
             
//             data_mosi_t = data_mosi.pop_front();
//             data_miso_t = data_miso.pop_front();
             
             
//             $display("Transaction check (in queue):");
    
//             $display("Transaction data MOSI: %h",tr_mosi.pwdata[DATA_WIDTH-1:0]);
//             $display("Data get : %h",data_mosi_t);
    
//             $display("SPI data MISO: %h", data_miso_t);
//             $display("Data get : %h",tr_miso.prdata[DATA_WIDTH-1:0]);
             
//                if((tr_mosi.pwdata[DATA_WIDTH-1:0] != data_mosi_t)||(data_miso_t != tr_miso.prdata[DATA_WIDTH-1:0])) begin
//                    ++cfg.nErrors;
//                    $display("This transaction is BAD");
//                end else
//                    $display("This transaction is GOOD");
                    
//                    if(cfg.nPack==nPackGet)
//                        this.wrap_up();
             
//         endtask : check_actual

         function void wrap_up();
            $display("Trans tx: %d, Trans rx : %d",cfg.nPack,nPackGet);
            $display("Num of Errors: %d",cfg.nErrors);
            $display("Check result: %d",(cfg.nErrors==0));
            $finish;
         endfunction : wrap_up
         
    endclass : Scoreboard

    
// =======================================================
// ==================== Configuration ====================
// =======================================================

    class Configuration;
        static int nErrors, nWarnings;
        static int nPack;

        function new(input int nPack);
            nErrors = 0;
            nWarnings = 0;
            this.nPack = nPack;
        endfunction : new

        function void display();
            $display("Config report: Errors: %d, Warnings: %d", nErrors, nWarnings);
        endfunction : display

    endclass : Configuration

    vapb_if apb;
    vspi_if spi;

    Environment env;

    initial begin
    
        apb = adc_ad7811_tb.apb;
        spi = adc_ad7811_tb.spi;
    
        env = new(apb,spi);
        env.build();
        env.run();
        env.wrap_up();
    end
    
endprogram : adc_ad7811_test

module adc_ad7811_tb();
    
    bit clk;
    bit rst_n;
    
    localparam real CLK_PERIOD = 12.5;

    apb_if apb(clk);
    spi_if spi();
    
   adc_ad7811_test t();
    
    adc_ad7811 DUT
    ( .clk(clk), .rst_n(rst_n),
      .spi(spi), .apb(apb)
    );
    
    initial begin
        rst_n = 1'b0;
        #10;
        rst_n = 1'b1;
    end
    
    initial begin
        clk = 0;
        forever begin
            #(CLK_PERIOD/2)
                clk=~clk;
        end
    end

endmodule