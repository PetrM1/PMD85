module i8251(

	
	input clk,
	input reset,
	input cs_n,
	input wr_n,
	input rd_n,
	input cd,
	inout [7:0] d,
	
	input RxC_n,
	input TxC_n
);
//
//// Mode instruction  - Asynchronous mode
//wire [1:0] S; // D7+6 - Number of stop bits; 00 = invalid, 01 = 1 bit, 10 = 1.5 bit, 11 = 2 bits
//wire EP;      // D5 - Even parity generation/check; 1 = even, 0 = odd
//wire PEN;     // D4 - Parity enable; 1 = enable, 0 = disable
//wire [1:0] L; // D3+2 - Character lenght; 00 = 5 bits, 01 = 6 bits,  10 = 7 bits, 11 = 8 bits
//wire [1:0] B; // D1+0 - Baud rade factor; 00 = Sync Mode, 01 = 1x, 10 = 16x, 11 = 64x
//
//// Mode instruction  - Synchronous mode
//wire SCS;     // D7 - Single character sync; 1 = single, 0 = double character sync
//wire ESD;     // D6 - External sync detect; 1 = SYNDET is an input, 0= output
//wire EP;      // D5 - Even parity generation/check; 1 = even, 0 = odd
//wire PEN      // D4 - Parity enable; 1 = enable, 0 = disable
//wire [1:0] L; // D3+2 - Character lenght; 00 = 5 bits, 01 = 6 bits,  10 = 7 bits, 11 = 8 bits
//wire [1:0] B; // D1+0 - Baud rade factor; 00 = Sync Mode!
//
//// Command
//wire EH;   // D7 - Enter hunt mode; 1 = enable search for Sync Characters
//wire IR;   // D6 - Internal RESET - "high" returns 8251 to Mode Instruction Format
//wire RTD;  // D5 - Request to send - "high" will force /RTS output to zero
//wire ER;   // D4 - Error RESET - 1 = reset all error flags (PE, OE, FE)
//wire SBRK; // D3 - Send break character - 1 = forces TxD "low", 0 = normal operation
//wire RxE;  // D2 - Receive enable, 1 = enable, 0 = disable
//wire DTR;  // D1 - Data terminal ready - "high" will force DTR output to zero
//wire TxEN; // D0 - Transmit enable - 1 = enable, 0 = disable
//
//
//// Status
//wire DSR;    // D7 - Data set Ready
//wire SYNDET; // D6 - 
//wire FE;     // D5 - Framing Error (Async Only), The FE is set when a valid StopBit is not detected at the end
//				 //      of every character. It is reset by the ER bit of the Command Instruction. FE does not inhibit the operation of the 8251.
//wire OE;     // D4 - Overrun error - The OE flag is set when the CPU does not read a character before the next 
//			    //      one becomes available. It is reset by the ER bit of the Command Instruction. OE does not inhibit operation of the 8251; 
//				 //      however the previously overrun character is lost
//wire PE;     // D3 - Parity Error - The PE flag is set when a parity error is detected. It is reset by the ER bit if the Command Instruction.
//				 //      PE does not inhibit operation of the 8251
//wire TxE;    // D2 - Transmitter empty
//wire RxRDY;  // D1 - Receiver ready to be read by CPU from 8251
//wire TxRDY;  // D0 - Transmitter ready to accept a data character, 0 when character loaded from CPU

//----------------------------

reg mode; // 0 = Instruction, 1 = Command

reg newTxData = 0;
reg newTxDataSet = 0;
reg newTxDataReset = 0;
reg [7:0] TxBit;

wire [7:0] status;
	
assign status = {5'd0, (TxBit == 8'hFF), 1'b0, (TxBit == 8'hFF)};
	
assign d = (~cs_n & ~rd_n) ?  status : 8'hzz;
	
initial begin

	mode = 0;
	
end

always @(newTxDataReset or newTxDataSet) begin	
	if (newTxDataReset)
		newTxData <= 0;
	else if (newTxDataSet) 
		newTxData <= 1;
end	


	
always @(negedge cs_n)
begin
	if (~wr_n)
		newTxDataSet <= 1;
	else
		newTxDataSet <= 0;
end
	
always @(posedge TxC_n)
begin
	if (newTxData)
	begin
		TxBit <= 8'd10;
		newTxDataReset <= 1;
	end
	else
	begin
		newTxDataReset <= 0;
		if (TxBit == 8'hFF)
		;
		else if (TxBit == 8'h00)
			TxBit <= 8'hFF;
		else
			TxBit <= TxBit - 1;

	end;
end
	
always @(posedge reset) begin

	mode = 0;
	
end	

endmodule //i8251

