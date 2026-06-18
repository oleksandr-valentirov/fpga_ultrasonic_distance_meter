`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/13/2026 03:51:51 PM
// Design Name: 
// Module Name: uart_tx
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


module uart_tx
    #(
        parameter CLK_FREQ_HZ = 12000000,
        parameter BAUD = 115200,
        parameter WORD_LENGTH_BITS = 8
    )
    (
        input logic clk,
        input logic rst,

        input  logic [7:0] s_axis_tdata,
        input  logic s_axis_tvalid,
        output logic s_axis_tready,
        input  logic s_axis_tlast,

        output logic tx_pin
    );
    
    // internal signals
    logic [WORD_LENGTH_BITS-1:0] tx_data_i; // internal data register
    logic tx_data_ready_i;                  // we are ready for a new data portion
    logic uart_tx_i;                        // internal tx signal which is conencted to the actual TX pin
    
    // copy external data into internal register
    always_ff @ (posedge clk) begin
        if (rst) begin
            tx_data_i = '0;
        end else begin
            if (s_axis_tvalid & tx_data_ready_i) begin
                // don't store the data unless we are ready
                tx_data_i <= s_axis_tdata;
            end
        end
    end
    
    // baud params
    localparam CLKS_PER_BIT = CLK_FREQ_HZ / BAUD;
    localparam BAUD_CNT_SIZE = $clog2(CLKS_PER_BIT);
    
    // data params
    localparam DATA_MAX = WORD_LENGTH_BITS;
    localparam DATA_CNT_SIZE = $clog2(DATA_MAX);
    
    // TX signals
    localparam TX_IDLE = 1'b1;
    localparam TX_START = 1'b0;
    localparam TX_STOP = 1'b1;
    
    enum {IDLE, START, DATA, STOP} current_state, next_state;
    
    logic [DATA_CNT_SIZE-1:0] data_cnt;
    logic [BAUD_CNT_SIZE-1:0] baud_cnt;
    logic baud_done;  // a flag for the state machine
    logic data_done;  // a flag for the state machine
        
    logic [WORD_LENGTH_BITS-1:0] data_shift_buffer;
    
    // baud generator
    always_ff @ (posedge clk) begin
        if (rst) begin
            baud_cnt <= '0;
        end else begin
            if (baud_done) begin
                baud_cnt <= 0;
            end else begin
                baud_cnt <= baud_cnt + 'd1;
            end
        end
    end
    
    assign baud_done = (baud_cnt == CLKS_PER_BIT-1) ? 1'd1 : 1'd0;
    
    // data shifter
    always_ff @ (posedge clk) begin
        if (rst) begin
            data_cnt <= '0;
            data_shift_buffer <= '0;
        end else if (baud_done) begin  // a moment to transmit a next bit
            if (current_state != next_state) begin
                data_cnt <= '0;
                data_shift_buffer <= tx_data_i;
            end else begin
                data_cnt <= data_cnt + 'd1;
                data_shift_buffer <= data_shift_buffer >> 1;
            end
        end
    end
    
   // uart_data_done indicates all bits are transmitted
   assign data_done = (data_cnt == DATA_MAX-1) ? 1'b1 : 1'b0;
    
    // state machine - combinational part\
    always_comb begin
        case (current_state)
            IDLE :
                begin
                    if (s_axis_tvalid) begin
                        next_state = START;
                    end else begin
                        next_state = current_state;
                    end
                end
            START :
                begin
                    if (baud_done) begin
                        next_state = DATA;
                    end else begin
                        next_state = current_state;
                    end
                end
            DATA :
                begin
                    if (baud_done & data_done) begin
                        next_state = STOP;
                    end else begin
                        next_state = current_state;
                    end
                end
            STOP :
                begin
                    if (baud_done) begin
                        next_state = IDLE;
                    end else begin
                        next_state = current_state;
                    end
                end
            default :
                next_state = current_state;
        endcase
    end
    
    // sate machine - sequential part
    always_ff @ (posedge clk) begin
        if (rst) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // data assigner
    always_comb begin
        case (current_state)
            IDLE :
                begin
                    uart_tx_i = TX_IDLE;
                end
            START :
                begin
                    uart_tx_i = TX_START;
                end
            DATA :
                begin
                    uart_tx_i = data_shift_buffer[0];
                end
            STOP :
                begin
                    uart_tx_i = TX_STOP;
                end
        endcase
    end

    assign tx_data_ready_i = (current_state == IDLE) ? 1'b1 : 1'b0;
    assign s_axis_tready = tx_data_ready_i;
    assign tx_pin = uart_tx_i;

endmodule
