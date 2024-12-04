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
        input oversampledTick /*sampling signal at 'X' times the known baud*/, 

        output logic data_ready,
        output logic [7:0] outData, //valid when data_ready is asserted (for one clock cycle)

        //Some more improvements from source code
        //To detect if gaps occur in received stream of data
        //-> Treat multiple characters in a burst as a "packet"
        output logic RxD_idle, // this is asserted after a set timeframe of no data\
        output logic RxD_packetEnd //asserted (for one clock) when packet has been detected (RxD idle goes HIGH)
        );
    // incoming 'RxD_in' signal has no relationship with our clock
    // Use 2 D-FFs to oversample the signal and synchronize it to the clock domain
    // First FF captures the async signal
    // Second FF provides stability by preventing rapid signal changes

    logic [1:0] RxD_syncr; // a 2-bit shift register
    parameter oversamplingFactor = 8;
    //(Still not sure I understand this whole 2FFs synchronizing thing to be honest)
    always_ff @(posedge clk) begin
        // so at the sampling frequency we update RxD synchronizer
        // 1. Moving the previous bit to MSB
        // 2. Capture the new RxD_in value at LSB
        if(oversampledTick) RxD_syncr <= {RxD_syncr[0], RxD_in};
    end
    //Filter data, so short spikes on RxD line aren't mistaken with start bits
    logic [1:0] RxD_cntr; //used to track signal stability
    logic RxD_bit; //this is the actual bit that we take from all our signal processing
    always_ff @(posedge clk) begin
        //at the sampling rate, we use a noise filtering technique
        //-> This way the design doesn't hastily consider consistent spikes as accurate data and just waits for constant behavior to assign the RxD bit
        if(oversampledTick) begin
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
    localparam IDLE = 4'b0000; localparam START = 4'b0001;
    localparam BIT0 = 4'b1000; localparam BIT1 = 4'b1001; localparam BIT2 = 4'b1010;
    localparam BIT3 = 4'b1011; localparam BIT4 = 4'b1100; localparam BIT5 = 4'b1101;
    localparam BIT6 = 4'b1110; localparam BIT7 = 4'b1111; localparam STOP = 4'b0010;

    logic [3:0] state;

    //Logic to determine when is the best time to sample the RxD line
    //Calculate base-2 log of number
    //log2(8) = 3 (2^3=8)
    function integer log2(input integer x); 
    begin
        log2 = 0;
        while(x>>log2)  log2 = log2+1;
    end
    endfunction
    //create a local parameter for the oversampling width
    localparam l2o = log2(oversamplingFactor); //num bits needed to count oversampling ticks

    logic [l2o-2:0] oversamplingCntr;
    always_ff @(posedge clk) begin
        //Increment cntr on each oversampled tick
        if(oversampledTick)
            oversamplingCntr <= (state == IDLE) ? '0 : oversamplingCntr <= oversamplingCntr + 1'd1;
    end 
    //trigger when cntr reaches middle of bit sample period
    logic sample_now = oversampledTick && (oversamplingCntr == oversamplingFactor/2-1);

    always_ff @(posedge clk) begin
        if(oversampledTick) begin
            case(state)
                IDLE:   if(~RxD_bit)   state <= START; //start bit found(?)
                START:  if(sample_now) state <= BIT0; //sync start bit to sample_now
                BIT0:   if(sample_now) state <= BIT1;
                BIT1:   if(sample_now) state <= BIT2;
                BIT2:   if(sample_now) state <= BIT3;
                BIT3:   if(sample_now) state <= BIT4;
                BIT4:   if(sample_now) state <= BIT5;
                BIT5:   if(sample_now) state <= BIT6;
                BIT6:   if(sample_now) state <= BIT7;
                BIT7:   if(sample_now) state <= STOP;
                STOP:   if(sample_now) state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end
    
    //Finally shift register collects data bits as they come
    logic [7:0] RxD_data;
    always_ff @(posedge clk) begin
        // at sampling time & in a bit State(MSB is 1)
        // assign RxD bit at MSB concatenated with upper 7 bits
        if(sample_now && state[3])
            RxD_data <= {RxD_bit, RxD_data[7:1]};
    end
    //logic for data_ready assertion
    always_ff @(posedge clk) begin
        data_ready <= (sample_now && state == STOP && RxD_bit); //a stop bit is received
    end
    assign outData = RxD_data; //connect output data with RxD

    //logic for gap detection on the incoming data line
    // create cntr used to detect extended periods of an idle line
    // wider than oversampling cntr
    logic [l2o+1:0] gapCntr;
    
    always_ff @(posedge clk) begin
        //if currently receiving data, gap == 0
        if(state != IDLE)   gapCntr <= '0;
        //else cntr is in IDLE state so increment gapCntr at the rate of the oversampledTick
        // ~gapCntr[log2(oversamplingFactor)+1] explained:
        // -> prevents cntr from incrementing after a certain point
        // -> log2(oversamplingFactor)+1 is the MSB
        // -> inverted MSB check as if cntr state is as an example: 0111
        // -> OK to increment, however at 1111 we cannot increment further
        else if(oversampledTick & ~gapCntr[log2(oversamplingFactor)+1])
            gapCntr <= gapCntr + 1'd1;
    end
    assign RxD_idle = gapCntr[l2o+1]; //idle when gapCntr reaches maximum size
    //End of packet detection
    always_ff @(posedge clk) begin
        // triggers end of a packet when:
        //-> oversamplingTick occurs
        //-> cntr has not reached MSB
        //-> All lower bits are HIGH(1) : 
        //-> '&gapCntr[l2o:0]' is a reduction AND operator that checks if all bits in range are 1
        RxD_packetEnd <= oversampledTick & ~gapCntr[l2o+1] &gapCntr[l2o:0];
    end
endmodule
