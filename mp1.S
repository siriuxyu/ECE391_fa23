
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
		pushfl

	.mp1_process_missiles:
		pushl	mp1_missile_list
		cmpl	$0x00, mp1_missile_list
		jne		.empty_list
		call	update_missiles
		popl	mp1_missile_list

	.empty_list:


	.mp1_redraw_base_and_crosshairs:
		call	draw_background

		popfl
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
		pushl	%ecx

		movl	12(%ebp), %ecx		# read cmd
		cmpl	$0, %ecx			# if cmd < 0
		jl		.invalid_cmd
		cmpl	$4, %ecx			# if cmd > 4
		jg		.invalid_cmd

		lea		ioctl_jumptable, %edx
		movl	(%edx, %ecx, 4), %eax
		jmp		*%eax
	
	.invalid_cmd:
		movl	$-1, %eax			# return -1

		popl	%ecx				# [callee-saved]
		popl	%edi
		popl	%esi
		popl	%ebx
			leave
			ret


# ----------------- Functions private to this file -------------------

# update_missiles (this)
update_missiles:
		pushl	%ebp
		movl	%esp, %ebp
		pushl	%ebx					# this
		pushl	%esi					# prev
		pushl	%edi
		pushl	%edx					# next

		movl	8(%ebp), %ebx			# read the missile pointer from stack
		movl	8(%ebp), %ecx			# read prev (head -> prev = head)

	.update_loop:
		cmpl	0x00, %ebx				# if null, end loop
		je 		.end_loop
		pushl	$' '						# wipe out old from screen
		pushl	Y(%ebx)
		pushl	X(%ebx)
		call	draw_char
		addl	$12, %esp

		cmpl	$0x00, EXPLODED(%ebx)	
		jg		.is_exploded				# if exploded parameter is positive

		movl	X(%ebx), %esi
		movl	Y(%ebx), %edi
		addl 	VX(%ebx), %esi		# update x
		addl	VY(%ebx), %edi		# update y
		movl	%esi, X(%ebx)
		movl	%edi, Y(%edi)

	.check_bound:
		cmpl	$0x004f0000, X(%ebx)		# if x > 79
		jg		.out_of_bounds
		cmpl	$0x00180000, Y(%ebx)		# if y > 24
		jg		.out_of_bounds
		cmpl	$0x00000000, X(%ebx)		# if x < 0
		jl		.out_of_bounds
		cmpl	$0x00000000, Y(%ebx)		# if y < 0
		jl		.out_of_bounds

	.in_bound:
		movl 	X(%ebx), %esi			# x
		movl	%esi, %ecx				# %ecx = x_shift
		shrl	$16, %ecx				# shift right 16 bits, to compare with x
		cmpl	%ecx, DEST_X(%ebx)
		jne	 	.not_exploded

		movl	Y(%ebx), %edi			# y
		movl	%edi, %edx				# %edx = y_shift
		shrl	$16, %edx				# shift right 16 bits, to compare with y
		cmpl	%edx, DEST_Y(%ebx)
		je		.is_exploded
		# jmp		not_exploded

	.not_exploded:
		# movl	Y(%ebx), %edi			# y
		# shrl	$16, %edi				# shift y
		# movl	X(%ebx), %esi			# x
		# shrl	$16, %esi				# shift x

		pushl	C(%ebx)					# draw new missile	
		pushl	%edx
		pushl	%ecx
		call	draw_char
		addl	$12, %esp

		jmp		.next_missile

	.is_exploded:
		pushl	EXPLOSION				# draw explosion
		pushl	%edx
		pushl	%ecx
		call	draw_char
		addl	$12, %esp

		pushl	%ebx
		# pushl	%edx
		call	missile_explode
		# popl	%edx
		popl	%ebx
		cmpl	%eax, 0x00
		je		.end_notify

	.notify:
		pushl	%eax
		call 	mp1_notify_user
		popl	%eax

	.end_notify:
		decl 	EXPLODED(%ebx)			# decrement exploded parameter
		cmpl	$0, EXPLODED(%ebx)	
		je 		.finish_explode

		movl	Y(%ebx), %edi			# y
		shrl	$16, %edi				# shift y
		movl	X(%ebx), %esi			# x
		shrl	$16, %esi				# shift x

		pushl	EXPLOSION				# char
		pushl	%edi
		pushl	%esi
		call	draw_char
		addl	$12, %esp
		
	.next_missile:
		movl	%ebx, %ecx				# prev = this
		movl	NEXT(%ebx), %ebx		# this = next
		jmp		.update_loop


	.end_loop:
		popl	%edx
		popl	%edi					# [callee-saved]
		popl	%esi
		popl	%ebx

	    	leave
			ret


	.out_of_bounds:
		movl	NEXT(%ebx), %edx		# next
		pushl	%ecx	# prev
		pushl	%ebx	# this
		call	mp1_missile_remove
		popl	%ebx
		popl	%ecx
		cmpl	%ebx, %ecx
		jne		.nonhead_condition
		movl	%edx, %ecx
	.nonhead_condition:
		movl	%edx, %ebx
		jmp		.update_loop


	.finish_explode:
		pushl	$' '					# wipe out old from screen
		pushl	Y(%ebx)
		pushl	X(%ebx)
		call	draw_char
		addl	$12, %esp

		movl	NEXT(%ebx), %edx
		pushl	%ecx	# prev
		pushl	%ebx	# this
		call	mp1_missile_remove
		popl	%ebx
		popl	%ecx
		cmpl	%ebx, %ecx
		jne		.nonhead_condition

		movl	%edx, %ecx
	.nothead_condition:
		movl	%edx, %ebx

		jmp		.update_loop


# draw_base (loc, status)
draw_base:
		pushl	%ebp
		movl	%esp, %ebp
		pushl	%ebx					# [callee-saved]
		pushl	%esi
		pushl	%edi
		pushl	%ecx

		movl	8(%ebp), %ebx			# read base location
		movl	12(%ebp), %esi			# read base status
		movl	$5, %ecx				# counter

		cmpl	$0, %esi
		je		.dead_base

	.live_base:
		lea		base_pic, %edi			# get base picture
		jmp		.draw_loop

	.dead_base:
		lea		dead_base_pic, %edi		# get dead base picture

	.draw_loop:
		pushl	(%edi)
		pushl	$24
		pushl	%ebx
		call	draw_char				# draw_char(x, y, char)
		addl	$12, %esp

		decl	%ecx
		incl 	%ebx
		incl	%edi
		jne		.draw_loop

		movl	%ebx, %esi				# save base location

		popl	%ecx					# 
		popl	%edi					# [callee-saved]
		popl	%esi
		popl	%ebx

			leave
			ret


# draw_char (x, y, char)
draw_char:
		pushl	%ebp
		movl	%esp, %ebp
		pushl	%eax
		pushl	%ebx					# [callee-saved]
		pushl	%esi
		pushl	%edi
		pushl	%ecx

		movl	8(%ebp), %eax			# read x
		movl	12(%ebp), %ebx			# read y
		movl	16(%ebp), %ecx			# read char

		imull	$80, %ebx
		addl	%eax, %ebx				# 80 * y + x
		imull	$2, %ebx

		movl	%ebx, %eax				# set input
		# pushl	%ecx
		pushl	%edx					# save %edx
		call	mp1_poke
		popl	%edx
		# popl	%ecx
		
		popl	%ecx
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
		movl	%ebx, %esi				# save base_alive
		andl	$0x00ff0000, %edi		# get base 3 status
		pushl	%edi
		pushl	$58
		call	draw_base
		addl	$8, %esp

		movl	%esi, %ebx				# restore base_alive
		movl	$0x0000ff00, %edi		# get base 2 status
		pushl	%edi
		pushl	$38
		call	draw_base
		addl	$8, %esp

		movl	%esi, %ebx				# restore base_alive
		movl	$0x000000ff, %edi		# get base 1 status
		pushl	%edi
		pushl	$18
		call	draw_base
		addl	$8, %esp

		
		movl	crosshairs_x, %ebx
		movl	crosshairs_y, %edi
		shrl	$16, %ebx
		shrl	$16, %edi

		pushl	$'+'					# char
		pushl	%edi					# y
		pushl	%ebx					# x
		call	draw_char
		addl	$16, %esp

		popl	%edi					# [callee-saved]
		popl	%esi
		popl	%ebx

			leave
			ret

# mp1_missle_remove (this, prev)
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
		je		.is_head

	.not_head:
		movl	%esi, NEXT(%esi)	# prev -> next = next
		jmp		.end_remove

	.is_head:
		movl	%edi, mp1_missile_list

	.end_remove:


		pushl	%ebx
		call	mp1_free			# free memory
		addl	$4, %esp

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
		je		.fail_malloc


		movl	%eax, %ecx
		movl	8(%ebp), %edx			# "from"
		pushl	$36
		pushl	%edx
		pushl	%ecx
		call	mp1_copy_from_user		# copy_from_user (to, from, 36)
		popl	%ecx
		addl	$8, %esp
		cmpl	$0, %eax
		jne		.fail_copy

		movl	mp1_missile_list, %edx
		movl	%edx, NEXT(%ecx)		# new -> next = head
		movl	%ecx, mp1_missile_list	# head = new

		movl	$0, %eax				# return 0

		popl	%ecx
		popl	%edi
		popl	%esi
		popl	%ebx

			leave
			ret

	.fail_copy:
		pushl	%ecx
		call	mp1_free
		addl	$4, %esp

	.fail_malloc:
		movl	$-1, %eax			# return -1

		popl	%ecx				# [callee-saved]
		popl	%edi
		popl	%esi
		popl	%ebx

			leave
			ret



mp1_ioctl_movexhairs:
		pushl	%edx

		pushl	$' '				# wipe out old from screen
		pushl	crosshairs_y
		pushl	crosshairs_x
		call	draw_char
		addl	$12, %esp

		movl	8(%ebp), %edx		# read arg
		movl	%edx, %eax			# copy arg

		sarl	$16, %eax			# get y
		addl	crosshairs_y, %eax
		cmpl	$24, %eax			# if y > 24
		jl	    .test_x
		cmpl	$0, %eax			# if y < 0
		jg		.test_x
		jmp		.end_movexhairs	

	.test_x:
		movl	%edx, %ebx
		and 	$0x0000ffff, %ebx	# get x
		addl	crosshairs_x, %ebx
		cmpl	$79, %ebx			# if x > 79
		jg		.end_movexhairs
		cmpl	$0, %ebx			# if x < 0
		jl		.end_movexhairs
		movl	%ebx, crosshairs_x	# if new_x in bounds, set x and y
		movl	%eax, crosshairs_y

	.end_movexhairs:
		pushl	$'+'				# draw new crosshairs
		pushl	crosshairs_y
		pushl	crosshairs_x
		call	draw_char
		addl	$12, %esp

		and 	$0x00, %eax			# always return 0
		popl	%edx
		
		popl	%ecx
		popl	%edi
		popl	%esi
		popl	%ebx
			leave
			ret

mp1_ioctl_getstatus:
		movl	mp1_score, %esi
		andl	$0x0000ffff, %esi		# %esi[3,0] = score

		movl	base_alive, %edi
		movl	%edi, %eax
		andl	$0x00ff0000, %eax
		cmpl	$0x00000000, %eax
		je		.city3_dead
		orl 	$0x00040000, %esi

	.city3_dead:
		movl	%edi, %eax
		andl	$0x0000ff00, %eax
		cmpl	$0x00000000, %eax
		je		.city2_dead
		orl 	$0x00020000, %esi

	.city2_dead:
		movl	%edi, %eax
		andl	$0x000000ff, %eax
		cmpl	$0x00000000, %eax
		je		.city1_dead
		orl 	$0x00010000, %esi

	.city1_dead:
		lea 	mp1_score, %ebx	    # read "from"
		movl	mp1_score, %ecx		# store score
		movl	%esi, (%ebx)		# store status
		movl	8(%ebp), %edx		# read "to"

		push	%ecx				# caller-saved
		pushl	$4
		pushl	%ebx				# from
		pushl	%edx				# to
		call	mp1_copy_to_user
		addl	$12, %esp
		popl	%ecx				# caller-restore

		movl	%ecx, mp1_score		# restore score
		cmpl	$0x00000000, %eax	# if copy_to_user failed
		jne		.fail_copy


		movl	$0, %eax			# return 0
		popl	%ecx				# [callee-saved]
		popl	%edi
		popl 	%esi
		popl	%ebx

			leave
			ret

	.failed_copy:
		movl	$-1, %eax			# return -1
		movl	%ecx, mp1_score		# reset score

		popl	%ecx				# [callee-saved]
		popl	%edi
		popl	%esi
		popl	%ebx

			leave
			ret

mp1_ioctl_endgame:
		movl	mp1_missile_list, %esi	
	
	.loop:
		cmpl	$0x00000000, %esi
		je		.loop_done
		movl	NEXT(%esi), %edi
		pushl	%eax
		pushl	%ecx
		pushl	%edx
		pushl	%esi
		call	mp1_free
		popl	%esi
		popl	%edx
		popl	%ecx
		popl	%eax
		movl	%edi, %esi
		jmp		.loop


	.loop_done:	
		popl	%ecx				# [callee-saved]
		popl	%edi
		popl	%esi
		popl	%ebx

			leave
			ret
