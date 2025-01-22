`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/08/2024 06:25:31 PM
// Design Name: 
// Module Name: RS_232
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module RS_232
    (
    input logic clk,
    input logic RxD,
    input logic [7:0] gpIn, //general purpose input
    output logic TxD,
    output logic RxD_idle,
    output logic RxD_packetEnd,
    output logic [7:0] gpOut //general purpose output
    );
    
    logic oversampledTick, tick;
    logic RxD_dataReady;
    logic [7:0] RxD_data;
    logic TxD_busy;
    
    //Baud generator for transmitter, 115200 bits per second, 1 sample per bit
    BaudGen #(.CLKFREQ(25000000), .baudRate(115200), .Oversampling(1)) basicTick(.clk(clk), .enable(TxD_busy), .tick(tick));
    
    //Baud generator for reciever, 115200 bits per second, oversampled at default 8 samples per bit
    BaudGen #(.CLKFREQ(25000000), .baudRate(115200), .Oversampling(8)) sampledTick(.clk(clk), .enable(1'b1), .tick(oversampledTick));
    
    RxD receiver(.clk(clk), .RxD_in(RxD), .oversampledTick(oversampledTick), 
                 .data_ready(RxD_dataReady), .outData(RxD_data), .RxD_idle(RxD_idle),
                 .RxD_packetEnd(RxD_packetEnd));
    //synchronize gpOutput with data ready
    always_ff @(posedge clk)
        if(RxD_dataReady)   gpOut <= RxD_data;
        
    TxD transmitter(.clk(clk), .BaudTick(tick), .start(/*RxD_dataReady*/1'b1), .inData(gpIn),
                    .busy(TxD_busy), .txd_out(TxD));
endmodule
