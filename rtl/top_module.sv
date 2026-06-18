`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/02/2026 05:47:19 PM
// Design Name: 
// Module Name: top_module
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


module top_module(
        input wire clk,
        input wire echo,
        output wire trig,
        output wire debug_uart_tx
    );

    logic [7:0] tdata;
    logic tvalid;
    logic tready;
    logic tlast;
    
    logic rst;
    assign rst = 0;
    
    us_sensor sens (
        .clk(clk),
        .rst(rst),
        .trig(trig),
        .echo(echo),
        .m_axis_tdata(tdata),
        .m_axis_tvalid(tvalid),
        .m_axis_tready(tready),
        .m_axis_tlast(tlast)
    );
    
    uart_tx debug_uart (
        .clk(clk),
        .rst(rst),
        .s_axis_tdata(tdata),
        .s_axis_tvalid(tvalid),
        .s_axis_tready(tready),
        .s_axis_tlast(tlast),
        .tx_pin(debug_uart_tx)
    );

//    always_ff @ (posedge clk) begin
//        if (tready) begin
//            tdata <= 8'd65;
//            tvalid <= 1;
//        end else begin
//            tdata <= '0;
//            tvalid <= '0;
//        end
//    end
endmodule
