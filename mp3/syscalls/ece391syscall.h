#if !defined(ECE391SYSCALL_H)
#define ECE391SYSCALL_H

#include <stdint.h>

/* All calls return >= 0 on success or -1 on failure. */

/*  
 * Note that the system call for halt will have to make sure that only
 * the low byte of EBX (the status argument) is returned to the calling
 * task.  Negative returns from execute indicate that the desired program
 * could not be found.
 */ 
extern int32_t ece391_halt (uint8_t status);
extern int32_t ece391_execute (const uint8_t* command);
extern int32_t ece391_read (int32_t fd, void* buf, int32_t nbytes);
extern int32_t ece391_write (int32_t fd, const void* buf, int32_t nbytes);
extern int32_t ece391_open (const uint8_t* filename);
extern int32_t ece391_close (int32_t fd);
extern int32_t ece391_getargs (uint8_t* buf, int32_t nbytes);
extern int32_t ece391_vidmap (uint8_t** screen_start);
extern int32_t ece391_set_handler (int32_t signum, void* handler);
extern int32_t ece391_sigreturn (void);
extern int32_t ece391_malloc (int32_t size);
extern int32_t ece391_free (void* ptr);
extern int32_t ece391_ioctl (unsigned long cmd, unsigned long arg);


enum signums {
	DIV_ZERO = 0,
	SEGFAULT,
	INTERRUPT,
	ALARM,
	USER1,
	NUM_SIGNALS
};

#endif /* ECE391SYSCALL_H */

