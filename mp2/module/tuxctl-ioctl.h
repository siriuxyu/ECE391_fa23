// All necessary declarations for the Tux Controller driver must be in this file

#ifndef TUXCTL_H
#define TUXCTL_H

#define TUX_SET_LED _IOR('E', 0x10, unsigned long)
#define TUX_READ_LED _IOW('E', 0x11, unsigned long*)
#define TUX_BUTTONS _IOW('E', 0x12, unsigned long*)
#define TUX_INIT _IO('E', 0x13)
#define TUX_LED_REQUEST _IO('E', 0x14)
#define TUX_LED_ACK _IO('E', 0x15)


// void tuxctl_ack(void);
// void tuxctl_bioc_event(unsigned arg1, unsigned arg2);
// void tuxctl_reset(struct tty_struct* tty);


// int tuxctl_init(struct tty_struct* tty);
// int tuxctl_buttons(unsigned long* ptr);
// int tuxctl_set_LED(struct tty_struct* tty, int32_t arg);



#endif

