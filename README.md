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
	
*   UART with AXI-Stream interface
    1.  .sv module file
    2.  Customizable FIFO depth
    3.  Customizable system frequency
    4.  Customizable baudrate
	5.  Customizable data bits
	6.  Customizable parity type
	7.  Customizable number of stop bits
	
*   AXI-Stream sync fifo
    1.  .sv module file
    2.  Customizable data type
    3.  Customizable FIFO depth
    4.  Customizable tlast, tuser fields width

## Repository structure

*   [soft](./soft/)         - C++ drivers
*   [src](./src/)           - .sv source files
*   [tb](./tb/)             - test bench for modules