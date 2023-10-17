/* page.h - Defines for various x86 descriptors, descriptor tables,
 * and selectors
 * vim:ts=4 noexpandtab
 */

#ifndef _PAGE_H
#define _PAGE_H

#include "types.h"

// #ifndef ASM


#define PD_ENTRY_NUM 1024               //page directory entry
#define PT_ENTRY_NUM 1024               //page table entry             
#define BYTES_TO_ALIGN_TO_PD (4*1024)   // 4kb
#define BYTES_TO_ALIGN_TO_PT (4*1024)   // 4kb
#define VIDEO_MEMORY 0xB8000            // start addr pf video memory
#define KERNEL_MEMORY 0x400000          // 4MB


/* This is a page director entry. */
typedef union page_directory_entry_t {
        uint32_t val;
        struct 
        {
            uint32_t present       : 1; // present bit
            uint32_t read_write    : 1; // read/write 
            uint32_t user_super    : 1; 
            uint32_t PWT           : 1;
            uint32_t PCD           : 1;
            uint32_t A             : 1; // accessed
            uint32_t D             : 1;  //dirty
            uint32_t PS            : 1;
            uint32_t global        : 1;  //global
            uint32_t AVL           : 3;
            uint32_t pt_addr       :20;    // page table addr
        } __attribute__ ((packed));
} page_directory_entry_t;

/* This is a page table entry. */
typedef union page_table_entry_t {
        uint32_t val;
        struct {
            uint32_t present       : 1;  //present bit
            uint32_t read_write    : 1;  //read/write
            uint32_t user_super    : 1;  //user supervisor
            uint32_t PWT           : 1;  //write through 
            uint32_t PCD           : 1;
            uint32_t A             : 1;  //accessed
            uint32_t D             : 1;  //dirty
            uint32_t PAT           : 1;  //page attribute table
            uint32_t G             : 1;  //global
            uint32_t AVL           : 3;  //available
            uint32_t page_addr     : 20; // page table addr
        } __attribute__ ((packed));
} page_table_entry_t;

//create a blank page directory and page table
page_directory_entry_t page_directory[PD_ENTRY_NUM] __attribute__((aligned (BYTES_TO_ALIGN_TO_PD)));        //assign them to 4kb
page_table_entry_t page_table[PT_ENTRY_NUM] __attribute__((aligned (BYTES_TO_ALIGN_TO_PT)));                //assign them to 4kb

//page init function
void page_init();


// #endif /* ASM */
#endif /* _PAGE_H */
