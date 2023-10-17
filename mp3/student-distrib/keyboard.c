#include "keyboard.h"
#include "lib.h"
#define KEYBOARD_IRQ 1
char scan_code_set[59]={
    0,'0','1','2','3','4','5','6','7','8','9','0','-','=','\b',
    '\t','q','w','e','r','t','y','u','i','o','p','[',']','\n',
    0,'a','s','d','f','g','h','j','k','l',';','\'','`',0,'\\',
    'z','x','c','v','b','n','m',',','.','/',0,'*',0,' ',0
}; // the scan code set 1 from official website

/* 
 * keyboard_init: initialize the keyboard  
 * Input: none
 * Output: none
 * Side effect: enable the interrupt from keyboard
*/
void keyboard_init(){
    enable_irq(KEYBOARD_IRQ);
}

/* 
 * keyboard_handler: the handler for keyboard  
 * Input: none
 * Output: none
 * Side effect: print the partial scancodes to the screen (and sending EOI afterwards)
*/
void keyboard_handler(){
    cli();
    uint8_t scancode = inb(KEYBOARD_DATA);
    if(scancode < 59) printf("%c", scan_code_set[scancode]); // make sure we're only showing things in checkpoint 1 (ignore the release part)
    send_eoi(KEYBOARD_IRQ);
    sti();
}
