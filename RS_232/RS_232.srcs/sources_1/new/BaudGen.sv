`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/12/2024 06:10:34 PM
// Design Name: 
// Module Name: BaudGen
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//  Generate a serial link at maximum speed 115200 bauds
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//  clk is a 25MHz clock configured from the 100MHz Oscillator on W5 Pin
//////////////////////////////////////////////////////////////////////////////////

/*
To achieve a closely approximate baud rate of 115200
-> We can use an accumulator to track when we should have a 'baud tick' occur.
-> For example, with a clk frequency of 2MHz, the ratio for a 115200 baud is 17.356
-> or 2M/115200 or 1024/59.
-> Using a 10-bit accumulator that increments by 59, we 'tick' when the accumulator
-> overflows marking a valid instance of the 115200 baud rate.
-> Therefore, the baud tick is the 11th bit of some accuracy register or variable that
-> represents the carry-out.
*/
module BaudGen #(parameter CLKFREQ = 25000000, baudRate = 115200,
                accWidth = 16)
    (
    input logic clk,
    output logic baud
    );
    /*
    -> baudRate << (accWidth-4): shifts baudRate left accWidth-4 bits, effectively
    ->-> multiplying by 2^(accWidth-4)
    -> CLKFREQ >> 4 ~ CLKFREQ/16
    -> CLKFREQ >> 5 ~ CLKFREQ/32
    -> + and / ops fine-tune increment value
    -> This creates a value when repeatedly added in a fixed-point accumulator,
    -> will overflow at a rate relative to the desired baud.
    -> (CLKFREQ >> 5) and (CLKFREQ >> 4) also minimize rounding errors
    */
    localparam baudShift = baudRate << (accWidth-4);
    localparam clkTerm = CLKFREQ >> 5;
    localparam clkDiv = CLKFREQ >> 4;
    localparam baudIncrementer = (baudShift+clkTerm) / clkDiv;

    logic [accWidth:0] accumulator; //17 bit accumulator - last bit for carry out
    always_ff @(posedge clk) begin
        //Use the first 16 bits from the previous result but save full 17 bit result to track the overflow without changing it
        accumulator <= accumulator[accWidth-1:0] + baudIncrementer;
    end
    assign baud = (accumulator[accWidth]); //accumulator carry out
endmodule
