/***********************************************************************************
 * Copyright (C) 2024 Kirill Turintsev <billiscreezo228@gmail.com>
 * See LICENSE file for licensing details.
 *
 * This file contains Ad53x8::init() function definition
 *
 ***********************************************************************************/

#include "ad53x8.h"

void Ad53x8::init() const 
    {
    	// Synchronous mode with constant data loading
        writeReg(Reg::CTRL, R_ctrl::SPI_LOAD);

        // Reset the device
        wr_some_data(Ad_cmd::WR_CMD | Ad_cmd::CTRL_RST | Ad_cmd::RST_DATA_CTRL);

        // All channels - on
        wr_some_data(Ad_cmd::WR_CMD | Ad_cmd::CTRL_PD);

        // Controlling LDAC Data Update via Hardware
        wr_some_data(Ad_cmd::WR_CMD | Ad_cmd::CTRL_LDAC | Ad_cmd::LDAC_HIGH);

        // On buffering of all channels, setting digitization ranges
        wr_some_data(Ad_cmd::WR_CMD | Ad_cmd::CTRL_GBV  | Ad_cmd::GBV_BUF_AD | Ad_cmd::GBV_BUF_EH | Ad_cmd::GBV_GAIN_0_VR_AD | Ad_cmd::GBV_GAIN_0_VR_EH);
    }