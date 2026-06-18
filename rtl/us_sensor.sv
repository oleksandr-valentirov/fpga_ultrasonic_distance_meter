`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/26/2026 11:41:01 PM
// Design Name: 
// Module Name: us_sensor
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


module us_sensor
    #(
        parameter CLK_FREQ_HZ = 12000000,
        parameter SPEED = 343000  // milimeters per second
    )
    (
        input  logic clk,
        input  logic rst,
        output logic trig,
        input  logic echo,

        output logic [7:0] m_axis_tdata,
        output logic       m_axis_tvalid,
        input  logic       m_axis_tready,
        output logic       m_axis_tlast
    );

    // scale factor for distance transformation    
    localparam longint unsigned NUM = (SPEED << 16);
    localparam longint unsigned DEN = (2 * CLK_FREQ_HZ);    
    localparam bit [23:0] SCALE = (NUM + DEN - 1) / DEN;

    // measuring params
    localparam int MEAS_PERIOD_TICKS = $ceil(CLK_FREQ_HZ * 60 / 1000);  // time after measurement end before measurement start
    localparam int TRIG_LENGTH_TICKS = CLK_FREQ_HZ / 100_000;
    
    /* ECHO signal metastability protection */
    logic echo_meta, echo_sync, echo_d;
    logic [31:0] data;
    logic distanse_ready;

    always_ff @(posedge clk) begin
        echo_meta <= echo;
        echo_sync <= echo_meta;
        echo_d <= echo_sync;
    end
    
    /* detect rising and falling edges */
    wire echo_rise = echo_sync & ~echo_d;  // echo_sync is high while echo_d still not
    wire echo_fall = ~echo_sync & echo_d;  // echo_sync is low while echo_d still not

    /* FSM */
    typedef enum logic [1:0] {
        IDLE,
        TRIG_PULSE,
        WAIT_ECHO,
        MEASURE
    } state_t;

    logic [47:0] mult; 
    logic [31:0] counter;
    logic [23:0] echo_time;
    state_t state;

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            counter <= 0;
            trig <= 0;
            data <= 0;
        end else begin
            case (state)
                IDLE: begin
                    // wait between measurements
                    trig <= 0;
                    if (counter >= MEAS_PERIOD_TICKS) begin
                        counter <= 0;
                        distanse_ready <= 0;
                        state <= TRIG_PULSE;
                    end else begin
                        counter <= counter + 1;
                    end
                end
                
                TRIG_PULSE: begin
                    // generate trigger pulse
                    trig <= 1;
                    if (counter >= TRIG_LENGTH_TICKS) begin
                        // trigger time passed 
                        trig <= 0;
                        counter <= 0;
                        state <= WAIT_ECHO;
                    end else begin
                        counter <= counter + 1;
                    end
                end
                
                WAIT_ECHO: begin
                    if (echo_rise) begin
                        echo_time <= 0;
                        state <= MEASURE;
                    end
                end
                
                MEASURE: begin
                    if (echo_sync) begin
                        // measure time while echo is 1
                        echo_time <= echo_time + 1;
                    end else if (echo_fall) begin
                        // calculate distance on fall
                        (* use_dsp = "yes" *)
                        mult <= echo_time * SCALE;
                        data <= mult >> 16;
                        state <= IDLE;
                        counter <= 0;
                        distanse_ready <= 1;
                    end
                end

            endcase
        end
    end
    
    // axi-stream
    enum {AXI_IDLE, START_BYTE, DATA_1, DATA_0, END_BYTE} axi_state;
    always_ff @ (posedge clk) begin
        if (rst) begin
            axi_state <= AXI_IDLE;
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
        end else begin
            case (axi_state)
                AXI_IDLE : if (distanse_ready) begin
                    axi_state <= START_BYTE;
                end
                
                START_BYTE : if (m_axis_tready) begin
                    m_axis_tdata <= 8'hAA;
                    m_axis_tvalid <= 1;
                    m_axis_tlast <= 0;
                    axi_state <= DATA_1;
                end
                
                DATA_1 : if (m_axis_tready) begin
                    m_axis_tdata <= data[15:8];
                    axi_state <= DATA_0;
                end
                
                DATA_0 : if (m_axis_tready) begin
                    m_axis_tdata <= data[7:0];
                    axi_state <= END_BYTE;
                end
                
                END_BYTE : if (m_axis_tready) begin
                    m_axis_tdata <= 8'h55;
                    m_axis_tlast <= 1;
                    axi_state <= AXI_IDLE;
                end
    
            endcase
            
            if (m_axis_tlast && m_axis_tready && axi_state == AXI_IDLE) begin
                m_axis_tvalid <= 0;
            end
        end
    end
endmodule
