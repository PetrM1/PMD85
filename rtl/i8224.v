module i8224(

	// oscilator output - same as clk
	output osc,
	
	// phi 1+2 = 8080 Clocks
	output reg phi1,
	output reg phi2,
	
	// Status STB
	output ststb_n,
	
	// Reset output
	output reg reset,
	
	// Ready Output
	output reg ready,

	// clock input - instead of crystal used in real HW
	input clk,
	
	input sync,
	
	// Reset in
	input resetin_n,
	
	// Ready input from 8080
	input readyin
);

	
reg [3:0] tick;
	
assign osc = clk;	
assign ststb_n = ~( (phi1 & sync) | reset );
	

	
initial
begin
	tick = 0;
	reset = 0;
	ready = 1;
	phi1 = 1;
	phi2 = 0;
end	


always @(posedge clk) 
begin
	if (tick == 'd1)
		phi1 <= 1'b1;
		
	if (tick == 'd3) 
	begin		
		phi1 <= 1'b0;
		phi2 <= 1'b1;
	end
	
	if (tick == 'd8) 		
		phi2 <= 1'b0;
	
	if (tick == 'd9) 
		tick <= 4'd1;
	else
		tick <= tick + 1;
end


always @(posedge phi2) 
begin
	reset <= ~resetin_n;
	ready <= readyin;	
end


endmodule //i8224

