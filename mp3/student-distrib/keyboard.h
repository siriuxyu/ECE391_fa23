#ifndef _KEYBOARD_H
#define _KEYBOARD_H
#include "types.h"
#include "i8259.h"

#define KEYBOARD_IRQ 1
#define KEYBOARD_DATA 0x60


// handler for keyboard
extern void keyboard_handler(); 
// initilize the keyboard
extern void keyboard_init(); 
#endif
