`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/13/2024 03:45:19 PM
// Design Name: 
// Module Name: TxD
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//  The transmitter takes 8-bit data inside the FPGA and serializes it (when "TxD_start" is asserted).
// -> The busy signal is asserted while a transmission occurs ("TxD_start" is ignored during)
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module TxD(
        input logic clk, BaudTick,
        input logic start,
        input logic [7:0] inData,
        output logic busy, txd_out //transmitted bit
    );
    //Asserting TxD_start for(at_least) one clock cycle to start transmission of TxD_data
    //TxD_data is latched so it doesn't have to stay valid while being sent (not too sure why this matters currently)
    
    //To go through the start, data, and stop bits, a state machine seems appropriate
    //pretty basic - enumerating all possible states of the transmitter using 4-bit state encoding
    localparam IDLE = 4'b0, START = 4'b0100;
    localparam BIT0 = 4'b1000; localparam BIT1 = 4'b1001; localparam BIT2 = 4'b1010;
    localparam BIT3 = 4'b1011; localparam BIT4 = 4'b1100; localparam BIT5 = 4'b1101;
    localparam BIT6 = 4'b1110; localparam BIT7 = 4'b1111; localparam STOP1 = 4'b0010;
    localparam STOP2 = 4'b0011;
    
    logic [3:0] state;
    //if state is IDLE, transmitter is ready
    //then ofc busy and ready are opposites
    logic txd_ready = (state == IDLE);
    assign busy = ~txd_ready;
    
    logic [7:0] txd_shift; //a register holding the shifted input data
    //transitions occur at the rate of baud-ticks
    always_ff @(posedge clk) begin
        if(txd_ready & start)   txd_shift <= inData;
        //shift the data by 1 bit for each baud Tick starting from BIT0 to Bit7
        else if (state[3] & BaudTick)   txd_shift <= txd_shift >> 1;
        case(state)
            IDLE:    if(start)         state <= START;
            START:   if(BaudTick)      state <= BIT0;
            BIT0:    if(BaudTick)      state <= BIT1;
            BIT1:    if(BaudTick)      state <= BIT2;
            BIT2:    if(BaudTick)      state <= BIT3;
            BIT3:    if(BaudTick)      state <= BIT4;
            BIT4:    if(BaudTick)      state <= BIT5;
            BIT5:    if(BaudTick)      state <= BIT6;
            BIT6:    if(BaudTick)      state <= BIT7;
            BIT7:    if(BaudTick)      state <= STOP1;
            STOP1:   if(BaudTick)      state <= STOP2;
            STOP2:   if(BaudTick)      state <= IDLE;
            default: if(BaudTick)      state <= IDLE; //makes sure state machine begins at IDLE
        endcase
    end
    //states < 4 (IDLE/START), output is 1
    //for data bit states, then the output is the lsb of the shift register
    assign txd_out = (state < 4) | (state[3] & txd_shift[0]);
endmodule
