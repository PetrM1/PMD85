# PMD85 v2
Computer PMD 85 is Czechoslovakian 8-bit computer produced by Tesla Piešťany and Tesla Bratislava. First version was designed by Roman Kišš.
And this is its implementation in Verilog for MISTEer FPGA.

## Specifications

* CPU MHB8080A @2.048MHz - Czechoslovakian clone of Intel 8080
* 64 kB RAM
* 4 kB ROM + up to 32 kB in detachable/changeable ROM pack used for example for Basic but also might be used other devices like emulator of 8048 uProcessor
* TV output or RGB video
* 288x256 pixels - 2 bits "color" attributes per 6 pixels (greyscale or blink or RGB)
* 2x8-bit parallel buss connectors
* application connector directly connected to IO system bus
* IMS-2 connector
* current loop RS232 connector
* connector for tape recorder to store and load programs

## What is implemented

* CPU
* 64 kB RAM
* Keyboard
* Beeper
* Green monitor mode, TV mode, RGB mode
* Color ACE mode - homemade color 
* loadable ROM Pack via menu for loading SW - *.rmm files needed
* MIF85 sound interface

## What is missing

* AllRAM wire pull up is missing!!
* floppy!!
* tape load?
* i8251 is not implemented - it only reports empty buffers. Implement and connect it to MISTer on board UART?
* i8255 only mode 0 is implemented, but haven’t found any SW that miss other modes yet
* mouse 
* i8253 gate inputs - missing pull ups


## How to start

* In menu choose *.rmm file you want to load
* Enable MIF85 in menu in sound item - if you want to be detected by SW and used
* Joystick and color mode can be changed during SW runs 
* Reset PMD - rom pack usually contains automatic load
* Enjoy the PMD and the game :)

## For more info see

* https://en.wikipedia.org/wiki/PMD_85
* https://pmd85.borik.net/
* https://www.schotek.cz/pmd/

Some of them are only in Czech or Slovak, but Google translator is your friend :)
