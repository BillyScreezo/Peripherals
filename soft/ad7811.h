/***********************************************************************************
 * Copyright (C) 2024 Kirill Turintsev <billiscreezo228@gmail.com>
 * See LICENSE file for licensing details.
 *
 * This file contains сlass for interacting with the Ad7811 module and the corresponding chip
 *
 ***********************************************************************************/

#ifndef AD7811_H
#define AD7811_H

#include "spi.h"
#include <cstdint>

// Class for interacting with the Ad7811 module and the corresponding chip
class Ad7811 final : public Spi {

private:

    // Register space of the module for interaction with ad7811
    enum Reg : uintptr_t {
        CTRL    = 0x0,                  // Control register ad7811              (r/w)
        STAT    = 0x4,                  // ad7811 status register               (r only)
        TX_FIFO = 0x8,                  // Write data to transfer FIFO          (w only)
        RX_FIFO = 0xC                   // Reading data from the receive FIFO   (r only)
    };

    // SPI Controller Control Register Fields
    enum R_ctrl : uint32_t {
        SPI_FAST = 0x0,                 // SPI speed bit
        SPI_SLOW = 0x1                  // SPI speed bit
    };

    // SPI Interface Controller Status Register Fields
    enum R_stat : uint32_t {
        TX_FULL     = 0b0001,           // TX fifo is full
        TX_EMPTY    = 0b0010,           // TX fifo is empty
        RX_FULL     = 0b0100,           // RX fifo is full
        RX_EMPTY    = 0b1000            // RX fifo is empty
    };

    // AD7811 Control Register Fields
    enum Ad_ctrl : uint32_t {
        EXT_REF     = 0b0'0000'0001,    // Use external voltage reference
        CONVST      = 0b0'0000'0010,    // Init convst
        CH_MASK     = 0b0'0000'1100,    // Channel mask
        DIFF        = 0b0'0001'0000,    // Use diff channels mode
        REF_V4      = 0b0'0010'0000,    // Use ch4 voltage ref

        PD_FPD      = 0b0'0000'0000,    // Full Power-Down of the AD7811
        PD_PPD_C    = 0b0'0100'0000,    // Partial Power-Down at the End of Conversion
        PD_FPD_C    = 0b0'1000'0000,    // Full Power-Down at the End of Conversion
        PD_FPU      = 0b0'1100'0000,    // Power-Up the AD7811

        ADDR        = 0b1'0000'0000,    // SPI address of AD7811
        CH_SH       = 0x2               // Chanel shift
    };

public:

    /*
        Ad7811 class constructor
        @param base_addr pointer to the beginning of the module's register space
    */
    constexpr Ad7811(const uintptr_t base_addr) : Spi{base_addr}{}

    /*
        Write command and read data from ad7811
        @param cmd_data the command we want to write to ad7811
        @returns Read data from ad7811
    */
    template<typename T = uint32_t>
    inline T wr_cmd(const T cmd_data) const 
    {
        // Sending a command
        writeReg(Reg::TX_FIFO, cmd_data);

        // We are waiting for the read data from the microcircuit
        wait_rx_fifo(Reg::STAT, R_stat::RX_EMPTY); // mb TRY_write without while?

        // Return the data read from the chip to the caller
        return readReg<Reg, T>(Reg::RX_FIFO);
    }

    // Initializing the ad7811 registers and interface controller for fast mode operation
    inline void init() const 
    {
        // Setting the fast SPI operating mode
        writeReg(Reg::CTRL, R_ctrl::SPI_FAST);

        // Sending the first test word to wait for time t_pu and switch to fast operating mode
        wr_cmd(Ad_ctrl::EXT_REF | Ad_ctrl::PD_FPU);
    }

    /*
        Reading data from ad7811
        @param channel_number channel number from which we want to read data
        @returns Read data from ad7811
    */
    template<typename T = uint32_t>
    inline T rd_data(const T channel_number) const 
    {
        // Return the read data to the caller
        return wr_cmd(Ad_ctrl::EXT_REF | Ad_ctrl::PD_FPU | (Ad_ctrl::CH_MASK & (channel_number << Ad_ctrl::CH_SH)));
    }
};

#endif