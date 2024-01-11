/***********************************************************************************
 * Copyright (C) 2024 Kirill Turintsev <billiscreezo228@gmail.com>
 * See LICENSE file for licensing details.
 *
 * This file contains a class that extends the functionality of the Device class by adding SPI queues
 *
 ***********************************************************************************/

#ifndef SPI_H
#define SPI_H

#include <cstdint>
#include "device.h"

// A class that extends the functionality of the Device class by adding SPI queues
class Spi : public Device {

private:

protected:

    /*
        Spi class constructor
        @param base_addr pointer to the beginning of the module's register space
    */
    constexpr Spi(const uintptr_t base_addr) : Device{base_addr}{}
    
    /*
        Waiting to write to tx_fifo
        @param tx_fifo_addr address of the tx_fifo status word in the module register space
        @param tx_full_position position of the tx_full field in the status word
    */
    template<typename T1 = uintptr_t, typename T2 = uint32_t>
    inline void wait_tx_fifo(const T1 tx_fifo_addr, const T2 tx_full_position) const 
    {
        while(readReg<T1, T2>(tx_fifo_addr) & tx_full_position);
    }

    /*
        Waiting to read from rx_fifo
        @param rx_fifo_addr address of the rx_fifo status word in the module register space
        @param rx_empty_position position of the rx_empty field in the status word
    */
    template<typename T1 = uintptr_t, typename T2 = uint32_t>
    inline void wait_rx_fifo(const T1 rx_fifo_addr, const T2 rx_empty_position) const 
    {
        while(readReg<T1, T2>(rx_fifo_addr) & rx_empty_position);
    }
};

#endif