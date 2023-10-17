#include "idt_handler.h"

// exceptions
// print exceptions to report errors
void division_error_handler() {cli(); clear(); printf("   Oops! Exception: Division Error   "); while(1); sti();}
void debug_handler() {cli(); clear(); printf("   Oops! Exception: Debug   "); while(1); sti();}
void nmi_handler() {cli(); clear(); printf("   Oops! Exception: Non-maskable Interrupt   "); while(1); sti();}
void breakpoint_handler() {cli(); clear(); printf("   Oops! Exception: Breakpoint   "); while(1); sti();}
void overflow_handler() {cli(); clear(); printf("   Oops! Exception: Overflow   "); while(1); sti();}
void bound_range_exceeded_handler() {cli(); clear(); printf("   Oops! Exception: Bound Range Exceeded   "); while(1); sti();}
void invalid_opcode_handler() {cli(); clear(); printf("   Oops! Exception: Invalid Opcode   "); while(1); sti();}
void device_not_avail_handler() {cli(); clear(); printf("   Oops! Exception: Device Not Available   "); while(1); sti();}
void double_fault_handler() {cli(); clear(); printf("   Oops! Exception: Double Fault   "); while(1); sti();}
void coprocessor_seg_overrun_handler() {cli(); clear(); printf("   Oops! Exception: Coprocessor Segment Overrun   "); while(1); sti();}
void invalid_task_state_seg_handler() {cli(); clear(); printf("   Oops! Exception: Invalid Task State Segment   "); while(1); sti();}
void seg_not_present_handler() {cli(); clear(); printf("   Oops! Exception: Segment Not Present   "); while(1); sti();}
void stack_seg_handler() {cli(); clear(); printf("   Oops! Exception: Stack Segment Fault   "); while(1); sti();}
void general_protection_handler() {cli(); clear(); printf("   Oops! Exception: General Protection Fault   "); while(1); sti();}
void page_fault_handler() {cli(); clear(); printf("   Oops! Exception: Page Fault   "); while(1); sti();}
void reserved_handler() {cli(); clear(); printf("   Oops! Exception: Reserved   "); while(1); sti();}
void floating_point_handler() {cli(); clear(); printf("   Oops! Exception: Floating Point Exception   "); while(1); sti();}
void alignment_check_handler() {cli(); clear(); printf("   Oops! Exception: Alignment Check   "); while(1); sti();}
void machine_check_handler() {cli(); clear(); printf("   Oops! Exception: Machine Check   "); while(1); sti();}
void simd_floating_point_handler() {cli(); clear(); printf("   Oops! Exception: SIMD Floating Point   "); while(1); sti();}

void sys_call_handler() {clear(); printf("System Call! Wait for checkpoint 3 and 4!"); while(1);}
