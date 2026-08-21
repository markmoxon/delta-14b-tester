\ DELTEST - tests for Delta 14B ghost buttons

\ ******************************************************************************
\
\ Configuration variables
\
\ ******************************************************************************

 CODE% = &2400          \ The address where the code will be run

 LOAD% = &FF2400        \ The address where the code will be loaded

 VIA = &FE00            \ Memory-mapped space for accessing internal hardware,
                        \ such as the video ULA, 6845 CRTC and 6522 VIAs (also
                        \ known as SHEILA)

 OSNEWL = &FFE7         \ The address for the OSNEWL routine

 OSWRCH = &FFEE         \ The address for the OSWRCH routine

 OSBYTE = &FFF4         \ The address for the OSBYTE routine

\ ******************************************************************************
\
\ DELTEST FILE
\
\ ******************************************************************************

 ORG &0070

.SC

 SKIP 2                 \ Screen address

\ ******************************************************************************
\
\       Name: ENTRY
\       Type: Subroutine
\   Category: Screen
\    Summary: The entry point for the tool
\
\ ******************************************************************************

 ORG CODE%              \ Set the assembly address to CODE%

.ENTRY

 LDA #%11110000         \ Set the Data Direction Register (DDR) of port B of the
 STA VIA+&62            \ user port so we can read the buttons on the Delta 14B
                        \ joystick, using PB4 to PB7 as output (so we can write
                        \ to the button columns to select the column we are
                        \ interested in) and PB0 to PB3 as input (so we can read
                        \ from the button rows)

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
 JSR PrintRearLetter

 LDX #1                 \ Print the letter for the side stick
 JSR PrintRearLetter

 INY                    \ Increment the button counter

 CPY #13                \ Loop back until we have printed buttons 1 to 12
 BCC lvdu3

.loop1

 LDY #(b_13 - b_table)  \ So set a decreasing counter in Y to work through the
                        \ Delta 14B buttons in b_table

.loop2

 LDA #%10000000         \ Set A to 128, as that's what the b_14 routine expects
                        \ as a parameter

 JSR b_14               \ Call b_14 to check the Delta 14B joystick buttons and
                        \ populate the key logger

 DEY                    \ Decrement the loop counter

 BNE loop2              \ If not zero, loop back to process the next key

 LDA #129               \ Call OSBYTE with A = 129 and (Y X) = 0 to read the
 LDX #0                 \ keyboard
 LDY #0
 JSR OSBYTE

 BCS loop1              \ If no key is being pressed, keep looping

 RTS                    \ Quit program

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

 EQUB 4                 \ VDU 4
                        \
                        \ Write text at the text cursor

 EQUB 31, 4, 0          \ VDU 31, 4, 0
                        \
                        \ Move the text cursor to (4, 0)

 EQUS "Rear socket"     \ Print text

 EQUB 31, 25, 0         \ VDU 31, 25, 0
                        \
                        \ Move the text cursor to (25, 0)

 EQUS "Side socket"     \ Print text

 EQUB 31, 0, 14         \ VDU 31, 0, 14
                        \
                        \ Move the text cursor to (0, 14)

 EQUS "----------"
 EQUS "----------"
 EQUS "----------"
 EQUS "----------"

 EQUB 255               \ End token

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
\       Name: yStore
\       Type: Variable
\   Category: Screen
\    Summary: Temporary storage for the Y register
\
\ ******************************************************************************

.yStore

 EQUB 0

\ ******************************************************************************
\
\       Name: xIndent
\       Type: Variable
\   Category: Screen
\    Summary: The x-coordinate indent to use when printing button letters
\
\ ******************************************************************************

.xIndent

 EQUB 0

\ ******************************************************************************
\
\       Name: PrintRearLetter
\       Type: Subroutine
\   Category: Screen
\    Summary: Print a specified stick letter
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   0 = rear stick, 1 = side stick
\
\   Y                   The button to print (1 for the first button in A/a)
\
\ ******************************************************************************

.PrintRearLetter

 STY yStore             \ Store the letter number in

 LDA #0                 \ Set A = 0 to use as the indent for the rear stick

 CPX #0                 \ If X = 0 then this is the rear stick, so jump to prin1
 BEQ prin1              \ to skip the following

 LDA #21                \ This is the side stick, so set A = 21 to use as the
                        \ indent for the side stick

.prin1

 STA xIndent            \ Store the indent in xIndent

 LDA #31                \ Move to the correct text coordinate for this letter,
 JSR OSWRCH             \ taking the coordinates from the buttonX and buttonY
 LDA buttonX-1,Y        \ tables and incorporating the indent
 CLC                    \
 ADC xIndent            \ We use VDU 31, x, y to move the text cursor
 JSR OSWRCH
 LDA buttonY-1,Y
 JSR OSWRCH

 TYA                    \ Set A to the ASCII code for the letter in Y (capital
 CLC                    \ "A" to "L")
 ADC #'A' - 1

 CPX #0                 \ If X = 0 then this is the rear stick, so jump to prin2
 BEQ prin2              \ to skip the following

 ORA #&20               \ Convert the letter in A into lower case for the side
                        \ stick

.prin2

 JSR OSWRCH             \ Print the button letter

 CMP #'B'               \ If we are printing the side stick's fire button, jump
 BEQ prin3              \ to prin3 to print the two extra buttons

 CMP #'b'               \ If we are not printing the rear stick's fire button,
 BNE prin4              \ jump to prin4 to return from the subroutine

.prin3

 TAY                    \ Copy the button letter into Y

 LDA #31                \ Move to the position for the top-left fire button on
 JSR OSWRCH             \ row 8, using the same column as the A button
 LDA buttonX
 CLC
 ADC xIndent
 JSR OSWRCH
 LDA #8
 JSR OSWRCH

 TYA                    \ Print the top-left fire button letter
 JSR OSWRCH

 LDA #31                \ Move to the position for the top-right fire button on
 JSR OSWRCH             \ row 8, using the same column as the C button
 LDA buttonX+2
 CLC
 ADC xIndent
 JSR OSWRCH
 LDA #8
 JSR OSWRCH

 TYA                    \ Print the top-right fire button letter
 JSR OSWRCH

.prin4

 LDY yStore             \ Retrieve Y

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: b_table
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

.b_table

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
\       Name: b_14
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Scan the Delta 14B joystick buttons
\
\ ------------------------------------------------------------------------------
\
\ Scan the Delta 14B for the flight key given in register Y, where Y is the
\ offset into the KYTB table above (so this is the same approach as in DKS1).
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   Y                   The offset into the KYTB table of the key that we want
\                       to scan on the Delta 14B
\
\ ******************************************************************************

.b_13

 LDA #0                 \ Set A = 0 for the second pass through the following,
                        \ so we can check the joystick plugged into the rear
                        \ socket of the Delta 14B adaptor

.b_14

                        \ This is the entry point for the routine, which is
                        \ called with A = 128 (the value of BSTK when the Delta
                        \ 14b is enabled), and if the key we are checking has a
                        \ corresponding button on the Delta 14B, it is run a
                        \ second time with A = 0

 TAX                    \ Store A in X so we can restore it below

 EOR b_table-1,Y        \ We now EOR the value in A with the Y-th entry in
 BEQ b_quit             \ b_table, and jump to b_quit to return from the
                        \ subroutine if the table entry is 128 (&80) - in other
                        \ words, we quit if Y is the offset for the roll and
                        \ pitch controls

                        \ If we get here, then the offset in Y points to a
                        \ control with a corresponding button on the Delta 14B,
                        \ and we pass through the following twice, once with a
                        \ starting value of A = 128, and again with a starting
                        \ value of A = 0
                        \
                        \ On the first pass, the EOR will set A to the value
                        \ from b_table but with bit 7 set, which means we scan
                        \ the joystick plugged into the side socket of the
                        \ Delta 14B adaptor
                        \
                        \ On the second pass, the EOR will set A to the value
                        \ from b_table (i.e. with bit 7 clear), which means we
                        \ scan the joystick plugged into the rear socket of the
                        \ Delta 14B adaptor

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

 BEQ b_pressed          \ In the above we AND'd the result from the user port
                        \ with the bottom four bits of the table value (the
                        \ low nibble). The low nibble in b_table contains
                        \ a 1 in the relevant position for that row that
                        \ corresponds with the clear bit in the response from
                        \ the user port, so if we AND the two together and get
                        \ a zero, that means that button is being pressed, in
                        \ which case we jump to b_pressed to update the key
                        \ logger for that button
                        \
                        \ For example, take the b_table entry for the escape pod
                        \ button, in the right column and third row. The value
                        \ in b_table is &34. The high nibble denotes the column,
                        \ which is &3 = %011, which means in the STA VIA+&60
                        \ above, we write %1011 in the first pass (when A = 128)
                        \ to set the right column for the side socket joystick,
                        \ and we write %0011 in the first pass (when A = 0) to
                        \ set the right column for the rear socket joystick
                        \
                        \ Now for the row. The low nibble of the &34 value
                        \ from b_table contains the row, so that's &4 = %0100.
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

 TXA                    \ Restore the original value of A that we stored in X

 BMI b_13               \ If we just did the above with A = 128, then loop back
                        \ to b_13 to do it again with A = 0

.b_quit

 RTS                    \ Return from the subroutine

.b_pressed

                        \ Y = button number
                        \
                        \ X = handset (bit 7 set = side)

 TXA                    \ If bit 7 of X is set then this is the side stick, so
 BMI b_side             \ jump to b_side

 TYA                    \ Print capital "A" to "L" for b_table entry 1 on the
 CLC                    \ rear stick
 ADC #'A' - 1
 JSR OSWRCH

 RTS                    \ Return from the subroutine

.b_side

 TYA                    \ Print lower case "a" to "l" for b_table entry on the
 CLC                    \ side stick
 ADC #'a' - 1
 JSR OSWRCH

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\ Save DELTEST.bin
\
\ ******************************************************************************

 SAVE "DELTEST", CODE%, P%, LOAD%, LOAD%
