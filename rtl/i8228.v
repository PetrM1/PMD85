
module i8228(
	// Memory Read
	output memr_n,

	// Memory Write
	output memw_n,

	// IO Read
	output ior_n,

	// IO Write
	output iow_n,
	
	// Interrupt Acknowledge
	output inta_n,

	
	// data from-to CPU 8080
	inout [7:0] d8080,

	// data from-to system bus
	inout [7:0] db,

	// Bus Enable Input
	input busen_n,

	// Status Strobe from 8224
	input ststb_n,

	// Data Bus In Control from 8080
	input dbin,

	// WR from 8080
	input wr_n,

	// Hold Acknowledge from 8080
	input hlda,
	
	// this is not present on original chip - instead if you need one level interrupt you were suppose to put 12V on inta_n pin. 
	// This is replacement of this behavior
	input inta_12V
	
);

wire memr;
wire memw;
wire ior;
wire iow;
wire inta;
reg[7:0] status; // CPU status


assign d8080 = (dbin) ? ((inta & inta_12V) ? 8'hFF : db) : 8'hzz; // RST 7 or system bus
assign db = ( ~busen_n & ~dbin ) ? d8080 : 8'hzz;

/*
Bidirectional data bus. The processor also transiently sets here the "processor state", providing information about what the processor is currently doing:

    D0 reading interrupt command. In response to the interrupt signal, the processor is reading and executing a single arbitrary command with this flag raised. Normally the supporting chips provide the subroutine call command (CALL or RST), transferring control to the interrupt handling code.
    D1 reading (low level means writing)
    D2 accessing stack (probably a separate stack memory space was initially planned)
    D3 doing nothing, has been halted by the HLT instruction
    D4 writing data to an output port
    D5 reading the first byte of an executable instruction
    D6 reading data from an input port
    D7 reading data from memory
*/

// internal signals only

assign memr = ( ~status[0] &  status[1] & ~status[3] & ~status[4] & ~status[6] & status[7] ); // ~INT & nWO & ~HLTA & ~OUT & ~INP & MEMR
// overeno! assign memr_n = ~( dbin & ~status[0] &  status[1] & ~status[4] & ~status[6] & status[7] ); // ~INT & nWO & ~OUT & ~INP & MEMR
assign memw = ( ~status[0] &  ~status[1] & ~status[3] & ~status[4] & ~status[6] & ~status[7] ); // ~INT & ~nWO & ~HLTA & ~OUT & ~INP & ~MEMR
// overeno! assign memw_n = ~( ~busen_n & ~wr_n &  ~status[4] ); 

assign ior = ( ~status[0] &  status[1] & ~status[2] & ~status[3] & ~status[4] & status[6] & ~status[7] ); // ~INT & nWO & ~STACK & ~HLTA & ~OUT & INP & ~MEMR
// overeno! assign ior_n  = ~( ~busen_n & status[6]  ); 

assign iow  = ( ~status[0] &  ~status[1] & ~status[2] & ~status[3] & status[4] & ~status[6] & ~status[7] ); // ~INT & ~nWO & ~STACK & ~HLTA & OUT & ~INP & ~MEMR
// overeno! assign iow_n = ~( ~busen_n & ~wr_n &  status[4] ); 


assign inta = ( status[0] );




// assigments to output pins
assign memr_n = ~( dbin & memr );
assign memw_n = ~( ~busen_n & ~wr_n & memw ); 
assign ior_n  = ~( ~busen_n & ior ); 
assign iow_n  = ~( ~busen_n & ~wr_n & iow ); 
assign inta_n = ~( inta );


initial 
begin
	status = 8'd0;
end


always @(negedge ststb_n) 
begin
	status <= d8080;
end


endmodule // i8228