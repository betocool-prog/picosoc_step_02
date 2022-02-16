/*
 *  PicoSoC - A simple example SoC using PicoRV32
 *
 *  Copyright (C) 2017  Clifford Wolf <clifford@clifford.at>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

module uart (
    input clk,
    input resetn,

    input  [ 3:0] reg_we,
    input  [ 3:0] reg_re,
    input  [ 3:0] reg_addr,
    input  [31:0] reg_di,
    output reg [31:0] reg_do,

    output ready, 

    input uart_rx,
    output uart_tx
);

  wire uart_clk;
  wire uart_resetn;

  wire wen;
  wire ren;
    
  reg [31:0] cfg_reg;   // Pos 0 
  reg cfg_wr_ready;    
  reg [31:0] clk_div_reg;   // Pos 1
  reg clk_div_wr_ready;
  reg [31:0] usr_reg;   // Pos 2
  reg usr_wr_ready;
  reg [31:0] tx_reg; // Pos 3
  reg tx_wr_ready;
  reg [31:0] rx_reg;   // Pos 4
  wire [31:0] rx_wire;

  reg rd_ready;

  assign uart_clk = clk;
  assign uart_resetn = resetn;

  assign wen = (reg_we != 4'b 0000);
  assign ren = (reg_re != 4'b 0000);

  assign ready = rd_ready || cfg_wr_ready || clk_div_wr_ready || usr_wr_ready || tx_wr_ready;

  /* Read Section */
  /* Read Data Register */
  always @(posedge clk) begin

    rd_ready <= 0;
    reg_do <= 32'h 0000_0000;

    if((reg_re != 4'b 0000) && (reg_addr == 4'b 0000)) begin
        reg_do <= cfg_reg;
        rd_ready <= 1;
    end

    if((reg_re != 4'b 0000) && (reg_addr == 4'b 0001)) begin
        reg_do <= clk_div_reg;
        rd_ready <= 1;
    end

    if((reg_re != 4'b 0000) && (reg_addr == 4'b 0010)) begin
        reg_do <= usr_reg;
        rd_ready <= 1;
    end

    if((reg_re != 4'b 0000) && (reg_addr == 4'b 0100)) begin
        reg_do <= rx_reg;
        rd_ready <= 1;
    end

    if(!resetn) begin
      reg_do <= 32'h 0000_0000;
      rd_ready <= 0;
    end 
  end

  /* Write registers  */
  always @(posedge clk) begin

    cfg_wr_ready <= 0;
    clk_div_wr_ready <= 0;
    usr_wr_ready <= 0;
    tx_wr_ready <= 0;

    cfg_reg <= cfg_reg; // This does look a bit funky... 
    clk_div_reg <= clk_div_reg;
    usr_reg <= usr_reg;
    tx_reg <= tx_reg;

    if((reg_we != 4'b 0000) && (reg_addr == 4'b 0000)) begin
        cfg_reg <= reg_di;
        cfg_wr_ready <= 1;
    end

    if((reg_we != 4'b 0000) && (reg_addr == 4'b 0001)) begin
        clk_div_reg <= reg_di;
        clk_div_wr_ready <= 1;
    end

    if((reg_we != 4'b 0000) && (reg_addr == 4'b 0010)) begin
        usr_reg <= reg_di;
        usr_wr_ready <= 1;
    end

    if((reg_we != 4'b 0000) && (reg_addr == 4'b 0011)) begin
        tx_reg <= reg_di;
        tx_wr_ready <= 1;
    end

    if(!resetn) begin

      cfg_wr_ready <= 0;
      clk_div_wr_ready <= 0;
      usr_wr_ready <= 0;
      tx_wr_ready <= 0;

      cfg_reg <= 32'h 0000_0000;
      clk_div_reg <= 32'h 0000_0000;
      usr_reg <= 32'h 0000_0000;
      tx_reg <= 32'h 0000_0000;
    end 
  end

	// uart_fifo tx_fifo (
	// 	.clk         (uart_clk    ),
	// 	.resetn      (uart_resetn ),

	// 	.wen		(),
	// 	.ren		(),
	// 	.wdata	(tx_reg[7:0]),
	// 	.rdata	(rx_wire[7:0]),
	// 	.full		(),
	// 	.empty	()
	// );

endmodule

// module uart_fifo #(
// 	parameter integer WORDS = 256
// ) (
// 	input clk,
//   input resetn,
// 	input wen,
//   input ren,
// 	input [7:0] wdata,
// 	output reg [7:0] rdata,
//   output reg full,
//   output reg empty
// );
// 	(* ram_style = "distributed" *) reg [7:0] fifo [0:WORDS-1];
  
//   reg [7:0] wr_addr;
//   reg [7:0] rd_addr;
//   reg [7:0] fifo_level;
//   reg fifo_full;
//   reg fifo_empty;

//   assign full = fifo_full;
//   assign empty = fifo_empty;
	
//   always @(posedge clk) begin

//     if (ren) begin
//       if (!fifo_empty) begin
//         rdata <= fifo[rd_addr];
//         rd_addr <= rd_addr + 1;
//       end
//     end

// 		if (wen) begin
//       fifo[wr_addr][7:0] <= wdata[7:0];
//       wr_addr <= wr_addr + 1;
//     end

//     if(!resetn) begin
//       rd_addr <= 0;
//       wr_addr <= 0;
//       rdata <= 8'h 00;
//       fifo_full <= 0;
//       fifo_empty <= 1;
//       fifo_level <= 8'h 00;
//     end
// 	end
// endmodule