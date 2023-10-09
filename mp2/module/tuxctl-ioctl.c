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

static bool ack_flag;			// 1 = ack, 0 = not ack; the ack flag returned by the tux
static spinlock_t button_lock;
static unsigned char LED_pattern[4];
static unsigned char buttons;


// 7-segment display number table
static char number_table[16] = {
	0xE7, 			// 0
	0x06, 			// 1
	0xCB, 			// 2
	0x8F, 			// 3
	0x2E, 			// 4
	0xAD, 			// 5
	0xED, 			// 6
	0x86, 			// 7
	0xEF, 			// 8
	0xAF, 			// 9

	0xEE, 			// A
	0x6D, 			// B
	0xE1, 			// C
	0x4F, 			// D
	0xE9, 			// E
	0xE8 			// F
};



/* tuxctl_handle_packet()
 * IMPORTANT : Read the header for tuxctl_ldisc_data_callback() in 
 * tuxctl-ld.c. It calls this function, so all warnings there apply 
 * here as well.
 */
void tuxctl_handle_packet (struct tty_struct* tty, unsigned char* packet)
{
    unsigned a, b, c;
	int idx;
	int EFLAGS;
	unsigned char package[8] = {MTCP_BIOC_ON, MTCP_LED_USR, MTCP_LED_SET, 0x0F, 0, 0, 0, 0};				// 8 bytes of the packet

    a = packet[0]; /* Avoid printk() sign extending the 8-bit */
    b = packet[1]; /* values when printing them. */
    c = packet[2];

	switch (a)
	{
		case MTCP_ACK:			
	    	ack_flag = 1;
			break;

		case MTCP_BIOC_EVENT:
			spin_lock_irqsave(&button_lock, EFLAGS);
			buttons = 0;
			buttons |= b & 0x0F;
			buttons |= (c & 0x01) << 4;		// right | left | down | up | C | B | A | start
			buttons |= (c & 0x02) << 5;
			buttons |= (c & 0x04) << 3;
			buttons |= (c & 0x08) << 4;
			spin_unlock_irqrestore(&button_lock, EFLAGS);
			break;

		case MTCP_RESET:	
			for (idx = 4; idx < 8; idx++) {
				package[idx] = LED_pattern[idx - 4];	// send to the according packet
			}

			tuxctl_ldisc_put(tty, package, 8);
			ack_flag = 0;
			break;
	
		default:
			return;
	}

    /*printk("packet : %x %x %x\n", a, b, c); */
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
int tuxctl_ioctl_init(struct tty_struct* tty)
{
	unsigned char packet[8] = {MTCP_BIOC_ON, MTCP_LED_USR, MTCP_LED_SET, 0x0F, 0, 0, 0, 0};
	LED_pattern[0] = 0;					// initialize the LED pattern -- all to 0
	LED_pattern[1] = 0;
	LED_pattern[2] = 0;
	LED_pattern[3] = 0;

	tuxctl_ldisc_put(tty, packet, 8);	// send the packet to the tux
	ack_flag = 1;						// set the ack flag to 1
	buttons = 0xFF;						// initialize the button status -- all to 1
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
int tuxctl_ioctl_buttons(unsigned long ptr)
{
	int EFLAGS;
	if ((int32_t*)ptr == NULL){
		return -EINVAL;
	}

	spin_lock_irqsave(&button_lock, EFLAGS);
	// *ptr = buttons;
	copy_to_user((int32_t*)ptr, &buttons, sizeof(int32_t));
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
int tuxctl_ioctl_set_LED(struct tty_struct* tty, unsigned long arg)
{
	unsigned char packet[6] = {0, 0, 0, 0, 0, 0};
	int i;
	int curr_num;		// current number
	int curr_loc;		// current LED location
	int curr_dec;		// current decimal point


	for (i = 0; i < 4; i++){					// loop each LED
		curr_num = (arg >> (i * 4)) & 0x0F;		// get the current number
		curr_loc = (arg >> (i + 16)) & 0x01;	// get LED
		curr_dec = (arg >> (i + 24)) & 0x01;	// get decimal point
		LED_pattern[i] = number_table[curr_num];
		if (curr_loc == 1) {					// if the LED is on			
			packet[i + 2] = number_table[curr_num];
			if (curr_dec == 1) {
				packet[i + 2] |= 0x10;			// set decimal point
			}
		}
	}
	packet[0] = MTCP_LED_SET;
	packet[1] = 0x0F;							// set all LED on
	if (!ack_flag) {
		return 0;
	}
	tuxctl_ldisc_put(tty, packet, 6);
	ack_flag = 0;								// LED porcessing

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
	case TUX_INIT:			return tuxctl_ioctl_init(tty);
	case TUX_BUTTONS:		return tuxctl_ioctl_buttons(arg);
	case TUX_SET_LED:		return tuxctl_ioctl_set_LED(tty, arg);
	case TUX_LED_ACK:		return -EINVAL;
	case TUX_LED_REQUEST:	return -EINVAL;
	case TUX_READ_LED:		return -EINVAL;
	default:
	    return -EINVAL;
    }
}


