/* tuxctl-ioctl.c
 *
 * Driver (skeleton) for the mp2 tuxcontrollers for ECE391 at UIUC.
 *
 * Mark Murphy 2006
 * Andrew Ofisher 2007
 * Steve Lumetta 12-13 Sep 2009
 * Puskar Naha 2013
 */

#include <asm/current.h>
#include <asm/uaccess.h>

#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/sched.h>
#include <linux/file.h>
#include <linux/miscdevice.h>
#include <linux/kdev_t.h>
#include <linux/tty.h>
#include <linux/spinlock.h>

#include "tuxctl-ld.h"
#include "tuxctl-ioctl.h"
#include "mtcp.h"

#define debug(str, ...) \
	printk(KERN_DEBUG "%s: " str, __FUNCTION__, ## __VA_ARGS__)
	

/************************ Protocol Implementation *************************/

static bool ack_flag;		// 1 = ack, 0 = not ack
static spinlock_t button_lock;
static unsigned char LED_pattern[4];
static unsigned char buttons;
static unsigned long EFLAGS;

// 7-segment display number table
static char number_table[16] {
	0xE7, 			// 0
	0xCB, 			// 2
	0x8F, 			// 3
	0x2E, 			// 4
	0xAD, 			// 5
	0xED, 			// 6
	0x86, 			// 7
	0xEF, 			// 8
	0xAE, 			// 9

	0xEE, 			// A
	0x6D, 			// B
	0xE1, 			// C
	0x4F, 			// D
	0xE9, 			// E
	0xE8 			// F
}



/* tuxctl_handle_packet()
 * IMPORTANT : Read the header for tuxctl_ldisc_data_callback() in 
 * tuxctl-ld.c. It calls this function, so all warnings there apply 
 * here as well.
 */
void tuxctl_handle_packet (struct tty_struct* tty, unsigned char* packet)
{
    unsigned a, b, c;

    a = packet[0]; /* Avoid printk() sign extending the 8-bit */
    b = packet[1]; /* values when printing them. */
    c = packet[2];

	switch (a)
	{
		case MTCP_ACK:			
	    	tuxctl_ack();
		case MTCP_BIOC_EVENT:
			tuxctl_bioc_event(b, c);
		case MTCP_RESET:
			tuxctl_reset(b, c);
	
		default:
			return;
	}

    /*printk("packet : %x %x %x\n", a, b, c); */
}


/*
 * tuxctl_ack()
 *   DESCRIPTION: Acknowledge the tux controller
 *   INPUTS: none
 *   OUTPUTS: none
 *   RETURN VALUE: none
 *   SIDE EFFECTS: set ack_flag to 1
*/

void tuxctl_ack()
{
	ack_flag = 1;
}


/*
 * tuxctl_bioc_event()
 *   DESCRIPTION: Handle the button event
 *   INPUTS: arg1 -- the first byte of the packet
 *			 arg2 -- the second byte of the packet
 *   OUTPUTS: none
 *   RETURN VALUE: none
 *   SIDE EFFECTS: set buttons to the button status
*/

void tuxctl_bioc_event(unsigned arg1, unsigned arg2)
{
	spin_lock_irqsave(&button_lock, EFLAGS);

	buttons = 0;
	buttons |= arg1 & 0x0F;
	buttons |= (arg2 & 0x01) << 4;		// right | left | down | up | C | B | A | start
	buttons |= (arg2 & 0x02) << 5;
	buttons |= (arg2 & 0x04) << 3;
	buttons |= (arg2 & 0x08) << 4;

	spin_unlock_irqrestore(&button_lock, EFLAGS);
}


/*
 * tuxctl_reset()
 *   DESCRIPTION: Reset the tux controller
 *   INPUTS: arg1 -- the first byte of the packet
 *			 arg2 -- the second byte of the packet
 *   OUTPUTS: none
 *   RETURN VALUE: none
 *   SIDE EFFECTS: reset the tux controller
*/

void tuxctl_reset(tty_struct* tty)
{
	unsigned char packet[8];				// 8 bytes of the packet

	packet[0] = MTCP_BIOC_ON;
	packet[1] = MTCP_LED_USR;
	packet[2] = MTCP_LED_SET;
	packet[3] = 0x0F;

	int idx;
	for (idx = 4; idx < 8; idx++) {
		packet[idx] = LED_pattern[idx - 4];
	}

	tuxctl_ldisc_put(tty, packet, 8);
	ack_flag = 0;
	buttons = 0xFF;
}




/******** IMPORTANT NOTE: READ THIS BEFORE IMPLEMENTING THE IOCTLS ************
 *                                                                            *
 * The ioctls should not spend any time waiting for responses to the commands *
 * they send to the controller. The data is sent over the serial line at      *
 * 9600 BAUD. At this rate, a byte takes approximately 1 millisecond to       *
 * transmit; this means that there will be about 9 milliseconds between       *
 * the time you request that the low-level serial driver send the             *
 * 6-byte SET_LEDS packet and the time the 3-byte ACK packet finishes         *
 * arriving. This is far too long a time for a system call to take. The       *
 * ioctls should return immediately with success if their parameters are      *
 * valid.                                                                     *
 *                                                                            *
 ******************************************************************************/

/*
 * tuxctl_init()
 *   DESCRIPTION: Initialize the tux controller
 *   INPUTS: tty -- the tty_struct of the tux controller
 *   OUTPUTS: none
 *   RETURN VALUE: 0
 *   SIDE EFFECTS: initialize the tux controller
*/

int32_t process_button() {
	int32_t button = 0;
	spin_lock_irqsave(&button_lock, EFLAGS);
	button = buttons;
	spin_unlock_irqrestore(&button_lock, EFLAGS);
	return button;
}

/*
 * tuxctl_init()
 *   DESCRIPTION: Initialize the tux controller
 *   INPUTS: tty -- the tty_struct of the tux controller
 *   OUTPUTS: none
 *   RETURN VALUE: 0
 *   SIDE EFFECTS: initialize the tux controller
*/
int tuxctl_init(struct tty_struct* tty)
{
	if (!ack_flag) {
		return 0;
	}

	unsigned char packet[4];
	packet[0] = MTCP_BIOC_ON;
	packet[1] = MTCP_LED_USR;
	packet[2] = MTCP_LED_SET;
	packet[3] = 0x00;			// set all LED to 0
	tuxctl_ldisc_put(tty, packet, 4);
	ack_flag = 0;
	buttons = 0xFF;
	button_lock = SPIN_LOCK_UNLOCKED;

	return 0;
}

/*
 * tuxctl_buttons()
 *   DESCRIPTION: Get the button status
 *   INPUTS: ptr -- the pointer to the button status
 *   OUTPUTS: none
 *   RETURN VALUE: 0 if success, -EINVAL if ptr is NULL
 *   SIDE EFFECTS: none
*/
int tuxctl_buttons(int32_t* ptr)
{
	if (ptr == NULL){
		return -EINVAL;
	}

	spin_lock_irqsave(&button_lock, EFLAGS);
	// *ptr = buttons;
	copy_to_user(ptr, &buttons, sizeof(int32_t));
	spin_unlock_irqrestore(&button_lock, EFLAGS);

	return 0;
}

/*
 * tuxctl_set_LED()
 *   DESCRIPTION: Set the LED pattern
 *   INPUTS: tty -- the tty_struct of the tux controller
 *			 arg -- the LED pattern
 *   OUTPUTS: none
 *   RETURN VALUE: 0 if success, -EINVAL if arg is invalid
 *   SIDE EFFECTS: set the LED pattern
*/
int tuxctl_set_LED(struct tty_struct* tty, int32_t arg)
{
	if (arg < 0 || arg > 0xFFFFFFFF){
		return -EINVAL;
	}

	int i;
	int curr_num;
	int curr_loc;
	int curr_dec;
	unsigned char packet[6];
	for (i = 0; i < 4; i++){					// loop each LED
		curr_num = (arg >> (i * 4)) & 0x0F;
		curr_loc = (arg >> (i + 16)) & 0x01;
		curr_dec = (arg >> (i + 24)) & 0x01;
		LED_pattern[i] = number_table[curr_num];
		if (curr_loc == 1) {					// if the LED is on			
			packet[i + 2] = number_table[curr_num];
			if (curr_dec == 1) {				// if the decimal point is on
				packet[i + 2] |= 0x10;
			}
		}
	}
	packet[0] = MTCP_LED_SET;
	packet[1] = 0x0F;
	tuxctl_ldisc_put(tty, packet, 6);
	ack_flag = 0;

	// send the LED pattern to the tux

	return 0;		// always return 0
}


/*
 * tuxctl_ioctl()
 *   DESCRIPTION: The ioctl function of the tux controller
 *   INPUTS: tty -- the tty_struct of the tux controller
 *			 file -- the file struct of the tux controller
 *			 cmd -- the command
 *			 arg -- the argument
 *   OUTPUTS: none
 *   RETURN VALUE: 0 if success, -EINVAL if cmd is invalid
 *   SIDE EFFECTS: none
*/
int 
tuxctl_ioctl (struct tty_struct* tty, struct file* file, 
	      unsigned cmd, unsigned long arg)
{
    switch (cmd) {
	case TUX_INIT:			return tuxctl_init(tty);
	case TUX_BUTTONS:		return tuxctl_buttons(&arg);
	case TUX_SET_LED:		return tuxctl_set_LED(arg);
	case TUX_LED_ACK:		break;
	case TUX_LED_REQUEST:	break;
	case TUX_READ_LED:		break;
	default:
	    return -EINVAL;
    }
}


