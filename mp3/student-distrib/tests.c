#include "tests.h"
#include "x86_desc.h"
#include "lib.h"

#include "debug.h"
#include "i8259.h"
#include "idt.h"
#include "idt_handler.h"
#include "idt_linkage.h"
#include "idt.h"
#include "keyboard.h"
#include "page.h"
#include "rtc.h"

#define PASS 1
#define FAIL 0

#define VIDEO_START 0xB8000
#define VIDEO_SIZE 0x1000

#define KERNEL_START 0x400000
#define KERNEL_SIZE 0x400000


/* format these macros as you see fit */
#define TEST_HEADER 	\
	printf("[TEST %s] Running %s at %s:%d\n", __FUNCTION__, __FUNCTION__, __FILE__, __LINE__)
#define TEST_OUTPUT(name, result)	\
	printf("[TEST %s] Result = %s\n", name, (result) ? "PASS" : "FAIL");

static inline void assertion_failure(){
	/* Use exception #15 for assertions, otherwise
	   reserved by Intel */
	asm volatile("int $15");
}


/* Checkpoint 1 tests */

/* IDT Test - Example
 * 
 * Asserts that first 10 IDT entries are not NULL
 * Inputs: None
 * Outputs: PASS/FAIL
 * Side Effects: None
 * Coverage: Load IDT, IDT definition
 * Files: x86_desc.h/S
 */
int idt_test(){
	TEST_HEADER;

	int i;
	int result = PASS;
	for (i = 0; i < 10; ++i){
		if ((idt[i].offset_15_00 == NULL) && 
			(idt[i].offset_31_16 == NULL)){
			assertion_failure();
			result = FAIL;
		}
	}

	return result;
}

/* -------------------- TEST EXCEPTIONS -------------------- */

/* #0x0 Divide by 0 Test
 * 
 * If successful, should pop a divide by 0 exception
 * Inputs: None
 * Outputs: Exception or FAIL
 * Side Effects: None
 * Coverage: IDT, IDT handler
 * Files: idt_handler.c/h
 */
int divide_by_0_test() {
	TEST_HEADER;
	int a = 1;
	int b = 0;
	int c = a / b;
	c = c;		// to avoid unused variable warning
	return FAIL;
}


/* #0x4 Overflow Test
 * 
 * If successful, should pop an overflow exception
 * Inputs: None
 * Outputs: Exception or FAIL
 * Side Effects: None
 * Coverage: IDT, IDT handler
 * Files: idt_handler.c/h
 */
// int overflow_test() {
// 	TEST_HEADER;
// 	int a = 0x7FFFFFFF;
// 	int b = 0x7FFFFFFF;
// 	b += a;		// to avoid unused variable warning
// 	return FAIL;
// }

/* #0x5 Bound Range Exceeded Test
 * 
 * If successful, should pop a bound range exceeded exception
 * Inputs: None
 * Outputs: Exception or FAIL
 * Side Effects: None
 * Coverage: IDT, IDT handler
 * Files: idt_handler.c/h
 */
// int bound_range_exceeded_test() {
// 	TEST_HEADER;
// 	int a[2] = {0, 1};
// 	int b = a[2];
// 	b = b;		// to avoid unused variable warning
// 	return FAIL;
// }

/* #0x6 Invalid Opcode Test
 * 
 * If successful, should pop an invalid opcode exception
 * Inputs: None
 * Outputs: Exception or FAIL
 * Side Effects: None
 * Coverage: IDT, IDT handler
 * Files: idt_handler.c/h
 */
int invalid_opcode_test() {
	TEST_HEADER;
	asm volatile("ud2");
	return FAIL;
}

/* Test Any Exceptions -- use ASM
 * 
 * If successful, should pop an exception as indicated
 * Inputs: None
 * Outputs: Exception or FAIL
 * Side Effects: None
 * Coverage: IDT, IDT handler
 * Files: idt_handler.c/h
 */
int Any_Exception_Test() {
	TEST_HEADER;
	asm volatile("int $0x01");
	return FAIL;
}


/* Test System call -- use ASM
 * 
 * If successful, should pop a system call as indicated
 * Inputs: None
 * Outputs: system call or FAIL
 * Side Effects: None
 * Coverage: IDT, IDT handler
 * Files: idt_handler.c/h
 */
int System_Call_Test() {
	TEST_HEADER;
	asm volatile("int $0x80");
	return FAIL;
}


/* -------------------- TEST PAGING -------------------- */

/* Page Fault Test Series
 * 
 * If successful, should pop a page fault exception
 * Inputs: None
 * Outputs: Exception or FAIL
 * Side Effects: None
 * Coverage: IDT, IDT handler
 * Files: idt_handler.c/h, page.c/h
 */
int page_fault_test_1() {
	TEST_HEADER;
	int *a = (int *)0x100000;
	int b = *a;
	b = b;
	return FAIL;
}
// lower boundary condition of kernel memory
int page_fault_kernel_boundary_1() {
	TEST_HEADER;
	int *a = (int *)0x3FFFFF;
	int b = *a;
	b = b;		// to avoid unused variable warning
	return FAIL;
}
// upper boundary condition of kernel memory
int page_fault_kernel_boundary_2() {
	TEST_HEADER;
	int *a = (int *)0x800000;
	int b = *a;
	b = b;		// to avoid unused variable warning
	return FAIL;
}
// lower boundary condition of video memory
int page_fault_video_boundary_1() {
	TEST_HEADER;
	int *a = (int *)0xB7FFF;
	int b = *a;
	b = b;		// to avoid unused variable warning
	return FAIL;
}
// upper boundary condition of video memory
int page_fault_video_boundary_2() {
	TEST_HEADER;
	int *a = (int *)0xB9000;
	int b = *a;
	b = b;		// to avoid unused variable warning
	return FAIL;
}

/* Page Dereference Null Test
 * 
 * If successful, should pop a page fault exception
 * Inputs: None
 * Outputs: Exception or FAIL
 * Side Effects: None
 * Coverage: IDT, IDT handler
 * Files: idt_handler.c/h, page.c/h
 */
int page_deref_null_test() {
	TEST_HEADER;

	int* a = NULL;
	int b = *a;			// should pop a page fault exception
	b = b;				// to avoid unused variable warning
	return FAIL;
}

/* Page Success Test
 * 
 * If successful, 
 * Inputs: None
 * Outputs: PASS
 * Side Effects: None
 * Coverage: IDT, IDT handler
 * Files: idt_handler.c/h, page.c/h
 */
int page_success_test() {
	TEST_HEADER;

	int* a = (int *) VIDEO_START;			// point to video memory
	int* b = (int *) KERNEL_START;			// point to kernel memory
	int temp;

	for (; a < (int *) (VIDEO_START + VIDEO_SIZE); a++) {
		temp = *a;							// try copy video memory out
	}
	for (; b < (int *) (KERNEL_START + KERNEL_SIZE); b++) {
		temp = *b;							// try copy kernel memory out
	}
	return PASS;							// if no exception, PASS
}



/* Checkpoint 2 tests */
/* Checkpoint 3 tests */
/* Checkpoint 4 tests */
/* Checkpoint 5 tests */


/* Test suite entry point */
void launch_tests(){
	TEST_OUTPUT("idt_test", idt_test());

	// TEST_OUTPUT("Test System Call", System_Call_Test());
	
	/* ---------- Exception Tests ---------- */

	// TEST_OUTPUT("Test Any Exceptions", Any_Exception_Test());

	// TEST_OUTPUT("divide_by_0_test", divide_by_0_test());

	// TEST_OUTPUT("invalid_opcode_test", invalid_opcode_test());


	/* ---------- Page Fault Test ---------- */
	// TEST_OUTPUT("page_fault_test_1", page_fault_test_1());
	// TEST_OUTPUT("page_fault_kernel_lower_boundary", page_fault_kernel_boundary_1());
	// TEST_OUTPUT("page_fault_kernel_upper_boundary", page_fault_kernel_boundary_2());
	// TEST_OUTPUT("page_fault_video_lower_boundary", page_fault_video_boundary_1());
	// TEST_OUTPUT("page_fault_video_upper_boundary", page_fault_video_boundary_2());
	// TEST_OUTPUT("page_deref_null_test", page_deref_null_test());
	// TEST_OUTPUT("page_SUCCESS_test", page_success_test());

	// launch your tests here
}
