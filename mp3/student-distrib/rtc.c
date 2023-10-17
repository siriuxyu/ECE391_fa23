#include "rtc.h"

#define RATE 0x0F
/* 
 * rtc_init: Enable (unmask) the specified IRQ and set a initial rate
 * Input: none
 * Output: none
 * Side effect: turn on bit 6 of register B and set the RATE (15) to register A
*/
void rtc_init(){
    disable_irq(RTC_IRQ); // disable the RTC IRQ line
    outb(RTC_REG_B, RTC_PORT); // select register B, and disable NMI
    char prev = inb(RTC_DATA); // read register B, and the content of register B will be lost
    outb(RTC_REG_B, RTC_PORT); // set the index again
    outb(prev | 0x40, RTC_DATA); // turn on bit 6 of register B
    // read register C to make sure to get another interrupt
    outb(RTC_REG_C&0x0F, RTC_PORT); // select register C (0x0C)
    inb(RTC_DATA); // read register C, and the content of register C will be lost
    // set rate
    outb(RTC_REG_A, RTC_PORT);		// set index to register A, disable NMI
    prev = inb(RTC_DATA);	// get initial value of register A
    outb(RTC_REG_A, RTC_PORT);		// reset index to A
    outb((prev & 0xF0) | RATE, RTC_DATA);  //write only our rate to A. Note, rate is the bottom 4 bits.
    enable_irq(RTC_IRQ);  // enable the RTC IRQ line
    }
/* 
 * rtc_handler: handler for rtc
 * Input: irq_num: none
 * Output: none
 * Side effect: call the test_interrupts to change the character throughout the screen (and sending EOI afterwards)
*/
void rtc_handler(){
    cli();
    
    test_interrupts(); // comment this to un-enable rtc test

    // read register C after an IRQ8 to happen again
    outb(RTC_REG_C&0x0F, RTC_PORT); // select register C (0x0C)
    inb(RTC_DATA); // read register C, and the content of register C will be lost
    send_eoi(RTC_IRQ);
    sti();
}
