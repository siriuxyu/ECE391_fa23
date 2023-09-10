
# mp1.S - missile-command version
# Good luck, and have fun!

.data
	
    # Constants for accessing the fields of a struct missile, 
    # struct missile is defined in rtc.h and mp1.h

	NEXT 	  = 0
	X	  = 4
	Y	  = 8
	VX	  = 12
	VY	  = 16
	DEST_X	  = 20
	DEST_Y	  = 24
	EXPLODED  = 28
	C	  = 32

    # Character to draw for an explosion - '@'

	EXPLOSION = 64


# Data shared between this file and rtc.c helper functions

# This '.globl' directive makes these symbols visible externally
.globl mp1_missile_list, base_alive, mp1_score

mp1_missile_list:	.long 0x0	# Head of list pointer
base_alive:		.long 0x0	# Array of 3 bytes, plus a padding byte
mp1_score:		.long 0x0	# Player's current score


# Data private to this  file

base_pic:     	    .string "/^^^\\"	# Picture of a live base
dead_base_pic: 	    .string "xxxxx"	# Picture of a dead base
crosshairs_x:		.long 0x0	# X-position of the crosshairs
crosshairs_y:		.long 0x0	# Y-position of the crosshairs

.text

# void mp1_poke(void);
# You can use this function to write to video memory.
#
# Interface: Register-based arguments (not C-style)
#    Inputs: %cl  - The byte you wish to write
#            %eax - Offset from the start of video memory that you wish
#                   to write to
#   Outputs: Text-mode video screen is written to at location %eax with
#            the byte in %cl
# Registers: Clobbers EDX

mp1_poke:
		movl    vmem_base_addr(,1),%edx
		movb    %cl,(%edx,%eax,1)
		ret

#   ----------------- Exported functions ---------------------

# void mp1_rtc_tasklet(unsigned long garbage);
# Performs three tasks:
#	(1) updates the list of missiles (implement this in update_missiles,
#           below, and call it from here).
#	(2) Redraw the bases - they may have been overwritten with missiles
#	(3) Redraw the crosshairs - it may have been overwritten with missiles
# Inputs   : none
# Outputs  : none
# Registers: Standard C calling convention

.globl mp1_rtc_tasklet
mp1_rtc_tasklet:
		pushl	%ebp
		movl	%esp, %ebp					
		pushl	%eax							# [callee-saved]
		pushl	%ecx
		pushl	%edx

		pushl	%ebx
		pushl	%esi
		pushl	%edi

	mp1_process_missiles:
		pushl	mp1_missile_list
		cmpl	0x00, mp1_missile_list
		jne		empty_list
		call	update_missiles

	empty_list:


	mp1_redraw_cities:


	mp1_redraw_xhairs:


		popl	%edi
		popl	%esi
		popl	%ebx

		popl	%edx
		popl	%ecx
		popl	%eax

			leave		
			ret

# int mp1_ioctl(unsigned long arg, unsigned int cmd)
# The dispatch function for the MP1 ioctls - should use the cmd argument
# and a jumptable to execute one of the specific ioctls implemented below.
# Inputs   : unsigned long arg - parameter to the mp1_ioctl_....
#          : unsigned int cmd  - specifies which mp1_ioctl_... function 
#          :                     to execute
# Outputs  : Returns an integer - depends on which ioctl() function is called
# Registers: Standard C calling convention

ioctl_jumptable:
		.long	mp1_ioctl_startgame
		.long	mp1_ioctl_addmissile
		.long	mp1_ioctl_movexhairs
		.long	mp1_ioctl_getstatus
		.long	mp1_ioctl_endgame

.globl mp1_ioctl
mp1_ioctl:
		pushl	%ebp
		movl	%esp, %ebp
		pushl	%ebx				# [callee-saved]
		pushl	%esi
		pushl	%edi

		movl	12(%ebp), %ecx		# read cmd
		cmpl	$0x00000000, %ecx	# if cmd < 0
		jb		invalid_cmd
		cmpl	$0x00000004, %ecx	# if cmd > 4
		ja		invalid_cmd

		lea		ioctl_jumptable, %edx
		movl	(%ebx, %edx, 4), %eax
		jmp		*%eax
	
	invalid_cmd:
		movl	$-1, %eax			# return -1

		popl	%edi				# [callee-saved]
		popl	%esi
		popl	%ebx
			leave
			ret


# ----------------- Functions private to this file -------------------

update_missiles:
		pushl	%ebp
		movl	%esp, %ebp
		pushl	%ebx					# [callee-saved]
		pushl	%esi
		pushl	%edi

	update_loop:
		movl	8(%ebp), %ebx			# read the missile pointer from stack
		cmpl	0x00, %ebx				# if null, end loop
		je 		end_loop
		movl	8(%ebp), %esi			# read prev (head -> prev = head)
		

		cmpl	0x00, EXPLODED(%ebx)	
		ja		is_exploded				# if exploded parameter is positive

	not_exploded:
		add 	VX(%ebx), X(%ebx)		# update x
		add		VY(%ebx), Y(%ebx)		# update y

	check_bound:
		cmpl	0x004f0000, X(%ebx)		# if x > 79
		ja		out_of_bounds
		cmpl	0x00180000, Y(%ebx)		# if y > 24
		ja		out_of_bounds
		cmpl	0x00000000, X(%ebx)		# if x < 0
		jb		out_of_bounds
		cmpl	0x00000000, Y(%ebx)		# if y < 0
		jb		out_of_bounds

	in_bound:
		movl 	DEST_X(%ebx), %esi		# read the destination x
		shrl	$16, %esi				# shift right 16 bits, to compare with x
		cmpl	%esi, X(%ebx)
		je	 	is_exploded

		movl	DEST_Y(%ebx), %edi		# read the destination y
		shrl	$16, %edi				# shift right 16 bits, to compare with y
		cmpl	%edi, Y(%ebx)
		je		is_exploded


	is_exploded:
		pushl	%ebx
		call	missile_explode

		cmpl	%eax, 0x00
		jne		notify

	end_notify:
		movl	%eax, EXPLODED(%ebx)	# set the exploded parameter

		popl	%ebx

	

	next_missile:
		movl	%ebx, %esi				# prev = this
		movl	NEXT(%ebx), %ebx		# this = next
		jmp		update_loop

		popl	%edi					# [callee-saved]
		popl	%esi
		popl	%ebx


	end_loop:
	    leave
		ret


	out_of_bounds:
		pushl	%esi	# prev
		pushl	%ebx	# this
		call	mp1_missile_remove
		popl	%ebx
		popl	%esi
		jmp		next_missile

	notify:
		call 	mp1_notify_user
		
		jmp 	end_notify





draw_base:
		pushl	%ebp
		movl	%esp, %ebp
		pushl	%ebx					# [callee-saved]
		pushl	%esi
		pushl	%edi

		movl	8(%ebp), %ebx			# read base location


draw_crosshairs:
		pushl	%ebp
		movl	%esp, %ebp
		pushl	%eax
		pushl	%ebx					# [callee-saved]
		pushl	%esi
		pushl	%edi

		movl	8(%ebp), %eax			# read x
		movl	12(%ebp), %ebx			# read y
		movl	16(%ebp), %esi			# read char
		movl	20(%ebp), %edi			# set color to black

		cmpl	$0, %edi
		je		no_shift

		shrl	$16, %eax				# get x
		shrl	$16, %ebx				# get y

	no_shift:
		iumll	$80, %ebx
		addl	%eax, %ebx				# 80 * y + x
		iumll	$2, %ebx				#
		
		call	mp1_poke
		
		popl	%edi					# [callee-saved]
		popl	%esi
		popl	%ebx
		popl	%eax

			leave
			ret

draw_background:
        pushl   %ebp
		movl    %esp, %ebp
		pushl   %ebx					# [callee-saved]
		pushl   %esi
		pushl   %edi

		movl	base_alive, %ebx	
		mobl	%ebx, %esi				# save base_alive
		movl	$0x00ff0000, %edi		# get base 3 status
		pushl	$18
		call	draw_base
		addl	$4, %esp

		movl	%esi, %ebx				# restore base_alive
		movl	$0x0000ff00, %edi		# get base 2 status
		pushl	$38
		call	draw_base
		addl	$4, %esp

		movl	%esi, %ebx				# restore base_alive
		movl	$0x000000ff, %edi		# get base 1 status
		pushl	$58
		call	draw_base
		addl	$4, %esp

		pushl	$0
		pushl	$'+'
		pushl	crosshairs_x
		pushl	crosshairs_y
		call	draw_crosshairs
		addl	$16, %esp

		popl	%edi					# [callee-saved]
		popl	%esi
		popl	%ebx

			leave
			ret

mp1_missile_remove:
		pushl	%ebp
		movl	%esp, %ebp
		pushl	%ebx
		pushl	%esi
		pushl	%edi

		movl	8(%ebp), %ebx		# this
		movl	12(%ebp), %esi		# prev
		movl	NEXT(%ebx), %edi	# next

		cmpl	%ebx, %esi			# if this is head
		je		is_head

	not_head:
		movl	%edi, NEXT(%esi)	# prev -> next = next
		jmp		end_remove

	is_head:
		movl	%edi, mp1_missile_list

	end_remove:
		popl	%edi				# [callee-saved]
		popl	%esi
		popl	%ebx

			leave
			ret


mp1_ioctl_startgame:
		movl 	$0, mp1_score			# init score
		movl	$0, (mp1_missile_list)	# init empty missile list
		movl	$0x00ffffff, base_alive	# init alive bases
		movl	$40, (crosshairs_x)		# init crosshairs to middle (40,12)
		movl	$12, (crosshairs_y)

		popl	%edi					# [callee-saved]
		popl	%esi
		popl	%ebx

			leave
			ret

mp1_ioctl_addmissile:
		pushl	%ecx				# [caller-saved]
		pushl	%edx
		pushl	$36
		call	mp1_malloc
		addl	$4, %esp	
		popl	%edx
		popl	%ecx

		cmpl	$0, %eax
		je		fail_malloc

		movl	8(%ebp), %edx			# "from"
		pushl	$36
		pushl	%edx
		pushl	%eax
		call	mp1_copy_from_user		# copy_from_user (to, from, 36)
		addl	$12, %esp
		cmpl	$0, %eax
		jne		fail_copy

		movl	mp1_missile_list, %edx
		movl	%edx, NEXT(%eax)		# new -> next = head
		movl	%eax, mp1_missile_list	# head = new

		movl	$0, %eax				# return 0
		popl	%edi
		popl	%esi
		popl	%ebx

			leave
			ret

	fail_copy:
		pushl	%eax
		call	mp1_free
		addl	$4, %esp

	fail_malloc:
		movl	$-1, %eax			# return -1
		popl	%edi
		popl	%esi
		popl	%ebx

			leave
			ret



mp1_ioctl_movexhairs:
		pushl	%edx


		movl	8(%ebp), %edx		# read arg
		movl	%edx, %eax			# copy arg

		shrl	$16, %eax			# get y
		movl	crosshairs_y, %eax
		cmpl	$24, %eax			# if y > 24
		ja	    test_x
		cmpl	$0, %eax			# if y < 0
		jb		test_x
		movl	%eax, crosshairs_y	# if new_y in bounds, set y

		popl	%edi
		popl	%esi
		popl	%ebx
		

	test_x:
		and 	$0x0000ffff, %edx	# get x
		add		crosshairs_x, %edx
		cmpl	$79, %edx			# if x > 79
		ja		end_movexhairs
		cmpl	$0, %edx			# if x < 0
		jb		end_movexhairs
		movl	%edx, crosshairs_x	# if new_x in bounds, set x


	end_movexhairs:
		and 	$0x00, %eax			# always return 0
		popl	%edx
		

		popl	%edi
		popl	%esi
		popl	%ebx
			leave
			ret

mp1_ioctl_getstatus:
		movl	mp1_score, %esi
		andl	$0x0000ffff, %esi	

		movl	base_alive, %edi
		movl	%edi, %eax
		andl	$0x00ff0000, %eax
		cmpl	$0x00000000, %eax
		je		city3_dead
		orl 	$0x00040000, %esi

	city3_dead:
		movl	%edi, %eax
		andl	$0x0000ff00, %eax
		cmpl	$0x00000000, %eax
		je		city2_dead
		orl 	$0x00020000, %esi

	city2_dead:
		movl	%edi, %eax
		andl	$0x000000ff, %eax
		cmpl	$0x00000000, %eax
		je		city1_dead
		orl 	$0x00010000, %esi

	city1_dead:
		lea 	mp1_score, %ebx	    # read "from"
		movl	mp1_score, %ecx		# store score
		movl	%esi, (%ebx)		# store status
		movl	8(%ebp), %edx		# read "to"
		pushl	%eax
		pushl	$4
		pushl	%ebx
		pushl	%edx
		call	mp1_copy_to_user
		addl	$12, %esp
		popl	%edx
		popl	%ebx
		popl	%esi
		cmpl	$0x00000000, %eax	# if copy_to_user failed
		jne		fail_copy

		popl	%edi				# [callee-saved]
		popl 	%esi
		popl	%ebx

			leave
			ret

	fail_copy:
		movl	$-1, %eax			# return -1
		movl	%ecx, mp1_score		# reset score

		popl	%edi				# [callee-saved]
		popl	%esi
		popl	%ebx

			leave
			ret

mp1_ioctl_endgame:
		movl	mp1_missile_list, %esi	
		cmpl	$0x00000000, %esi
		je		loop_done

	loop:
		movl	NEXT(%esi), %edi
		pushl	%eax
		pushl	%ecx
		pushl	%edx
		pushl	%esi
		call	mp1_free
		addl	$4, %esp
		popl	%edx
		popl	%ecx
		popl	%eax
		movl	%edi, %esi
		jmp		loop


	loop_done:	
		popl	%edi					# [callee-saved]
		popl	%esi
		popl	%ebx

			leave
			ret
