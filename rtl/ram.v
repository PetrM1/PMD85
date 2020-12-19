module ram(




	input         reset,
	input         DDRAM_CLK,

	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

//	input  [27:0] addr,        // 256MB at the end of 1GB
//	output  [7:0] dout,        // data output to cpu
//	input   [7:0] din,         // data input from cpu
//	input         we,          // cpu requests write
//	input         rd,          // cpu requests read
//	output        ready        // dout is valid. Ready to accept new read/write.


	input clk_80M,
	input locked,
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
	

	inout [7:0] d,
	
	input clk_50M,
	input clk_sys,	
	input [7:0] addr,
	input [15:0] addrRamMAX,
	input ras_n,
	input cas_n,
	input we_n,
	
	
//	input [15:0] addrIn,
//	input [7:0] dataIn,
//	
//	input [15:0] addrOut,
//	output[7:0] out,
	
	 
	inout         ioctl_download , // signal indicating an active download
	inout   [7:0] ioctl_index,        // menu index used to upload the file
	inout         ioctl_wr,
	inout  [26:0] ioctl_addr,         // in WIDE mode address will be incremented by 2
	inout  [7:0] ioctl_dout,
	inout  [31:0] ioctl_file_ext	 
);
	

//assign out = {addrRamMAX[14:10], addrRamMAX[1:0]}; // <--- test co je na sbernici kdyz vzorkuji VIDEO
//assign out = ram_out;
	
	
reg [7:0] row;
reg [7:0] col;
reg rowValid;
reg colValid;

wire addrValid = ( rowValid & colValid );
wire [15:0] addrInternal = { row, col };
reg [15:0] addrRamMAXInternal;



//wire [15:0] addrOrig = { row[7], col[7:0], row[6:0] }; // PMD do addr MUX and bit shuffle - this is addr as is seen by PMD 


//assign d = ( en & ~ras_n & ~cas_n & we_n ) ? mem[addr_internal] : 8'bz;
//assign d = ( addrValid & we_n ) ? mem[addrInternal] : 8'bz;

//wire vysilamDRAM = ( addrValid & we_n );


wire [7:0] ram_in = ( ~cas_n & ~we_n) ? d : 8'bz;
wire [7:0] ram_out;

assign d = ( ~cas_n & we_n ) ? ram_out : 8'bz;


//wire [7:0] ram_outX = (row[0] == 1'b1) ? 8'hFF : 8'h00;
//assign d = ( addrValid & we_n ) ? ram_outX : 8'bz;

wire ready;

//ddram myddram
//(
//	.reset(reset),
//	.DDRAM_CLK(DDRAM_CLK),	
//	.DDRAM_BUSY(DDRAM_BUSY),
//	.DDRAM_BURSTCNT(DDRAM_BURSTCNT),
//	.DDRAM_ADDR(DDRAM_ADDR),
//	.DDRAM_DOUT(DDRAM_DOUT),
//	.DDRAM_DOUT_READY(DDRAM_DOUT_READY),
//	.DDRAM_RD(DDRAM_RD),
//	.DDRAM_DIN(DDRAM_DIN),
//	.DDRAM_BE(DDRAM_BE),
//	.DDRAM_WE(DDRAM_WE),
//
//
//
//	.addr(addrRamMAXInternal),        // 256MB at the end of 1GB
//	.dout(ram_out),        // data output to cpu
//	.din(ram_in),         // data input from cpu
//	.we(write & ~cas_n & ~we_n & ~reset),          // cpu requests write
//	.rd(~cas_n & we_n & ~reset),          // cpu requests read
//	.ready(ready)        // dout is valid. Ready to accept new read/write.	
//);



	
	
//sdram mySdram
//(
//	//.*,
//.SDRAM_CLK(SDRAM_CLK),
//.SDRAM_CKE(SDRAM_CKE),
//.SDRAM_A(SDRAM_A),
//.SDRAM_BA(SDRAM_BA),
//.SDRAM_DQ(SDRAM_DQ),
//.SDRAM_DQML(SDRAM_DQML),
//.SDRAM_DQMH(SDRAM_DQMH),
//.SDRAM_nCS(SDRAM_nCS),
//.SDRAM_nCAS(SDRAM_nCAS),
//.SDRAM_nRAS(SDRAM_nRAS),
//.SDRAM_nWE(SDRAM_nWE),
//	
//	.init(~locked),
//	.clk(clk_80M),
//	.dout(ram_out),
//	.din (ram_in),
//	.addr(addrRamMAX),
//	.we(~cas_n & ~we_n & ~reset),
//	.rd(~cas_n & we_n & ~reset),
//	.ready(ready)
//);
// 
//  













reg write;
reg writeInternal;

dpram #(.ADDRWIDTH(16)) myRam
(
	.clock(clk_sys),
	//.address_a(addrRamMAXInternal),
	.address_a(addrRamMAX),
	.data_a(ram_in),
	//.wren_a(~cas_n & write),
	.wren_a(~cas_n & ~we_n),
	//.wren_a(write & ~cas_n & ~we_n),
	.q_a(ram_out)	
	
	
	,  .address_b(ioctl_addr_HW),
	.data_b(ioctl_dout),
	//.data_b(8'hFF),
	.wren_b(ioctl_wr & ioctl_download),	
);





wire [15:0] ioctl_addr_HW;


//hps_io hps_io
//(
//	.clk_sys(clk_sys),
//	
//	
//	.ioctl_wr(ioctl_wr),
//	.ioctl_addr(ioctl_addr),
//	.ioctl_dout(ioctl_data),
//	.ioctl_download(ioctl_download),
//	.ioctl_index(ioctl_index)  
//);

assign ioctl_addr_HW = { 2'b11, ioctl_addr[13:0] };

//---------------------------------------------------------------------
initial begin

	row = 0;
	col = 0;
	rowValid = 0;
	colValid = 0;
	
end

//always @(negedge clk_sys)
//begin
//		writeInternal <= write;
//
//end
//
always @(negedge cas_n)
begin
	addrRamMAXInternal <= addrRamMAX;
	write <= ~we_n;

end

//always @(ras_n, cas_n) begin
////always @(posedge clk_sys) begin
////always @(posedge clk_50M) begin
//
//	if (~ras_n & cas_n) begin // eliminate "hidden refresh"
//		row <= addr;
//		rowValid <= 1;
//	end 
//
////	if (ras_n & cas_n) 
////		rowValid <= 0;
//
//	if (~cas_n) begin
//		if (~ras_n) begin
//			col <= addr;
//			colValid <= 1;
//			addrRamMAXInternal <= addrRamMAX;
//			write <= ~we_n;
//		end else begin
//			rowValid <= 0;
//			colValid <= 0;
//		end
//	end
//
//	if (cas_n & ras_n) begin 
//		rowValid <= 0;
//		colValid <= 0;
//	end
//end


//always @(addrValid, we_n) begin
// 
//	if ( ~we_n & addrValid ) begin
//
//		//mem[addrInternal] <= d;
//		$display("%t RAM Write %h (%h) value %h", $time, addrInternal, addrOrig, d ); 
//	end
//
//	if ( we_n & addrValid ) begin
//
////		$display("%t RAM Read %h (%h) value %h", $time, addrInternal, addrOrig, d ); 
//	end
//end

endmodule // ram