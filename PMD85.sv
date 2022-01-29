//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

//assign ADC_BUS  = 'Z;
//assign USER_OUT = '1;

assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_SL = 0;
assign VGA_F1 = 0;


assign AUDIO_S = 0;
assign AUDIO_MIX = 3;

wire LED_YELLOW;
wire LED_RED;

assign LED_POWER = {1'b1, led_blink[23] | allRam_n};

wire [23:0] led_blink;
always @(posedge CLK_50M)
begin
   led_blink <= led_blink + 1;
end




assign LED_USER = LED_RED;
assign LED_DISK = { 1'b1, LED_YELLOW };	
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

// PMD85 videoresolution is 288 columns x 256 rows
// PMD85 videoresolution is 288 columns x 256 visible (312,5) rows 
assign VIDEO_ARX = 8'd4;
assign VIDEO_ARY = 8'd3; 

`include "build_id.v" 
localparam CONF_STR = {
	"PMD85;;",
	"-;",	
	"F1,rmm,Load to ROM Pack",
	"-;",
	"O12,Video,Green,TV,RGB,ColorACE;",
	"D0O3,Sound,Beeper,Beeper + MIF85 on K2;",
	"O45,Joystick,None,K3,K4;",
	"D1O6,Mouse,None,K2;",		
	"-;",	
	"R0,Reset PMD;",
	"J,Fire 1,Fire 2;",
	"V,v",`BUILD_DATE 
};

wire forced_scandoubler = 1;
wire  [1:0] buttons;
wire [31:0] status;
wire [10:0] ps2_key;
wire [24:0] ps2_mouse;

wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_data;
wire        ioctl_download;
wire  [7:0] ioctl_index;

wire [15:0] joy0;
wire [15:0] joy1;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),
	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask({status[3], status[6]}),
	
	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse),
	
	.joystick_0(joy0),
	.joystick_1(joy1),
	
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index)  
);



///////////////////////   CLOCKS   ///////////////////////////////

wire locked;
wire clk_sys; // PMD85 system clock (for 8224) is 18.432MHz
wire clk_8M; // 8MHz clock for audio (SAA1099)

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.locked(locked),
	.outclk_1(clk_8M)
);

wire reset = RESET | status[0] | buttons[1];

//////////////////////////////////////////////////////////////////

wire clk_video;
wire SR_n;
wire SD_n;
wire ZAT_n;
wire pixel;
wire [1:0] pixelFunction;
wire allRam_n;
wire RxD;
wire TxD;
assign USER_OUT[1:0] = {TxD, 1'b1};
assign RxD = USER_IN[0];
	
	
PMD85_2A PMD85core
(
	.clk_50M(CLK_50M),
	.clk_8M(clk_8M),
	.clk_sys(clk_sys),
	.reset_main(reset),
	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse),
	.clk_video(clk_video),
	.SR_n(SR_n),
	.SD_n(SD_n),
	.ZAT_n(ZAT_n), 
	.pixel(pixel),
	
	.ADC_BUS(ADC_BUS),
	.RxD(RxD),
	.TxD(TxD),   
	.audioMode(status[3]),
	.AUDIO_L(AUDIO_L),
	.AUDIO_R(AUDIO_R),
	
	.ColorMode(status[2:1]),
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),	
		
	.LED_YELLOW(LED_YELLOW),
	.LED_RED(LED_RED),
   .allRam_n(allRam_n),
	 	
	.joystickPort(status[5:4]),
	.joy0(joy0),
	.joy1(joy1),
	.mouseEnabled(status[6]),
	
	.ioctl_wr(ioctl_wr),	
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index)
);

assign CLK_VIDEO = clk_sys;
assign CE_PIXEL = clk_video;
//assign CE_PIXEL = 1;

assign VGA_HS = SR_n;
assign VGA_VS = SD_n;
assign VGA_DE = ZAT_n;


endmodule
