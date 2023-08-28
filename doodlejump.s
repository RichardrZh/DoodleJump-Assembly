#####################################################################
#
# Author: Richard Zhuang
#
# Setup: 
# - Using MARS MIPS, open and setup the bitmap display (tools -> bitmap display) using the configuration below,
#   also open the keyboard simulator (tools -> keyboard and display mmio simulator). Then ensure that both tools 
#   are conected to the assembly by clicking the "connect to mips" button. Then assemble the file and run the program.
#
# Bitmap Display Configuration:
# - Unit width in pixels: 8					     
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
# Controls: 
# - When entering the player name in the welcome screen, chars allowed are [0-9,A-Z,a-z,space]
# - During main gameplay use "j", "k" chars to move left/right respectively
#
# Bug: 
# - if multiple keypreses are pressed on a single gameloop, the game freezes, a non-issue on fast speeds.
#   take care and moderate keypress speed on slow speeds/computers 
#
# Additional Information:
# - when entering the player name in the welcome screen, chars allowed are [0-9,A-Z,a-z,space]
#   chars will be entered on key press (same mechanic as j/k left/right player movement) 
#   no take backies, ie any typo/mistake in the name cannot be backspaced.
#   as well, you might have to wait between button presses as if you type too quickly, it will not register.
# - game gets dynamically harder based on your score. when the score reaches 50, 80, difficulty will increase by factor of 1
#   when difficulty increases, platform size decreases.
# - game ends at score WIN_THRESHOLD (100 by default)
# - as this ran relativly slow on my laptop, I added constants you can change in the code for testing convenience. it probably won't break the program.
#   everything under the "# game constants" comment (ie. WIN_THRESHOLD) should be able to be changed reasonably.
#   DIFFICULTY_THRESHOLD_HARD overrides DIFFICULTY_THRESHOLD_MEDIUM which overrides DIFFICULTY_THRESHOLD_EASY. 
#   this means that if DIFFICULTY_THRESHOLD_HARD = 10, DIFFICULTY_THRESHOLD_MEDIUM = 20,
#   then score 15 would be of hard difficulty
#   DIFFICULTY_THRESHOLD_EASY is actually there for clarity and is not used in the code.
# - some comments have variable name inconsitancies, ie comment says # $s1++, when it should be # $t0++. 
#   this is as they were written early on, and upon code refactoring, I didnt want to go through each comment to correct it.
#   the general gist is there though. (ie. the logic behind it should be clear)
# - when i tested, spamming keys ie. jjjj would freeze the program. I don't know if this is just because my laptop is slow, but take care when entering keys.
#####################################################################

### METADATA START ###

# ascii codes
.eqv ASCII_SPACE 32

.eqv ASCII_0 48
.eqv ASCII_1 49
.eqv ASCII_2 50
.eqv ASCII_3 51
.eqv ASCII_4 52
.eqv ASCII_5 53
.eqv ASCII_6 54
.eqv ASCII_7 55
.eqv ASCII_8 56
.eqv ASCII_9 57

.eqv ASCII_A 65
.eqv ASCII_B 66
.eqv ASCII_C 67
.eqv ASCII_D 68
.eqv ASCII_E 69
.eqv ASCII_F 70
.eqv ASCII_G 71
.eqv ASCII_H 72
.eqv ASCII_I 73
.eqv ASCII_J 74
.eqv ASCII_K 75
.eqv ASCII_L 76
.eqv ASCII_M 77
.eqv ASCII_N 78
.eqv ASCII_O 79
.eqv ASCII_P 80
.eqv ASCII_Q 81
.eqv ASCII_R 82
.eqv ASCII_S 83
.eqv ASCII_T 84
.eqv ASCII_U 85
.eqv ASCII_V 86
.eqv ASCII_W 87
.eqv ASCII_X 88
.eqv ASCII_Y 89
.eqv ASCII_Z 90

.eqv ASCII_a 97
.eqv ASCII_b 98
.eqv ASCII_c 99
.eqv ASCII_d 100
.eqv ASCII_e 101
.eqv ASCII_f 102
.eqv ASCII_g 103
.eqv ASCII_h 104
.eqv ASCII_i 105
.eqv ASCII_j 106
.eqv ASCII_k 107
.eqv ASCII_l 108
.eqv ASCII_m 109
.eqv ASCII_n 110
.eqv ASCII_o 111
.eqv ASCII_p 112
.eqv ASCII_q 113
.eqv ASCII_r 114
.eqv ASCII_s 115
.eqv ASCII_t 116
.eqv ASCII_u 117
.eqv ASCII_v 118
.eqv ASCII_w 119
.eqv ASCII_x 120
.eqv ASCII_y 121
.eqv ASCII_z 122

# useful constants
.eqv WORD_BYTE_SIZE 4
.eqv GRID_LENGTH 32

# game contants 
.eqv SLEEP_TIME 333			# denotes sleep time in mlliseconds, between each gameloop. 
.eqv DIFFICULTY_THRESHOLD_EASY 0	# score in range [0,50) is easy and platforms are of length 7,8,9,10
.eqv DIFFICULTY_THRESHOLD_MEDIUM 50	# score in range [50,80) is medium and platforms are of length 4,5,6
.eqv DIFFICULTY_THRESHOLD_HARD 80	# score in range [80,100+] is hard and platforms are of length 1,2,3. Although technically score can be higher than 100, if score hits 100, you win the game.
.eqv WIN_THRESHOLD 100			# if score >= win threshold, you win. should be: 0 <= WIN_THRESHOLD <= 100

# address'
.eqv DISPLAY_ADDRESS 0x10008000
.eqv BUTTON_PRESSED_ADDRESS 0xffff0000
.eqv BUTTON_ASCII_ADDRESS 0xffff0004

# colours
.eqv BG_COLOUR 0xd6deff 	# pastel blue
.eqv PLAYER_COLOUR 0x00ff00 	# green
.eqv TEXT_COLOUR 0x000000	# black
.eqv PLATFORM_COLOUR 0x964B00	# brown

.data
	playerName: .word 0, 0, 0, 0, 0, 0				# 6 char name in ascii code
	playerCoord: .word 590, 590, 0 					# current position of player, previous location of player, 3rd val: move up = 0, move down = 1
	platformArray: .word 8, 7, 258, 10, 533, 6, 772, 7, 684, 7, 182, 7 	# 6 platforms pos and length, in consecutive pairs, first 4 are fixed, last 2 are random, platfor size 1->10
										# platform size groups: (1,2,3) (4,5,6) (7,8,9,10)
.text								
.globl main

### METADATA END ###




### GAME START ###

# Layout of file:
#
# main (entry point of the assembly)
#
# InitGame (draws the initial menu screen and awaits player input)
# GameLoop (main gameloop for the game)
#
# DrawUnitRC (draws a pixel in the specified row/col of the display array)
# DrawUnitI (draws a pixel in the specified index of the display array)
# RCtoIndex (helper funtion for converting row/col to index of the display screen)
# IndextoRC (helper function for converting index to row/col of the display screen)
#
# ClearScreen (clears the display screen)
# IntersectPlatform (determines if the player intersects the platform)
# MovePlatform (move a platform from the bottom to the top of the display 
#               to preserve memory addresses (due to limited registers). 
#               also generates a new width and position)
# DrawPlatforms	(draws multiple platforms)
# DrawPlatform (draws a single platfrom)
# DrawPlayer (draws the player)
#
# ButtonPressed (awaits keypress input from the user)
# MovePlayerVertical (moves the player on the vertical axis and draws)
#
# WelcomeScreen (draws the main welcome menu screen form game start)
# GameOverScreen (draws the end screen from game end)
# DrawScore (draws the score during main gameloop)
# DrawASCII (draws an ascii character in the specified location, chars allowed are [0-9,A-Z,a-z,space])
#
# Exit (exit point for the assembly)


main:
	la $s0, playerCoord	# $s0 stores initial position of player, previous location of player, 3rd val: move up = 0, move down = 1
	la $s1, platformArray	# $s1 stores the 6 platforms pos and length, in consecutive pairs, first 4 are fixed, last 2 are random
	li $s2, 0		# $s2 stores the blocks traversed, score = blocks traversed / 12
	li $s3, 0		# $s3 stores the player jump counter 0 -> 11, can jump 12 blocks: 0 <= count < 12
	la $s4, playerName	# $s4 stores player name in ascii code
	li $s5, GRID_LENGTH	# $s5 stores the number of rows/cols, ie. this is a (row * col) sized grid (will be a square)
	#li $s6,
	#$s7 is reserved for a func as a hack fix to a bug, might revisit and fix this later
	
	jal WelcomeScreen
	
	jal InitGame
	
	j GameLoop

InitGame: # clear screen, draw platforms, player, score, name 
	addi $sp, $sp, -4		# decrement stack pointer to prepare for push
	sw $ra, 0($sp)			# push $ra on stack
	
	jal ClearScreen
	
	li $a0, 0
	jal DrawPlatforms
	
	li $a0, 0
	jal DrawPlayer
	
	li $a0, 33
	li $a1, TEXT_COLOUR
	li $a2, 2
	jal DrawScore
	
	lw $a2, 0($s4) 	# load 1st letter of player name
	li $a0, 836
	jal DrawASCII
	lw $a2, 4($s4) 	# load 2nd letter of player name
	li $a0, 840
	jal DrawASCII
	lw $a2, 8($s4) 	# load 3rd letter of player name
	li $a0, 844
	jal DrawASCII
	lw $a2, 12($s4) # load 4th letter of player name
	li $a0, 848
	jal DrawASCII
	lw $a2, 16($s4) # load 5th letter of player name
	li $a0, 852
	jal DrawASCII
	lw $a2, 20($s4) # load 6th letter of player name
	li $a0, 856
	jal DrawASCII
	
	lw $ra, 0($sp)			# pop $ra from stack
	addi $sp, $sp, 4		# reset stack pointer through increment
	jr $ra

GameLoop: # the main loop of the game
	# save player curr to prev
	lw $t0, 0($s0) 		# load curr player pos into $t0
	sw $t0, 4($s0)		# save curr player pos into prev player pos

	# check for button press if true then set player loc array moved (left/right)
	li $v0, 0				# set button pressed to be false (by default)
	li $t0, BUTTON_PRESSED_ADDRESS 		# load button pressed address that stores if a button was pressed
	lw $t1, 0($t0)				# load info at address into $t1, if 1 then button was pressed.
	beqz $t1, ButtonNotPressed		# branch to skip button press handler
	# else: button pressed
	jal ButtonPressed
	
	ButtonNotPressed:
	
	# move player up/down, may update score
	jal MovePlayerVertical		# move player up/down
	
	addi $sp, $sp, -4		# decrement stack pointer to prepare for push
	sw $v0, 0($sp)			# push $v0 on stack
	
	# delete player
	li $a0, 1
	jal DrawPlayer
	
	# draw player		# we draw player here to give the illusion of a fast paint, however it actually makes the program run slower 
	li $a0, 0
	jal DrawPlayer
	
	lw $v0, 0($sp)			# pop $vo from stack
	addi $sp, $sp, 4		# reset stack pointer through increment (for both v0, score)
	
	# delete/draw platforms
	move $a0, $v0
	jal DrawPlatforms
	
	# draw player
	li $a0, 0
	jal DrawPlayer
	
	# draw score/name
	li $a0, 33
	li $a1, TEXT_COLOUR
	li $a2, 2
	jal DrawScore
	
	lw $a2, 0($s4) 	# load 1st letter of player name
	li $a0, 836
	jal DrawASCII
	lw $a2, 4($s4) 	# load 2nd letter of player name
	li $a0, 840
	jal DrawASCII
	lw $a2, 8($s4) 	# load 3rd letter of player name
	li $a0, 844
	jal DrawASCII
	lw $a2, 12($s4) # load 4th letter of player name
	li $a0, 848
	jal DrawASCII
	lw $a2, 16($s4) # load 5th letter of player name
	li $a0, 852
	jal DrawASCII
	lw $a2, 20($s4) # load 6th letter of player name
	li $a0, 856
	jal DrawASCII

	# sleep and loop
	li $v0, 32
	li $a0, SLEEP_TIME 	# (1 sec = 1000 milliseconds) (33 millisec sleep approx 30 sleeps per sec)
	syscall
	j GameLoop

DrawUnitRC: # take vars from registers $a0,$a1,$a2 as row,col,colour and paint that unit, 0 <= row/col < $s5 (DOES NOT MODIFY $a0,$a1,$a2)
	# lmao i dont think i acc use this, nice for testing tho
	addi $sp, $sp, -4		# decrement stack pointer to prepare for push
	sw $ra, 0($sp)			# push $ra on stack
	jal RCtoIndex			# get index in $v0 
	lw $ra, 0($sp)			# pop $ra from stack
	addi $sp, $sp, 4		# reset stack pointer through increment
	
	li $t0, DISPLAY_ADDRESS		# get clone of display address $s0
	li $t1, WORD_BYTE_SIZE		# temp $t1 = 4
	mult $v0, $t1			# index * 4, here we mult by 4 for word alignment, 4 bytes to a word
	mflo $t2			# $t2 = index * 4 = offset
	add $t0, $t0, $t2		# at end should be $t0 = $t0 + offset = $s0 + offset
	sw $a2, 0($t0) 			# paint unit at $t0 = $s0 + offset to colour $a2
	jr $ra 				# return 
	
DrawUnitI: # take vars from registers $a0,$a1 as index,colour and paint that unit, 0 <= index < $s5 * $s5 (DOES NOT MODIFY $a0,$a1)
	li $t0, DISPLAY_ADDRESS		# get clone of display address $s0
	li $t1, WORD_BYTE_SIZE			
	mult $a0, $t1			# index * 4, here we mult by 4 for word alignment, 4 bytes to a word
	mflo $t2			# $t2 = index * 4 = offset
	add $t0, $t0, $t2		# at end should be $t0 = $t0 + offset = $s0 + offset
	sw $a1, 0($t0) 			# paint unit at $t0 = $s0 + offset to colour $a2
	jr $ra 				# return 
	
RCtoIndex: # take row,col from $a0, $a1 and return index (in row-major) saved in $v0, (DOES NOT MODIFY ANYTHING BUT lo,hi,$v0)
	#dont think i use this either xd
	mult $a0, $s5 		# row * ($s5=numcols)
	mflo $v0		# $v0 = row x ($s5=numcols)
	add $v0, $v0, $a1	# $v0 = row x ($s5=numcols) + col = index (in row major)
	jr $ra			# return
	
IndextoRC: # take index (in row-major) from $a0 and return row,col saved in $v0,$v1, 0 <= row/col < $s5 (DOES NOT MOFDIFY ANYTHING BUT lo,hi,$v0,$v1)
	div $a0, $s5 		# hi = floor($a0/$s5), lo = index % ($s5=numcols)
	mflo $v0		# $v0 = floor($a0/$s5) = row
	mfhi $v1		# $v1 = index % ($s5=numcols) = col
	jr $ra 			# return
	
ClearScreen: # paint all units to background colour 
	ClearScreenInit:
		li $t0, 0			# $t0 = i
		mult $s5, $s5			# 0 <= index < $s5 * $s5
		mflo $t1			# $t1 = $s5 x $s5 = max num of indices
		li $a1, BG_COLOUR 		# save background colour into $a1
		addi $sp, $sp, -4		# decrement stack pointer to prepare for push
		sw $ra, 0($sp)			# push $ra on stack
	ClearScreenLoop:
		bge $t0, $t1, ClearScreenEnd	# escape condition, end if i >= max num of indices
			
		addi $sp, $sp, -4		# decrement stack pointer to prepare for push
		sw $t0, 0($sp)			# push $t0 on stack
		addi $sp, $sp, -4		# decrement stack pointer to prepare for push
		sw $t1, 0($sp)			# push $t1 on stack
		
		move $a0, $t0			# set index to func args for DrawUnitI, $a1 colour set at ClearScreenInit
		jal DrawUnitI			# draw unit at row col
		
		lw $t1, 0($sp)			# pop $t1 from stack
		addi $sp, $sp, 4		# reset stack pointer through increment
		lw $t0, 0($sp)			# pop $t0 from stack
		addi $sp, $sp, 4		# reset stack pointer through increment
		
		addi $t0, $t0, 1		# i++
		j ClearScreenLoop		# loop
	ClearScreenEnd:
		lw $ra, 0($sp)			# pop $ra from stack
		addi $sp, $sp, 4		# reset stack pointer through increment
		jr $ra
		
IntersectPlatform: # takes $a0 as index, returns $v0 as 1 if intersect occurs with any platform, else 0
	
	addi $sp, $sp, -4		# decrement stack pointer to prepare for push
	sw $ra, 0($sp)			# push $ra on stack
	
	jal IndextoRC
	move $t3, $v1		# $t3 is col of index
	move $t7, $v0		# $t7 is row
	
	move $t0, $s1 		# copy platform array address
	li $t1, 0		# i = 0
	li $t2, 6		# n = 6		
	IntersectPlatformLoop: # loop [0-6)
		bge $t1, $t2, IntersectPlatformFail
		
		lw $a0, 0($t0) 		# $a0 is index of platform
		lw $t5, 4($t0)		# $t5 is length
		
		jal IndextoRC
		bne $v0, $t7, IntersectPlatformLoopEnd 		# index is not on same row as platform
		# else: on same row
		move $t4, $v1		# $t4 is col of platform init index
		
		add $t6, $t4, $t5	# $t6 = platform col + len
		
		bgt $t6, 31, IntersectPlatformEdgeCase		# platform crosses edge
		# else normal:
		blt $t3, $t4, IntersectPlatformLoopEnd 		# branch if $t3 is left of platform init
		bge $t3, $t6, IntersectPlatformLoopEnd		# branch if $t3 is right of platform end
		# else: is on platform
		j IntersectPlatformSuccess
		
		IntersectPlatformEdgeCase:
			bge $t3, $t4, IntersectPlatformSuccess 		# branch if is to inclusive right of platform init, as platform reaches right edge, index is on platform
			div $t6, $s5
			mfhi $t6					# $t6 is col of closest upper bound of end (locally)
			blt $t3, $t6, IntersectPlatformSuccess	 	# branch if $t3 is in range [0,t6), which is on platform
			# else: not in range (as platform length <= 10), goto loopEnd
		IntersectPlatformLoopEnd: # no intersects with curr platform, loop again on next platform
			addi $t0, $t0, 8
			addi $t1, $t1, 1
			j IntersectPlatformLoop
	IntersectPlatformSuccess:
		li $v0, 1
		j IntersectPlatformEnd
	IntersectPlatformFail:
		li $v0, 0
	IntersectPlatformEnd:
		lw $ra, 0($sp)			# pop $ra from stack
		addi $sp, $sp, 4		# reset stack pointer through increment
		jr $ra

MovePlatform: # moves platform down and respawns it if necessary, $a0 is 0-5, denoting which platform
	addi $sp, $sp, -4		# decrement stack pointer to prepare for push
	sw $ra, 0($sp)			# push $ra on stack
	
	move $t0, $s1 				# copy platform array
	
	li $t1, 8
	mult $a0, $t1		# $a0 * 2 * 4
	mflo $t1 
	add $t0, $t0, $t1	# increment address to correct loc
	
	lw $a0, 0($t0)		# load index
	jal IndextoRC
	
	bge $v0, 31, MovePlatformRespawn 	# if row >= 31 ie at bottom
	# else:
	lw $t2, 0($t0)
	addi $t2, $t2, GRID_LENGTH
	sw $t2, 0($t0)
	j MovePlatformEnd
	
	MovePlatformRespawn:
		addi $sp, $sp, -4		# decrement stack pointer to prepare for push
		sw $t0, 0($sp)			# push $t0 on stack
	
		li $t3, 12
		div $s2, $t3
		mflo $t3	# $t3 = score
		
		bge $t3, DIFFICULTY_THRESHOLD_HARD, IfScoreHard
		bge $t3, DIFFICULTY_THRESHOLD_MEDIUM, IfScoreMed
		# else score is easy, ie lowest difficulty
		IfScoreEasy:
			li $a0, 0		# pick psudorand gen 0
			li $v0, 42  		# 42 = syscall rand int in range 0 <= res < $a1
			li $a1, 4 		# upper bound
			syscall	 		# rand int res at $a0 in range [0,4)
			
			addi $a0, $a0, 7
			lw $t0, 0($sp)			# peek $t0 
			sw $a0, 4($t0)			# save $a0 as length, in range [7,10]
			j SetPlatformLengthDone
		IfScoreHard:
			li $a0, 0		# pick psudorand gen 0
			li $v0, 42  		# 42 = syscall rand int in range 0 <= res < $a1
			li $a1, 3 		# upper bound
			syscall	 		# rand int res at $a0 in range [0,3)
			
			addi $a0, $a0, 1
			lw $t0, 0($sp)			# peek $t0 
			sw $a0, 4($t0)			# save $a0 as length, in range [1,3]
			j SetPlatformLengthDone
		IfScoreMed:
			li $a0, 0		# pick psudorand gen 0
			li $v0, 42  		# 42 = syscall rand int in range 0 <= res < $a1
			li $a1, 3 		# upper bound
			syscall	 		# rand int res at $a0 in range [0,3)
			
			addi $a0, $a0, 4
			lw $t0, 0($sp)			# peek $t0 
			sw $a0, 4($t0)			# save $a0 as length, in range [4,6]
			j SetPlatformLengthDone
			
		SetPlatformLengthDone: 	# now we set the index
		li $a0, 0		# pick psudorand gen 0
		li $v0, 42  		# 42 = syscall rand int in range 0 <= res < $a1
		li $a1, GRID_LENGTH	# upper bound
		syscall	 		# rand int res at $a0
		
		move $a1, $a0 		# col in range [0,32)
		li $a0, 0
		jal RCtoIndex
		
		lw $t0, 0($sp)			# pop $t0 from stack
		addi $sp, $sp, 4		# reset stack pointer through increment
		sw $v0, 0($t0)
	MovePlatformEnd:
		lw $ra, 0($sp)			# pop $ra from stack
		addi $sp, $sp, 4		# reset stack pointer through increment
		jr $ra

DrawPlatforms: # moves, creates platforms, $a0 is 1 if need to move platforms else 0
	addi $sp, $sp, -4		# decrement stack pointer to prepare for push
	sw $ra, 0($sp)			# push $ra on stack
	
	beqz $a0, DrawPlatformsDefault
	MovePlatforms: # platforms move so we delete at old pos and redraw at new pos
		addi $s2, $s2, 1 	# increment block traversal counter
		li $a0, 0
		li $a1, 1
		jal DrawPlatform
		li $a0, 1
		li $a1, 1
		jal DrawPlatform
		li $a0, 2
		li $a1, 1
		jal DrawPlatform
		li $a0, 3
		li $a1, 1
		jal DrawPlatform
		li $a0, 4
		li $a1, 1
		jal DrawPlatform
		li $a0, 5
		li $a1, 1
		jal DrawPlatform
		  
		# move platform pos

		li $a0, 0
		jal MovePlatform
		li $a0, 1
		jal MovePlatform
		li $a0, 2
		jal MovePlatform
		li $a0, 3
		jal MovePlatform
		li $a0, 4
		jal MovePlatform
		li $a0, 5
		jal MovePlatform
		
	DrawPlatformsDefault: # redraw platforms 
		li $a0, 0
		li $a1, 0
		jal DrawPlatform
		li $a0, 1
		li $a1, 0
		jal DrawPlatform
		li $a0, 2
		li $a1, 0
		jal DrawPlatform
		li $a0, 3
		li $a1, 0
		jal DrawPlatform
		li $a0, 4
		li $a1, 0
		jal DrawPlatform
		li $a0, 5
		li $a1, 0
		jal DrawPlatform
		
	DrawPlatformsEnd:
		lw $ra, 0($sp)			# pop $ra from stack
		addi $sp, $sp, 4		# reset stack pointer through increment
		jr $ra
									
DrawPlatform: # $a0 is int 0-5 to specify platform, $a1 is 1 if delete, 0 if draw
	# diagram: O is pos, O,x are units to be painted
	#			+0, +1, +2, +3, +4
	#	O x x x x	or +1 +1 +1 +1 +1
	#			length is 5 so paint 5 units
	addi $sp, $sp, -4		# decrement stack pointer to prepare for push
	sw $ra, 0($sp)			# push $ra on stack
	
	move $t0, $s1 	# $t0 is platformArray address
	
	li $t1, 8
	mult $a0, $t1 	# $a0 * 2 * $
	mflo $t1	# $t1 = $a0 * 2 * 4
	
	add $t0, $t0, $t1 	# add offset to address
	
	beqz $a1, DrawPlatformPaint
	
	DrawPlatformDelete:
		li $a2, BG_COLOUR
		j DrawPlatformEnd
	DrawPlatformPaint:
		li $a2, PLATFORM_COLOUR
	DrawPlatformEnd:
		DrawPlatformLoopInit:	
			lw $a0, 0($t0)		# loads platfor pos (as index)
			jal IndextoRC
			move $a0, $v0		# row
			move $a1, $v1		# col 
			
			move $t3, $a1		# i = col
			lw $t4, 4($t0)		# loads platform length 
			
			add $t4, $t4, $t3	# n = col + length
			
			addi $sp, $sp, -4		# decrement stack pointer to prepare for push
			sw $a0, 0($sp)			# push $a1 on stack, row
			addi $sp, $sp, -4		# decrement stack pointer to prepare for push
			sw $t4, 0($sp)			# push $t4 on stack, n
			addi $sp, $sp, -4		# decrement stack pointer to prepare for push
			sw $t3, 0($sp)			# push $t3 on stack, i
		DrawPlatformLoop: # loop [i,n)
			lw $t4, 4($sp)			# peek $t4 from stack
			lw $t3, 0($sp)			# peek $t3
			bge $t3, $t4, DrawPlatformLoopEnd
			
			lw $t3, 0($sp)			# peek $t5
			li $t5, GRID_LENGTH
			div $t3, $t5
			mfhi $a1
			lw $a0, 8($sp)			# peek $a0, row
			jal DrawUnitRC
			
			lw $t3, 0($sp)			# peek $t5
			addi $t3, $t3, 1
			sw $t3, 0($sp)			# save i++
			j DrawPlatformLoop
		DrawPlatformLoopEnd:
			addi $sp, $sp, 12		# reset stack pointer through increment
	lw $ra, 0($sp)			# pop $ra from stack
	addi $sp, $sp, 4		# reset stack pointer through increment
	jr $ra 

DrawPlayer: # $a0 is 1 if delete, 0 if draw
	# diagram: O is pos, x are units to be painted
	#	O x		+1, +32, +33, +34, +64, +66
	#	x x x		or +1 +31 +1 +1 +30 +2
	#	x   x
	lw $t0, 0($s0)		# current pos
	lw $t1, 4($s0) 		# prev pos
	
	addi $sp, $sp, -4		# decrement stack pointer to prepare for push
	sw $ra, 0($sp)			# push $ra on stack
	
	beqz $a0, DrawPlayerPaint
	
	DrawPlayerDelete:
		li $a2, BG_COLOUR
		move $a0, $t1
		jal IndextoRC
		j DrawPlayerEnd
	DrawPlayerPaint:
		li $a2, PLAYER_COLOUR
		move $a0, $t0
		jal IndextoRC
	DrawPlayerEnd: 
		# $v0,v1 = row,col
	
		addi $sp, $sp, -4		# decrement stack pointer to prepare for push
		sw $v0, 0($sp)			# push row on stack
		addi $sp, $sp, -4		# decrement stack pointer to prepare for push
		sw $v1, 0($sp)			# push col on stack
		
		move $a0, $v0		# row
		addi $a1, $v1, 1 	# col++
		li $t2, 32
		div $a1, $t2
		mfhi $a1
		jal DrawUnitRC
		
		lw $a0, 4($sp)		# row
		lw $a1, 0($sp)		# col
		addi $a0, $a0, 1
		li $t2, 32
		div $a1, $t2
		mfhi $a1
		jal DrawUnitRC
		
		lw $a0, 4($sp)		# row
		lw $a1, 0($sp)		# col
		addi $a0, $a0, 1
		addi $a1, $a1, 1
		li $t2, 32
		div $a1, $t2
		mfhi $a1
		jal DrawUnitRC
		
		lw $a0, 4($sp)		# row
		lw $a1, 0($sp)		# col
		addi $a0, $a0, 1
		addi $a1, $a1, 2
		li $t2, 32
		div $a1, $t2
		mfhi $a1
		jal DrawUnitRC
		
		lw $a0, 4($sp)		# row
		lw $a1, 0($sp)		# col
		addi $a0, $a0, 2
		li $t2, 32
		div $a1, $t2
		mfhi $a1
		jal DrawUnitRC
		
		lw $a0, 4($sp)		# row
		lw $a1, 0($sp)		# col
		addi $a0, $a0, 2
		addi $a1, $a1, 2
		li $t2, 32
		div $a1, $t2
		mfhi $a1
		jal DrawUnitRC
		
		addi $sp,$sp, 8			# reset stack pointer through increment
		lw $ra, 0($sp)			# pop $ra from stack
		addi $sp, $sp, 4		# reset stack pointer through increment
		jr $ra
	
ButtonPressed: # processes button press. 
	# either "j" pressed -> player move left or "k" pressed -> player move right
	li $t0, BUTTON_ASCII_ADDRESS		# load button ascii address 
	lw $t1, 0($t0)				# load value at address into $t1
	
	addi $sp, $sp, -4		# decrement stack pointer to prepare for push
	sw $ra, 0($sp)			# push $ra on stack
	
	beq $t1, ASCII_J, JPressed		# if j pressed branch to JPressed
	beq $t1, ASCII_j, JPressed
	beq $t1, ASCII_K, KPressed		# if k pressed branch to KPressed
	beq $t1, ASCII_k, KPressed
	
	InvalidPress:			# Invalid button press, label for semantics
		j ButtonPressedEnd
	JPressed: # player move left
		lw $a0, 0($s0) 		# current pos of player
		jal IndextoRC
		beq $v1, 0, JPressedEdge
		addi $a0, $a0, -1	# index - 1 = move left
		j JPressedEnd
		JPressedEdge:
			addi $a0, $a0, 31
		JPressedEnd:
			sw $a0, 0($s0)		# save new pos into current pos
			j ButtonPressedEnd	# branch end
	KPressed: # player move right
		lw $a0, 0($s0) 		# current pos of player
		jal IndextoRC
		beq $v1, 31, KPressedEdge
		addi $a0, $a0, 1	# index + 1 = move right
		j KPressedEnd
		KPressedEdge:
			addi $a0, $a0, -31
		KPressedEnd:
			sw $a0, 0($s0)		# save new pos into current pos
	ButtonPressedEnd: # jump back
		lw $ra, 0($sp)			# pop $ra from stack
		addi $sp, $sp, 4		# reset stack pointer through increment
		jr $ra
		
MovePlayerVertical: # moves the player pos vertically up/down, returns $v0, 1 if need to move platforms, else 0 
	addi $sp, $sp, -4		# decrement stack pointer to prepare for push
	sw $ra, 0($sp)			# push $ra on stack
	
	lw $t0, 0($s0) # current player pos
	lw $t1, 8($s0) # move direction, 0 if up, 1 if down
	
	beqz $t1, MPVUp
	MPVDown:
		# if hit low bound then game over
		move $a0, $t0
		jal IndextoRC
		bne $v0, 29, MPVNotGameOver	# row is 29, bottom of player at 31
		# else, game over
		li $a0, 0
		j GameOverScreen 
		
		MPVNotGameOver:
		# move down
		addi $t0, $t0, GRID_LENGTH
		
		# if platform below, set player direction/jump
		addi $sp, $sp, -4		# decrement stack pointer to prepare for push
		sw $t0, 0($sp)			# push $t0 on stack 
		
		lw $t0, 0($sp)			# peek $t0 from stack
		addi $a0, $t0, 96 		# 96 = GRID_LENGTH * 3
		jal IntersectPlatform 
		lw $t0, 0($sp)			# peek $t0 from stack
		addi $sp, $sp, 4		# reset stack pointer through increment
		beq $v0, 1, MPVDownIntersect
		
		addi $sp, $sp, -4		# decrement stack pointer 
		lw $t0, 0($sp)			# peek $t0 from stack
		addi $a0, $t0, 97 	
		jal IntersectPlatform 
		lw $t0, 0($sp)			# peek $t0 from stack
		addi $sp, $sp, 4		# reset stack pointer through increment
		beq $v0, 1, MPVDownIntersect
		
		addi $sp, $sp, -4		# decrement stack pointer 
		lw $t0, 0($sp)			# peek $t0 from stack
		addi $a0, $t0, 98	
		jal IntersectPlatform 
		lw $t0, 0($sp)			# peek $t0 from stack
		addi $sp, $sp, 4		# reset stack pointer through increment
		beq $v0, 1, MPVDownIntersect
		
		
		j MPVDownDefault
		MPVDownIntersect:
			li $t1, 0
			sw $zero, 8($s0)	# save up movement direction
			li $s3, 0		# reset jump counter
		MPVDownDefault:
			li $v0 0	# set return val
			j MPVEnd
	MPVUp: 
		# check direction correct
		bge $s3, 16, MPVUpChangeDirec
		j MPVUpChangeDirecEnd
		
		MPVUpChangeDirec:
			li $t1, 1
			sw $t1, 8($s0)	# save down movement direction
			li $s3, 0	# reset jump counter
			j MPVDown
		MPVUpChangeDirecEnd:
		# if $s3 == 16, change direction down and reset jump counter
		# if hit up bound then move platforms ie set return value to 1
		addi $s3, $s3, 1		# increment player jump counter
		
		move $a0, $t0
		jal IndextoRC
		slti $v0, $v0, 7		# row is 7
		beq $v0, 1, MPVEnd
		
		addi $t0, $t0, -GRID_LENGTH 	# move up
	MPVEnd:
		sw $t0, 0($s0)
		
	lw $ra, 0($sp)			# pop $ra from stack
	addi $sp, $sp, 4		# reset stack pointer through increment
	jr $ra
	
WelcomeScreen: 
	addi $sp, $sp, -4		# decrement stack pointer to prepare for push
	sw $ra, 0($sp)			# push $ra on stack
	
	jal ClearScreen
	
	li $a1, TEXT_COLOUR
	
	# draw welcome message
	li $a0, 68
	li $a2, ASCII_D
	jal DrawASCII
	li $a0, 72
	li $a2, ASCII_O
	jal DrawASCII
	li $a0, 76
	li $a2, ASCII_O
	jal DrawASCII
	li $a0, 80
	li $a2, ASCII_D
	jal DrawASCII
	li $a0, 84
	li $a2, ASCII_L
	jal DrawASCII
	li $a0, 88
	li $a2, ASCII_E
	jal DrawASCII
	
	li $a0, 264
	li $a2, ASCII_J
	jal DrawASCII
	li $a0, 268
	li $a2, ASCII_U
	jal DrawASCII
	li $a0, 272
	li $a2, ASCII_M
	jal DrawASCII
	li $a0, 276
	li $a2, ASCII_P
	jal DrawASCII
	
	li $a0, 520
	li $a2, ASCII_E
	jal DrawASCII
	li $a0, 524
	li $a2, ASCII_N
	jal DrawASCII
	li $a0, 528
	li $a2, ASCII_T
	jal DrawASCII
	li $a0, 532
	li $a2, ASCII_E
	jal DrawASCII
	li $a0, 536
	li $a2, ASCII_R
	jal DrawASCII
	
	li $a0, 712
	li $a2, ASCII_N
	jal DrawASCII
	li $a0, 716
	li $a2, ASCII_A
	jal DrawASCII
	li $a0, 720
	li $a2, ASCII_M
	jal DrawASCII
	li $a0, 724
	li $a2, ASCII_E
	jal DrawASCII
	# draw colon :
	li $a0, 761
	jal DrawUnitI
	li $a0, 825
	jal DrawUnitI

	
	# take player name 6 chars from [A-Z, a-z, 0-9, space], no typos allowed (as idk if Enter maps to Carriage Return)
	li $t0, BUTTON_PRESSED_ADDRESS 		# load button pressed address that stores if a button was pressed
	li $t2, BUTTON_ASCII_ADDRESS		# load button ascii address 
	move $t4, $s4
	li $t5, 0				# count
	WelcomeWait:
		lw $t1, 0($t0)				# load info at address into $t1, if 1 then button was pressed.
		andi $t1, $t1, 0x00000001		# Isolate ready bit
		beqz $t1, WelcomeWait 			# wait
		j WelcomeInput
	WelcomeInput:
		lw $t3, 0($t2)				# load value at address into $t3
		sw $t3, 0($t4) 				# save into name array
		addi $t5, $t5, 1			# count++
		addi $t4, $t4, 4			# increment address
		blt $t5, 6, WelcomeWait
	WelcomeEnd:
		lw $ra, 0($sp)			# pop $ra from stack
		addi $sp, $sp, 4		# reset stack pointer through increment
		jr $ra
	
GameOverScreen: # display name, score, $a0 is 1 if win, 0 if lose
	addi $sp, $sp, -4		# decrement stack pointer to prepare for push
	sw $a0, 0($sp)			# push $a0 on stack
	
	jal ClearScreen
	
	li $a1, TEXT_COLOUR
	
	# paint you (win/lose)
	li $a0, 66
	li $a2, ASCII_Y
	jal DrawASCII
	li $a0, 70
	li $a2, ASCII_O
	jal DrawASCII
	li $a0, 74
	li $a2, ASCII_U
	jal DrawASCII
	
	lw $a0, 0($sp)			# pop $a0 from stack
	addi $sp, $sp, 4		# reset stack pointer through increment
	# You Win/Lose
	beqz $a0, GameOverLose
	
	GameOverWin:
		li $a0, 79
		li $a2, ASCII_W
		jal DrawASCII
		li $a0, 83
		li $a2, ASCII_I
		jal DrawASCII
		li $a0, 87
		li $a2, ASCII_N
		jal DrawASCII
		
		j GameOverEnd
	GameOverLose:
		li $a0, 79
		li $a2, ASCII_L
		jal DrawASCII
		li $a0, 83
		li $a2, ASCII_O
		jal DrawASCII
		li $a0, 87
		li $a2, ASCII_S
		jal DrawASCII
		li $a0, 91
		li $a2, ASCII_E
		jal DrawASCII
	GameOverEnd:
		lw $a2, 0($s4) 	# load 1st letter of player name
		li $a0, 292
		jal DrawASCII
		lw $a2, 4($s4) 	# load 2nd letter of player name
		li $a0, 296
		jal DrawASCII
		lw $a2, 8($s4) 	# load 3rd letter of player name
		li $a0, 300
		jal DrawASCII
		lw $a2, 12($s4) # load 4th letter of player name
		li $a0, 304
		jal DrawASCII
		lw $a2, 16($s4) # load 5th letter of player name
		li $a0, 308
		jal DrawASCII
		lw $a2, 20($s4) # load 6th letter of player name
		li $a0, 312
		jal DrawASCII
		
		li $a0, 580
		li $a2, ASCII_S
		jal DrawASCII
		li $a0, 584
		li $a2, ASCII_C
		jal DrawASCII
		li $a0, 588
		li $a2, ASCII_O
		jal DrawASCII
		li $a0, 592
		li $a2, ASCII_R
		jal DrawASCII
		li $a0, 596
		li $a2, ASCII_E
		jal DrawASCII
		# draw colon :
		li $a0, 633
		jal DrawUnitI
		li $a0, 697
		jal DrawUnitI
		
		# paint score
		li $a0, 816
		li $a2, 3
		jal DrawScore
		
		j Exit

DrawScore: # $a0 is starting index, $a1 is paint colour, $a2 is num digits (2-3)
	move $s7, $a0 #hack
	
	li $t0, 12
	div $s2, $t0
	mflo $t0	# $t0 = score

	addi $sp, $sp, -4		# decrement stack pointer to prepare for push
	sw $ra, 0($sp)			# push $ra on stack

	beq $a2, 2, DrawScore2
	beq $a2, 3, DrawScore3
	
	DrawScore2:
		addi $sp, $sp, -4		# decrement stack pointer to prepare for push
		sw $t0, 0($sp)			# push $ra on stack
		# if score >= 100 by default, win
		bge $t0, WIN_THRESHOLD, WinByScorePoint 	# branch if win
		# else: not win
		j NotWinByScorePoint
		
		WinByScorePoint:
			li $a0, 1
			j GameOverScreen
		NotWinByScorePoint:
		# delete
		move $t7, $a1	# old colour in $t7
		li $a1, BG_COLOUR
		li $a2, -1
		
		addi $a0, $s7, 0
		jal DrawASCII
		addi $a0, $s7, 4
		jal DrawASCII
		
		# draw
		move $a1, $t7
		lw $t0, 0($sp)			# pop $ra from stack
		addi $sp, $sp, 4		# reset stack pointer through increment
		
		li $t1, 10
		div $t0, $t1
		mflo $t0		# $t0 is stripped of one's digit
		mfhi $t1		# $t1 is one's digit
		addi $a2, $t1, 48 	# $a2 = $t1 + 48 = ascii code
		addi $a0, $s7, 4 	# set index
		addi $sp, $sp, -4		# decrement stack pointer to prepare for push
		sw $t0, 0($sp)			# push $t0 on stack
		jal DrawASCII
		
		lw $t0, 0($sp)			# pop $t0 from stack
		addi $sp, $sp, 4		# reset stack pointer through increment
		li $t1, 10
		div $t0, $t1
		mfhi $t1		# $t1 is ten's digit
		addi $a2, $t1, 48 	# $a2 = $t1 + 48 = ascii code
		addi $a0, $s7, 0 	# set index
		jal DrawASCII
		
		j DrawScoreEnd
	DrawScore3:
		li $t1, 10
		div $t0, $t1
		mflo $t0		# $t0 is stripped of one's digit
		mfhi $t1		# $t1 is one's digit
		addi $a2, $t1, 48 	# $a2 = $t1 + 48 = ascii code
		addi $a0, $s7, 8 	# set index
		addi $sp, $sp, -4		# prep stack ptr
		sw $t0, 0($sp)			# push $t0 on stack
		jal DrawASCII
		
		lw $t0, 0($sp)			# pop $t0 from stack
		addi $sp, $sp, 4		# reset stack pointer through increment
		li $t1, 10
		div $t0, $t1
		mflo $t0		# $t0 is stripped of ten's digit (and one's)
		mfhi $t1		# $t1 is ten's digit
		addi $a2, $t1, 48 	# $a2 = $t1 + 48 = ascii code
		addi $a0, $s7, 4 	# set index
		addi $sp, $sp, -4		# prep stack ptr
		sw $t0, 0($sp)			# push $t0 on stack
		jal DrawASCII
		
		lw $t0, 0($sp)			# pop $t0 from stack
		addi $sp, $sp, 4		# reset stack pointer through increment
		li $t1, 10
		div $t0, $t1
		mfhi $t1		# $t1 is hundred's digit
		addi $a2, $t1, 48 	# $a2 = $t1 + 48 = ascii code
		addi $a0, $s7, 0	# set index
		jal DrawASCII
	DrawScoreEnd:
		lw $ra, 0($sp)			# pop $ra from stack
		addi $sp, $sp, 4		# reset stack pointer through increment
		jr $ra

DrawASCII: # $a0 is staring index, $a1 is colour, $a2 is ascii code, can only accept language [A-Z, a-z, 0-9], is case insensitive, (DOES NOT MODIFY ANYTHING BUT $a0)
	
	addi $sp, $sp, -4		# decrement stack pointer to prepare for push
	sw $ra, 0($sp)			# push $ra on stack
	
	beq $a2, -1, DrawClear 		# special draw as ascii cannot be negative
	
	beq $a2, ASCII_SPACE, DrawSpace
	
	beq $a2, ASCII_0, Draw0
	beq $a2, ASCII_1, Draw1
	beq $a2, ASCII_2, Draw2
	beq $a2, ASCII_3, Draw3
	beq $a2, ASCII_4, Draw4
	beq $a2, ASCII_5, Draw5
	beq $a2, ASCII_6, Draw6
	beq $a2, ASCII_7, Draw7
	beq $a2, ASCII_8, Draw8
	beq $a2, ASCII_9, Draw9
	
	beq $a2, ASCII_A, DrawA
	beq $a2, ASCII_a, DrawA
	
	beq $a2, ASCII_B, DrawB
	beq $a2, ASCII_b, DrawB

	beq $a2, ASCII_C, DrawC
	beq $a2, ASCII_c, DrawC
	
	beq $a2, ASCII_D, DrawD
	beq $a2, ASCII_d, DrawD
	
	beq $a2, ASCII_E, DrawE
	beq $a2, ASCII_e, DrawE
	
	beq $a2, ASCII_F, DrawF
	beq $a2, ASCII_f, DrawF
	
	beq $a2, ASCII_G, DrawG
	beq $a2, ASCII_g, DrawG
	
	beq $a2, ASCII_H, DrawH
	beq $a2, ASCII_h, DrawH
	
	beq $a2, ASCII_I, DrawI
	beq $a2, ASCII_i, DrawI
	
	beq $a2, ASCII_J, DrawJ
	beq $a2, ASCII_j, DrawJ
	
	beq $a2, ASCII_K, DrawK
	beq $a2, ASCII_k, DrawK
	
	beq $a2, ASCII_L, DrawL
	beq $a2, ASCII_l, DrawL
	
	beq $a2, ASCII_M, DrawM
	beq $a2, ASCII_m, DrawM
	
	beq $a2, ASCII_N, DrawN
	beq $a2, ASCII_n, DrawN
	
	beq $a2, ASCII_O, DrawO
	beq $a2, ASCII_o, DrawO

	beq $a2, ASCII_P, DrawP
	beq $a2, ASCII_p, DrawP
	
	beq $a2, ASCII_Q, DrawQ
	beq $a2, ASCII_q, DrawQ
	
	beq $a2, ASCII_R, DrawR
	beq $a2, ASCII_r, DrawR
	
	beq $a2, ASCII_S, DrawS
	beq $a2, ASCII_s, DrawS
	
	beq $a2, ASCII_T, DrawT
	beq $a2, ASCII_t, DrawT
	
	beq $a2, ASCII_U, DrawU
	beq $a2, ASCII_u, DrawU
	
	beq $a2, ASCII_V, DrawV
	beq $a2, ASCII_v, DrawV
	
	beq $a2, ASCII_W, DrawW
	beq $a2, ASCII_w, DrawW
	
	beq $a2, ASCII_X, DrawX
	beq $a2, ASCII_x, DrawX
	
	beq $a2, ASCII_Y, DrawY
	beq $a2, ASCII_y, DrawY
	
	beq $a2, ASCII_Z, DrawZ
	beq $a2, ASCII_z, DrawZ
	
	j DrawASCIIEnd
		
	DrawClear:
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawSpace:
		j DrawASCIIEnd
	Draw0:
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		j DrawASCIIEnd
	Draw1:
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		j DrawASCIIEnd
	Draw2:
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 33
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		j DrawASCIIEnd
	Draw3:
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 33
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		
		addi $a0, $a0, 33
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		j DrawASCIIEnd
	Draw4:
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		j DrawASCIIEnd
	Draw5:
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 33
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		j DrawASCIIEnd
	Draw6:
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		
		j DrawASCIIEnd
	Draw7:
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		j DrawASCIIEnd
	Draw8:
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
				
		j DrawASCIIEnd
	Draw9:
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawA:
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawB:
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawC:
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawD:
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawE:
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawF:
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawG:
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawH:
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawI:
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawJ:
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawK:
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawL:
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawM:
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawN:
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawO:		
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawP:
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawQ:
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawR:
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawS:
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		
		addi $a0, $a0, 33
		jal DrawUnitI
		
		addi $a0, $a0, 33
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawT:
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawU:
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawV:
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawW:
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawX:
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawY:
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 2
		jal DrawUnitI
		
		addi $a0, $a0, 30
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		j DrawASCIIEnd
	DrawZ:
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		
		addi $a0, $a0, 31
		jal DrawUnitI
		
		addi $a0, $a0, 32
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		addi $a0, $a0, 1
		jal DrawUnitI
		
	DrawASCIIEnd:
		lw $ra, 0($sp)			# pop $ra from stack
		addi $sp, $sp, 4		# reset stack pointer through increment
		jr $ra

Exit:
	li $v0, 10 # terminate the program gracefully
	syscall
        
### GANE END ###