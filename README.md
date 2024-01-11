# Peripherals

## Composition

*   AD53x8 SPI DAC
    1.  .sv module file and C++ driver
    2.  Customizable FIFO depth
    3.  Customizable system frequency
    4.  Setting up registers by APB

*   AD7811 SPI ADC
    1.  .sv module file and C++ driver
    2.  Customizable FIFO depth
    3.  Customizable system frequency
    4.  Setting up registers by APB

## Repository structure

*   [soft](./soft/)         - C++ drivers
*   [src](./src/)           - .sv source files
*   [tb](./tb/)             - test bench for modules