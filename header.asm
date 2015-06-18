*=$500;set offset to 0x500

LOW=$00FF
HIGH=$FF00

CLR_VALUE=32

ZP_DISK=$00 ;8 bit read only
ZP_CONSOLE=$01 ;8 bit read only
ZP_SHELL_LINE=$02 ;8 bit
ZP_SHELL_OFFSET=$03 ;8 bit
ZP_LASTWORD=$04

STACK_PAGE=$0100
OSCALL_PAGE=$0200
RSTACK_PAGE=$0300
EXTERNAL_PAGE=$0400
BLOCK_PAGE=$1D00
INPUT_PAGE=$1E00
SHELL_PAGE=$1F00
REDBUS_PAGE=$FF00

RSTACK_START=$03FE

MMU_REDBUS_SETID=$00
MMU_REDBUS_SETPAGE=$01
MMU_REDBUS_ENABLE=$02
MMU_REDBUS_DISABLE=$82
MMU_EMMW_SETPAGE=$03
MMU_EMMW_ENABLE=$04
MMU_BRK_VECTOR_SET=$05
MMU_POR_SETADDRESS=$06

IOX_IN=REDBUS_PAGE+$00
IOX_OUT=REDBUS_PAGE+$02

KEYBOARD_START=REDBUS_PAGE+$04
KEYBOARD_END=REDBUS_PAGE+$05
KEYBOARD_CHAR=REDBUS_PAGE+$06

SCREEN_ROW=REDBUS_PAGE+$00
CURSOR_X=REDBUS_PAGE+$01
CURSOR_Y=REDBUS_PAGE+$02
CURSOR_MODE=REDBUS_PAGE+$03
BLIT_S_X=REDBUS_PAGE+$08
BLIT_S_Y=REDBUS_PAGE+$09
BLIT_O_X=REDBUS_PAGE+$0A
BLIT_O_Y=REDBUS_PAGE+$0B
BLIT_WIDTH=REDBUS_PAGE+$0C
BLIT_HEIGHT=REDBUS_PAGE+$0D
BLIT_MODE=REDBUS_PAGE+$07
BLIT_MODE_FILL=1
BLIT_MODE_INVERT=2
BLIT_MODE_SHIFT=3
SCREEN_MEMORY=REDBUS_PAGE+$10
SCREEN_WIDTH=$50
SCREEN_HEIGHT=$32

CALL_CHARPUT=$00
CALL_CHARGET=$01
CALL_CLEARSCREEN=$02
