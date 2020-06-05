module sysUnit #(
    parameter dataWidth = 32,
    parameter RowIndex = 0,
    parameter ColumnIndex = 0,
    parameter featureLen = 128,
    parameter SysDimension = 32
)
(
	clk,               // input clock
	rst,               // input reset
	enable,			   // input enable		
	weight,            // input weight
	featureIn,         // input feature
	preresult,         // input previous result
	featureOut,        // output feature  
	featurePass,       // pass feature
	weightPass         // pass weight 
);

// define the input
input clk;
input rst;
input enable;
input [dataWidth - 1:0] weight;
input [dataWidth - 1:0] featureIn;
input [dataWidth - 1:0] preresult;

//define the output
output [dataWidth - 1:0] featureOut;
reg [dataWidth - 1:0] featureOut;
output [dataWidth - 1:0] featurePass;
reg [dataWidth - 1:0] featurePass;
output [dataWidth - 1:0] weightPass;
reg [dataWidth - 1:0] weightPass;


parameter InitialLantency = 45;
parameter StartPlace = RowIndex + ColumnIndex + featureLen + InitialLantency  + 1;
parameter counterWidth = $clog2(InitialLantency + RowIndex + ColumnIndex + featureLen + 8);


parameter InitialStat = 1'b0;
parameter PipelineStat = 1'b1;

always @(posedge clk or negedge rst) begin : proc_weightPass
	if(~rst) begin
		weightPass <= 0;
	end else begin
		if(enable)
			weightPass <= weight;
		else
			weightPass <= weightPass;
	end
end

always @(posedge clk or negedge rst) begin : proc_featurePass
	if(~rst) begin
		featurePass <= 0;
	end else begin
		if(enable)
			featurePass <= featureIn;
		else
			featurePass <= featurePass;
	end
end


reg [counterWidth - 1: 0] counter;

reg state;

always @(posedge clk or negedge rst) begin : proc_state
	if(~rst) begin
		state <= InitialStat;
	end else begin
		if(state == InitialStat && counter == StartPlace) begin 
			state <= PipelineStat;
		end
		else begin 
			state <= state;
		end
	end
end


always @(posedge clk or negedge rst) begin : proc_counter
	if(~rst) begin
		counter <= 0;
	end else begin
		if(enable) begin 
			if(state == InitialStat && counter < StartPlace - 1)
				counter <= counter + 1;
			else if(state == InitialStat && counter ==  StartPlace - 1)
				counter <= 0;
			else if(state == PipelineStat && counter < featureLen - 1)
				counter <= counter + 1;
			else if(state == PipelineStat && counter == featureLen - 1)
			    counter <= 0;
			else
				counter <= counter + 1;
		end
		else begin 
			counter <= counter;
		end
	end
end



reg dataValid;

always @(posedge clk or negedge rst) begin : proc_dataValid
	if(~rst) begin
		dataValid <= 1'b0;
	end else begin
		if( state == InitialStat  && enable && counter >= RowIndex + ColumnIndex )
			dataValid <= 1'b1;
		else if(state == PipelineStat && enable)
			dataValid <= 1'b1;
		else
			dataValid <= 1'b0;
	end
end

reg dataLast;

always @(posedge clk or negedge rst) begin : proc_dataLast
	if(~rst) begin
		dataLast <= 0;
	end else begin
		if(state == InitialStat && enable && counter == RowIndex + ColumnIndex  + featureLen)
			dataLast <= 1'b1;
		else if(state == PipelineStat && enable && counter == featureLen - InitialLantency)
			dataLast <= 1'b1;
		else
			dataLast <= 1'b0;
	end
end

wire Mulvalid;
wire [dataWidth - 1:0] Mulresult;
wire Mullast;


floating_point_sys_adder sysMul (
  .aclk(clk),                                  // input wire aclk
  .s_axis_a_tvalid(dataValid),            // input wire s_axis_a_tvalid
  .s_axis_a_tdata(weight),              // input wire [31 : 0] s_axis_a_tdata
  .s_axis_a_tlast(dataLast),              // input wire s_axis_a_tlast
  .s_axis_b_tvalid(dataValid),            // input wire s_axis_b_tvalid
  .s_axis_b_tdata(featureIn),              // input wire [31 : 0] s_axis_b_tdata
  .m_axis_result_tvalid(Mulvalid),  // output wire m_axis_result_tvalid
  .m_axis_result_tdata(Mulresult),    // output wire [31 : 0] m_axis_result_tdata
  .m_axis_result_tlast(Mullast)    // output wire m_axis_result_tlast
);

wire Accvalid;
wire [dataWidth - 1:0] Accresult;
wire Acclast;

floating_point_Sys_Acc sysAcc (
  .aclk(clk),                                  // input wire aclk
  .s_axis_a_tvalid(Mulvalid),            // input wire s_axis_a_tvalid
  .s_axis_a_tdata(Mulresult),              // input wire [31 : 0] s_axis_a_tdata
  .s_axis_a_tlast(Mullast),              // input wire s_axis_a_tlast
  .m_axis_result_tvalid(Accvalid),  // output wire m_axis_result_tvalid
  .m_axis_result_tdata(Accresult),    // output wire [31 : 0] m_axis_result_tdata
  .m_axis_result_tlast(Acclast)    // output wire m_axis_result_tlast
);


// 
reg [dataWidth - 1:0] temResult;

always @(posedge clk or negedge rst) begin : proc_temResult
	if(~rst) begin
		temResult <= 0;
	end else begin
		if(Acclast && Accvalid)
			temResult <= Accresult;
		else
			temResult <= temResult;
	end
end

always @(posedge clk or negedge rst) begin : proc_featureOut
	if(~rst) begin
		featureOut <= 0;
	end else begin
		if(state == PipelineStat && enable && counter == 2*SysDimension - (RowIndex + ColumnIndex))
			featureOut <= temResult;
		else if (state == PipelineStat && enable && counter == 2*SysDimension - (RowIndex + ColumnIndex))
			featureOut <= preresult;
		else
			featureOut <= featureOut;
	end
end


 
endmodule
