\ DELTEST - tests for Delta 14B ghost buttons

\ ******************************************************************************
\
\ Configuration variables
\
\ ******************************************************************************

 CODE% = &4000          \ The address where the code will be run

 LOAD% = &FF4000        \ The address where the code will be loaded

 VIA = &FE00            \ Memory-mapped space for accessing internal hardware,
                        \ such as the video ULA, 6845 CRTC and 6522 VIAs (also
                        \ known as SHEILA)

 OSNEWL = &FFE7         \ The address for the OSNEWL routine

 OSWRCH = &FFEE         \ The address for the OSWRCH routine

 OSBYTE = &FFF4         \ The address for the OSBYTE routine

\ ******************************************************************************
\
\       Name: ZP
\       Type: Workspace
\    Address: &0070 to &008F
\   Category: Workspaces
\    Summary: Important variables
\
\ ******************************************************************************

 ORG &0070

.SC

 SKIP 2                 \ Screen address

.MOS

 SKIP 1                 \ Records the machine type:
                        \
                        \   * 0 = BBC Micro/Electron
                        \
                        \   * &FF = BBC Master/Compact

.FONT

 SKIP 2                 \ Address of the character font in the MOS

.aStore

 SKIP 1                 \ Temporary storage for the A register

.yStore

 SKIP 1                 \ Temporary storage for the Y register

.xIndent

 SKIP 1                 \ The x-coordinate indent to use when printing button
                        \ letters

.XC

 SKIP 1                 \ The text column for printing a character directly into
                        \ screen memory

.YC

 SKIP 1                 \ The text row for printing a character directly into
                        \ screen memory

.COL

 SKIP 1                 \ The colour to be printed directly to the screen:
                        \
                        \   * 0 = normal
                        \
                        \   * &FF = inverted

.P

 SKIP 3                 \ Temporary variable

\ ******************************************************************************
\
\ DELTEST FILE
\
\ ******************************************************************************

 ORG CODE%              \ Set the assembly address to CODE%

\ ******************************************************************************
\
\       Name: ENTRY
\       Type: Subroutine
\   Category: Screen
\    Summary: The entry point for the tool
\
\ ******************************************************************************

.ENTRY

 LDA #%11110000         \ Set the Data Direction Register (DDR) of port B of the
 STA VIA+&62            \ user port so we can read the buttons on the Delta 14B
                        \ joystick, using PB4 to PB7 as output (so we can write
                        \ to the button columns to select the column we are
                        \ interested in) and PB0 to PB3 as input (so we can read
                        \ from the button rows)

 LDA #0                 \ Call OSBYTE with A = 0 and X = 1 to detect the OS
 LDX #1                 \ type, which returns the following in X:
 JSR OSBYTE             \
                        \   * 0 = Electron
                        \
                        \   * 1 = BBC Micro
                        \
                        \   * 2 = BBC Micro B+
                        \
                        \   * 3 = BBC Master
                        \
                        \   * 4 = BBC Master ET
                        \
                        \   * 5 = BBC Master Compact

 CPX #3                 \ If X >= 3 then this is a Master, so jump to mast1
 BCS mast1

 LDA #&BF               \ Set FONT to the correct values for the BBC Micro and
 STA FONT               \ Acorn Electron, for use in PrintCharacter
 LDA #&C1
 STA FONT+1

 LDA #0                 \ Set MOS = 0 to indicate that this is a BBC Micro or
 STA MOS                \ Acorn Electron

 BEQ mast2              \ Jump to mast2 to skip the following (this BEQ is
                        \ effectively a JMP as A is always zero)

.mast1

 LDA #&88               \ Set FONT to the correct values for the BBC Master, for
 STA FONT               \ use in PrintCharacter
 LDA #&8A
 STA FONT+1

 LDA VIA+&30            \ Set bit 7 of the ROM Select latch at SHEILA &30 to
 ORA #%10000000         \ switch the MOS ROM into &8000-&BFFF, updating the RAM
 STA &F4                \ copy in &F4 at the same time
 STA VIA+&30            \
                        \ This ensures that the MOS ROM font is paged into
                        \ memory so PrintCharacter can access it

 LDA #&FF               \ Set MOS = &FF to indicate that this is a BBC Micro or
 STA MOS                \ Acorn Electron

.mast2

 JSR DrawScreen         \ Set up the screen display

 JSR SetTextWindow      \ Set the text window for the logger

.loop1

 LDY #12                \ So set a decreasing counter in Y to work through the
                        \ 12 Delta 14B buttons in the buttons table

.loop2

 LDA #0                 \ Clear bit 7 of A so ReadDelta14B scans the rear socket

 JSR ReadDelta14B       \ Read the Delta 14B joystick buttons and update the
                        \ screen

 LDA #%10000000         \ Set bit 7 of A so ReadDelta14B scans the side socket

 JSR ReadDelta14B       \ Read the Delta 14B joystick buttons and update the
                        \ screen

 DEY                    \ Decrement the loop counter

 BNE loop2              \ If not zero, loop back to process the next key

 JSR ReadADC            \ Read the analogue port and update the screen

 LDA #129               \ Call OSBYTE with A = 129 and (Y X) = 0 to read the
 LDX #0                 \ keyboard
 LDY #0
 JSR OSBYTE

 BCS loop1              \ If no key is being pressed, keep looping

 JSR ResetTextWindow    \ Restore the default text window

 RTS                    \ Quit program

\ ******************************************************************************
\
\       Name: DrawScreen
\       Type: Subroutine
\   Category: Screen
\    Summary: Set up the screen display
\
\ ******************************************************************************

.DrawScreen

 LDX #0                 \ Set a counter to work through the VDU commands in the
                        \ vduCommands table

.lvdu1

 LDA vduCommands,X      \ Set A to the X-th command from the vduCommands table

 CMP #255               \ If A = 255 then we have reached the end of the table,
 BEQ lvdu2              \ so jump to lvdu2 to exit the loop

 JSR OSWRCH             \ Print the VDU command in A

 INX                    \ Increment the loop counter in X

 BNE lvdu1              \ Loop back until we have printed all the VDU commands

.lvdu2

 LDY #1                 \ Set a counter to work through the buttons on the Delta
                        \ 14B, starting from A = 1

.lvdu3

 LDX #0                 \ Print the letter for the rear stick
 LDA #0
 JSR PrintButtonLetter

 LDX #1                 \ Print the letter for the side stick
 LDA #0
 JSR PrintButtonLetter

 INY                    \ Increment the button counter

 CPY #13                \ Loop back until we have printed buttons 1 to 12
 BCC lvdu3

 LDY #3                 \ Set a counter to work through the four arrows

.lvdu4

 LDX #0                 \ Print the arrow for the rear stick
 LDA #0
 JSR PrintArrow

 LDX #1                 \ Print the arrow for the side stick
 LDA #0
 JSR PrintArrow

 DEY                    \ Decrement the arrow counter

 BPL lvdu4              \ Loop back until we have printed all four

 LDX #0                 \ Print the unpressed fire button for the rear stick
 LDY #0
 JSR PrintFireButton

 LDX #1                 \ Print the unpressed fire button for the side stick
 LDY #0
 JSR PrintFireButton

 LDA #5                 \ Print a left arrow at (5, 2)
 STA XC
 LDA #2
 STA YC
 LDY #0
 JSR PrintShape

 INC YC                 \ Print an up arrow at (5, 3)
 LDY #3
 JSR PrintShape

 INC XC                 \ Print a down arrow at (7, 3)
 INC XC
 LDY #2
 JSR PrintShape

 DEC YC                 \ Print a right arrow at (7, 2)
 LDY #1
 JSR PrintShape

 LDA #26                \ Print a left arrow at (26, 2)
 STA XC
 LDY #0
 JSR PrintShape

 INC YC                 \ Print an up arrow at (26, 3)
 LDY #3
 JSR PrintShape

 INC XC                 \ Print a down arrow at (26, 3)
 INC XC
 LDY #2
 JSR PrintShape

 DEC YC                 \ Print a right arrow at (26, 2)
 LDY #1
 JSR PrintShape

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: vduCommands
\       Type: Variable
\   Category: Screen
\    Summary: VDU codes for setting up the mode 6 screen
\
\ ******************************************************************************

.vduCommands

 EQUB 22, 6             \ Switch to screen mode 6

 EQUB 23, 0, 10, 32     \ Disable cursor
 EQUB 0, 0, 0
 EQUB 0, 0, 0

 EQUB 4                 \ Write text at the text cursor

 EQUB 31, 4, 0          \ Move the text cursor to (4, 0)

 EQUS "Rear socket"     \ Print text

 EQUB 31, 25, 0         \ Move the text cursor to (25, 0)

 EQUS "Side socket"     \ Print text

 EQUB 31, 0, 14         \ Move the text cursor to (0, 14)

 EQUS "----------"
 EQUS "----------"
 EQUS "----------"
 EQUS "----------"

 EQUB 31, 9, 2          \ Move the text cursor to (9, 2)

 EQUS "&xxxx"           \ Print &xxxx

 EQUB 31, 9, 3         \ Move the text cursor to (9, 3)

 EQUS "&xxxx"           \ Print &xxxx

 EQUB 31, 30, 2         \ Move the text cursor to (30, 2)

 EQUS "&xxxx"           \ Print &xxxx

 EQUB 31, 30, 3         \ Move the text cursor to (30, 3)

 EQUS "&xxxx"           \ Print &xxxx

 EQUB 255               \ End token

\ ******************************************************************************
\
\       Name: shapesAddr
\       Type: Variable
\   Category: Screen
\    Summary: Lookup table for the custom chararacter definitions
\
\ ******************************************************************************

.shapesAddr

 EQUW shapes
 EQUW shapes+8
 EQUW shapes+16
 EQUW shapes+24
 EQUW shapes+32
 EQUW shapes+40

\ ******************************************************************************
\
\       Name: shapes
\       Type: Variable
\   Category: Screen
\    Summary: Custom chararacter definitions
\
\ ******************************************************************************

.shapes

 EQUB %00000000         \ 0 = left arrow
 EQUB %00001000
 EQUB %00010000
 EQUB %00111110
 EQUB %00010000
 EQUB %00001000
 EQUB %00000000
 EQUB %00000000

 EQUB %00000000         \ 1 = right arrow
 EQUB %00001000
 EQUB %00000100
 EQUB %00111110
 EQUB %00000100
 EQUB %00001000
 EQUB %00000000
 EQUB %00000000

 EQUB %00000000         \ 2 = down arrow
 EQUB %00001000
 EQUB %00001000
 EQUB %00101010
 EQUB %00011100
 EQUB %00001000
 EQUB %00000000
 EQUB %00000000

 EQUB %00000000         \ 3 = up arrow
 EQUB %00001000
 EQUB %00011100
 EQUB %00101010
 EQUB %00001000
 EQUB %00001000
 EQUB %00000000
 EQUB %00000000

 EQUB %00000000         \ 4 = fire button (not pressed)
 EQUB %00011100
 EQUB %00100010
 EQUB %00100010
 EQUB %00100010
 EQUB %00011100
 EQUB %00000000
 EQUB %00000000

 EQUB %00000000         \ 5 = fire button (pressed)
 EQUB %00011100
 EQUB %00111110
 EQUB %00111110
 EQUB %00111110
 EQUB %00011100
 EQUB %00000000
 EQUB %00000000

\ ******************************************************************************
\
\       Name: buttonX
\       Type: Variable
\   Category: Screen
\    Summary: Text column numbers for button letters for the rear stick
\
\ ******************************************************************************

.buttonX

 EQUB 5                 \ A
 EQUB 9                 \ B
 EQUB 13                \ C
 EQUB 5                 \ D
 EQUB 9                 \ E
 EQUB 13                \ F
 EQUB 5                 \ G
 EQUB 9                 \ H
 EQUB 13                \ I
 EQUB 5                 \ J
 EQUB 9                 \ K
 EQUB 13                \ L

\ ******************************************************************************
\
\       Name: buttonY
\       Type: Variable
\   Category: Screen
\    Summary: Text row numbers for button letters for the rear stick
\
\ ******************************************************************************

.buttonY

 EQUB 9                 \ A
 EQUB 9                 \ B
 EQUB 9                 \ C
 EQUB 10                \ D
 EQUB 10                \ E
 EQUB 10                \ F
 EQUB 11                \ G
 EQUB 11                \ H
 EQUB 11                \ I
 EQUB 12                \ J
 EQUB 12                \ K
 EQUB 12                \ L

\ ******************************************************************************
\
\       Name: arrowX
\       Type: Variable
\   Category: Screen
\    Summary: Text column numbers for arrows for the rear stick
\
\ ******************************************************************************

.arrowX

 EQUB 8                 \ Left
 EQUB 10                \ Right
 EQUB 9                 \ Down
 EQUB 9                 \ Up

\ ******************************************************************************
\
\       Name: arrowY
\       Type: Variable
\   Category: Screen
\    Summary: Text row numbers for arrows for the rear stick
\
\ ******************************************************************************

.arrowY

 EQUB 6                 \ Left
 EQUB 6                 \ Right
 EQUB 7                 \ Down
 EQUB 5                 \ Up

\ ******************************************************************************
\
\       Name: arrowX
\       Type: Variable
\   Category: Screen
\    Summary: Text column number for the fire button for the rear stick
\
\ ******************************************************************************

.fireX

 EQUB 9                 \ Fire

\ ******************************************************************************
\
\       Name: arrowY
\       Type: Variable
\   Category: Screen
\    Summary: Text row number for arrows for the rear stick
\
\ ******************************************************************************

.fireY

 EQUB 6                 \ Fire

\ ******************************************************************************
\
\       Name: PrintArrow
\       Type: Subroutine
\   Category: Screen
\    Summary: Print a direction arrow for the specified stick
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The colour:
\
\                         * 0 = normal
\
\                         * 1 = inverse
\
\   X                   The stick:
\
\                         * 0 = rear stick
\
\                         * 1 = side stick
\
\   Y                   The arrow to print:
\
\                         * 0 = left
\
\                         * 1 = right
\
\                         * 2 = down
\
\                         * 3 = up
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   Y                   Y is preserved
\
\ ******************************************************************************

.PrintArrow

 STY yStore             \ Store the arrow number in yStore

 JSR SetColour          \ Set the correct colour according to the value in A

 JSR SetIndent          \ Store the correct indent for this stick in xIndent

 LDA arrowX,Y           \ Set YC to the correct column for this arrow from the
 CLC                    \ arrowX table, adding the correct indent
 ADC xIndent
 STA XC

 LDA arrowY,Y           \ Set YC to the correct row for this arrow from the
 STA YC                 \ arrowY table

 LDY yStore             \ Print the arrow as a shape
 JSR PrintShape

 LDY yStore             \ Retrieve Y

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: PrintFireButton
\       Type: Subroutine
\   Category: Screen
\    Summary: Print a fire button for the specified stick
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The stick:
\
\                         * 0 = rear stick
\
\                         * 1 = side stick
\
\   Y                   The fire button state to print:
\
\                         * 0 = no fire
\
\                         * 1 = fire
\
\ ******************************************************************************

.PrintFireButton

 JSR SetIndent          \ Store the correct indent for this stick in xIndent

 LDA fireX              \ Set YC to the correct column for this button from
 CLC                    \ fireX, adding the correct indent
 ADC xIndent
 STA XC

 LDA fireY              \ Set YC to the correct row for this button from fireY
 STA YC

 TYA                    \ Set Y = Y + 4 to give us the shape number to print
 CLC
 ADC #4
 TAY

 JSR PrintShape         \ Print the button as a shape

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: PrintButtonLetter
\       Type: Subroutine
\   Category: Screen
\    Summary: Print the letter for the specified stick button
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The colour:
\
\                         * 0 = normal
\
\                         * 1 = inverse
\
\   X                   The stick:
\
\                         * 0 = rear stick
\
\                         * 1 = side stick
\
\   Y                   The button to print (A = 1 to L = 12)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   The letter that was printed
\
\   Y                   Y is preserved
\
\ ******************************************************************************

.PrintButtonLetter

 STY yStore             \ Store the button number in

 JSR SetColour          \ Set the correct colour according to the value in A

 JSR SetIndent          \ Store the correct indent for this stick in xIndent

 LDA buttonX-1,Y        \ Set YC to the correct column for this button from the
 CLC                    \ buttonX table, adding the correct indent
 ADC xIndent
 STA XC

 LDA buttonY-1,Y        \ Set YC to the correct row for this button from the
 STA YC                 \ buttonY table

 TYA                    \ Set A to the ASCII code for the letter in Y (capital
 CLC                    \ "A" to "L")
 ADC #'A' - 1

 CPX #0                 \ If X = 0 then this is the rear stick, so jump to prin2
 BEQ prin2              \ to skip the following

 ORA #&20               \ Convert the letter in A into lower case for the side
                        \ stick

.prin2

 JSR PrintCharacter     \ Print the button letter

 CMP #'B'               \ If we are printing the side stick's fire button, jump
 BEQ prin3              \ to prin3 to print the two extra buttons

 CMP #'b'               \ If we are not printing the rear stick's fire button,
 BNE prin4              \ jump to prin4 to return from the subroutine

.prin3

 LDA buttonX            \ Set XC to the column for the top-left fire button on
 CLC                    \ row 8, using the same column as the A button
 ADC xIndent
 STA XC

 LDA #8                 \ Set YC to row 8
 STA YC

 LDA aStore             \ Print the top-left fire button letter
 JSR PrintCharacter

 LDA buttonX+2          \ Set XC to the column for the top-right fire button on
 CLC                    \ row 8, using the same column as the C button
 ADC xIndent
 STA XC

 LDA #8                 \ Set YC to row 8
 STA YC

 LDA aStore             \ Print the top-right fire button letter
 JSR PrintCharacter

.prin4

 LDY yStore             \ Retrieve Y

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: SetColour
\       Type: Subroutine
\   Category: Screen
\    Summary: Set the specified colour
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The colour:
\
\                         * 0 = normal
\
\                         * 1 = inverse
\
\ ******************************************************************************

.SetColour

 CMP #0                 \ If the colour is normal, jump to scol1 to set COL = 0
 BEQ scol1

 LDA #&FF               \ If the colour is inverse, set A = &FF to set as the
                        \ value of COL

.scol1

 STA COL                \ Set the current colour in COL

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: SetIndent
\       Type: Subroutine
\   Category: Screen
\    Summary: Set the xIndent for the specified stick
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The stick:
\
\                         * 0 = rear stick
\
\                         * 1 = side stick
\
\ ******************************************************************************

.SetIndent

 LDA #0                 \ Set A = 0 to use as the indent for the rear stick

 CPX #0                 \ If X = 0 then this is the rear stick, so jump to arrw1
 BEQ arrw1              \ to skip the following

 LDA #21                \ This is the side stick, so set A = 21 to use as the
                        \ indent for the side stick

.arrw1

 STA xIndent            \ Store the indent in xIndent

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: SetTextWindow
\       Type: Subroutine
\   Category: Screen
\    Summary: Set a text window for row 16 and down, for the logger
\
\ ******************************************************************************

.SetTextWindow

 LDA #17                \ Set the foreground colour to white (1)
 JSR OSWRCH
 LDA #1
 JSR OSWRCH

 LDA #17                \ Set the background colour to black (128)
 JSR OSWRCH
 LDA #128
 JSR OSWRCH

 LDA #28                \ Start the VDU 28 command
 JSR OSWRCH

 LDA #0                 \ Set leftX
 JSR OSWRCH

 LDA #24                \ Set bottomY
 JSR OSWRCH

 LDA #39                \ Set rightX
 JSR OSWRCH

 LDA #16                \ Set topY and return from the subroutine using a tail
 JMP OSWRCH             \ call

\ ******************************************************************************
\
\       Name: ResetTextWindow
\       Type: Subroutine
\   Category: Screen
\    Summary: Reset the text window
\
\ ******************************************************************************

.ResetTextWindow

 LDA #26                \ Restore the default text window and return from the
 JMP OSWRCH             \ subroutine using a tail call

\ ******************************************************************************
\
\       Name: PrintShape
\       Type: Subroutine
\   Category: Screen
\    Summary: Print a bitmap shape directly into screen memory at (XC, YC)
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   Y                   The shape to print:
\
\                         * 0 = left arrow
\
\                         * 1 = right arrow
\
\                         * 2 = down arrow
\
\                         * 3 = up arrow
\
\                         * 4 = fire button (not pressed)
\
\                         * 5 = fire button (pressed)
\
\   XC                  Contains the text column to print at (the x-coordinate)
\
\   YC                  Contains the line number to print on (the y-coordinate)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   A is preserved
\
\ ******************************************************************************

.PrintShape

 STA aStore             \ Store A in aStore

 TYA                    \ Set Y = Y * 2
 ASL A
 TAY

 LDA shapesAddr,Y       \ Set P(2 1) to the Y-th address from the shapesAddr
 STA P+1                \ table, which is the character definition we need
 LDA shapesAddr+1,Y       
 STA P+2

 JMP char1              \ Jump into PrintCharacter to draw the shape onto the
                        \ screen

\ ******************************************************************************
\
\       Name: PrintCharacter
\       Type: Subroutine
\   Category: Screen
\    Summary: Print a character directly into screen memory at (XC, YC)
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The character to be printed
\
\   XC                  Contains the text column to print at (the x-coordinate)
\
\   YC                  Contains the line number to print on (the y-coordinate)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   A is preserved
\
\ ******************************************************************************

.PrintCharacter

 STA aStore             \ Store the character number in aStore

                        \ Now we want to set X to point to the relevant page
                        \ number for this character - i.e. &C0, &C1 or &C2.

                        \ The following logic is easier to follow if we look
                        \ at the three character number ranges in binary:
                        \
                        \   Bit #  76543210
                        \
                        \   32  = %00100000     Page 0 of bitmap definitions
                        \   63  = %00111111
                        \
                        \   64  = %01000000     Page 1 of bitmap definitions
                        \   95  = %01011111
                        \
                        \   96  = %01100000     Page 2 of bitmap definitions
                        \   125 = %01111101
                        \
                        \ We'll refer to this below

 LDX FONT               \ Set X to point to the first font page in ROM minus 1,
                        \ which is &C0 - 1, or &BF, in the BBC Micro/Electron, or
                        \ &88 - 1, or &87, in the BBC Master

 ASL A                  \ If bit 6 of the character is clear (A is 32-63)
 ASL A                  \ then skip the following instruction
 BCC P%+4

 LDX FONT+1             \ A is 64-126, so set X to point to page &C1 for the BBC
                        \ Micro/Electron, or &8A for the BBC Master

 ASL A                  \ If bit 5 of the character is clear (A is 64-95)
 BCC P%+3               \ then skip the following instruction

 INX                    \ Increment X
                        \
                        \ By this point, we started with X = &BF, and then
                        \ we did the following:
                        \
                        \   If A = 32-63:   skip    then INX  so X = &C0
                        \   If A = 64-95:   X = &C1 then skip so X = &C1
                        \   If A = 96-126:  X = &C1 then INX  so X = &C2
                        \
                        \ In other words, X points to the relevant page. But
                        \ what about the value of A? That gets shifted to the
                        \ left three times during the above code, which
                        \ multiplies the number by 8 but also drops bits 7, 6
                        \ and 5 in the process. Look at the above binary
                        \ figures and you can see that if we cleared bits 5-7,
                        \ then that would change 32-53 to 0-31... but it would
                        \ do exactly the same to 64-95 and 96-125. And because
                        \ we also multiply this figure by 8, A now points to
                        \ the start of the character's definition within its
                        \ page (because there are 8 bytes per character
                        \ definition)
                        \
                        \ Or, to put it another way, X contains the high byte
                        \ (the page) of the address of the definition that we
                        \ want, while A contains the low byte (the offset into
                        \ the page) of the address

 STA P+1                \ Store the address of this character's definition in
 STX P+2                \ P(2 1)

.char1

                        \ Now to calculate the screen address we need to write
                        \ to, as follows:
                        \
                        \   SC = &6000 + (char row * 256) + (char row * 64) + 0

 LDA #0                 \ Set SC = 0 for use in the calculation below
 STA SC

 LDA YC
 LSR A                  \ Set (A SC) = (A SC) / 4
 ROR SC                 \            = (4 * ((char row * 64) + 0)) / 4
 LSR A                  \            = char row * 64 + 0
 ROR SC

 ADC YC                 \ Set SC(1 0) = (A SC) + (YC 0) + &6000
 ADC #&60               \             = (char row * 64 + 0)
 STA SC+1               \               + char row * 256
                        \               + &6000
                        \
                        \ which is what we want, so SC(1 0) contains the address
                        \ of the first visible pixel on the character row we
                        \ want

 LDA #0                 \ Set (P A) = XC, the x-coordinate (column) of the text
 STA P                  \ cursor
 LDA XC

 ASL A                  \ Multiply (P A) by 8, and add to SC(1 0) to give us the
 ROL P                  \ screen address of the character block where we want to
 ASL A                  \ print this character
 ROL P                  \
 ASL A                  \ Starting with the low bytes
 ROL P
 ADC SC
 STA SC

 LDA SC+1               \ Add the high bytes
 ADC P
 STA SC+1

 LDY #7                 \ We want to print the 8 bytes of character data to the
                        \ screen (one byte per row), so set up a counter in Y
                        \ to count these bytes

.RRL1

 LDA (P+1),Y            \ The character definition is at P(2 1) - we set this up
                        \ above - so load the Y-th byte from P(2 1), which will
                        \ contain the bitmap for the Y-th row of the character

 EOR COL                \ Apply the colour in COL (so when COL is &FF it inverts
                        \ the colour)

 STA (SC),Y             \ Store the Y-th byte at the screen address for this
                        \ character location

 DEY                    \ Decrement the loop counter

 BPL RRL1               \ Loop back for the next byte to print to the screen

 LDA aStore             \ Retrieve the character number into A

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: buttons
\       Type: Variable
\   Category: Keyboard
\    Summary: Lookup table for Delta 14B joystick buttons
\
\ ------------------------------------------------------------------------------
\
\ In the following table, which maps buttons on the Delta 14B to the flight
\ controls, the high nibble of the value gives the column:
\
\   &6 = %110 = left column
\   &5 = %101 = middle column
\   &3 = %011 = right column
\
\ while the low nibble gives the row:
\
\   &1 = %0001 = top row
\   &2 = %0010 = second row
\   &4 = %0100 = third row
\   &8 = %1000 = bottom row
\
\ ******************************************************************************

.buttons

 EQUB &61               \ Left column    Top row              A
 EQUB &51               \ Middle column  Top row              B
 EQUB &31               \ Right column   Top row              C

 EQUB &62               \ Left column    Second row           D
 EQUB &52               \ Middle column  Second row           E
 EQUB &32               \ Right column   Second row           F

 EQUB &64               \ Left column    Third row            G
 EQUB &54               \ Middle column  Third row            H
 EQUB &34               \ Right column   Third row            I

 EQUB &68               \ Left column    Bottom row           J
 EQUB &58               \ Middle column  Bottom row           K
 EQUB &38               \ Right column   Bottom row           L

\ ******************************************************************************
\
\       Name: ReadDelta14B
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Scan the Delta 14B joystick buttons and update the screen
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The socket to scan:
\
\                         * Bit 7 clear = rear socket
\
\                         * Bit 7 set = side socket
\
\   Y                   The offset into the buttons table of the button that we
\                       want to scan on the Delta 14B
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              The result:
\
\                         * Clear = button not being pressed
\
\                         * Set = button is being pressed
\
\   A                   A is preserved
\
\   Y                   Y is preserved
\
\ ******************************************************************************

.ReadDelta14B

 TAX                    \ Store A in X so we can restore it below

 EOR buttons-1,Y        \ Fetch this button's entry from the buttons table and
                        \ set bit 7 according to the socket that we want to scan
                        \ (which is defined in bit 7 of A)

 STA VIA+&60            \ Set 6522 User VIA output register ORB (SHEILA &60) to
                        \ the value in A, which tells the Delta 14B adaptor box
                        \ that we want to read the buttons specified in PB4 to
                        \ PB7 (i.e. bits 4-7), as follows:
                        \
                        \ On the side socket joystick (bit 7 set):
                        \
                        \   %1110 = read buttons in left column   (bit 4 clear)
                        \   %1101 = read buttons in middle column (bit 5 clear)
                        \   %1011 = read buttons in right column  (bit 6 clear)
                        \
                        \ On the rear socket joystick (bit 7 clear):
                        \
                        \   %0110 = read buttons in left column   (bit 4 clear)
                        \   %0101 = read buttons in middle column (bit 5 clear)
                        \   %0011 = read buttons in right column  (bit 6 clear)

 AND #%00001111         \ We now read the 6522 User VIA to fetch PB0 to PB3 from
 AND VIA+&60            \ the user port (PB0 = bit 0 to PB3 = bit 3), which
                        \ tells us whether any buttons in the specified column
                        \ are being pressed, and if they are, in which row. The
                        \ values read are as follows:
                        \
                        \   %1111 = no button is being pressed in this column
                        \   %1110 = button pressed in top row    (bit 0 clear)
                        \   %1101 = button pressed in second row (bit 1 clear)
                        \   %1011 = button pressed in third row  (bit 2 clear)
                        \   %0111 = button pressed in bottom row (bit 3 clear)
                        \
                        \ In other words, if a button is being pressed in the
                        \ top row in the previously specified column, then PB0
                        \ (bit 0) will go low in the value we read from the user
                        \ port

 BEQ delt2              \ In the above we AND'd the result from the user port
                        \ with the bottom four bits of the table value (the
                        \ low nibble). The low nibble in buttons contains
                        \ a 1 in the relevant position for that row that
                        \ corresponds with the clear bit in the response from
                        \ the user port, so if we AND the two together and get
                        \ a zero, that means that button is being pressed, in
                        \ which case we jump to delt2 to record the button press
                        \
                        \ For example, take the buttons entry for the escape pod
                        \ button, in the right column and third row. The value
                        \ in buttons is &34. The high nibble denotes the column,
                        \ which is &3 = %011, which means in the STA VIA+&60
                        \ above, we write %1011 in the first pass (when A = 128)
                        \ to set the right column for the side socket joystick,
                        \ and we write %0011 in the first pass (when A = 0) to
                        \ set the right column for the rear socket joystick
                        \
                        \ Now for the row. The low nibble of the &34 value
                        \ from buttons contains the row, so that's &4 = %0100.
                        \ When we read the user port, then we will fetch %1011
                        \ from VIA+&60 if the button in the third row is being
                        \ pressed, so when we AND the two together, we get:
                        \
                        \   %0100 AND %1011 = 0
                        \
                        \ which will indicate the button is being pressed. If
                        \ any other button is being pressed, or no buttons at
                        \ all, then the result will be non-zero and we move on
                        \ to the next button

.delt1

 LDA #0                 \ Print the button letter without a highlight and return
 JMP PrintButtonLetter  \ from the subroutine using a tail call

.delt2

 LDA #1                 \ Print the button letter with a highlight
 JSR PrintButtonLetter

 JMP OSWRCH             \ Print the letter into logger (the text window) and
                        \ return from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: ReadADC
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Scan the analogue port and update the screen
\
\ ******************************************************************************

.ReadADC

 LDA #0                 \ Set the colour to non-highlight
 JSR SetColour

 LDX #1                 \ Call OSBYTE with A = 128 to fetch the 16-bit value
 LDA #128               \ from ADC channel 1 (the rear joystick X value),
 JSR OSBYTE             \ returning the value in (Y X)

 LDA #10                \ Move the cursor to (10, 2)
 STA XC
 LDA #2
 STA YC

 JSR PrintHexWord       \ Print (Y X) in hexadecimal

                        \ Highlight left/right arrow

 LDX #2                 \ Call OSBYTE with A = 128 to fetch the 16-bit value
 LDA #128               \ from ADC channel 2 (the rear joystick Y value),
 JSR OSBYTE             \ returning the value in (Y X)

 LDA #10                \ Move the cursor to (10, 2)
 STA XC
 LDA #3
 STA YC

 JSR PrintHexWord       \ Print (Y X) in hexadecimal

                        \ Highlight up/down arrow

 LDX #3                 \ Call OSBYTE with A = 128 to fetch the 16-bit value
 LDA #128               \ from ADC channel 3 (the side joystick X value),
 JSR OSBYTE             \ returning the value in (Y X)

 LDA #31                \ Move the cursor to (31, 2)
 STA XC
 LDA #2
 STA YC

 JSR PrintHexWord       \ Print (Y X) in hexadecimal

                        \ Highlight left/right arrow

 LDX #4                 \ Call OSBYTE with A = 128 to fetch the 16-bit value
 LDA #128               \ from ADC channel 4 (the side joystick Y value),
 JSR OSBYTE             \ returning the value in (Y X)

 LDA #31                \ Move the cursor to (31, 3)
 STA XC
 LDA #3
 STA YC

 JSR PrintHexWord       \ Print (Y X) in hexadecimal

                        \ Highlight up/down arrow

 LDA #&51               \ Set 6522 User VIA output register ORB (SHEILA &60) to
 STA VIA+&60            \ the Delta 14B joystick button in the middle column
                        \ (high nibble &5) and top row (low nibble &1), which
                        \ corresponds to the fire button

 LDA &FE40              \ Read 6522 System VIA input register IRB (SHEILA &40),
                        \ which has bit 4 clear if the rear joystick's fire
                        \ button is pressed (otherwise it's set), bit 5 clear
                        \ if the side joystick's fire button is pressed
                        \ (otherwise it's set)

 LSR A                  \ Extract the low nibble of A, so bits 0 and 1 are set
 LSR A                  \ to bits 4 and 5 from the original value of A
 LSR A
 LSR A

 PHA                    \ Store A on the stack

 AND #1                 \ Set Y to bit 4 of the original A, inverted
 EOR #1
 TAY

 LDX #0                 \ Draw the rear stick's fire button according to Y
 JSR PrintFireButton

 PLA                    \ Restore A from the stack

 LSR A                  \ Set Y to bit 5 of the original A, inverted
 AND #1
 EOR #1
 TAY

 LDX #1                 \ Draw the side stick's fire button according to Y
 JSR PrintFireButton

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: PrintHexWord
\       Type: Subroutine
\   Category: Utility routines
\    Summary: Print the 16-bit word in (Y X) in hexadecimal, followed by a full
\             stop and a carriage return
\
\ ******************************************************************************

.PrintHexWord

 TYA                    \ Print the value in Y in hexadecimal
 JSR PrintHexByte

 TXA                    \ Print the value in X in hexadecimal
 JSR PrintHexByte

                        \ So we have just printed (Y X) in hexadecimal

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: PrintHexByte
\       Type: Subroutine
\   Category: Utility routines
\    Summary: Print the byte in A in hexadecimal
\
\ ******************************************************************************

.PrintHexByte

 PHA                    \ Store A on the stack

 AND #&F0               \ Extract the top nibble of A into bits 0-3 of A
 LSR A
 LSR A
 LSR A
 LSR A

 JSR PrintHexDigit      \ Call PrintHexDigit to print the top nibble as a
                        \ hexedecimal digit

 PLA                    \ Restore the original value of A from the stack and
 AND #&0F               \ extract the bottom nibble of A into bits 0-3 of A

                        \ Fall into PrintHexDigit to print the bottom nibble as
                        \ a hexedecimal digit

\ ******************************************************************************
\
\       Name: PrintHexDigit
\       Type: Subroutine
\   Category: Utility routines
\    Summary: Print the nibble in A in hexadecimal
\
\ ******************************************************************************

.PrintHexDigit

 CLC                    \ Set A to ASCII "0" plus A, so A contains the ASCII
 ADC #'0'               \ character that represents A

 CMP #'9'+1             \ If A is in the range "0" to "9" then it is already a
 BCC phex1              \ valid hexdecimal digit, so jump to phex1 to print it

 CLC                    \ Otherwise the hexadecimal value is in the range "A" to
 ADC #7                 \ "F", so add 7 to bump ":" to ">" up to "A" to "F"

.phex1

 JSR PrintCharacter     \ Print the hexadecimal digit in A and return from the
                        \ subroutine using a tail call

 INC XC                 \ Move the text cursor along

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\ Save DELTEST.bin
\
\ ******************************************************************************

 SAVE "DELTEST", CODE%, P%, LOAD%, LOAD%
