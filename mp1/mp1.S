
# Author: Zixuan Qu (zixuanq3)
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
readynotifyuser:     .long 0x0
explodewhenenter:	.long 0x0

.text

# void mp1_poke(void);
# You can use this function to write to video memory.
#
# Interface: Register-based arguments (not C-style)
#    Inputs: %cl  - The byte you wish to write
#            %eax - Offset from the start of video memory that you wish
#                   to write to
#   Outputs: Text-mode video screen is written to at location %eax with
#            the byte in %ecx
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

# ------------------------------------------new function
.globl mp1_rtc_tasklet
mp1_rtc_tasklet:
		pushl %ebp
		movl %esp, %ebp

		PUSHL %eax
		PUSHL %ebx # use ebx to store mp1_missile_list
		PUSHL %ecx
		PUSHL %edx
		PUSHL %edi
		PUSHL %esi
		
		MOVL $0, readynotifyuser
		CALL update_missiles

	# all registers available now
	drawbases:
		MOVL $0x000000FF, %edi # judge base_alive
		MOVL base_alive, %esi # base alive info, example 0x00FF00FF
		MOVL $18, %ecx # first x coord

	drawbasesloop:
		CMPL $0xFF000000, %edi
		JE drawcrosshairs
		MOVL %esi, %edx # example 0x00FF00FF
		ANDL %edi, %edx # if alive, edx==1
		CMPL $0, %edx
		JNE setalive
		JMP startdraw
	setalive:
		MOVL $1, %edx
	startdraw:
		PUSHL %edx # as arg of base_alive info in draw_a_base
		PUSHL %ecx # as arg of x coordinate in draw_a_base
		CALL draw_a_base # (x, info)
		ADDL $8, %esp
		SHLL $8, %edi
		ADDL $20, %ecx
		JMP drawbasesloop

	drawcrosshairs:
		MOVL crosshairs_x, %ebx
		MOVL crosshairs_y, %ecx
		PUSHL $43 # draw + char for crosshair
		PUSH %ecx
		PUSH %ebx
		CALL draw_helper
		ADDL $12, %esp

	taskletdone:
		POPL %esi
		POPL %edi
		POPL %edx
		POPL %ecx
		POPL %ebx
		POPL %eax

		leave
		ret

# ---------------------------------------------------helper functions for drawing---------------------------------------------------
draw_helper:
		pushl %ebp
		movl %esp, %ebp
		PUSHL %eax
		PUSHL %ebx
		PUSHL %ecx
		PUSHL %edx # save all regis for me
		PUSHL %esi
		PUSHL %edi

		MOVL 8(%ebp), %ebx # input X high 16
		MOVL 12(%ebp), %ecx # input Y high 16
		MOVL 16(%ebp), %edx # input char to be draw
		IMULL $80, %ecx
		ADDL %ecx, %ebx
		IMULL $2, %ebx
		MOVL %ebx, %eax
		MOVL %edx, %ecx
		CALL mp1_poke

		POPL %edi
		POPL %esi
		POPL %edx # restore regis
		POPL %ecx
		POPL %ebx
		POPL %eax
		leave
		ret
# ---------------------------------------------------helper functions for drawing----------------------------------------------------

# (x, baselive info ) helper functions for drawing----------------------------------------------------
draw_a_base:
		pushl %ebp
		movl %esp, %ebp
		PUSHL %ebx
		PUSHL %ecx
		PUSHL %edx
		PUSHL %edi

		MOVL $5, %edi # down counter for drawing
		MOVL 8(%ebp), %ebx # x
		MOVL 12(%ebp), %ecx # 1 is alive, 0 is not
		CMPL $0, %ecx
		JE basedead
		LEA base_pic, %edx
		JMP drawabaseloop
	basedead:
		LEA dead_base_pic, %edx
	drawabaseloop:
		CMPL $0, %edi
		JE drawabasedone
		PUSHL (%edx)
		PUSHL $24
		PUSHL %ebx
		CALL draw_helper
		ADDL $12, %esp
		SUBL $1, %edi
		ADDL $1, %ebx
		ADDL $1, %edx
		JMP drawabaseloop
	drawabasedone:

		POPL %edi
		POPL %edx
		POPL %ecx
		POPL %ebx
		leave
		ret
# (x, baselive info ) helper functions for drawing----------------------------------------------------


# int mp1_ioctl(unsigned long arg, unsigned int cmd)
# The dispatch function for the MP1 ioctls - should use the cmd argument
# and a jumptable to execute one of the specific ioctls implemented below.
# Inputs   : unsigned long arg - parameter to the mp1_ioctl_....
#          : unsigned int cmd  - specifies which mp1_ioctl_... function 
#          :                     to execute
# Outputs  : Returns an integer - depends on which ioctl() function is called
# Registers: Standard C calling convention

# ------------------------------------------new function
.globl mp1_ioctl
mp1_ioctl:

		MOVL 8(%esp), %ecx # cmd is in ECX followed calling convention
		CMPL $4, %ecx		# compare whether cmd > 4
		JG mp1_ioctl_cmd_error   # above 4 go to done
		CMPL $0, %ecx
		JL mp1_ioctl_cmd_error

	mp1_ioctl_jump:
# -----------------------------------------------------------------------
		JMP *jump_table(, %ecx, 4)
		# it seems like a correct one?
# -----------------------------------------------------------------------

	mp1_ioctl_cmd_error:
		MOVL $-1, %eax

		ret

jump_table:
	.long mp1_ioctl_startgame, mp1_ioctl_addmissile, mp1_ioctl_movexhairs, mp1_ioctl_getstatus, mp1_ioctl_endgame

# ----------------- Functions private to this file -------------------

# ------------------------------------------new function
update_missiles:
		pushl %ebp
		movl %esp, %ebp

		PUSHL %ebx # use ebx to store mp1_missile_list
		PUSHL %ecx # previous missile pointer
		PUSHL %edx # local var1
		PUSHL %edi # local var2
		PUSHL %esi

		MOVL mp1_missile_list, %ebx # current missile 
		MOVL mp1_missile_list, %ecx # previous missile

	update_missiles_continue:

		MOVL $0, explodewhenenter
		# read missile list from global
		# MOVL mp1_missile_list, %ebx
		CMPL $0, %ebx
		JE update_missiles_done

		PUSHL $0x20
		MOVL X(%ebx), %edx 	# edx is X (loc1)
		SHRL $16, %edx 		# high 16 of x
		MOVL Y(%ebx), %edi 	# edi is Y (loc2)
		SHRL $16, %edi 		# high 16 of Y
		PUSHL %edi
		PUSHL %edx
		CALL draw_helper
		ADDL $12, %esp
		
		MOVL EXPLODED(%ebx), %esi
		CMPL $0, %esi
		JG before_check_explosion # first check explosion, if explode, no movement

		MOVL X(%ebx), %edx # edx is X (loc1)
		MOVL Y(%ebx), %edi # edi is Y (loc2)

		ADDL VX(%ebx), %edx # move the missile if not explode as describe
		ADDL VY(%ebx), %edi #
		MOVL %edx, X(%ebx)
		MOVL %edi, Y(%ebx) # update VX+X and VY+Y

		# three cases after movement below
		# 1. whether missile out of screen

		CMPL $0, %edx
		JL ready_remove
		CMPL $0, %edi
		JL ready_remove

		CMPL $0x0018FFFF, %edi
		JG ready_remove
		CMPL $0x004FFFFF, %edx
		JG ready_remove

		# restore full bits for updated X and Y --------------------------------------------------
		MOVL X(%ebx), %edx
		MOVL Y(%ebx), %edi # -------------------------------------------------------------

		# 2. whether missile is exploding
		# MOVL EXPLODED(%ebx), %esi
		# CMPL $0, %esi
		# JG check_explosion # exploded is 0 means to check explode
		SHRL $16, %edx # high 16 of x
		SHRL $16, %edi # high 16 of Y
		CMPL DEST_X(%ebx), %edx
		JE check_dest_y # meaning dest_X = high X, need to check Y

	# draw new locs
	normalmove:

		# restore full bits for X and Y --------------------------------------------------
		MOVL X(%ebx), %edx
		MOVL Y(%ebx), %edi # -------------------------------------------------------------
		SHRL $16, %edx # high 16 of x
		SHRL $16, %edi # high 16 of Y

		PUSHL C(%ebx)
		PUSHL %edi
		PUSHL %edx
		CALL draw_helper
		ADDL $12, %esp

		CMPL %ebx, %ecx
		JE process_first_missile # check whether is first missile
		
	process_not_first_missile:
		MOVL NEXT(%ebx), %ebx    # no first, update all pointers
		MOVL NEXT(%ecx), %ecx
		JMP update_missiles_continue

	process_first_missile: # its first missile then, only update ebx
		MOVL NEXT(%ebx), %ebx
		JMP update_missiles_continue

	check_dest_y:
		CMPL DEST_Y(%ebx), %edi
		JE check_explosion # meaning dest_Y = high Y, need to check explosion
		JMP normalmove

	before_check_explosion:
		MOVL $1, explodewhenenter

	check_explosion:
		PUSHL %edx	# prevent from being changed
		PUSHL %ecx
		PUSHL %ebx # argument for missile_explode 
		CALL missile_explode
		POPL %ebx
		POPL %ecx
		POPL %edx

		ORL %eax, readynotifyuser

		DECL EXPLODED(%ebx) # exploded --
		CMPL $0, EXPLODED(%ebx) # see if exploded==0, =0 means need to remove
		JE ready_remove

		# draw explosion if exploded not 0
	draw_explosion:
		# restore full bits for X and Y --------------discard-------------------------
		# MOVL X(%ebx), %edx
		# MOVL Y(%ebx), %edi # ----------------------discard---------------------------------
		# SUBL VY(%ebx), %edi
		# SUBL VX(%ebx), %edx
		# SHRL $16, %edx # high 16 of X
		# SHRL $16, %edi # high 16 of Y

		# PUSHL $0x20
		# PUSHL %edi
		# PUSHL %edx # ----------------------discard---------------------------------
		# CALL draw_helper
		# ADDL $12, %esp

		MOVL X(%ebx), %edx
		MOVL Y(%ebx), %edi # -------------------------------------------------
		SHRL $16, %edx # high 16 of X
		SHRL $16, %edi # high 16 of Y

		PUSHL $EXPLOSION
		PUSHL %edi
		PUSHL %edx
		CALL draw_helper
		ADDL $12, %esp

		CMPL %ebx, %ecx
		JE explode_first_missile # check whether is first missile

	explode_not_first_missile:
		MOVL NEXT(%ebx), %ebx    # no first, update all pointers
		MOVL NEXT(%ecx), %ecx
		JMP update_missiles_continue # 

	explode_first_missile: # its first missile then, only update ebx
		MOVL NEXT(%ebx), %ebx
		JMP update_missiles_continue

	ready_remove:
		CALL mp1_missile_remove # pre-caller for missile remove
		CMPL $1, %eax
		JE deletefirstmissile

	deletemissilefromlist:
		MOVL NEXT(%ebx), %edi
		MOVL %edi, NEXT(%ecx)	# delete no first missile
		PUSHL %ecx
		PUSHL %ebx
		CALL mp1_free
		ADDL $4, %esp
		POPL %ecx
		MOVL NEXT(%ecx), %ebx # move next ptr for ebx

		JMP deletedone

	deletefirstmissile:
		MOVL NEXT(%ebx), %ecx
		MOVL %ecx, mp1_missile_list
		PUSHL %ecx
		PUSHL %ebx			# delete first missile only update ebx
		CALL mp1_free
		ADDL $4, %esp
		POPL %ecx
		MOVL %ecx, %ebx

	deletedone:
		JMP update_missiles_continue

	update_missiles_done:
		CMPL $0, readynotifyuser
		JE updatefinish				# all missile list member updated
		CALL mp1_notify_user
	
	updatefinish:
		POPL %esi
		POPL %edi
		POPL %edx
		POPL %ecx
		POPL %ebx
		leave
		ret

# ------------------------------------------new function-----------------------------------------------
#
mp1_missile_remove:
		pushl %ebp
		movl %esp, %ebp

		PUSHL %ebx
		PUSHL %ecx
		PUSHL %edx
		PUSHL %edi
		PUSHL %esi

		CMPL %ebx, %ecx
		JE firstmissile		# add the missile and set the status
		MOVL $0, %eax
		JMP removedone

	firstmissile:
		MOVL $1, %eax

	removedone:
		POPL %esi
		POPL %edi
		POPL %edx
		POPL %ecx
		POPL %ebx
		leave
		ret
# ------------------------------------------new function-----------------------------------------------

mp1_ioctl_startgame:
		pushl %ebp
		movl %esp, %ebp
		# SUBL $16, %esp # creat 4 local variables a,b,c,d
		# ecx contain cmd, edx contain arg and ecx is available now
		MOVL $40, crosshairs_x
		MOVL $12, crosshairs_y
		ANDL $0, mp1_score # init score to 0
		ANDL $0, mp1_missile_list
		MOVL $0x00FFFFFF, base_alive
	startdone:
		leave 
		ret


mp1_ioctl_addmissile:
		# ecx contain cmd, edx contain arg and ecx is available now
		pushl %ebp
		movl %esp, %ebp
		
		PUSHL 	%ecx
		PUSHL 	%edx
		PUSHL	%edi

	 	PUSHL $36
	 	CALL mp1_malloc
	 	ADDL $4, %esp
	 	CMPL $0, %eax		# malloc the space of 36 for a missile
	 	JNE mallocsuccess
	 	MOVL $-1, %eax
	 	JMP mallocdone

	 mallocsuccess: # now eax have the new pointer
	 	MOVL %eax, %edi
	 	PUSHL %edi
		PUSHL $36
		PUSHL 8(%ebp) # after this, edx is available ----------------------------------------------------------------------------------------------------------------------------------
		PUSHL %edi # copy user missile to ebx
		CALL mp1_copy_from_user
	 	ADDL $12, %esp
		POPL %edi
	 	CMPL $0, %eax
	 	JE copysuccess
	 	PUSHL %edi
		CALL mp1_free
	 	ADDL $4, %esp
	 	MOVL $-1, %eax
	 	JMP mallocdone

	 copysuccess:
	 	MOVL mp1_missile_list, %edx # copy is success
	 	MOVL %edx, NEXT(%edi)
	 	MOVL %edi, mp1_missile_list
	 	MOVL $0, %eax

	 mallocdone:
		POPL	%edi		# restore all regis
	 	POPL 	%edx
	 	POPL 	%ecx
	 	leave
	 	ret


mp1_ioctl_movexhairs:
		pushl %ebp
		movl %esp, %ebp

		# ecx contain cmd, edx contain arg and ecx is available now
		PUSHL 	%ecx
		PUSHL 	%edx
		PUSHL	%ebx
		PUSHL	%esi		# save regis
		PUSHL	%edi
		PUSHL 	%eax

		MOVL 8(%ebp), %edx # arg in edx--------------------------------------------------------------------------------------------
		MOVL %edx, %eax
		MOVSWL %ax, %eax 		# x change = 0xFF00
		MOVL %edx, %ebx
		SARL $16, %ebx 		   	# y change = 0xEF01
		MOVL crosshairs_x, %edi
		MOVL crosshairs_y, %esi

	deleteoldcross:
		PUSHL $0x20
		PUSHL %esi
		PUSHL %edi
		CALL draw_helper
		ADDL $12, %esp

		ADDL %edi, %eax # new x
		# ANDL $0xFFFF, %eax
		ADDL %esi, %ebx # new y
		# ANDL $0xFFFF, %ebx
		CMPL $0, %eax
		JGE xlarger0
		MOVL $0, %eax # stay still to edge
		JMP checky
	xlarger0:
		CMPL $79, %eax
		JLE checky
		MOVL $79, %eax # stay still to edge
	checky:
		CMPL $0, %ebx
		JGE ylarger0
		MOVL $0, %ebx # stay still to edge
		JMP drawcross
	ylarger0:
		CMPL $24, %ebx
		JLE drawcross
		MOVL $24, %ebx # stay still to edge

	drawcross:
		PUSHL $43
		PUSHL %ebx
		PUSHL %eax
		CALL draw_helper
		ADDL $12, %esp

	drawcrossfinish:
		MOVL %eax, crosshairs_x
		MOVL %ebx, crosshairs_y
		MOVL $0, %eax

		POPL 	%eax
		POPL	%edi
		POPL	%esi
		POPL	%ebx			# restore all regis
		POPL 	%edx
		POPL 	%ecx
		leave
		ret


mp1_ioctl_getstatus:
		# ecx contain cmd, edx contain arg and ecx is available now
		# PUSHL %ebx # bases alive? all base alive info
		# PUSHL %edi # base number
		# PUSHL %esi
		pushl %ebp
		movl %esp, %ebp
		
		PUSHL 	%ecx
		PUSHL 	%edx
		PUSHL	%ebx
		PUSHL	%esi		# save regis
		PUSHL	%edi

		MOVL $0x00000000, %ebx # init total base status
		MOVL $0x000000FF, %edi # init base number
		MOVL $0x00010000, %esi # initial and counter up for base bit

		# check bases:
	checkbasesloop:
		CMPL $0xFF000000, %edi
		JE allcheked
		PUSHL base_alive
		PUSHL %edi
		CALL check_bases
		ADDL $8, %esp
		CMPL $1, %eax
		JE basealived
		# base no alived
		SHLL $8, %edi
		SHLL $1, %esi
		JMP checkbasesloop
	basealived:
		ORL %esi, %ebx
		SHLL $8, %edi # example change 0x00FF to 0xFF00
		SHLL $1, %esi # shift to next bit of 16,17,18
		JMP checkbasesloop

	allcheked:
		# after this, edi and esi is available
		MOVL mp1_score, %esi # ready to restore mp1_score after giving user
		MOVL mp1_score, %edi
		ANDL $0x0000FFFF, %edi # wipe off high 16 bit
		ADDL %ebx, %edi
		MOVL %edi, mp1_score
		LEA mp1_score, %ebx
		PUSHL %esi # prevent it from changing
		PUSHL $4
		PUSHL %ebx
		PUSHL 8(%ebp) # edx is arg -------------------------------------------------------------------------------------------------------------
		CALL mp1_copy_to_user
		ADDL $12, %esp
		POPL %esi # restore mp1_score
		MOVL %esi, mp1_score
		CMPL $0, %eax
		JNE getstatusfail # return -1 when fail
		JMP getstatusdone
	
	getstatusfail:
		MOVL $-1, %eax

	getstatusdone:
		POPL	%edi
		POPL	%esi
		POPL	%ebx			# restore all regis
		POPL    %edx
		POPL    %ecx
		leave
		ret


mp1_ioctl_endgame:
		# ecx contain cmd, edx contain arg and ecx is available now
		pushl %ebp
		movl %esp, %ebp

		PUSHL %ecx
		PUSHL %edx
		PUSHL %esi
		PUSHL %edi

		MOVL mp1_missile_list, %edi
	continuefree: # aloop for deleting missile list
		CMPL $0, %edi
		JE enddone
		MOVL NEXT(%edi), %ecx # save next pointer
		PUSHL %ecx
		PUSHL %edi
		CALL mp1_free
		ADDL $4, %esp
		POPL %ecx
		MOVL %ecx, %edi # get the next pointer
		JMP continuefree 
	enddone:

		POPL	%edi
		POPL	%esi			# restore all regis
		POPL 	%edx
		POPL 	%ecx
		leave
		ret

# -----------------helper function for ioctl
# base no alive return 0, or return 1
check_bases:
		pushl %ebp
		movl %esp, %ebp

		PUSHL %ebx
		PUSHL %ecx

		MOVL 8(%ebp), %ebx # ebx = 0x00?????? indicate the number of base
		MOVL 12(%ebp), %ecx # the base_alive info
		ANDL %ebx, %ecx
		CMPL $0, %ecx
	
		JE noalived # noalive then return 0
		MOVL $1, %eax # alive return 1
		JMP checkdone

	noalived:
		MOVL $0, %eax # noalive then return 0
	
	checkdone:
		POPL %ecx
		POPL %ebx
		leave
		ret
		
