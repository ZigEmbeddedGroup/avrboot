# avrboot

This repo aims to be a Zig AVR flashing tool!

Currently only tested/working for Arduino UNO boards.

## Usage

`zig build`
`avrboot [port] [.bin file]`
e.g. `avrboot \\.\COM3 test-blinky-chips.atmega328p.bin`
