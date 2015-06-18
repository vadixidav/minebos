!src "header.asm"

.coldboot
clc
xce
rep #$30
!al
!rl

; Initialize the redbus
lda #*
mmu #MMU_POR_SETADDRESS
lda #3
mmu #MMU_REDBUS_SETID
lda #REDBUS_PAGE
mmu #MMU_REDBUS_SETPAGE
mmu #MMU_REDBUS_ENABLE


lda #$AAAA
sta IOX_OUT

.main
jmp .main
stp

!src "footer.asm"