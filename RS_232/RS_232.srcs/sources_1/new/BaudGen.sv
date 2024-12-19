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

The following module follows this reasoning but with some mathematical improvements
-> to improve accuracy and support an oversampling tick feature which functions simply as a scale factor without much changing the accumulator logic
*/
module BaudGen #(parameter CLKFREQ = 25000000, baudRate = 115200, oversampling = 1)
    (
    input logic clk,
    input logic enable,
    output logic tick //generate baud tick at specified baud * oversampling Factor
    );
    /*
    */
    //Logic to determine when is the best time to sample the RxD line
    //Calculate base-2 log of number
    //log2(8) = 3 (2^3=8)
    function integer log2(input integer x); 
    begin
        log2 = 0;
        while(x>>log2)  log2 = log2+1;
    end
    endfunction
    // +/- 2% timing error over a byte
    // -> by adding extra bits for timing error tolerance
    localparam accWidth = log2(CLKFREQ/baudRate)+8;
    localparam baudShiftLimiter = log2(baudRate*oversampling >> (31-accWidth)); //makes sure incremented calculation does not overflow

    /*
    -> Creates scaling factors for precise division
    -> Better manage larger numbers
    */
    localparam clkTerm = CLKFREQ >> (baudShiftLimiter+1);
    localparam clkDiv = CLKFREQ >> baudShiftLimiter;
    localparam baudIncrementer = ((baudRate*oversampling << (accWidth-baudShiftLimiter))+clkTerm) / clkDiv;


    logic [accWidth:0] accumulator; //Accumulator - last bit for carry out
    always_ff @(posedge clk) begin
        if(enable)
            accumulator <= accumulator[accWidth-1:0] + baudIncrementer[accWidth:0];
        else accumulator <= baudIncrementer[accWidth:0];
    end
    assign tick = accumulator[accWidth]; //accumulator carry out
endmodule
