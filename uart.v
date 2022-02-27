/*
MIT License

Copyright (c) 2022 betocool-prog

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
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

  wire wen;
  wire ren;
  
  /* Module registers */
  reg [31:0] cfg_reg;       // Config Register, Pos 0 
  reg cfg_wr_ready;  

  reg [31:0] clk_div_reg;   // Clock Div Register, Pos 1
  reg clk_div_wr_ready;

  reg [31:0] usr_reg;       // UART Status Register, Pos 2
  reg usr_wr_ready;
  wire tx_fifo_full;
  wire tx_fifo_empty;
  wire rx_fifo_full;
  wire rx_fifo_empty;

  reg [31:0] tx_reg;        // Transmit Register, Write Only, Pos 3
  reg [7:0] tx_output_reg;
  reg tx_wr_ready;
  reg tx_wr_fifo;
  reg tx_rd_fifo;
  wire tx_fifo_wr_ready;

  reg [31:0] rx_reg;        // Receive Register, Read Only, Pos 4
  reg [7:0] rx_input_reg;
  reg rx_wr_fifo;
  reg rx_rd_fifo;
  wire [7:0] rx_wire;

  reg rd_ready;

  /* UART Status Register USR */
  assign usr_reg[0] = tx_fifo_full;
  assign usr_reg[1] = tx_fifo_empty;
  assign usr_reg[2] = rx_fifo_full;
  assign usr_reg[3] = rx_fifo_empty;

  assign wen = (reg_we != 4'b 0000);
  assign ren = (reg_re != 4'b 0000);

  assign ready = rd_ready || cfg_wr_ready || clk_div_wr_ready || usr_wr_ready || tx_wr_ready;

  /* Read Section */
  /* Read Data Register */
  always @(posedge clk) begin

    rd_ready <= 0;
    reg_do <= 32'h 0000_0000;
    rx_rd_fifo <= 0;

    if(ren) begin

      case(reg_addr)
        4'b 0000: begin
          reg_do <= cfg_reg;
          rd_ready <= 1;
        end
        4'b 0001: begin
          reg_do <= clk_div_reg;
          rd_ready <= 1;
        end
        4'b 0010: begin
          reg_do <= usr_reg;
          rd_ready <= 1;
        end
        4'b 0100: begin
          reg_do <= (32'h 0000_0000 | rx_wire);
          rd_ready <= 1;
          rx_rd_fifo <= 1;
        end
        default: reg_do <= 32'h 0000_0000;
      endcase
    end

    if(!resetn) begin
      reg_do <= 32'h 0000_0000;
      rd_ready <= 0;
      rx_rd_fifo <= 0;
    end 
  end

  /* Write Data Section */
  /* Write registers  */
  always @(posedge clk) begin

    cfg_wr_ready <= 0;
    clk_div_wr_ready <= 0;
    tx_wr_ready <= 0;
    tx_wr_fifo <= 0;

    if(wen) begin
      case(reg_addr)
        4'b 0000: begin
          cfg_reg <= reg_di;
          cfg_wr_ready <= 1;
        end
        4'b 0001: begin
          clk_div_reg <= reg_di;
          clk_div_wr_ready <= 1;
        end
        4'b 0011: begin
          tx_reg <= reg_di;
          tx_wr_ready <= 1;
          tx_wr_fifo <= 1;
        end
        default: begin
          cfg_reg <= cfg_reg;
          clk_div_reg <= clk_div_reg;
          tx_reg <= tx_reg;
        end
      endcase
    end

    if(!resetn) begin

      cfg_wr_ready <= 0;
      clk_div_wr_ready <= 0;
      usr_wr_ready <= 0;
      tx_wr_ready <= 0;

      cfg_reg <= 32'h 0000_0000;
      clk_div_reg <= 32'h 0000_0001;
      tx_reg <= 32'h 0000_0000;
    end 
  end

  /* UART clock divider */
  reg uart_clk;
  reg[31:0] uart_clk_cnt;
  always @(posedge clk) begin
    
    uart_clk <= 0;
    uart_clk_cnt <= uart_clk_cnt + 1;

    if(uart_clk_cnt == clk_div_reg) begin
      uart_clk_cnt <= 32'h 0000_0000;
      uart_clk <= 1;
    end

    if(!resetn) begin
      uart_clk <= 0;
      uart_clk_cnt <= 32'h 0000_0000;
    end
  end

  /* TX Fifo to serial
    UART output
    Start bit - 0
    Bits 0- 7
    Stop bit - 1
  */
  localparam UART_IDLE = 2'b00;
  localparam UART_START = 2'b01;
  localparam UART_DATA = 2'b10;
  localparam UART_STOP = 2'b11;
  reg [1:0] uart_state;
  reg [7:0] uart_out_reg;
  reg [2:0] uart_bits_out;

  always @(posedge uart_clk) begin

    uart_tx <= 1;
    tx_rd_fifo <= 0;

    case(uart_state)
      
      UART_IDLE: begin
        uart_bits_out <= 3'b000;
        uart_state <= UART_IDLE;

        if(!tx_fifo_empty) begin
          uart_state <= UART_START;
          tx_rd_fifo <= 1;
        end
        
      end

      UART_START: begin
        uart_tx <= 0;
        uart_out_reg <= tx_output_reg;
        uart_state <= UART_DATA;
      end

      UART_DATA: begin
        uart_out_reg[6:0] <= uart_out_reg[7:1];
        uart_tx <= uart_out_reg[0];
        uart_bits_out <= uart_bits_out + 1;

        if(uart_bits_out == 7) begin
          uart_state <= UART_STOP;
        end

      end

      UART_STOP: begin
        uart_tx <= 1;    
        uart_state <= UART_IDLE;    
      end
      
    endcase

    /* Update uart_out_reg if fifo is not empty */
    
    if(!resetn) begin
      uart_out_reg <= 10'h 3FF;
    end
  end

  /* Tx Fifo */
	uart_fifo tx_fifo (
		.clk      (clk    ),
		.resetn   (resetn ),

		.wen		  (tx_wr_fifo),
		.ren		  (tx_rd_fifo),
		.wdata	  (tx_reg[7:0]),
		.rdata	  (tx_output_reg),
		.full		  (tx_fifo_full),
		.empty	  (tx_fifo_empty)
	);

  /* Rx Fifo */
	uart_fifo rx_fifo (
		.clk      (clk    ),
		.resetn   (resetn ),

		.wen		  (rx_wr_fifo),
		.ren		  (rx_rd_fifo),
		.wdata	  (rx_input_reg),
		.rdata	  (rx_wire),
		.full		  (rx_fifo_full),
		.empty	  (rx_fifo_empty)
	);

endmodule

module uart_fifo #(
	parameter integer WORDS = 256
) (
	input clk,
  input resetn,
	input wen,
  input ren,
	input [7:0] wdata,
	output reg [7:0] rdata,
  output full,
  output empty
);
	(* ram_style = "distributed" *) reg [7:0] fifo [0:WORDS-1];
  
  reg [7:0] wr_addr;
  reg [7:0] rd_addr;
  reg [8:0] fifo_level;
  reg fifo_full;
  reg fifo_empty;
  reg prev_wen;
  reg prev_ren;

  initial begin
    wr_addr = 8'h 00;
    rd_addr = 8'h 00;
    fifo_level = 8'h 0F;
    fifo_full = 0;
    fifo_empty = 1;
    prev_wen = 0;
    prev_ren = 0;

  end

  assign full = fifo_full;
  assign empty = fifo_empty;
	
  always @(posedge clk) begin

    fifo_level <= fifo_level;
    wr_addr <= wr_addr;
    rd_addr <= rd_addr;
    prev_wen <= wen;
    prev_ren <= ren;

    if (ren & !prev_ren) begin
      if (!fifo_empty) begin
        fifo_level <= fifo_level - 1;
        rd_addr <= rd_addr + 1;
        rdata <= fifo[rd_addr];
      end
    end

		if (wen) begin
      if(!fifo_full) begin
        fifo[wr_addr][7:0] <= wdata[7:0];
        if(prev_wen) begin
          fifo_level <= fifo_level + 1;
          wr_addr <= wr_addr + 1;
        end
      end
    end

    if (fifo_level == 9'h 100) begin
      fifo_full <= 1;
    end else if(fifo_level == 9'h 000) begin
      fifo_empty <= 1;
    end else begin
      fifo_full <= 0;
      fifo_empty <= 0;
    end

    if(!resetn) begin
      rd_addr <= 0;
      wr_addr <= 0;
      fifo_full <= 0;
      fifo_empty <= 1;
      fifo_level <= 8'h 00;
    end
	end
endmodule