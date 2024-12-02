`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/13/2024 03:45:19 PM
// Design Name: 
// Module Name: RxD
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

/*
    Module assembles bitwise data coming in from 'RxD' line as it comes.
    ->  As a byte being received, it appears on the 'data' bus coming out.
    ->  Data_ready asserted when a complete byte has been recieved
    ->  Data is only valid when data_ready is asserted, otherwise don't use it as new data that may come that shuffles it
*/
module RxD(
        input logic clk,
        input logic RxD_in,
        input baudTick /*may not be needed but idk yet*/,
        input baud8tick /*sampling signal at 8 times the known baud*/, 
        output logic data_ready,
        output logic [7:0] outData
        );
    // incoming 'RxD_in' signal has no relationship with our clock
    // Use 2 D-FFs to oversample the signal and synchronize it to the clock domain
    // First FF captures the async signal
    // Second FF provides stability by preventing rapid signal changes

    logic [1:0] RxD_syncr; // a 2-bit shift register

    //(Still not sure I understand this whole 2FFs synchronizing thing to be honest)
    always_ff @(posedge clk) begin
        // so at the sampling frequency we update RxD synchronizer
        // 1. Moving the previous bit to MSB
        // 2. Capture the new RxD_in value at LSB
        if(baud8tick) RxD_syncr <= {RxD_syncr[0], RxD_in};
    end
    //Filter data, so short spikes on RxD line aren't mistaken with start bits
    logic [1:0] RxD_cntr; //used to track signal stability
    logic RxD_bit; //this is the actual bit that we take from all our signal processing
    always_ff @(posedge clk) begin
        //at the sampling rate, we use a noise filtering technique
        //-> called a "debounce" or "glitch filter" for digital inputs
        //-> This way the design doesn't hastily consider consistent spikes as accurate data and just waits for constant behavior to assign the RxD bit
        if(baud8tick) begin
            //increment when the signal is high consistently high
            if(RxD_syncr[1] && RxD_cntr != 2'b11) RxD_cntr <= RxD_cntr + 1;
            //decrement when signal is consistenly low
            else if(~RxD_syncr[1] && RxD_cntr != 2'b00) RxD_cntr <= RxD_cntr - 1;

            //So then signal is considered LOW, when cntr goes down to 0
            //remember we would check the consistent LOW for the start bit
            if(RxD_cntr == 2'b00) RxD_bit <= 0;
            //And HIGH when cntr is 3
            if(RxD_cntr == 2'b11) RxD_bit <= 1;
        end
    end

    //Once a start bit is received, similar to the transmitter, a state machine is used
    localparam START = 4'b0000;
    localparam BIT0 = 4'b1000; localparam BIT1 = 4'b1001; localparam BIT2 = 4'b1010;
    localparam BIT3 = 4'b1011; localparam BIT4 = 4'b1100; localparam BIT5 = 4'b1101;
    localparam BIT6 = 4'b1110; localparam BIT7 = 4'b1111; localparam STOP = 4'b0001;

    //next bit signal to go from bit to bit
    //Since we know that each bit is represented by 8 samples
    //use a 3-bit register to count 8 bit width and assign new bit
    logic [2:0] bit_spacing;
    logic next_bit;
    always_ff @(posedge clk) begin
        //assign at start bit
        if(state == START)  bit_spacing <= 3'b0;
        //other states
        else if(baud8tick)  bit_spacing <= bit_spacing + 1;
        next_bit = (bit_spacing == 3'd7);
    end

    logic [3:0] state;
    always_ff @(posedge clk) begin
        if(baud8tick) begin
            case(state)
                START:  if(~RxD_bit) state <= BIT0;
                BIT0:   if(next_bit) state <= BIT1;
                BIT1:   if(next_bit) state <= BIT2;
                BIT2:   if(next_bit) state <= BIT3;
                BIT3:   if(next_bit) state <= BIT4;
                BIT4:   if(next_bit) state <= BIT5;
                BIT5:   if(next_bit) state <= BIT6;
                BIT6:   if(next_bit) state <= BIT7;
                BIT7:   if(next_bit) state <= STOP;
                default: state <= START;
            endcase
        end
    end
    
    //Finally shift register collects data bits as they come
    logic [7:0] RxD_data;
    always_ff @(posedge clk) begin
        //at sampling rate & next valid bit & in a bit State(MSB is 1)
        // assign RxD bit at MSB concatenated with upper 7 bits
        if(baud8tick && next_bit && state[3])
            RxD_data <= {RxD_bit, RxD_data[7:1]};
    end
    assign outData = RxD_data; //connect output data with RxD
endmodule