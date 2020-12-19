
module i8255(

	inout [7:0] PA,
	inout [7:0] PB,
	inout [7:0] PC,
	input [7:0] DIn,
	output [7:0] DOut,

	input clk,
	input RD_n,
	input WR_n,
	input [1:0] A,
	input RESET,
	input CS_n
);



reg [1:0] grpAmode; // port A + port C[7:4]
reg grpBmode; // port B + port C[3:0]
reg PAisInput;
reg PBisInput;
reg PCLisInput;
reg PCHisInput;

reg [7:0] PAreg;
reg [7:0] PBreg;
reg [7:0] PCreg;
reg [7:0] Dreg;


assign PA = ( !PAisInput ) ? PAreg : 8'hzz;
assign PB = ( !PBisInput ) ? PBreg : 8'hzz;
assign PC = { ( !PCHisInput ) ? PCreg[7:4] : 4'hz ,
		( !PCLisInput ) ? PCreg[3:0] : 4'hz  };

wire [7:0] drat;	
assign DOut = (~RD_n & ~CS_n & WR_n) ? drat : 8'hzz;
		
		


assign drat =  ( A == 2'b00 ) ? PA : 
					( A == 2'b01 ) ? PB :
					( A == 2'b10) ? PC : 
					8'hzz;	
		
reg [7:0] control;
// control WORD
// GROUP B
// control[0] => portC [3:0]: 1=input, 0=output
// control[1] => portB: 1=input, 0=output
// control[2] => mode selection: 0=mode 0, 1=mode 1
// GROUP A
// control[3] => portC [7:4]: 1=input, 0=output
// control[4] => portA: 1=input, 0=output
// control[6:5] => mode selection: 00=mode 0, 01=mode1, 1x=mode2
// control[7] => mode set flag: 1=active



// control WORD - port C single bit set/reset when port C is used as status/control port for ports A+B (if bits are configured as output)
// control[0] => bit set / reset: 1=set, 0=reset
// control[3:1] => bit select
// control[6:4] => DON'T CARE
// control[7] => bit set / reset flag: 0=active




//assign D = ( RD_n ) ? 8'hzz : Dout;

 initial begin
 
	// set both groups to mode 0
	grpAmode = 0;
	grpBmode = 0;
	// all ports to input mode
	PAisInput = 1;
	PBisInput = 1;
	PCLisInput = 1;
	PCHisInput = 1;
	
 end

//always @(negedge WR_n or posedge RESET) begin

always @(posedge clk) 
begin
	if (RESET) begin
		// set both groups to mode 0
		grpAmode = 0;
		grpBmode = 0;
		// all ports to input mode
		PAisInput = 1;
		PBisInput = 1;
		PCLisInput = 1;
		PCHisInput = 1;
	end 
	else if (~WR_n & ~CS_n & RD_n) 
	begin
		case (A)
			2'b00: PAreg <= DIn; // port A
			2'b01: PBreg <= DIn; // port B
			2'b10: PCreg <= DIn; // port C
			2'b11: begin // control word
					if ( DIn[7] == 1) begin
						// mode set flag
						control <= DIn;
						PCLisInput <= DIn[0];
						PBisInput <= DIn[1];
						grpBmode <= DIn[2];
						PCHisInput <= DIn[3];
						PAisInput <= DIn[4];
						grpAmode <= DIn[6:5];
					end 
					else begin
						// port C bit set / reset flag
						PCreg[DIn[3:2]] <= DIn[0];
					end
				end
		endcase
	end				 		 
end


endmodule // i8255
