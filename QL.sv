//============================================================================
//  Sinclair QL
//
//  Copyright (c) 2015 Till Harbaum <till@harbaum.org> 
//
//  Port to MiSTer
//  Copyright (C) 2017-2019 Sorgelig
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
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

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

	input         CLK_AUDIO, // 24.576 MHz
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

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

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
	output	USER_OSD,
output	[1:0] USER_MODE,
input	[7:0] USER_IN,
output	[7:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
wire         CLK_JOY = CLK_50M;         //Assign clock between 40-50Mhz
wire   [2:0] JOY_FLAG  = {status[30],status[31],status[29]}; //Assign 3 bits of status (31:29) o (63:61)
wire         JOY_CLK, JOY_LOAD, JOY_SPLIT, JOY_MDSEL;
wire   [5:0] JOY_MDIN  = JOY_FLAG[2] ? {USER_IN[6],USER_IN[3],USER_IN[5],USER_IN[7],USER_IN[1],USER_IN[2]} : '1;
wire         JOY_DATA  = JOY_FLAG[1] ? USER_IN[5] : '1;
assign       USER_OUT  = JOY_FLAG[2] ? {3'b111,JOY_SPLIT,3'b111,JOY_MDSEL} : JOY_FLAG[1] ? {6'b111111,JOY_CLK,JOY_LOAD} : '1;
assign       USER_MODE = JOY_FLAG[2:1] ;
assign       USER_OSD  = joydb_1[10] & joydb_1[6];

assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;

assign LED_USER  = mdv_led | ioctl_download | sd_act;
assign LED_DISK  = {1'b1, status[0]};
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign VGA_SCALER= 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;

video_freak video_freak
(
	.*,
	.VGA_DE_IN(VGA_DE),
	.VGA_DE(),
	.ARX((!ar) ? 12'd4 : (ar - 1'd1)),
	.ARY((!ar) ? 12'd3 : 12'd0),
	.CROP_SIZE(0),
	.CROP_OFF(0),
	.SCALE(status[14:13])
);

/////////////////  CONFIGURATION  /////////////////
`include "build_id.v" 
parameter CONF_STR = {
	"QL;;",
	"SC0,WIN,Mount HD image;",	
	"-;",
	"F2,MDV,Load MDV image;",
	"O2,MDV direction,normal,reverse;",
	"-;",
	"F4,ROM,Load OS;",
	"-;",
	"O3,Video mode,PAL,NTSC;",
	"OBC,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O9A,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
	"ODE,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"-;",
	"OUV,UserIO Joystick,Off,DB9MD,DB15 ;",
	"OT,UserIO Players, 1 Player,2 Players;",
	"-;",
	"O78,CPU speed,QL,16 Mhz,24 Mhz,Full;",
	"O45,RAM,128k,640k,896k,4096k;",
	"R0,Reset & unload MDV;",
	"V,v",`BUILD_DATE
};

parameter MDV_IOCTL_INDEX = 8'd2;
parameter ROM_IOCTL_INDEX = 8'd4;

wire mdv_reverse = status[2];
wire ntsc_mode = status[3];
wire osd_reset = status[0];
wire [1:0] cpu_speed = status[8:7];
wire [1:0] scale = status[10:9];
wire ql_mode = cpu_speed == 2'b00;
wire gc_en = ram_cfg == 2'b11;
wire [1:0] ar = status[12:11];

reg [1:0] ram_cfg;			// 00 = 128k, 01 = 640k, 10 = 896k, 11 = 4096k
always @(posedge clk_sys) if (reset) ram_cfg <= status[5:4];


/////////////////  CLOCKS  ////////////////////////

wire clk_sys;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),						// System clock
	.locked(pll_locked)
);

// 84MHz sys_clk
parameter FRACT_BUS_QL = 17'd11702;		// 84MHz * 11702 / 65536 = 14.999MHz
parameter FRACT_BUS_16 = 17'd24966;		// 84MHz * 24966 / 65536 = 31.999MHz
parameter FRACT_BUS_24 = 17'd37449;		// 84MHz * 37449 / 65536 = 48.000MHz
parameter FRACT_BUS_FULL = 17'h10000;	// 84MHz

parameter FRACT_SD = 17'd19505;			// 84MHz * 39010 / 65536 = 50Mhz (effectively 25Mhz SPI speed)
parameter FRACT_11M = 17'd8582;			// 84MHz * 8582 / 65536 = 10.999Mhz
parameter DIV_131k = 10'd640;				// 84MHz / 640 = 131250Hz
parameter DIV_VID = 4'd8;					// 84MHz / 8 = 10.5MHz

// 94.5MHz sys_clk
/*parameter FRACT_BUS_QL = 17'd10403;		// 94.5MHz * 10403 / 65536 = 15.000MHz
parameter FRACT_BUS_16 = 17'd22192;		// 94.5MHz * 22192 / 65536 = 31.999MHz
parameter FRACT_BUS_24 = 17'd33288;		// 94.5MHz * 33288 / 65536 = 48.000MHz
parameter FRACT_BUS_FULL = 17'h10000;	// 94.5MHz

parameter FRACT_SD = 17'd34675;			// 94.5MHz * 34675 / 65536 = 49.999MHz (effectively 25Mhz SPI speed)
parameter FRACT_11M = 17'd7629;			// 94.5MHz * 7629 / 65536 = 11.001MHz
parameter DIV_131k = 10'd720;				// 94.5MHz / 720 = 131250Hz
parameter DIV_VID = 4'd9;					// 94.5MHz / 9 = 10.5MHz*/

// 105MHz sys_clk
/*parameter FRACT_BUS_QL = 17'd9362;		// 105MHz * 9362 / 65536 = 14.999MHz
parameter FRACT_BUS_16 = 17'd19973;		// 105MHz * 19973 / 65536 = 32.000MHz
parameter FRACT_BUS_24 = 17'd29959;		// 105MHz * 29959 / 65536 = 47.999MHz
parameter FRACT_BUS_FULL = 17'h10000;	// 105MHz

parameter FRACT_SD = 17'd31208;			// 105MHz * 31208 / 65536 = 50.000MHz (effectively 25Mhz SPI speed)
parameter FRACT_11M = 17'd6866;			// 105MHz * 6866 / 65536 = 11.001MHz
parameter DIV_131k = 10'd800;				// 105MHz / 800 = 131250Hz
parameter DIV_VID = 4'd10;					// 105MHz / 10 = 10.5MHz*/

wire [16:0] fract_bus = 
	cpu_speed == 0? FRACT_BUS_QL:
	cpu_speed == 1? FRACT_BUS_16:
	cpu_speed == 2? FRACT_BUS_24:
	FRACT_BUS_FULL;

reg ce_bus_p, ce_bus_n;
reg ce_131k;									// Supposed to be 131025 Hz for SDRAM refresh and clock update
reg ce_vid;										// 10.5Mhz pixel clock
reg ce_sd;										// ~50 Mhz SD clock
reg ce_11m;

always @(negedge clk_sys)
begin
	reg bus_pol;
	reg bus_tick;
	reg [15:0] cnt_bus;
	reg [15:0] cnt_sd;
	reg [15:0] cnt_11m;
	reg [9:0] div131k;
	reg [3:0] divVid;

	if (reset) 
	begin
		bus_pol <= 0;
		cnt_bus <= 0;
		div131k <= 0;
		divVid <= 0;
	end else begin	
		div131k<= div131k + 10'd1;
		divVid <= divVid + 4'd1;
		end
	
	// CPU clock
	{bus_tick, cnt_bus} <= cnt_bus + fract_bus;
	ce_bus_p <= bus_tick && !bus_pol;
	ce_bus_n <= bus_tick && bus_pol;
	bus_pol <= bus_tick ^ bus_pol; 

	// SDRAM refresh and clock update	
	if (div131k == DIV_131k - 1) div131k <= 0;
	ce_131k <= !div131k;						
		
	// 10.5Mhz pixel clock
	if (divVid == DIV_VID - 1) divVid <= 0;	
	ce_vid <= !divVid;
	
	// QL-SD clock
	{ce_sd, cnt_sd} <= cnt_sd + FRACT_SD;
	
	// 11Mhz IPC clock
	{ce_11m, cnt_11m} <= cnt_11m + FRACT_11M;
end

//////////////// QL RAM timing ////////////////////

wire ram_delay_dtack;

ql_timing ql_timing(
	.*,
	.enable(ql_mode)
);

/////////////////  HPS  ///////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

wire [15:0] joystick_0_USB, joystick_1_USB;
wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [15:0] ioctl_dout = {ioctl_data[7:0], ioctl_data[15:8]};
wire [15:0] ioctl_data;
reg         ioctl_wait = 0;

wire [31:0] sd_lba;
wire        sd_rd;
wire        sd_wr;
wire        sd_ack;
wire  [7:0] sd_buff_addr;
wire [15:0] sd_buff_dout;
wire [15:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [63:0] img_size;

wire [24:0] ps2_mouse;
wire [10:0] ps2_key;
wire [32:0] TIMESTAMP;

wire        forced_scandoubler;
wire [21:0] gamma_bus;

// F4 F3 F2 F1 U D L R 
wire [31:0] joystick_0 = joydb_1ena ? (OSD_STATUS? 32'b000000 : joydb_1[7:0]) : joystick_0_USB;
wire [31:0] joystick_1 = joydb_2ena ? (OSD_STATUS? 32'b000000 : joydb_2[7:0]) : joydb_1ena ? joystick_0_USB : joystick_1_USB;

wire [15:0] joydb_1 = JOY_FLAG[2] ? JOYDB9MD_1 : JOY_FLAG[1] ? JOYDB15_1 : '0;
wire [15:0] joydb_2 = JOY_FLAG[2] ? JOYDB9MD_2 : JOY_FLAG[1] ? JOYDB15_2 : '0;
wire        joydb_1ena = |JOY_FLAG[2:1]              ;
wire        joydb_2ena = |JOY_FLAG[2:1] & JOY_FLAG[0];

//----BA 9876543210
//----MS ZYXCBAUDLR
reg [15:0] JOYDB9MD_1,JOYDB9MD_2;
joy_db9md joy_db9md
(
  .clk       ( CLK_JOY    ), //40-50MHz
  .joy_split ( JOY_SPLIT  ),
  .joy_mdsel ( JOY_MDSEL  ),
  .joy_in    ( JOY_MDIN   ),
  .joystick1 ( JOYDB9MD_1 ),
  .joystick2 ( JOYDB9MD_2 )	  
);

//----BA 9876543210
//----LS FEDCBAUDLR
reg [15:0] JOYDB15_1,JOYDB15_2;
joy_db15 joy_db15
(
  .clk       ( CLK_JOY   ), //48MHz
  .JOY_CLK   ( JOY_CLK   ),
  .JOY_DATA  ( JOY_DATA  ),
  .JOY_LOAD  ( JOY_LOAD  ),
  .joystick1 ( JOYDB15_1 ),
  .joystick2 ( JOYDB15_2 )	  
);

hps_io #(.CONF_STR(CONF_STR), .WIDE(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	
	.TIMESTAMP(TIMESTAMP),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	.ioctl_wait(ioctl_wait),

	.joy_raw(OSD_STATUS? (joydb_1[5:0]|joydb_2[5:0]) : 6'b000000 ),
	
	.sd_lba('{sd_lba}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{sd_buff_din}),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),
	
	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse),

	.joystick_0(joystick_0_USB),
	.joystick_1(joystick_1_USB)
);

/////////////////  SD  ////////////////////////////

// SD card emulator
reg vsd_sel = 0;
always @(posedge clk_sys) if (img_mounted) vsd_sel <= |img_size;

wire vsd_miso;
wire sd_clk;
wire sd_mosi;
wire sd_miso = sd_phys_cs? vsd_miso: SD_MISO;
wire sd_cs1, sd_cs2;
wire sd_phys_cs = vsd_sel? sd_cs2: sd_cs1;	// Physical SD as card2 if vitual SD is enabled

sd_card #(.WIDE(1)) sd_card
(
	.*,

	.clk_spi(clk_sys),
	.sdhc(1),
	.sck(sd_clk),
	.ss(sd_cs1 || ~vsd_sel),
	.mosi(sd_mosi),
	.miso(vsd_miso)
);

assign SD_CS   = sd_phys_cs;
assign SD_SCK  = sd_phys_cs? 1'd0: sd_clk;
assign SD_MOSI = sd_phys_cs? 1'd0: sd_mosi;

// QL-SD interface
wire qlsd_en  = (!gc_en || rom_shadow) && cpu_rom && cpu_rd;
wire qlsd_reg = qlsd_en && (cpu_addr[15:4] == 12'hfee || cpu_addr[15:4] == 12'hfef);
wire qlsd_rd  = qlsd_en && (cpu_addr[15:0] == 16'hfee4);  // only one register actually returns data
wire qlsd_dat = qlsd_en &&  cpu_addr[15:8] == 8'hff;
wire qlsd_sel = qlsd_reg || qlsd_dat;
wire [7:0] qlsd_dout;
wire qlsd_dtack;

qlromext qlromext
(
	.clk		( clk_sys    		),

	.ce_sd	( ce_sd    			),
	.dtack   ( qlsd_dtack      ),

	.romoel  ( !qlsd_sel 		),
	.a       ( cpu_addr[15:0]	),
	.d       ( qlsd_dout       ),
	.sd_do   ( sd_miso         ),
	.sd_cs1l ( sd_cs1          ),
	.sd_cs2l ( sd_cs2          ),
	.sd_clk  ( sd_clk          ),
	.sd_di   ( sd_mosi         ),
	.io2     ( 1'b0            )
); 


// SD led
reg sd_act;

always @(posedge clk_sys) begin
	reg old_mosi, old_miso;
	integer timeout = 0;

	old_mosi <= sd_mosi;
	old_miso <= sd_miso;

	sd_act <= 0;
	if (timeout < 4000000) begin
		timeout <= timeout + 1;
		sd_act <= 1;
	end

	if ((old_mosi ^ sd_mosi) || (old_miso ^ sd_miso)) timeout <= 0;
end

/////////////////  RESET  /////////////////////////

reg [11:0] reset_cnt;
wire reset = (reset_cnt != 0);
always @(posedge clk_sys) begin
	if(RESET || buttons[1] || osd_reset || !pll_locked || rom_download)
		reset_cnt <= 12'hfff;
	else if(ce_bus_p && reset_cnt != 0)
		reset_cnt <= reset_cnt - 1'd1;
end

/////////////////  SDRAM  /////////////////////////

wire [23:0] sdram_addr = { 3'b000, cpu_addr[21:1]};
wire [15:0] sdram_din  = cpu_dout;
wire        sdram_wr   = cpu_as && !cpu_rw && (cpu_ram || rom_shadow_write);
wire        sdram_oe   = cpu_rd && (cpu_ram || rom_shadow_read);
wire			sdram_uds  = cpu_uds;
wire			sdram_lds  = cpu_lds;
wire [15:0] sdram_dout;
wire			sdram_dtack;

assign SDRAM_CKE = 1;
sdram sdram
(
	.*,

   // system interface
   .clk		( clk_sys      ),
	.refresh	( ce_131k		),
   .init  	( !pll_locked  ),

   // cpu interface
   .din		( sdram_din    ),
   .addr		( sdram_addr   ),
   .we		( sdram_wr     ),
   .oe		( sdram_oe     ),
   .uds		( sdram_uds    ),
   .lds		( sdram_lds    ),
   .dout		( sdram_dout   ),
	.dtack 	( sdram_dtack	)
);

//////////////  GoldCard registers  ///////////////

// GoldCard style ROM shadow RAM
reg rom_shadow;
wire rom_shadow_read = cpu_rd && cpu_os_rom && rom_shadow;
wire rom_shadow_write = cpu_as && !cpu_rw && cpu_os_rom && !rom_shadow;

always @(posedge clk_sys)
begin
	if (reset) 
		rom_shadow <= 0;
	else if (gc_io && cpu_wr && cpu_uds && !cpu_lds)
	begin
		if (cpu_addr[7:0] == 8'h60)
			rom_shadow <= 1;				// glo_rena: enable shadow RAM
		else if (cpu_addr[7:0] == 8'h64)
			rom_shadow <= 0;				// glo_rdis: disable shadow RAM
	end
end

//////////////////  ROM  //////////////////////////

wire rom_download = ioctl_download && (!ioctl_index || ioctl_index == ROM_IOCTL_INDEX);
wire rom_ioctl_write = ioctl_wr && (!ioctl_index || ioctl_index == ROM_IOCTL_INDEX);

wire [15:0] ql_rom_dout;
dpram #(15) ql_rom
(
	.wrclock		( clk_sys				),
	.wraddress	( ioctl_addr[15:1] 	),
	.wren			( rom_ioctl_write	 	),
	.byteena_a	( 2'b11					),
	.data			( ioctl_dout			),

	.rdclock		( clk_sys				),
	.rdaddress	( cpu_addr[15:1]		),
	.q				( ql_rom_dout			)
);


///////////  MisterGoldCard boot ROM  /////////////

wire [15:0] gc_rom_dout;
mgc_rom gc_rom (
	.clock		( clk_sys			),
	.address		( cpu_addr[15:1]	),
	.q				( gc_rom_dout		)
);

/////////////////  VRAM  //////////////////////////	

wire [15:0] vram_dout;
dpram #(15) vram
(
	.wrclock(clk_sys),
	.wraddress	( cpu_addr[15:1] ),
	.wren			( cpu_wr && (cpu_addr[23:16] == 2) ),
	.byteena_a	( {cpu_uds, cpu_lds}	),
	.data			( cpu_dout ),

	.rdclock(clk_sys),
	.rdaddress(video_addr),
	.q(vram_dout)
);

/////////////////  ZX8301  ////////////////////////

wire video_r, video_g, video_b;
wire HS, VS;
wire HBlank, VBlank, ce_pix;

reg HSync, VSync;
always @(posedge CLK_VIDEO) begin
	HSync <= HS;
	if(~HSync & HS) VSync <= VS;
end

assign VGA_SL = scale ? scale - 1'd1 : 2'd0;
assign VGA_F1 = 0;

assign CLK_VIDEO = clk_sys;

video_mixer #(.HALF_DEPTH(1), .GAMMA(1)) video_mixer
(
	.*,
	.scandoubler(scale || forced_scandoubler),
	.hq2x(scale==1),
	.freeze_sync(),

	.R({4{video_r}}),
	.G({4{video_g}}),
	.B({4{video_b}})
);

wire [14:0] video_addr;

// The zx8301 has only one write-only register at $18063
wire zx8301_ce = ql_io && ({cpu_addr[6:5], cpu_addr[1]} == 3'b111) && cpu_wr && cpu_lds;

reg [7:0] mc_stat;
always @(posedge clk_sys)
begin
	if (reset) 
	begin
		mc_stat <= 8'h00;
	end
	else if (zx8301_ce) 
	begin
		mc_stat <= cpu_dout[7:0];
	end
end

zx8301 zx8301
(
	.reset   ( reset      ),

	.clk     ( clk_sys    ),
	.ce      ( ce_vid     ),
	.ce_out  ( ce_pix     ),

	.ntsc    ( ntsc_mode  ),
	.mc_stat ( mc_stat    ),

	.addr    ( video_addr ),
	.din     ( vram_dout  ),

	.hs      ( HS         ),
	.vs      ( VS         ),
	.r       ( video_r    ),
	.g       ( video_g    ),
	.b       ( video_b    ),
	.HBlank  ( HBlank     ),
	.VBlank  ( VBlank     )
);

/////////////////  ZX8302  ////////////////////////

wire zx8302_sel = cpu_io && ql_io && !cpu_addr[6];
wire [1:0] zx8302_addr = {cpu_addr[5], cpu_addr[1]};
wire [15:0] zx8302_dout;

wire mdv_download = (ioctl_index == MDV_IOCTL_INDEX) && ioctl_download;

wire audio;
assign AUDIO_L = {15{audio}};
assign AUDIO_R = {15{audio}};
assign AUDIO_S = 0;
assign AUDIO_MIX = 0;

wire mdv_led;

zx8302 zx8302
(
	.reset        ( reset        ),
	.reset_mdv    ( osd_reset    ),
	.clk          ( clk_sys      ),
	.ce_11m       ( ce_11m       ),

	.xint         ( qimi_irq     ),
	.ipl          ( cpu_ipl      ),
	.led          ( mdv_led      ),
	.audio        ( audio        ),
	
	// CPU connection
	.cep          ( ce_bus_p     ),
	.cen          ( ce_bus_n     ),

	.ce_131k      ( ce_131k      ),
	.rtc_data     ( TIMESTAMP    ),

	.cpu_sel      ( zx8302_sel   ),
	.cpu_wr       ( cpu_wr       ),
	.cpu_addr     ( zx8302_addr  ),
	.cpu_uds		  ( cpu_uds 	  ),
	.cpu_lds      ( cpu_lds		  ),
	.cpu_din      ( cpu_dout     ),
   .cpu_dout     ( zx8302_dout  ),

	// joysticks 
	.js0          ( joystick_0[4:0] ),
	.js1          ( joystick_1[4:0] ),

	.ps2_key      ( ps2_key      ),
	
	.vs           ( VS           ),

	.mdv_reverse  ( mdv_reverse  ),

	.mdv_download ( mdv_download ),
	.mdv_dl_wr    ( ioctl_wr && mdv_download),
	.mdv_dl_data  ( ioctl_dout   ),
	.mdv_dl_addr  ( ioctl_addr[17:1] )
);

/////////////////  MOUSE  /////////////////////////

// qimi is at 1bfxx
wire qimi_sel = cpu_io && ql_io && (cpu_addr[13:8] == 6'b111111);
wire [7:0] qimi_data;
wire qimi_irq;
	
qimi qimi
(
   .reset     ( reset          ),
	.clk       ( clk_sys        ),
	.cep       ( ce_bus_p       ),
	.cen       ( ce_bus_n       ),

	.cpu_sel   ( qimi_sel       ),
	.cpu_addr  ( { cpu_addr[5], cpu_addr[1] } ),
	.cpu_data  ( qimi_data      ),
	.irq       ( qimi_irq       ),
	
	.ps2_mouse ( ps2_mouse      )
);

/////////////////  CPU  ///////////////////////////

wire ram_128 = !ram_cfg;
wire ram_512 = ram_cfg == 2'b01;
wire ram_768 = ram_cfg == 2'b10;
wire ram_4k  = &ram_cfg;

wire [23:0] cpu_addr_mask =
	ram_128? 			  24'h03FFFF:		// Wrap address space at 256kb (128KB RAM)
	ram_512 || ram_768? 24'h0FFFFF:		// Wrap address space at 1MB (640 + 896KB RAM)
							  24'h7FFFFF;		// Wrap address space at 8MB (4MB RAM + extended I/O space)

// Address decoding
wire cpu_rd   = cpu_as &&  cpu_rw && (cpu_uds || cpu_lds);
wire cpu_wr   = cpu_as && !cpu_rw && (cpu_uds || cpu_lds);
wire cpu_io   = cpu_rd || cpu_wr;
wire ql_io    = {cpu_addr[23:14], 2'b00} == 12'h018; 							// internal IO 	$18000-$1bfff
wire cpu_bram = cpu_addr[23:17] == 5'b00001; 	       						// 128k RAM   		$20000-$3ffff
wire cpu_ram512 = ram_512 && !cpu_addr[23:20] && ^cpu_addr[19:18];		// ExtRAM 512k  	$40000-$bffff
wire cpu_ram768 = ram_768 && !cpu_addr[23:20] && |cpu_addr[19:18];		// ExtRAM 768k		$40000-$fffff
wire cpu_ram4k  = ram_4k  && !cpu_addr[23:22] && |cpu_addr[21:18];		// ExtRAM 4096k	$40000-$3fffff
wire cpu_xram = cpu_ram512 || cpu_ram768 || cpu_ram4k;						// ExtRAM 512k/768k/4096k
wire cpu_ram  = (cpu_bram || cpu_xram || gc_ram1 || gc_ram2);				// any RAM
wire cpu_rom  = cpu_addr[23:16] == 8'h00;	 										// 64k     ROM $0000-$ffff
wire cpu_ext_rom = {cpu_addr[23:14], 2'b00} == 12'h00C;						// 16k ext ROM $c000-$ffff
wire cpu_os_rom  = cpu_rom && !cpu_ext_rom;										// 48k OS  ROM $0000-$bfff

// Additional (Super)GoldCard spaces
wire gc_io  = gc_en && ({cpu_addr[23:8]} == 16'h01C0);						// GoldCard IO $1c000-$1c0ff
wire gc_ram1 = gc_en && {cpu_addr[23:15], 3'b000} == 12'h010;				// 32kb additional SuperGoldCard RAM $10000-$17fff
wire gc_ram2 = gc_en && {cpu_addr[23:14], 2'b00} == 12'h01C && !gc_io; 	// 16kb additional SuperGoldCard RAM $1c100-$1ffff
wire gc_boot_rom = gc_en && cpu_addr[23:16] == 8'h04;							// Another copy of the boot ROM $040000-$04ffff
wire gc_os_rom = gc_en && cpu_addr[23:16] == 8'h40;							// SuperGoldCard copy of QL ROM $400000-$40ffff
//wire gc_ext_io = gc_en && {cpu_addr[23:18], 2'b00} == 8'h4c;				// SuperGoldCard extended I/O $4c0000-$4fffff

wire [15:0] io_dout = 
	qimi_sel? {qimi_data, qimi_data}:
	zx8302_sel? zx8302_dout:
	16'h0000;	

// Data bus on GC boot (shadow RAM disabled)
wire [15:0] gc_dout_boot =
	cpu_rom? gc_rom_dout:								// 000000..00ffff: GC ROM
	gc_boot_rom? gc_rom_dout:							// 040000..04ffff: Another copy of GC ROM
	gc_os_rom? ql_rom_dout:								// 400000..40ffff: Original OS ROM
	cpu_ram? sdram_dout:
	16'hffff;

// Data bus if GC RAM shadow is enabled
wire [15:0] gc_dout_shadow = 
	cpu_os_rom? sdram_dout:								// 000000..007fff: Shadow-RAM
	qlsd_rd? {qlsd_dout, qlsd_dout}:  				// 00fee4        : QL-SD maps into rom area
	cpu_ext_rom? ql_rom_dout:							// 00c000..00ffff: EXT-ROM space
	gc_os_rom? ql_rom_dout:								// 400000..40ffff: Original OS ROM
	cpu_ram? sdram_dout:
	16'hffff;

// Gold Card mode data bus
wire [15:0] gc_dout = 
	rom_shadow? gc_dout_shadow: gc_dout_boot;
	
// QL mode data bus
wire [15:0] ql_dout =
	qlsd_rd? {qlsd_dout, qlsd_dout}:    			// 00fee4        : QL-SD maps into rom area
	cpu_rom? ql_rom_dout:								// 000000..00ffff: OS ROM + EXT ROM
	cpu_ram? sdram_dout:
	16'hffff;

// Bring it all together
wire [15:0] cpu_din =
	ql_io? io_dout:										// 18000..1bfff: Always mapped
	gc_en? gc_dout:											// GC-mode memory spaces
	ql_dout;													// QL-mode memory spaces


wire cpu_dtack =
	qlsd_sel? qlsd_dtack:
	rom_shadow_read || rom_shadow_write? sdram_dtack:
	cpu_ram? sdram_dtack && !ram_delay_dtack:
	!ram_delay_dtack;

// Debugging only
//reg [23:0] cpu_addr_reg  /* synthesis noprune */;
//always @(posedge clk_sys) begin
//	cpu_addr_reg <= cpu_addr;	
//end

wire [23:1] cpu_addr16;
wire [23:0] cpu_addr = {cpu_addr16, !cpu_uds && cpu_lds} & cpu_addr_mask;
wire [15:0] cpu_dout;
wire [1:0] cpu_ipl;
wire cpu_uds_n;
wire cpu_lds_n;
wire cpu_uds = !cpu_uds_n;
wire cpu_lds = !cpu_lds_n;
wire cpu_as_n;
wire cpu_as = !cpu_as_n;
wire cpu_rw;
wire [2:0] cpu_fc;
wire cpu_int_ack = &cpu_fc;

fx68k fx68k
(
	.clk				( clk_sys    	),
	.HALTn			( 1'b1			),
	.extReset		( reset			),
	.pwrUp			( reset			),
	.enPhi1			( ce_bus_p		),
	.enPhi2			( ce_bus_n		),
	
	.eRWn				( cpu_rw 		), 
	.ASn				( cpu_as_n		),
	.UDSn				( cpu_uds_n		),
	.LDSn				( cpu_lds_n		),
	
	.FC0				( cpu_fc[0]		),
	.FC1				( cpu_fc[1]		),
	.FC2				( cpu_fc[2]		),
	
	.BGn				(					),
	.DTACKn			( ~cpu_dtack	),
	.VPAn				( ~cpu_int_ack	),
	.BERRn			( 1				),
	.BRn				( 1				),
	.BGACKn			( 1				),
	.IPL0n			( cpu_ipl[0]	),
	.IPL1n			( cpu_ipl[1]	),
	.IPL2n			( cpu_ipl[0]	),		// ipl 0 and 2 are tied together on 68008
	.iEdb				( cpu_din		),
	.oEdb				( cpu_dout		),
	.eab				( cpu_addr16	)
);

endmodule
