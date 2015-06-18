!src "header.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.init ;Init sequence; it is not a FORTH word
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
	cpx #0
	beq +
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

;Link every word into the new backstack
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

;Initialize POR
lda #.cold_def
mmu #MMU_POR_SETADDRESS

bra .cold_def ;Branch to the definition of cold (to skip header)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.cold ;COLD word - runs on power-on-reset
!16 0 ;Since this is the first word, it has the null-terminator in the linked list
!16 .cold_name
!16 (.cold_end-.cold_def)
.cold_def
rep #$30 ;If there is a power-on-reset then we need to ensure the mode
!al
!rl

;DEBUG: Initialize the redbus to use IOX on addr 3
lda #3
mmu #MMU_REDBUS_SETID
lda #REDBUS_PAGE
mmu #MMU_REDBUS_SETPAGE
mmu #MMU_REDBUS_ENABLE

lda #9
sta IOX_OUT

stp
.cold_end

.systemBackStack
.cold_name !raw "COLD", 0
.systemBackStackEnd

!src "footer.asm"