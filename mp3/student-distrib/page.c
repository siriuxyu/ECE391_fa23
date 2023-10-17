#include "page.h"

void page_init() 
{
    //initialize all the entries in PD and PT to 0 ; blank page directory and page table
    int i;
    for(i=0; i < PD_ENTRY_NUM; i++)
    {
        page_directory[i].val = 0x2;
    }
    for(i=0; i < PT_ENTRY_NUM; i++)
    {
        page_table[i].val = 0;
    }
    // populate value to page table
    uint32_t video_memory_ = VIDEO_MEMORY;                      //video memory addr
    uint32_t page_table_addr = (uint32_t)page_table;            //pt addr
    uint32_t page_directory_addr = (uint32_t)page_directory;    //pd addr

    page_table[video_memory_  >> 12].val = (video_memory_ & 0xFFFFF000) | 0x3;      //pt entry
    page_directory[0].val = (page_table_addr & 0xFFFFF000) | 0x3;                   //pd entry(pt)
    page_directory[1].val = (page_directory_addr & 0xFFFFF000) | 0x183;             //pd entry(kernel page)
    // cr3 : page directory addr
    // cr4 : allow 4 mb page (enable PSE)
    // cr0 : set paging (PG)
    asm volatile(
        "movl  %0, %%eax;           \
         movl  %%eax, %%cr3;        \
         movl  %%cr4, %%eax;        \
         orl   $0x00000010, %%eax;  \
         movl  %%eax, %%cr4;        \
         movl  %%cr0, %%eax;        \
         orl   $0x80000000, %%eax;  \
         movl  %%eax, %%cr0;"
        : /*no output*/
        : "r" (&page_directory)
        : "%eax"
    );
}
