!src "header.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.init ;Init sequence; it is not a FORTH word
sei ;Disable interrupts while initializing
clc
xce
rep #$30
!al
!rl

;Enter short accumulator and long index register mode
rep #$10
sep #$20
!as
!rl

;Find end of memory and set the backstack pointer
	;Start searching from the end of this code
	;If memory ends before this code does then there are bigger problems
	ldx #.codeEnd
-
	;Branch to end if we reached address zero (it still works with 0)
	beq + ;Zero flag set by inx and ldx before this instruction
	lda 0,X ;Load byte to memory
	inc ;Increment the value in A to get a unique value
	sta 0,X ;Store it back
	cmp 0,X ;See if the value changed when we stored it
	bne + ;If they are not equal then this is not valid memory (which is the end)
	dec ;Decrement the value in A to restore it
	sta 0,X ;Restore old value
	inx ;Increment X to go to the next spot
	bra -	
+

	;Now X is equal to the first non-existent memory address
	ldy #.systemBackStackEnd ;Load Y with the address after the system backstack
	;Copy all of the bytes starting from the end of the backstack
-
	;Move index registers back a byte
	dey
	dex
	;Move the byte
	lda 0,Y
	sta 0,X
	;Did we copy the last byte?
	cpy #.systemBackStack
	bne - ;If not, then go back

	;Now that we are done, X is equal to the beginning of the backstack
	stx ZP_BACKSTACK ;Store it to the ZP

rep #$30
!al
!rl

ldx #FORTH_LAST_KERNEL_WORD ;Get address of the last forth word
stx ZP_LASTWORD ;Store it to the ZP

;Link every system buffer into the new backstack
	;Compute the difference from the beginning of each stack
		lda ZP_BACKSTACK
		sec
		sbc #.systemBackStack
		tay ;Transfer the difference to Y
	;Add the amount to each name pointer
-
		tya ;Transfer the difference back to A
		clc
		adc FORTH_WORDOFFSET_NAME,X ;Add the difference to the offset
		sta FORTH_WORDOFFSET_NAME,X ;Store the new address back
		;Since we cannot use X addressing modes when loading X, use A
		lda FORTH_WORDOFFSET_LINK,X
		tax
		cpx #0
		bne - ;So long as we arent at the last link continue
	;Link in the input buffer
		lda #.inputbuffer_off ;Load A with offset of input buffer
		clc
		adc ZP_BACKSTACK ;Add backstack pointer to offset
		sta ZP_FORTH_TIB ;Store to ZP
	;Link in the parse buffer
		lda #.parsebuffer_off ;Load A with offset of parse buffer
		clc
		adc ZP_BACKSTACK ;Add backstack pointer to offset
		sta ZP_FORTH_PARSEBUFFER ;Store to ZP

;Initialize POR
lda #.cold_def
mmu #MMU_POR_SETADDRESS
cli ;Allow interrupts because now POR works fine

;bra .cold ;Branch to the definition of cold (to skip header)
bra .test
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.cold ;COLD word - runs on power-on-reset
!16 0 ;Since this is the first word, it has the null-terminator in the linked list
!16 .cold_name
!16 (.cold_end - .cold_def)
.cold_def
rep #$30 ;If there is a power-on-reset then we need to ensure the mode
!al
!rl

;DEBUG: Initialize the redbus to use IOX on addr 3
lda #3
sta ZP_REDBUS_ID ;Store ID in use to ZP
mmu #MMU_REDBUS_SETID
lda #REDBUS_PAGE
mmu #MMU_REDBUS_SETPAGE
mmu #MMU_REDBUS_ENABLE

;Set IOX output to 9
lda #9
sta IOX_OUT

;Disable compile mode
lda #0
sta ZP_MODE_COMPILE

stp
.cold_end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.begin ;begin a loop (:) - pushes address of the end of the dictionary onto rstack
!16 .cold
!16 .begin_name
!16 (.begin_end - .begin_def) | FORTH_WORDFLAG_IMMEDIATE
.begin_def
ldx ZP_FORTH_HERE ;Get HERE
rhx ;Push HERE to rstack
nxt
.begin_end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.again ;end a loop (:) - compiles address from rstack into word definition
!16 .begin
!16 .again_name
!16 (.again_end - .again_def) | FORTH_WORDFLAG_IMMEDIATE
.again_def
ldx ZP_FORTH_HERE ;Get HERE
ldy #.again_does ;Load loop does
sty 0,X ;Add loop does to thread (POSTPONE)
inx
inx
rly ;Pull address from rstack
sty 0,X ;Place address HERE
inx
inx
stx ZP_FORTH_HERE ;Store new HERE back
nxt
.again_end
.again_does
tix ;Transfer pointer to loop thread beginning into X
ldy 0,X ;Load Y with thread beginning pointer
tyx ;Transfer thread beginning to X
txi ;Transfer thread beginning to I
nxt

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.bsalloc ;backstack allocate (num : addr) - allocates num bytes onto backstack and
;returns address to memory
!16 .again
!16 .bsalloc_name
!16 (.bsalloc_end - .bsalloc_def)
.bsalloc_def
pha ;Push A back to stack (it contained the amount of bytes)
lda ZP_BACKSTACK ;Load backstack pointer into A from ZP
sec
sbc 0,S ;Subtract amount of bytes from backstack pointer
sta ZP_BACKSTACK ;Store new backstack pointer to ZP
plx ;Remove amount of bytes from stack
;A (top of stack) now contains the address of the beginning of this memory
nxt
.bsalloc_end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.bsfree ;backstack free (num :) - frees num bytes from backstack
!16 .bsalloc
!16 .bsfree_name
!16 (.bsfree_end - .bsfree_def)
.bsfree_def
clc
adc ZP_BACKSTACK ;Add backstack pointer to amount of bytes
sta ZP_BACKSTACK ;Store new backstack pointer
nxt
.bsfree_end

.test
stp;###################################################

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.parse ;parse string (delim "ccc<delim>" -- addr bytes) - parse characters from input
;until the delimiter is reached
!16 .bsfree
!16 .parse_name
!16 (.parse_end - .parse_def)
.parse_def

;Enter 8-bit accumulator mode
	sep #$20
	!as

;Copy string to buffer and stop at delim or max size; count kept in Y
	ldy #0
-
	cmp (ZP_FORTH_PARSELOC),Y ;Compare delim in A to character in buffer
	beq + ;Branch to end if we reached the delimiter
	cpy #FORTH_PARSE_SIZE ;Compare Y to the size of the parse area
	beq + ;Branch to end if we reached buffer size limit as a precaution
	tad ;Move A to D temporarily
	lda (ZP_FORTH_PARSELOC),Y ;Load character from buffer
	sta (ZP_FORTH_PARSEBUFFER),Y ;Store character into parse buffer
	tda ;Move D back to A
	iny ;Move to next character
	bra - ;Do it again
+

;Exit 8-bit accumulator mode
	rep #$20
	!al

lda ZP_FORTH_PARSELOC ;Place parse location address into A
pha ;Push it onto stack
tya ;Y contains the amount of bytes so it should be moved to A
iny ;Move Y forward one byte to skip delim
sty ZP_FORTH_PARSELOC ;Store this location to the parse location

nxt
.parse_end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.next ;next word () - moves to next FORTH word in a thread and leaves calling word
!16 .parse
!16 .next_name
!16 (.next_end - .next_def)
.next_def
rli ;Get I from rstack (before enter was called)
nxt ;Go to next word on the outside
.next_end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.doconst ;push contant (: const) - loads an immediate constant onto stack
!16 .next
!16 .doconst_name
!16 (.doconst_end - .doconst_def)
.doconst_def
pha ;Push old A to stack
nxa ;Get constant
nxt
.doconst_end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.fetch ;load variable (addr : data) - loads data at address addr and puts it on stack
!16 .doconst
!16 .fetch_name
!16 (.fetch_end - .fetch_def)
.fetch_def
tax
lda 0,X
nxt
.fetch_end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.store ;store variable (data addr :) - stores data to address addr
!16 .fetch
!16 .store_name
!16 (.store_end - .store_def)
.store_def
tax
pla
sta 0,X
pla ;Get next thing off stack
nxt
.store_end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.count ;count characters (addr1 : addr2 num) - retrieves string address (addr2) and
;number of characters (num) from counted string addr1
!16 .store
!16 .count_name
!16 (.count_end - .count_def)
.count_def
tax ;Move address into X

;Switch into 8-bit accum mode
	sep #$20
	!as

lda 0,X ;Get num into A

;Switch back to 16-bit accum mode
	rep #$20
	!al

inx ;Move X forward to point to string
phx ;Address is now on stack

nxt
.count_end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.strcmp ;compare strings (addr1 n1 addr2 n2 : same?) - compares strings from addr1
;and addr2 using n1 and n2 as their respective lengths
!16 .count
!16 .strcmp_name
!16 (.strcmp_end - .strcmp_def)
.strcmp_def
;A already contains n2, the only amount we will use
plx ;Pull addr2 into X
;We must find the smaller of the two strings
cmp 0,S ;Compare A (n2) to n1 on stack
beq + ;Move to + if they are the same length
;Here the strings are not the same
pld ;Discard n1 from stack
pld ;Discard addr1 from stack
lda #0 ;Put false into A because they are not the same
nxt ;Go to the next word
+
pld ;Discard n1 from stack (it is the same as n2)
ply ;Pull addr1 into Y

;Begin string comparison
	;Switch to 8-bit accumulator (for characters)
		sep #$20
		!as
	;It is important to consider that A has changed to 8 bits
-
	cmp #0
	beq + ;If A is 0, there are no characters left to compare
	tad ;Back up count into D
	lda 0,X ;Load A with character from addr2
	cmp 0,Y ;Compare A with character from addr1
	beq ++ ;Branch to ++ to continue if the character is the same
	;Switch to 16-bit before moving to next word
		rep #$20
		!al
	lda #0 ;Character is not the same so return false
	nxt ;Go to next word
	++
	!as ;At this location we are still in short mode, so inform the assembler
	;Update all counters and addresses
	inx
	iny
	dec A
	bra - ;Do it again!
+

;Switch to 16-bit before returning
	rep #$20
	!al

lda #-1 ;Put all 1 into A to indicate success

nxt
.strcmp_end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.find ;find word (delim : nameaddr 0 | token 1 | token -1)
!16 .strcmp
!16 .find_name
!16 (.find_end - .find_def)
.find_def
pha
lda #' ' ;Load space character as the delimiter
ent
!16 .parse
!16 + ;Place address after this as next word
+
rli ;Pull I from enter
nxt
.find_end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.create ;create a new word definition
!16 .find
!16 .create_name
!16 (.create_end - .create_def)
.create_def

nxt
.create_end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.tmpend ;marks end of system dictionary - only for testing purposes!
!16 .create
!16 .tmpend_name
!16 (.tmpend_end - .tmpend_def)
.tmpend_def
;You can call this, but you will be disappointed because it does nothing
nxt
.tmpend_end

.systemBackStack
.tmpend_name !raw 6, "TMPEND"
.create_name !raw 6, "CREATE"
.find_name !raw 4, "FIND"
.strcmp_name !raw 6, "STRCMP"
.count_name !raw 5, "COUNT"
.store_name !raw 1, "!"
.fetch_name !raw 1, "@"
.doconst_name !raw 7, "DOCONST"
.next_name !raw 4, "NEXT"
.inputbuffer_off !fill FORTH_INPUTBUFFER_SIZE
.parsebuffer_off !fill FORTH_PARSE_SIZE
.parse_name !raw 5, "PARSE"
.bsfree_name !raw 6, "BSFREE"
.bsalloc_name !raw 7, "BSALLOC"
.again_name !raw 5, "AGAIN"
.begin_name !raw 5, "BEGIN"
.cold_name !raw 4, "COLD"
.systemBackStackEnd

!src "footer.asm"