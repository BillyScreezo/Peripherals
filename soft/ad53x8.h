/***********************************************************************************
 * Copyright (C) 2024 Kirill Turintsev <billiscreezo228@gmail.com>
 * See LICENSE file for licensing details.
 *
 * This file contains сlass for interacting with the Ad53x8 module and the corresponding chip
 *
 ***********************************************************************************/

#ifndef AD53X8_H
#define AD53X8_H

#include "spi.h"
#include <cstdint>

// Class for interacting with the Ad53x8 module and the corresponding chip
class Ad53x8 final : private Spi {

private:

    // Register space of the module for interaction with ad53x8
    enum Reg : uintptr_t {
        CTRL    = 0x0,          	// Control register ad53x8      (r/w)
        STAT    = 0x4,          	// ad53x8 status register       (r only)
        TX_FIFO = 0x8,          	// Write data to transfer FIFO  (w only)
    };

    // Fields of the SPI interface controller control register
    enum R_ctrl : uint32_t {
        SPI_LOAD  = 0x0,         	// Rewriting DAC registers to issue new voltage outputs across channels
        SPI_STORE = 0x1          	// Disable overwriting of DAC registers, output channels will not change their values
    };

    // SPI Interface Controller Status Register Fields
    enum R_stat : uint32_t {
        TX_FULL     = 0b01,   		// TX fifo is full
        TX_EMPTY    = 0b10,			// TX fifo is empty
    };

    // AD7811 Data Register Fields
    enum Ad_data : uint32_t {
        CH_SH     = 12,				// Chanel shift
        DT_SH     = 2,				// Data shift
        CH_MSK    = 0x7 	<< 12,	// Chanel mask
        DT_MSK    = 0x3FF 	<< 2,	// Data mask
    };

    // Command word fields
    enum Ad_cmd : uint32_t {
    	WR_CMD 				=	(1 	<< 15),	 	// WR cmd mode 

		CTRL_GBV 			=	(0x0 << 13),	// Setting Gain, Buf, Vdd
		CTRL_LDAC 			=	(0x1 << 13),	// Setting LDAC mode
		CTRL_PD 			=	(0x2 << 13),	// Setting power down mode
		CTRL_RST 			=	(0x3 << 13),	// Reset setting

		GBV_VDD_AD 			=  	(1 << 0),		// A-D channels reference to Vdd 
		GBV_VDD_EH			=	(1 << 1),		// E-H channels reference to Vdd 
		GBV_BUF_AD			=	(1 << 2),		// A-D channels buffered reference
		GBV_BUF_EH			=	(1 << 3),		// E-H channels buffered reference
		GBV_GAIN_0_VR_AD	=	(0 << 4),		// A-D output range of 0 V to VREF
		GBV_GAIN_0_VR_EH	=	(0 << 5),		// E-H output range of 0 V to VREF
		GBV_GAIN_0_2VR_AD	=	(1 << 4),		// A-D output range of 0 V to 2VREF
		GBV_GAIN_0_2VR_EH	=	(1 << 5),		// E-H output range of 0 V to 2VREF

		LDAC_LOW			=	0x0, 			// LDAC reg is permanently low (updated continuously)
		LDAC_HIGH			=	0x1, 			// LDAC reg is permanently high (DAC registers are latched)
		LDAC_SINGLE			=	0x2,			// This option causes a single pulse on LDAC, updating the DAC registers once

		PD_CH_A 			=	(1 << 0),		// Power-down chA
		PD_CH_B 			=	(1 << 1),		// Power-down chB
		PD_CH_C 			=	(1 << 2),		// Power-down chC
		PD_CH_D 			=	(1 << 3),		// Power-down chD
		PD_CH_E 			=	(1 << 4),		// Power-down chE
		PD_CH_F 			=	(1 << 5),		// Power-down chF
		PD_CH_G 			=	(1 << 6),		// Power-down chG
		PD_CH_H 			=	(1 << 7),		// Power-down chH

		RST_DATA_ONLY 		=	(0 << 12),		// DAC Data Reset
		RST_DATA_CTRL 		=	(1 << 12)		// DAC Data and Control Reset
    };

public:

    /*
        Ad53x8 class constructor
        @param base_addr pointer to the beginning of the module's register space
    */
    constexpr Ad53x8(const uintptr_t base_addr) : Spi{base_addr}{}

    /*
        Write command/data to ad53x8
        @param wr_data command/data that we want to write to ad53x8
    */
    inline void wr_some_data(const uint16_t wr_data) const 
    {
        // Check for transferability
        wait_tx_fifo(Reg::STAT, R_stat::TX_FULL); // mb TRY_write without while?

        // Send command/data to be recorded
        writeReg(Reg::TX_FIFO, wr_data);
    }

    // Initializing ad53x8 registers and interface controller
    void init() const;

    /*
        Writing data to ad53x8
        @param channel_number channel number to which we want to record data
        @param data data to write
    */
    inline void wr_data(const uint8_t channel_number, const uint16_t data) const 
    {
        wr_some_data((Ad_data::CH_MSK & (channel_number << Ad_data::CH_SH)) | (Ad_data::DT_MSK & (data << Ad_data::DT_SH)));
    }
};

#endif