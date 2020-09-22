#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "xparameters.h"
#include "xil_cache.h"
#include "xgpio.h"
#include "AXI_VGA_Slave.h"

#define paddle_offset 4

void display_on_VGA(int top, int bottom, int x_pos, int color) {
	int i, x;
	for (i = top; i < bottom; i++) {
		x = i*80 + x_pos;
		AXI_VGA_SLAVE_mWriteReg(XPAR_AXI_VGA_SLAVE_0_S00_AXI_BASEADDR, x, color);
	}
}

int main()
{
	XGpio gpio;
	u32 data; // switch input
	XGpio_Initialize(&gpio, XPAR_GPIO_0_DEVICE_ID);

	u32 difficulty = 0; // difficulty mode
	int speed = 1; // speed of game
	u32 pause = 0; // used to pause the game

	u32 player1, player2; // player inputs
	int p1_top = 480/2-32, p1_bottom = 480/2+32; // top and bottom of player 1 paddle
	int p2_top = p1_top, p2_bottom = p1_bottom; // top and bottom of player 2 paddle
	int p1_pos = 0, p2_pos = 0; // vertical position of each paddle
	int p1_color, p2_color; // color of paddles

	int ball_delay = 0; // controls speed of ball
	int ball_top = 480/2-8, ball_bottom = 480/2; // top and bottom of ball
	int h_pos = 0; // horizontal position of ball
	int v_dir = 1, h_dir = 1; // vertical and horizontal directions of ball

	// initialize paddles
	display_on_VGA(p1_top, p1_bottom, paddle_offset, 0x88888888);
	display_on_VGA(p2_top, p2_bottom, 80-paddle_offset, 0x88888888);

	// initialize ball
	display_on_VGA(ball_top, ball_bottom, 80/2, 0x88888888);

	sleep(2); // wait 2 seconds before starting game

	// game logic
	for (;;) {
		while (1) {
			XGpio_SetDataDirection(&gpio, 1, 0xFFFFFFFF);
			data = XGpio_DiscreteRead(&gpio, 1); // read switch input
			
			// check if pause switch is enabled
			pause = (data & 0b0000000000001000) >> 3;
			if (!pause) {
				break;
			}
			display_on_VGA(p1_top, p1_bottom, paddle_offset, 0x88888888);
			display_on_VGA(p2_top, p2_bottom, 80-paddle_offset, 0x88888888);
			display_on_VGA(ball_top, ball_bottom, 80/2 + h_pos, 0x88888888);
		}

		difficulty = (data & 0b0000000110000000) >> 7;

		// easy
		if (difficulty == 0) {
			speed = 1;
		}
		// medium
		else if (difficulty == 1) {
			speed = 2;
		}
		// hard
		else if (difficulty == 2) {
			speed = 4;
		}
		// insane
		else if (difficulty == 3) {
			speed = 8;
		}

		player1 = (data & 0b1000000000000000) >> 15;
		player2 = data & 0b0000000000000001;

		// calculate and display new position of player 1
		if (player1 && p1_pos > 32-480/2) {
			p1_pos -= speed;
		}
		else if (!player1 && p1_pos < 480/2-32) {
			p1_pos += speed;
		}
		p1_top = 480/2-32 + p1_pos;
		p1_bottom = 480/2+32 + p1_pos;
		display_on_VGA(p1_top, p1_bottom, paddle_offset, 0xFFFFFFFF);
		display_on_VGA(0, p1_top, paddle_offset, 0);
		display_on_VGA(p1_bottom, 480, paddle_offset, 0);

		// calculate and display new position of player 2
		if (player2 && p2_pos > 32-480/2) {
			p2_pos -= speed;
		}
		else if (!player2 && p2_pos < 480/2-32) {
			p2_pos += speed;
		}
		p2_top = 480/2-32 + p2_pos;
		p2_bottom = 480/2+32 + p2_pos;
		display_on_VGA(p2_top, p2_bottom, 80-paddle_offset, 0xFFFFFFFF);
		display_on_VGA(0, p2_top, 80-paddle_offset, 0);
		display_on_VGA(p2_bottom, 480, 80-paddle_offset, 0);

		// ball
		ball_delay++;
		if (ball_delay >= 8/speed) {
			ball_delay = 0;
			
			// erase old position
			display_on_VGA(ball_top, ball_bottom, 80/2 + h_pos, 0);

			// bounce off top
			if (ball_top <= 0) {
				v_dir = 1;
			}
			// bounce off bottom
			else if (ball_bottom >= 480) {
				v_dir = -1;
			}

			// recalculate and display new position
			h_pos += h_dir;
			ball_top += 8*v_dir;
			ball_bottom += 8*v_dir;
			display_on_VGA(ball_top, ball_bottom, 80/2 + h_pos, 0xFFFFFFFF);
		}

		// bounce off player 1 paddle
		if (80/2 + h_pos <= paddle_offset+1
				&& ((ball_bottom > p1_top && ball_bottom < p1_bottom)
						|| (ball_top > p1_top && ball_top < p1_bottom))) {
			h_dir = 1;
		}
		// bounce off player 2 paddle
		else if (80/2 + h_pos >= 80-paddle_offset-1
				&& ((ball_bottom > p2_top && ball_bottom < p2_bottom)
						|| (ball_top > p2_top && ball_top < p2_bottom))) {
			h_dir = -1;
		}

		// if either player misses, reset everything
		if (80/2 + h_pos < paddle_offset+1 || 80/2 + h_pos > 80-paddle_offset-1) {
			// erase current position of ball
			display_on_VGA(ball_top, ball_bottom, 80/2 + h_pos, 0);
			
			// if player 1 loses, ball is served to player 2
			if (80/2 + h_pos < paddle_offset+1) {
				h_dir = 1;
				h_pos = paddle_offset+1 - 80/2;
				p1_color = 0x88888888;
				p2_color = 0x22222222;
			}
			// if player 2 loses, ball is served to player 1
			else {
				h_dir = -1;
				h_pos = 80-paddle_offset-1 - 80/2;
				p1_color = 0x22222222;
				p2_color = 0x88888888;
			}

			// reset variables
			p1_top = 480/2-32; p1_bottom = 480/2+32;
			p2_top = p1_top; p2_bottom = p1_bottom;
			p1_pos = 0; p2_pos = 0;

			ball_delay = 0;
			ball_top = 480/2-8; ball_bottom = 480/2;

			// reset positions of paddles and ball
			display_on_VGA(p1_top, p1_bottom, paddle_offset, p1_color);
			display_on_VGA(0, p1_top, paddle_offset, 0);
			display_on_VGA(p1_bottom, 480, paddle_offset, 0);

			display_on_VGA(p2_top, p2_bottom, 80-paddle_offset, p2_color);
			display_on_VGA(0, p2_top, 80-paddle_offset, 0);
			display_on_VGA(p2_bottom, 480, 80-paddle_offset, 0);

			display_on_VGA(ball_top, ball_bottom, 80/2 + h_pos, 0xFFFFFFFF);

			sleep(2); // wait 2 seconds before continuing
		}

	}
	return 0;
}
