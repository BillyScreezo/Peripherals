/***********************************************************************************
 * Copyright (C) 2024 Kirill Turintsev <billiscreezo228@gmail.com>
 * See LICENSE file for licensing details.
 *
 * This file contains base class of a slave device for which read/write operations are possible
 *
 ***********************************************************************************/

#ifndef DEVICE_H
#define DEVICE_H

#include <cstdint>

// Base class of a slave device for which read/write operations are possible
class Device {

private:

    // Address of the beginning of the module register space
    const uintptr_t m_base_addr;

protected:

    /*
        Device class constructor
        @param base_addr pointer to the beginning of the module's register space
    */
    constexpr Device(const uintptr_t base_addr) : m_base_addr{base_addr} {}
    
    /*
        Writing a value to a register
        @param offset offset relative to the beginning of the register space
        @param wr_data data to be written to the register
    */
    template<typename T1 = uintptr_t, typename T2 = uint32_t>
    inline void writeReg(const T1 offset, const T2 wr_data) const
    {
        *reinterpret_cast<volatile T2*>(
            m_base_addr + static_cast<uintptr_t>(offset)) = wr_data;
    }

    /*
        Reading a value from a register
        @param offset offset relative to the beginning of the register space
        @returns Value from the specified register
    */
    template<typename T1 = uintptr_t, typename T2 = uint32_t>
    inline T2 readReg(const T1 offset) const 
    {
        return *reinterpret_cast<volatile T2*>(
            m_base_addr + static_cast<uintptr_t>(offset));
    }
};

#endif