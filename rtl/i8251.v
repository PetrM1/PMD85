// *******************************************************
// Verilog implementation of MHB8251 - clone of i8251
// 2022 Petr Mrzena
//
//  only Async is implemented

`default_nettype none

module i8251(

	
	input wire CLK,
	input wire RESET,
	input wire CS_n,
	input wire WR_n,
	input wire RD_n,
	input wire CD,			// 1 = Control, 0 = Data
	inout wire [7:0] D,
	
	input wire RxD,
	output reg RxRDY,
	input wire RxC_n,
// SYNDET???

	output reg TxD,
	output wire TxRDY, // = buffer is empty
	output reg TxEMPTY,
	input wire TxC_n,

	input wire DSR_n,
	output reg DTR_n,

	input wire CTS_n,
	output reg RTS_n
);

//
//// Mode instruction  - Asynchronous mode
reg [1:0] S; // D7+6 - Number of stop bits; 00 = invalid, 01 = 1 bit, 10 = 1.5 bit, 11 = 2 bits
reg EP;      // D5 - Even parity generation/check; 1 = even, 0 = odd
reg PEN;     // D4 - Parity enable; 1 = enable, 0 = disable
reg [1:0] L; // D3+2 - Character lenght; 00 = 5 bits, 01 = 6 bits,  10 = 7 bits, 11 = 8 bits
reg [1:0] B; // D1+0 - Baud rate factor; 00 = Sync Mode, 01 = 1x, 10 = 16x, 11 = 64x
//
//// Mode instruction  - Synchronous mode
reg SCS;     // D7 - Single character sync; 1 = single, 0 = double character sync
reg ESD;     // D6 - External sync detect; 1 = SYNDET is an input, 0= output
//wire EP;      // D5 - Even parity generation/check; 1 = even, 0 = odd
//wire PEN      // D4 - Parity enable; 1 = enable, 0 = disable
//wire [1:0] L; // D3+2 - Character lenght; 00 = 5 bits, 01 = 6 bits,  10 = 7 bits, 11 = 8 bits
//wire [1:0] B; // D1+0 - Baud rate factor; 00 = Sync Mode!
//
//// Command
//wire EH;   // D7 - Enter hunt mode; 1 = enable search for Sync Characters
//wire IR;   // D6 - Internal RESET - "high" returns 8251 to Mode Instruction Format
//wire RTD;  // D5 - Request to send - "high" will force /RTS output to zero
//wire ER;   // D4 - Error RESET - 1 = reset all error flags (PE, OE, FE)
reg SBRK; // D3 - Send break character - 1 = forces TxD "low", 0 = normal operation
reg RxE;  // D2 - Receive enable, 1 = enable, 0 = disable
//wire DTR;  // D1 - Data terminal ready - "high" will force DTR output to zero
reg TxEN; // D0 - Transmit enable - 1 = enable, 0 = disable
//
//
//// Status
reg DSR;    // D7 - Data set Ready
reg SYNDET; // D6 - 
reg FE;     // D5 - Framing Error (Async Only), The FE is set when a valid StopBit is not detected at the end
//				 //      of every character. It is reset by the ER bit of the Command Instruction. FE does not inhibit the operation of the 8251.
reg OE;     // D4 - Overrun error - The OE flag is set when the CPU does not read a character before the next 
//			    //      one becomes available. It is reset by the ER bit of the Command Instruction. OE does not inhibit operation of the 8251; 
//				 //      however the previously overrun character is lost
reg PE;     // D3 - Parity Error - The PE flag is set when a parity error is detected. It is reset by the ER bit if the Command Instruction.
//				 //      PE does not inhibit operation of the 8251
//wire TxE;    // D2 - Transmitter empty
//wire RxRDY;  // D1 - Receiver ready to be read by CPU from 8251
//wire TxRDY;  // D0 - Transmitter ready to accept a data character, 0 when character loaded from CPU

//----------------------------
wire RD = ~(CS_n || RD_n);
wire WR = ~(CS_n || WR_n);
reg TxRDYStatus;
reg TxRDYStatusSet;
reg TxRDYStatusReset;
assign TxRDY = TxRDYStatus && TxEN && ~CTS_n;
reg RxRDYSet;
reg RxRDYReset;
reg FESet;
reg OESet;
reg PESet;
reg ErrorsReset;
reg [1:0] mode = 2'd0; // 0 = Instruction, 1 = SyncChar1, 2 = SyncChar2, 3 = Command
reg [7:0] syncChar1;
reg [7:0] syncChar2;
wire [3:0] charLenBits = (L == 2'b00) ? 4'd4 : (L == 2'b01) ? 4'd5 : (L == 2'b10) ? 4'd6 : 4'd7; // 00 = 5 bits, 01 = 6 bits,  10 = 7 bits, 11 = 8 bits
wire [6:0] baudRateDiv = (~B[1]) ? 7'd0 : (~B[0]) ? 7'd15 : 7'd63; // 00 = Sync Mode, 01 = 1x, 10 = 16x, 11 = 64x
wire [6:0] baudHalfRateDiv = (~B[1]) ? 7'd0 : (~B[0]) ? 7'd7 : 7'd31; // 00 = Sync Mode, 01 = 1/2=1x, 10 = 16/2=8x, 11 = 64/2=32x
reg [3:0] RESET_Internal_cnt = 0;
wire RESET_Internal = RESET || (RESET_Internal_cnt != 4'd0);


always @(posedge TxRDYStatusSet or posedge TxRDYStatusReset)
begin
   if (TxRDYStatusReset)
      TxRDYStatus <= 0;
   else
      TxRDYStatus <= 1;
end

always @(posedge RxRDYSet or posedge RxRDYReset)
begin
   if (RxRDYReset)
      RxRDY <= 0;
   else
      RxRDY <= 1 && RxE;
end

always @(posedge FESet or posedge OESet or posedge PESet or posedge ErrorsReset)
begin
   if (ErrorsReset)
   begin
      FE <= 1'b0;
      OE <= 1'b0;
      PE <= 1'b0;   
   end
   else if (FESet)
      FE <= 1'b1;
   else if (OESet)      
      OE <= 1'b1;
   else if (PESet)      
      PE <= 1'b1;   
end


// *********************************************************************************************
// Instruction, command and data read from CPU
//

reg [7:0] TxDataBuffer;
reg [7:0] RxDataBuffer;
reg WR_last;

wire WRx = (WR) && (WR == ~WR_last);

always @(posedge CLK)
begin
	
   if (RESET_Internal)
   begin
      if (RESET_Internal_cnt != 4'd0)
         RESET_Internal_cnt <= RESET_Internal_cnt - 1'b1;
      mode         <= 2'd0;
      RTS_n        <= 1'b1; // Request to send - "high" will force /RTS output to zero
      RxE          <= 1'b0; // Receive enable, 1 = enable, 0 = disable
      DTR_n        <= 1'b1; // Data terminal ready - "high" will force DTR output to zero
      TxEN         <= 1'b0; // Transmit enable - 1 = enable, 0 = disable
      ErrorsReset  <= 1'b1;
      TxDataBuffer <= 8'd0;
	end
   	
   else 
   begin
      TxRDYStatusReset <= 1'b0;
      ErrorsReset <= 1'b0;
      WR_last <= WR;
            
      if ((WR) && (WR == ~WR_last))
      begin
         
 
         if (CD == 1) // Instruction & Command
         begin
            if (mode == 2'd0) // Instruction
            begin
               // Common
               EP    <= D[5]; // Even parity generation/check; 1 = even, 0 = odd
               PEN   <= D[4]; // Parity enable; 1 = enable, 0 = disable
               L     <= D[3:2]; // Character lenght; 00 = 5 bits, 01 = 6 bits,  10 = 7 bits, 11 = 8 bits
               B     <= D[1:0]; // Baud rate factor; 00 = Sync Mode, 01 = 1x, 10 = 16x, 11 = 64x

               // Mode instruction  - Asynchronous mode
               S     <= D[7:6]; // Number of stop bits; 00 = invalid, 01 = 1 bit, 10 = 1.5 bit, 11 = 2 bits

               // Mode instruction  - Synchronous mode
               SCS   <= D[7]; // Single character sync; 1 = single, 0 = double character sync
               ESD   <= D[6]; // External sync detect; 1 = SYNDET is an input, 0= output

               mode  <= (D[1:0] == 2'b00) ? 2'd1 : 2'd3;
            end
			
            else if (mode == 2'd1) // SyncChar1
            begin
               syncChar1 <= D;
               mode <= (SCS) ? 2'd3 : 2'd2;
            end
            
            else if (mode == 2'd2) // SyncChar2
            begin
               syncChar2 <= D;
               mode <= 2'd3;
            end
			
            else //if (mode == 2'd3) // Command
            begin
               //wire EH;   // D7 - Enter hunt mode; 1 = enable search for Sync Characters
               if (D[6]) // IR ... D6 - Internal RESET - "high" returns 8251 to Mode Instruction Format
                  RESET_Internal_cnt <= 4'b0111;
               RTS_n <= ~D[5]; // Request to send - "high" will force /RTS output to zero
               if (D[4]) // ER ... D4 - Error RESET - 1 = reset all error flags (PE, OE, FE)
                  ErrorsReset <= 1'b1;
               SBRK <= D[3]; // Send break character - 1 = forces TxD "low", 0 = normal operation
               RxE <= D[2]; // Receive enable, 1 = enable, 0 = disable
               DTR_n <= ~D[1]; // Data terminal ready - "high" will force DTR output to zero
               TxEN <= D[0]; // Transmit enable - 1 = enable, 0 = disable
            end
         end
         else if (CD == 0) // data
            begin				 				
               TxDataBuffer <= D;
               TxRDYStatusReset <= 1'b1; // resetuj TxRDY				 
            end
      end
	end	
end
	 

// *********************************************************************************************
// Status read by CPU

wire [7:0] status = {~DSR_n, // Data set Ready
//wire [7:0] status = {DSR_d2, // Data set Ready
		1'd0, // SYNDET
		FE, // Framing Error
		OE, // Overrun error
		PE, // Parity Error
		TxEMPTY, // Transmitter empty
		RxRDY, // Receiver ready to be read by CPU from 8251
		TxRDYStatus  // Transmitter ready to accept a data character, 0 when character loaded from CPU
		};	
reg [7:0] DOut;
always @(posedge RD)
   DOut <= ((CD) ? status : RxDataBuffer);
      
reg DSR_d1;
reg DSR_d2;
      
always @(posedge CLK)
begin
   DSR_d1 <= ~DSR_n;
   DSR_d2 <= DSR_d1;
end

      
assign D = (RD) ? ((CD) ? status : RxDataBuffer) : 8'hzz;
reg RD_last;

always @(posedge RESET_Internal or posedge CLK)
begin
	if (RESET_Internal)
	begin
		RxRDYReset <= 1'b1;
	end
	else
   begin
      RxRDYReset <= 1'b0;
      RD_last <= RD;
      
      if ((RD) && (RD == ~RD_last))
      begin
         if (~CD)
            RxRDYReset <= 1'b1;
      end
   end
end



// *********************************************************************************************
// Transmitter 
//    inspired by code on http://www.nandland.com
	
  parameter s_IDLE          = 3'b000;
  parameter s_START_BIT  = 3'b001;
  parameter s_DATA_BITS  = 3'b010;
  parameter s_PARITY_BIT = 3'b011;
  parameter s_STOP_BITS  = 3'b100;  
   
  reg [7:0]    TxData;
  reg [2:0]    Tx_State     = 0;
  reg [7:0]    Tx_ClockCnt  = 0;
  reg [2:0]    Tx_BitIndex  = 0;  
  reg          Tx_Parity    = 0;
  reg          Tx_StopBitNr = 0;
  reg [7:0]    baudRateDivStop;
  /////S = Number of stop bits; 00 = invalid, 01 = 1 bit, 10 = 1.5 bit, 11 = 2 bits            
  /////wire [12:0] baudRateDivStopBits = (S == 2'b01) ? baudRateDiv : (S == 2'b10) ? baudRateDiv + baudRateDiv / 2 : 2*baudRateDiv; 
  
always @(posedge RESET_Internal or negedge TxC_n)
begin 
	if (RESET_Internal)
	begin
	   Tx_State       <= s_IDLE;
		TxEMPTY        <= 1'b1;
		TxD            <= 1'b1;
      TxRDYStatusSet <= 1'b1;
	end
	else begin	   

	TxRDYStatusSet <= 1'b0;
   
   case (Tx_State)
         s_IDLE :
         begin
            TxD           <= (SBRK) ? 1'b0 : 1'b1;
            TxEMPTY       <= 1'b1;				
            Tx_ClockCnt   <= 0;
            Tx_BitIndex   <= 0;
            Tx_Parity     <= ~EP;          // Even parity generation/check; 1 = even, 0 = odd
            			
            if ((~TxRDYStatus) && (TxEN) && (~CTS_n))
              begin
                TxEMPTY          <= 1'b0;
                TxRDYStatusSet   <= 1'b1; // nastav TXRDY
					 TxData           <= TxDataBuffer;
                Tx_State         <= s_START_BIT;
                baudRateDivStop  <= baudRateDiv;
              end
            else
              Tx_State <= s_IDLE;
         end // case: s_IDLE
         
         
         // Send out Start Bit. Start bit = 0
         s_START_BIT :
         begin
            TxD <= 1'b0;
             
            // Wait CLKS_PER_BIT-1 clock cycles for start bit to finish
            if (Tx_ClockCnt < baudRateDiv)
              begin
                Tx_ClockCnt <= Tx_ClockCnt + 1;
                Tx_State    <= s_START_BIT;
              end
            else
              begin
                Tx_ClockCnt <= 0;
                Tx_State    <= s_DATA_BITS;
              end
         end // case: s_START_BIT
         
   
         // Wait CLKS_PER_BIT-1 clock cycles for data bits to finish         
         s_DATA_BITS :
         begin
            TxD <= TxData[Tx_BitIndex];
             				
            if (Tx_ClockCnt < baudRateDiv)
              begin
                Tx_ClockCnt <= Tx_ClockCnt + 1;
                Tx_State    <= s_DATA_BITS;
              end
            else
              begin
                Tx_ClockCnt <= 0;
                 
				if (TxData[Tx_BitIndex])
					Tx_Parity <= ~Tx_Parity;
					
                // Check if we have sent out all bits
                if (Tx_BitIndex < charLenBits)
                  begin
                    Tx_BitIndex <= Tx_BitIndex + 1;
                    Tx_State    <= s_DATA_BITS;
                  end
                else
                  begin
                    Tx_BitIndex <= 0;
                    Tx_ClockCnt  <= 0;
                    Tx_StopBitNr <= 0;
                  // PEN = Parity enable; 1 = enable, 0 = disable
                    Tx_State   <= (PEN) ? s_PARITY_BIT : s_STOP_BITS;
                  end
              end
         end // case: s_DATA_BITS
         
         // Send out Parity bit.
         s_PARITY_BIT:
         begin
            TxD <= Tx_Parity;
				 
            // Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
            if (Tx_ClockCnt < baudRateDiv)
              begin
                Tx_ClockCnt  <= Tx_ClockCnt + 1;
                Tx_State     <= s_PARITY_BIT;
              end
            else
              begin                
                Tx_ClockCnt  <= 0;
                Tx_StopBitNr <= 0;
                Tx_State     <= s_STOP_BITS;
              end
         end // case: s_PARITY_BIT 
         
                 
         // Send out Stop bit(s).  Stop bit(s) = 1, 1.5, 2
         s_STOP_BITS :
         begin
            TxD <= 1'b1;
				            			 
            // Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
            // [1:0] S =  Number of stop bits; 00 = invalid, 01 = 1 bit, 10 = 1.5 bit, 11 = 2 bits
            if (Tx_ClockCnt < baudRateDivStop)
              begin
                Tx_ClockCnt <= Tx_ClockCnt + 1;
                Tx_State     <= s_STOP_BITS;
              end
            else
              begin		 
                Tx_ClockCnt   <= 0;
                Tx_StopBitNr  <= 1;
                baudRateDivStop <= S[0] ? baudRateDiv : baudHalfRateDiv;
                Tx_State      <= ((~S[1]) || Tx_StopBitNr) ? s_IDLE : s_STOP_BITS;
              end
         end // case: s_STOP_BITS
         
        default :
          Tx_State <= s_IDLE;
         
      endcase
   end
end

// *********************************************************************************************
// Receiver 
//    inspired by code on http://www.nandland.com

reg [7:0]    RxData;
reg [2:0]    Rx_State     = 0;
reg [7:0]    Rx_ClockCnt  = 0;
reg [2:0]    Rx_BitIndex  = 0;  
reg          Rx_Parity    = 0;
reg          RxD_DR;
reg          RxD_DR2;



// Purpose: Double-register the incoming data.
// This allows it to be used in the UART RX Clock Domain.
// (It removes problems caused by metastability)
always @(posedge RxC_n)
begin
   RxD_DR2 <= RxD;
   RxD_DR  <= RxD_DR2;
end

always @(posedge RESET_Internal or posedge RxC_n)
begin
 
   if (RESET_Internal)
   begin
      Rx_State     <= s_IDLE;
      RxDataBuffer <= 8'd0;
   end
   else 
   begin         
      FESet    <= 1'b0;
      OESet    <= 1'b0;
      PESet    <= 1'b0;
      RxRDYSet <= 1'b0;   
      case (Rx_State)
         s_IDLE :
         begin
            RxData      <= 8'd0;
            Rx_ClockCnt <= 0;
            Rx_BitIndex <= 0;
            Rx_Parity   <= ~EP;       // Even parity generation/check; 1 = even, 0 = odd
             
            if (RxD_DR == 1'b0)          // Start bit detected
            begin
               // reg [1:0] B; // D1+0 - Baud rate factor; 00 = Sync Mode, 01 = 1x, 10 = 16x, 11 = 64x
               if (B[1])               
                  Rx_State <= s_START_BIT;
               else
                  Rx_State <= s_DATA_BITS; // skip waiting for start bit in case of 1x clock
            end
            else
              Rx_State <= s_IDLE;
         end
         
         // Check middle of start bit to make sure it's still low
         s_START_BIT :
         begin
            if (Rx_ClockCnt == baudHalfRateDiv)
              begin
                if (RxD_DR == 1'b0)
                  begin
                    Rx_ClockCnt <= 0;  // reset counter, found the middle
                    Rx_State    <= s_DATA_BITS;
                  end
                else
                  Rx_State <= s_IDLE;
              end
            else
              begin
                Rx_ClockCnt <= Rx_ClockCnt + 1;
                Rx_State    <= s_START_BIT;
              end
         end // case: s_START_BIT
                  
         // Wait CLKS_PER_BIT-1 clock cycles to sample serial data
         s_DATA_BITS :
         begin
            if (Rx_ClockCnt < baudRateDiv)
            begin
               Rx_ClockCnt <= Rx_ClockCnt + 1;
               Rx_State    <= s_DATA_BITS;
            end
            else
            begin
               Rx_ClockCnt         <= 0;
               RxData[Rx_BitIndex] <= RxD_DR;
               if (RxD_DR)
                  Rx_Parity <= ~Rx_Parity;
                 
               // Check if we have received all bits
               if (Rx_BitIndex < charLenBits)
               begin
                  Rx_BitIndex <= Rx_BitIndex + 1;
                  Rx_State    <= s_DATA_BITS;
               end
               else
               begin
                  Rx_BitIndex <= 0;
                  // PEN = Parity enable; 1 = enable, 0 = disable
                  Rx_State    <= (PEN) ? s_PARITY_BIT : s_STOP_BITS;
               end
            end
         end // case: s_DATA_BITS     
         
         // Receive Parity bit.
         s_PARITY_BIT:
         begin
            // Wait CLKS_PER_BIT-1 clock cycles for Parity bit 
            if (Rx_ClockCnt < baudRateDiv)
            begin
               Rx_ClockCnt <= Rx_ClockCnt + 1;
               Rx_State    <= s_PARITY_BIT;
            end
            else
            begin              
               Rx_ClockCnt  <= 0;          
               Rx_State     <= s_STOP_BITS;
               if (RxD_DR != Rx_Parity)
                  PESet <= 1'b1;
            end
         end // case: s_PARITY_BIT      
     
         // Receive Stop bit.  Stop bit = 1
         s_STOP_BITS:
         begin
            // Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
            if (Rx_ClockCnt < baudRateDiv)
              begin
                Rx_ClockCnt <= Rx_ClockCnt + 1;
                Rx_State    <= s_STOP_BITS;
              end
            else
            begin
               Rx_ClockCnt   <= 0;
               Rx_State      <= s_IDLE;               
               RxDataBuffer  <= RxData;
               RxRDYSet      <= 1'b1;
               if (RxD_DR != 1'b1)
                  FESet <= 1'b1;
               if (RxRDY)
                  OESet <= 1'b1;                  
            end
         end // case: s_STOP_BITS
         
         default :
            Rx_State <= s_IDLE;         
      endcase   
   end
end
 
endmodule //i8251

