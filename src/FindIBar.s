; Copyright 1998-2014, Stephen Fryatt (info@stevefryatt.org.uk)
;
; This file is part of FindIBar:
;
;   http://www.stevefryatt.org.uk/software/
;
; Licensed under the EUPL, Version 1.2 only (the "Licence");
; You may not use this work except in compliance with the
; Licence.
;
; You may obtain a copy of the Licence at:
;
;   http://joinup.ec.europa.eu/software/page/eupl
;
; Unless required by applicable law or agreed to in
; writing, software distributed under the Licence is
; distributed on an "AS IS" basis, WITHOUT WARRANTIES
; OR CONDITIONS OF ANY KIND, either express or implied.
;
; See the Licence for the specific language governing
; permissions and limitations under the Licence.

; FindIBar.s
;
; FindIBar Module Source
;
; 26/32 bit neutral

	GET	$Include/AsmSWINames

; ----------------------------------------------------------------------------------------------------------------------
; Set up the Module Workspace

WS_BlockSize		*	256

			^	0
WS_TaskHandle		#	4	; Task Handle (Task Active Flag)
WS_Quit			#	4	; Task Quit Flag
WS_PointerInBar		#	4	; Pointer Over Iconbar Flag
WS_PointerMargin	#	4	; Active Area Margin from Screen Base
WS_MiscBuffer		#	16	; Miscellaneous Workspace
WS_Block		#	WS_BlockSize
WS_Size			*	@

; ======================================================================================================================
; Module Header

	AREA	Module,CODE,READONLY
	ENTRY

ModuleHeader
	DCD	TaskCode			; Offset to task code
	DCD	InitCode			; Offset to initialisation code
	DCD	FinalCode			; Offset to finalisation code
	DCD	ServiceCode			; Offset to service-call handler
	DCD	TitleString			; Offset to title string
	DCD	HelpString			; Offset to help string
	DCD	CommandTable			; Offset to command table
	DCD	0				; SWI Chunk number
	DCD	0				; Offset to SWI handler code
	DCD	0				; Offset to SWI decoding table
	DCD	0				; Offset to SWI decoding code
	DCD	0				; MessageTrans file
	DCD	ModuleFlags			; Offset to module flags

; ======================================================================================================================

ModuleFlags
	DCD	1				; 32-bit compatible

; ======================================================================================================================

TitleString
	DCB	"FindIBar",0
	ALIGN

HelpString
	DCB	"Icon Bar Finder",9,$BuildVersion," (",$BuildDate,") ",169," Stephen Fryatt, 1998-",$BuildDate:RIGHT:4,0
	ALIGN

; ======================================================================================================================

CommandTable
	DCB	"Desktop_FindIBar",0
	ALIGN
	DCD	CommandDesktop
	DCD	&00000000
	DCD	0
	DCD	0

	DCB	"IBarFind",0
	ALIGN
	DCD	0
	DCD	&00010000
	DCD	0
	DCD	0

	DCB	"IBarMargin",0
	ALIGN
	DCD	CommandMargin
	DCD	&00010000
	DCD	CommandMarginSyntax
	DCD	CommandMarginHelp

	DCD	0

; ----------------------------------------------------------------------------------------------------------------------

CommandDesktop
	STMFD	R13!,{R14}

	MOV	R2,R0
	ADR	R1,TitleString
	MOV	R0,#2
	SWI	XOS_Module

	LDMFD	R13!,{PC}

; ----------------------------------------------------------------------------------------------------------------------

CommandMarginHelp
	DCB	"*"
	DCB	27
	DCB	0
	DCB	" "
	DCB	27
	DCB	19
	DCB	"size of"
	DCB	27
	DCB	2
	DCB	"band at"
	DCB	27
	DCB	2
	DCB	"base of"
	DCB	27
	DCB	2
	DCB	"screen in which"
	DCB	27
	DCB	2
	DCB	"pointer will bring"
	DCB	27
	DCB	2
	DCB	"icon bar to"
	DCB	27
	DCB	2
	DCB	"front."
	DCB	13

CommandMarginSyntax
	DCB	27
	DCB	30
	DCB	"<margin>]"
	DCB	0
	ALIGN

CommandMargin
	STMFD	R13!,{R14}

	LDR	R12,[R12]

	CMP	R1,#1
	BEQ	SetMargin

ShowMargin
	SWI	XOS_WriteS
	DCB	"Margin is ",0
	ALIGN

	LDR	R0,[R12,#WS_PointerMargin]
	ADD	R1,R12,#WS_MiscBuffer
	MOV	R2,#16
	SWI	XOS_BinaryToDecimal

	MOV	R0,R1
	MOV	R1,R2
	SWI	XOS_WriteN

	SWI	XOS_WriteS
	DCB	" OS Units",0
	ALIGN

	SWI	XOS_NewLine

	LDMFD	R13!,{PC}

SetMargin
	MOV	R1,R0
	MOV	R0,#10
	SWI	XOS_ReadUnsigned

	STRVC	R2,[R12,#WS_PointerMargin]
	BVC	SetMarginOK

SetMarginError
	SWI	XOS_WriteS
	DCB	"This is not a valid margin size.",0
	ALIGN

	SWI	XOS_NewLine

SetMarginOK
	LDMFD	R13!,{PC}

; ======================================================================================================================

InitCode

	STMFD	R13!,{R14}

; Claim 296 bytes of workspace for ourselves and store the pointer in our private workspace.

	MOV	R0,#6
	MOV	R3,#WS_Size
	SWI	XOS_Module
	BVS	InitExit
	STR	R2,[R12]
	MOV	R12,R2

; Initialise the workspace:

	MOV	R0,#0
	STR	R0,[R12,#WS_TaskHandle]

	MOV	R0,#2
	STR	R0,[R12,#WS_PointerMargin]

InitExit
	LDMFD	R13!,{PC}

; ======================================================================================================================

FinalCode

	STMFD	R13!,{R14}
	LDR	R12,[R12]

; Kill the wimp task if it's running.

	LDR	R0,[R12,#WS_TaskHandle]
	TEQ	R0,#0
	LDRGT	R1,Task
	SWIGT	XWimp_CloseDown

; Free the workspace.

	TEQ	R12,#0
	BEQ	FinalExit
	MOV	R0,#7
	MOV	R2,R12
	SWI	XOS_Module

FinalExit
	LDMFD	R13!,{PC}

; ======================================================================================================================

ServiceCode
	STMFD	R13!,{R14}
	LDR	R12,[R12]

ServiceReset
	TEQ	R1,#&27
	MOVEQ	R14,#0
	STREQ	R14,[R12,#WS_TaskHandle]
	BEQ	ServiceExit

ServiceStartWimp
	TEQ	R1,#&49
	BNE	ServiceStartedWimp

	LDR	R14,[R12,#WS_TaskHandle]
	TEQ	R14,#0
	MOVEQ	R14,#-1
	STREQ	R14,[R12,#WS_TaskHandle]
	ADREQ	R0,CommandDesktop
	MOVEQ	R1,#0

	B	ServiceExit

ServiceStartedWimp
	LDR	R14,[R12,#WS_TaskHandle]
	CMN	R14,#1
	MOVEQ	R14,#0
	STREQ	R14,[R12,#WS_TaskHandle]

ServiceExit
	LDMFD	R13!,{PC}

; ======================================================================================================================

Task
	DCB	"TASK"

WimpVersion
	DCD	310

WimpMessages
	DCD	0

PollMask
	DCD	&1FFE

MisusedStartCommand
	DCD	0
	DCB	"Use *Desktop to start FindIBar",0
	ALIGN

; ----------------------------------------------------------------------------------------------------------------------

TaskCode
	LDR	R12,[R12]

; Check we aren't in the Desktop

	SWI	XWimp_ReadSysInfo
	TEQ	R0,#0
	ADREQ	R0,MisusedStartCommand
	SWIEQ	OS_GenerateError

; Kill any previous version of our task which may be running.

	LDR	R0,[R12,#WS_TaskHandle]
	TEQ	R0,#0
	LDRGT	R1,Task
	SWIGT	XWimp_CloseDown
	MOV	R0,#0
	STRGT	R0,[R12,#WS_TaskHandle]

; Set the Quit flag to be zero.

	STR	R0,[R12,#WS_Quit]

; Initialise the module as a wimp task (again), remembering the task handle.

	LDR	R0,WimpVersion
	LDR	R1,Task
	ADR	R2,TitleString
	ADR	R3,WimpMessages
	SWI	XWimp_Initialise
	SWIVS	OS_Exit
	STR	R1,[R12,#WS_TaskHandle]

; Set the flag to False to say that the pointer is not over the Icon Bar.

	MOV	R0,#0
	STR	R0,[R12,#WS_PointerInBar]

; Point R1 to the poll_block

	ADD	R1,R12,#WS_Block

; ----------------------------------------------------------------------------------------------------------------------

PollLoop
	SWI	OS_ReadMonotonicTime
	ADD	R2,R0,#50
	LDR	R0,PollMask
	SWI	Wimp_PollIdle

; Deal with a null event.

	TEQ	R0,#0
	BLEQ	NullEvent

; If it is a message 17 or 18 and code is 0 set the quit flag.

	TEQ	R0,#17
	TEQNE	R0,#18
	LDREQ	R0,[R1,#16]
	TEQEQ	R0,#0
	MOVEQ	R0,#1
	STREQ	R0,[R12,#WS_Quit]

; Continue to poll until the quit flag is true.

	LDR	R0,[R12,#WS_Quit]
	TEQ	R0,#0
	BEQ	PollLoop

; ----------------------------------------------------------------------------------------------------------------------

CloseDown
	LDR	R0,[R12,#WS_TaskHandle]
	LDR	R1,Task
	SWI	XWimp_CloseDown

; Having exited, set task_handle to zero and die.

	MOV	R0,#0
	STR	R0,[R12,#WS_TaskHandle]

	SWI	OS_Exit

; ======================================================================================================================

ShiftF12
	DCD	&1DC

; ----------------------------------------------------------------------------------------------------------------------

NullEvent
	SWI	Wimp_GetPointerInfo

; Check if we think the pointer is in the bar or not...

	LDR	R2,[R12,#WS_PointerInBar]
	TEQ	R2,#0
	BEQ	NotInBar

InBar
	LDR	R2,[R1,#12]			; Is the window under the pointer
	CMN	R2,#2				; the icon bar (-2)?
	MOVEQ	PC,R14				; If so, do nothing more.

	MOV	R2,#0				; Unset the pointer_in_bar flag to show
	STR	R2,[R12,#WS_PointerInBar]	; that the pointer is out of the bar

	MOV	R2,#-2				; Get the window flags for the icon bar.
	STR	R2,[R1]
	SWI	Wimp_GetWindowState

	LDR	R0,ShiftF12			; Do a Shift-F12. This will either put the
	SWI	Wimp_ProcessKey			; bar to the back or bring it to the front.

	LDR	R2,[R1,#32]			; Was the icon bar obscured *before* the
	AND	R2,R2,#&20000			; first Shift-F12. If so, it will now be
	TEQ	R2,#0				; on top after one Shift-F12 and will need
	LDREQ	R0,ShiftF12			; another to put it to the bottom as
	SWIEQ	Wimp_ProcessKey			; required.

	MOV	PC,R14

NotInBar
	LDR	R2,[R1,#4]			; Is pointer_y < pointer_margin?
	LDR	R3,[R12,#WS_PointerMargin]
	CMP	R2,R3
	MOVGE	PC,R14				; If not, quit.

	MOV	R2,#1				; Set the pointer_in_bar flag to show that
	STR	R2,[R12,#WS_PointerInBar]	; the pointer is over the bar.

	MOV	R2,#-2				; Get the icon bar's window flags
	STR	R2,[R1]
	SWI	Wimp_GetWindowState

	LDR	R2,[R1,#32]			; If the bar is obscured, do a Shift-F12
	AND	R2,R2,#&20000			; to bring it to the front.
	TEQ	R2,#0
	LDREQ	R0,ShiftF12
	SWIEQ	Wimp_ProcessKey

	MOV	PC,R14

; ======================================================================================================================

	END
