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

module simplecounter (
    input clk,
    input resetn,

    input  [ 3:0] reg_we,
    input  [ 3:0] reg_re,
    input  [ 3:0] reg_addr,
    input  [31:0] reg_di,
    output reg [31:0] reg_do,

    output ready
);
  reg [31:0] cfg_reg;   // Pos 0
  reg cfg_wr_ready;
  reg [31:0] presc_reg; // Pos 1
  reg presc_wr_ready;
  reg [31:0] cnt_reg;   // Pos 2
  reg cnt_wr_ready;

  reg [31:0] presc_cnt;
  reg presc_clk;
  wire cnt_clk;

  reg rd_ready;

  assign ready = cfg_wr_ready || presc_wr_ready || cnt_wr_ready || rd_ready;

  always @(*) begin
    if (reg_re != 4'b 0000) begin
      rd_ready = 1;

      case(reg_addr)
        4'b 0000: reg_do = cfg_reg;
        4'b 0001: reg_do = presc_reg;
        4'b 0010: reg_do = cnt_reg;
        default: reg_do = 32'h 0000_0000;
      endcase

    end else begin
      rd_ready = 0;
      reg_do = 32'h 0000_0000;
    end
  end

  always @(posedge clk) begin

    cfg_wr_ready <= 0; 
    cfg_reg <= cfg_reg; // This does look a bit funky... 

    if((reg_we != 4'b 0000) && (reg_addr == 4'b 0000)) begin
        cfg_reg <= reg_di;
        cfg_wr_ready <= 1;
    end

    if(!resetn) begin
      cfg_reg <= 32'h 0000_0000;
      cfg_wr_ready <= 0;
    end 
  end

  always @(posedge clk) begin

    presc_wr_ready <= 0;
    presc_reg <= presc_reg;

    if((reg_we != 4'b 0000) && (reg_addr == 4'b 0001)) begin
      presc_reg <= reg_di;
      presc_wr_ready <= 1;
    end

    if(!resetn) begin
      presc_reg <= 32'h 0000_0000;
      presc_wr_ready <= 0;
    end     
  end

  always @(posedge clk) begin

    presc_cnt <= presc_cnt + 1;
    presc_clk <= 0;

    if(presc_cnt == presc_reg) begin
      presc_cnt <= 32'h 0000_0000;
      presc_clk <= 1;
    end

    if((!resetn) || (presc_reg == 32'h 0000_0000)) begin
      presc_cnt <= 32'h 0000_0000;
      presc_clk <= 0;
    end
  end

  assign cnt_clk = (presc_reg == 0) ? clk : presc_clk;

  always @(posedge cnt_clk) begin
    
    cnt_wr_ready <= 0;
    cnt_reg <= 0;
    
    if(cfg_reg[0] == 1) begin
      cnt_reg <= cnt_reg + 1;
    end

    if((reg_we != 4'b 0000) && (reg_addr == 4'b 0010)) begin
        cnt_reg <= reg_di;
        cnt_wr_ready <= 1;
    end 
  end

endmodule
