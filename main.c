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

#include <stdint.h>
#include <stdbool.h>

#define reg_leds (*(volatile uint32_t*)0x03000000)

#define counter_cfg_reg (*(volatile uint32_t*)0x02001000)
#define counter_presc_reg (*(volatile uint32_t*)0x02001004)
#define counter_cnt_reg (*(volatile uint32_t*)0x02001008)


#define uart_cfg_reg (*(volatile uint32_t*)0x02000100)
#define uart_clk_div_reg (*(volatile uint32_t*)0x02000104)
#define uart_usr_reg (*(volatile uint32_t*)0x02000108)
#define uart_tx_reg (*(volatile uint32_t*)0x0200010C)
#define uart_rx_reg (*(volatile uint32_t*)0x02000110)

// --------------------------------------------------------

/* Private functions */
static void led_counter(void);
static uint32_t get_time_ms(void);
static void print_char(char out_data);
static bool read_char(volatile char* data_in);

/* Private variables */

void main()
{

	reg_leds = 0x0;
    static volatile char in_char = 0;

    counter_presc_reg = (100000000/1000) - 1;
    counter_cfg_reg = 0x1;

    uint32_t idx = 0;

    /* Set UART division */
    uart_clk_div_reg = 100000000 / 115200;

	while (1)
	{
		led_counter();

        if(read_char(&in_char))
        {
            print_char(in_char);
        }

	}
}

static void led_counter(void)
{

    static uint32_t last_time_ms = 0;

    if(20 <= (get_time_ms() - last_time_ms))
    {
        last_time_ms = get_time_ms();
        if(0x10 == ++reg_leds)
        {
            reg_leds = 0;
        }
    }
}

static bool read_char(volatile char* data_in)
{
    bool retval = false;
    
    if((uart_usr_reg & 0x8) == 0) //Rx fifo not empty
    {
        *data_in = uart_rx_reg;
        retval = true;
    }
    else
    {
        retval = false;
    }

    return retval;
}

static void print_char(char out_data)
{        
    uart_tx_reg = out_data;
}

static uint32_t get_time_ms(void)
{
    return counter_cnt_reg;
}