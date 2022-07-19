#!/bin/bash

### Different links, helped for developing this script...
# https://sites.uclouvain.be/SystInfo/usr/include/bits/signum.h.html
### Different solving and ideas
#content=$(xxd -s $((length+$offset)) -l 2 -g 2 "$1" | sed -E "s/^.{9}(.{3,48})?.*$/\1/g" | sed -E "s/([0-9a-f]+):?/0x\1/g" )

### Audio Stream Player Presets
zx_tape_hz=48000			# Sampling frequency for ZX-Spectrum's tape
player_rk_alsa='aplay -r 16000 -N'
player_zx_alsa='aplay -r %d --start-delay=0 -f U8 -c 1'
player_rk_pulse='pacat --rate=16000 --format=U8 --channels=1'
player_zx_pulse='pacat --rate=%d --format=U8 --channels=1'

### Experimental feature
player_rk_vlc='cvlc -A --demux=rawaud --rawaud-channels=1 --rawaud-fourcc="u8<>" --rawaud-samplerate=16000 --play-and-exit - vlc://quit'
player_zx_vlc='cvlc -A --demux=rawaud --rawaud-channels=1 --rawaud-fourcc="u8<>" --rawaud-samplerate=%d --play-and-exit - vlc://quit'

### Session default Settings
screen_resolution="auto"		# Quality of ZX-Spectrum's Screen$
screen_wrap=false			# Improvings of ZX-Spectrum's Screen$
screen_only=false			# Stop after ZX-Spectrum's Screen$ loading
screen_block=false			# Block-pseudographic conversion
debug_mode=false			# Logging dump of tape's blocks
disassm_mode=false			# Disassembly
###
dialog_mode=false			# Interactive Mode
settings_mode=false			# Show Settings Dialog as first
all_ready=false				# Flag of preparings
discover=false				# Discover the ZX-Spectrum's tape
progress_name=""			# Common progress name
percents=0				# Common progress percents

## Detect forsession  player
if dpkg -l pulseaudio >/dev/null 2>/dev/null
then
	player_rk="$player_rk_pulse"	# Player for *.rk/gam files
	player_zx="$player_zx_pulse"	# Player for *.tap files
else
	player_rk="$player_rk_alsa"	# Player for *.rk/gam files
	player_zx="$player_zx_alsa"	# Player for *.tap files
fi

### Session arguments
files=()				# List of input tapes
ansies=("./.screen.txt")		# List of output screens as ANSI-Escapes

### Prepare session output descriptors
if { >&4; }				# Tape logging descriptor
then	date >&4			# Is using
else	exec 4>&1			# Redirect
fi 2>/dev/null

if { >&5; }				# Screen$ logging descriptor
then	date >&5			# Is using
else	exec 5>&1			# Redirect
fi 2>/dev/null

if { >&6; }				# Tape dumping descriptor
then	date >&6			# Is using
else	exec 6>&1			# Redirect
fi 2>/dev/null

if { >&9; }				# Tape dumping descriptor
then	echo 0>&9			# Is using
else	exec 9>/dev/gauge		# Redirect
fi 2>/dev/null

### Helping page
function Usage {
cat << EOF
Usage:
	-h
	--help
		Print this Help page
	-a[a...] FILE [FILE...]
	--ansi=FILE
		Print the ZX-Spectrum's Screen$ to the specific file with
		coloured ANSI Escape-sequencies
		Default: ./_screen_.txt
	--ansi-resolution=LOW|HIGH|AUTO
		Print the ZX-Spectrum's Screen with specific Braille-dots blocks
		LOW) Use 2x1 Braille letters - 4x4 pixels
		HIGH) Use 4x2 Braille letters - 8x8 pixels
		AUTO) Select mode by current terminal mode (64x25 or 128x50)
		Default: AUTO
	--ansi-wrap
		Force for an experimental operation over Braille-dots processing
		improving picture quality
	--ansi-block
		Force for block-pseudographic conversion
	-s
	--screen-only
		Force stopping after ZX-Spectrum's Screen loading
	--debug-mode
		Print a dump of current tape-block
	-z
	--z80-disassm
		Print disassembly (in debug mode only)
	--settings
		Start with Settings-dialog
	--player=ALSA|PULSE|VLC-alsa|VLC-pulse
		Force using selected player
	-v
	--version
		v1.00 2022/05/09 by Alikberov

Example:
$ tape86zx --ansi=./Tujad.txt --ansi-resolution=High ./Tujad.tap
$ tape86zx -aa ./Tujad.txt ./Trantor.txt --screen-only ./Tujad.tap ./Trantor.tap

$ ( exec 4<> >(:); ./tape86zx.sh 5>&4 | x-terminal-emulator -e "cat <&4" )
EOF
}

### Interactive settings
function Settings {
	local resolution_auto=false
	local resolution_high=false
	local ONOFF=(ON OFF)
	local flags=()
	[ ${screen_resolution} == "auto" ] && resolution_auto=true
	[ ${screen_resolution} == "high" ] && resolution_high=true
	flags+=("a" "ANSI Auto-Resolution" ${ONOFF[$(${resolution_auto}; echo $?)]})
	flags+=("h" "ANSI High-Resolution" ${ONOFF[$(${resolution_high}; echo $?)]})
	flags+=("w" "ANSI Wrap Processing" ${ONOFF[$(${screen_wrap}; echo $?)]})
	flags+=("u" "ANSI Block Pseudographic" ${ONOFF[$(${screen_block}; echo $?)]})
	flags+=("s" "Load Screen$ Only" ${ONOFF[$(${screen_only}; echo $?)]})
	flags+=("d" "Debugging Mode" ${ONOFF[$(${debug_mode}; echo $?)]})
	flags+=("z" "z80-Disassembly Mode" ${ONOFF[$(${disassm_mode}; echo $?)]})
	help_file=$(mktemp)
	(
		if [ -f "./.conf" ]
		then
			echo "#./.conf"
			cat "./.conf"
			echo; echo "# Current Settings #"
		fi
		echo "${player_rk}"
		printf "$(echo "$player_zx")" $zx_tape_hz
	) > ${help_file}
	trap "rm ${help_file}" SIGINT
   	CHECKS=$(dialog --title "Settings" \
			--hfile $help_file \
			--backtitle "Tape player configuration" \
			--extra-button \
			--extra-label "see options" \
			--checklist \
				"[F1] for see extras" 15 60 $((${#flags[*]}/3)) "${flags[@]}" \
		3>&1 1>&2 2>&3)
	local exitstatus=$?
	trap - SIGINT
	rm ${help_file}
	if [ $exitstatus = 0 ] || [ $exitstatus = 3 ]
	then
		if [ $exitstatus = 0 ]
		then
			screen_resolution="low";
			screen_wrap=false;
			screen_block=false;
			screen_only=false;
			debug_mode=false;
			disassm_mode=false
			for flag in $CHECKS
			do
				case $flag in
				a)	screen_resolution="auto";;
				h)	screen_resolution="high";;
				u)	screen_block=true;;
				w)	screen_wrap=true;;
				s)	screen_only=true;;
				d)	debug_mode=true;;
				z)	disassm_mode=true;;
				esac
				echo $flag
			done
		else
			printf "\e[0m"
			Usage
			echo
			printf "$ %s" $0
			screen_resolution="low";
			for flag in $CHECKS
			do
				case $flag in
				a)	screen_resolution="auto";;
				h)	screen_resolution="high";;
				esac
			done
			[ ${screen_resolution} != "auto" ] && printf " --ansi-resolution=%s" $screen_resolution
			for flag in $CHECKS
			do
				case $flag in
				w)	printf " --ansi-wrap";;
				u)	printf " --ansi-block";;
				s)	printf " --screen-only";;
				d)	printf " --debug-mode";;
				z)	printf " --z80-disassm";;
				esac
			done
			echo ' ...'
			exit
		fi
	fi
}

function tap_assm_prepare {
	local	mnemos='''
NOP	LD_BC,@	LD_(BC),A	INC_BC	INC_B	DEC_B	LD_B,*	RLCA	EX_AFAF	ADD_HL,BC	LD_A,(BC)	DEC_BC	INC_C	DEC_C	LD_C,*	RRCA
DJNZ_±	LD_DE,@	LD_(DE),A	INC_DE	INC_D	DEC_D	LD_D,*	RLA	JR_±	ADD_HL,DE	LD_A,(DE)	DEC_DE	INC_E	DEC_E	LD_E,*	RRA
JR_NZ,±	LD_HL,@	LD_(@),HL	INC_HL	INC_H	DEC_H	LD_H,*	DAA	JR_Z,±	ADD_HL,HL	LD_HL,(@)	DEC_HL	INC_L	DEC_L	LD_L,*	CPL
JR_NC,±	LD_SP,@	LD_(@),A	INC_SP	INC_(HL)	DEC_(HL)	LD_(HL),*	SCF	JR_C,±	ADD_HL,SP	LD_A,(@)	DEC_SP	INC_A	DEC_A	LD_A,*	CCF
LD_B,B	LD_B,C	LD_B,D	LD_B,E	LD_B,H	LD_B,L	LD_B,(HL)	LD_B,A
LD_C,B	LD_C,C	LD_C,D	LD_C,E	LD_C,H	LD_C,L	LD_C,(HL)	LD_C,A
LD_D,B	LD_D,C	LD_D,D	LD_D,E	LD_D,H	LD_D,L	LD_D,(HL)	LD_D,A
LD_E,B	LD_E,C	LD_E,D	LD_E,E	LD_E,H	LD_E,L	LD_E,(HL)	LD_E,A
LD_H,B	LD_H,C	LD_H,D	LD_H,E	LD_H,H	LD_H,L	LD_H,(HL)	LD_H,A
LD_L,B	LD_L,C	LD_L,D	LD_L,E	LD_L,H	LD_L,L	LD_L,(HL)	LD_L,A
LD_(HL),B	LD_(HL),C	LD_(HL),D	LD_(HL),E	LD_(HL),H	LD_(HL),L	HLT	LD_(HL),A
LD_A,B	LD_A,C	LD_A,D	LD_A,E	LD_A,H	LD_A,L	LD_A,(HL)	LD_A,A
ADD_A,B	ADD_A,C	ADD_A,D	ADD_A,E	ADD_A,H	ADD_A,L	ADD_A,(HL)	ADD_A,A
ADC_A,B	ADC_A,C	ADC_A,D	ADC_A,E	ADC_A,H	ADC_A,L	ADC_A,(HL)	ADC_A,A
SUB_B	SUB_C	SUB_D	SUB_E	SUB_H	SUB_L	SUB_(HL)	SUB_A
SBC_A,B	SBC_A,C	SBC_A,D	SBC_A,E	SBC_A,H	SBC_A,L	SBC_A,(HL)	SBC_A,A
AND_B	AND_C	AND_D	AND_E	AND_H	AND_L	AND_(HL)	AND_A
XOR_B	XOR_C	XOR_D	XOR_E	XOR_H	XOR_L	XOR_(HL)	XOR_A
OR_B	OR_C	OR_D	OR_E	OR_H	OR_L	OR_(HL)		OR_A
CP_B	CP_C	CP_D	CP_E	CP_H	CP_L	CP_(HL)		CP_A
RET_NZ	POP_BC	JP_NZ,@	JP_@	CALL_NZ,@	PUSH_BC	ADD_A,*	RST_$00
RET_Z	RET	JP_Z,@	BITS	CALL_Z,@	CALL_@	ADC_A,*	RST_$08
RET_NC	POP_DE	JP_NC,@	OUT_(*),A	CALL_NC,@	PUSH_DE	SUB_*	RST_$10
RET_C	EXX	JP_C,@	IN_A,(*)	CALL_C,@	IX	SBC_A,*	RST_$18
RET_PO	POP_HL	JP_PO,@	EX_(SP),HL	CALL_PO,@	PUSH_HL	AND_*	RST_$20
RET_PE	JP_(HL)	JP_PE,@	EX_DE,HL	CALL_PE,@	EXTD	XOR_*	RST_$28
RET_P	POP_AF	JP_P,@	DI	CALL_P,@	PUSH_AF	OR_*	RST_$30
RET_M	LD_SP,HL	JP_M,@	EI	CALL_M,@	IY	CP_*	RST_$38
	'''
	local	mnemos_ed='''
---	---	---	---	---	---	---	---	---	---	---	---	---	---	---	---
---	---	---	---	---	---	---	---	---	---	---	---	---	---	---	---
---	---	---	---	---	---	---	---	---	---	---	---	---	---	---	---
---	---	---	---	---	---	---	---	---	---	---	---	---	---	---	---
IN_B,(C)	OUT_(C),B	SBC_HL,BC	LD_(@),BC	NEG	RETN	IM_0	LD_I,A
IN_C,(C)	OUT_(C),C	ADC_HL,BC	LD_BC,(@)	NEG	RETI	IM_0-1	LD_R,A
IN_D,(C)	OUT_(C),D	SBC_HL,DE	LD_(@),DE	NEG	RETN	IM_1	LD_A,I
IN_E,(C)	OUT_(C),E	ADC_HL,DE	LD_DE,(@)	NEG	RETN	IM_2	LD_A,R
IN_H,(C)	OUT_(C),H	SBC_HL,HL	LD_(@),HL	NEG	RETN	IM_0	RRD
IN_L,(C)	OUT_(C),L	ADC_HL,HL	LD_HL,(@)	NEG	RETI	IM_0-1	RLD
IN_(C)		OUT_(C),0	SBC_HL,SP	LD_(@),SP	NEG	RETN	IM_1	---
IN_A,(C)	OUT_(C),A	ADC_HL,SP	LD_SP,(@)	NEG	RETN	IM_2	---
---	---	---	---	---	---	---	---	---	---	---	---	---	---	---	---
---	---	---	---	---	---	---	---	---	---	---	---	---	---	---	---
LDI	CPI	INI	OUTI	---	---	---	---	LDD	CPD	IND	OUTD	---	---	---	---
LDIR	CPIR	INIR	OTIR	---	---	---	---	LDDR	CPDR	INDR	OTDR
---	---	---	---	---	---	---	---	---	---	---	---	---	---	---	---
---	---	---	---	---	---	---	---	---	---	---	---	---	---	---	---
---	---	---	---	---	---	---	---	---	---	---	---	---	---	---	---
---	---	---	---	---	---	---	---	---	---	---	---	---	---	---	---
	'''
	local	regs=("B" "C" "D" "E" "H" "L" "(HL)" "A")
	local	rel8='±'
	local	data8='\*'
	local	data16='\@'
	local	mnems
	local	i
	mnemox=()
	let i=0
	printf "|\b"
	printf "XXX\n20\nXXX\n" >&9
	while [ $i -lt 256 ]
	do
		if [ $i -lt 8 ]; then mnemox+=(`printf "s/^_?0xcb_0x%02x/_RLC_%s#/" $i ${regs[$(($i&7))]}`)
		elif [ $i -lt 16 ]; then mnemox+=(`printf "s/^_?0xcb_0x%02x/_RRC_%s#/" $i ${regs[$(($i&7))]}`)
		elif [ $i -lt 24 ]; then mnemox+=(`printf "s/^_?0xcb_0x%02x/_RL_%s#/" $i ${regs[$(($i&7))]}`)
		elif [ $i -lt 32 ]; then mnemox+=(`printf "s/^_?0xcb_0x%02x/_RR_%s#/" $i ${regs[$(($i&7))]}`)
		elif [ $i -lt 40 ]; then mnemox+=(`printf "s/^_?0xcb_0x%02x/_SLA_%s#/" $i ${regs[$(($i&7))]}`)
		elif [ $i -lt 48 ]; then mnemox+=(`printf "s/^_?0xcb_0x%02x/_SRA_%s#/" $i ${regs[$(($i&7))]}`)
		elif [ $i -lt 56 ]; then mnemox+=(`printf "s/^_?0xcb_0x%02x/_SLL_%s#/" $i ${regs[$(($i&7))]}`)
		elif [ $i -lt 64 ]; then mnemox+=(`printf "s/^_?0xcb_0x%02x/_SRL_%s#/" $i ${regs[$(($i&7))]}`)
		elif [ $i -lt 128 ]; then mnemox+=(`printf "s/^_?0xcb_0x%02x/_BIT_%d,%s#/" $i $(($i&7)) ${regs[$(($i/8&7))]}`)
		elif [ $i -lt 192 ]; then mnemox+=(`printf "s/^_?0xcb_0x%02x/_RES_%d,%s#/" $i $(($i&7)) ${regs[$(($i/8&7))]}`)
		else mnemox+=(`printf "s/^_?0xcb_0x%02x/_SET_%d,%s#/" $i $(($i&7)) ${regs[$(($i/8&7))]}`)
		fi
		let i=$i+1
	done
	let i=0
	mnems=($mnemos_ed)
	printf "/\b"
	printf "XXX\n30\nXXX\n" >&9
	for cmd in ${mnems[@]}
	do
		if [[ "$cmd" =~ $data16 ]]
		then
			cmd=`printf "%s" $cmd | sed 's/@/\$\x5C2\x5C1/'`
			mnemox+=(`printf "s/^_?0xed_0x%02x_0x(..)_0x(..)/_%s#/" $i ${cmd}`)
		else
			mnemox+=(`printf "s/^_?0xed_0x%02x/_%s#/" $i ${cmd}`)
		fi
		let i=$i+1
	done
	let i=0
	mnems=($mnemos)
	printf "\x2D\b"
	printf "XXX\n40\nXXX\n" >&9
	for cmd in ${mnems[@]}
	do
		if [[ "$cmd" =~ $data16 ]]
		then
			cmd=`printf "%s" $cmd | sed 's/@/\$\x5C2\x5C1/'`
			mnemox+=(`printf "s/^_?0x%02x_0x(..)_0x(..)/_%s#/" $i ${cmd}`)
		elif [[ "$cmd" =~ $data8 ]]
		then
			cmd=`printf "%s" $cmd | sed 's/\*/\$\x5C1/'`
			mnemox+=(`printf "s/^_?0x%02x_0x(..)/_%s#/" $i ${cmd}`)
		elif [[ "$cmd" =~ $rel8 ]]
		then
			cmd=`printf "%s" $cmd | sed 's/±/\$+\$\x5C1/'`
			mnemox+=(`printf "s/^_?0x%02x_0x(..)/_%s#/" $i ${cmd}`)
		else
			mnemox+=(`printf "s/^_?0x%02x/_%s#/" $i ${cmd}`)
		fi
		let i=$i+1
	done
}

function tap_basic_prepare {
	local	cols=(0 4 1 5 2 6 3 7)
	local	tokens=($(seq 0 127))
	local	pseudo="\U2588	\U2599	\U259F	\U2583	\U259B	\U258B	\U259E	\U2596	\U259C	\U259A	\U2590	\U2587	\2580	\U2598	\U259D	\U0020"
	#	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
	# 2580	▀	▁	▂	▃	▄	▅	▆	▇	█	▉	▊	▋	▌	▍	▎	▏
	# 2596	▐	░	▒	▓	▔	▕	▖	▗	▘	▙	▚	▛	▜	▝	▞	▟
	# 80	\U2588	\U2599	\U259F	\U2583	\U259B	\U258B	\U259E	\U2596	\U259C	\U259A	\U2590	\U2587	\2580	\U2598	\U259D	\U0020
	local	pseudos=($pseudos)
	local	zx_tokens='''
	\\U2588	\\U2599	\\U259F	\\U2583	\\U259B	\\U258B	\\U259E	\\U2596	\\U259C	\\U259A	\\U2590	\\U2587	\\U2580	\\U2598	\\U259D	\\U0020
	A	B	C	D	E	F	G	H	I	J	K	L	M	N	O	P
	Q	R	S	SPECTRUM	PLAY	RND	INKEY$	PI	FN	POINT	SCREEN$	ATTR	AT	TAB	VAL$	CODE
	VAL	LEN	SIN	COS	TAN	ASN	ACS	ATN	LN	EXP	INT	SQR	SGN	ABS	PEEK	IN
	USR	STR$	CHR$	NOT	BIN	OR	AND	<=	>=	<>	LINE	THEN	TO	STEP	DEF_FN	CAT
	FORMAT	MOVE	ERASE	OPEN	CLOSE	MERGE	VERIFY	BEEP	CIRCLE	INK	PAPER	FLASH	BRIGHT	INVERSE	OVER	OUT
	LPRINT	LLIST	STOP	READ	DATA	RESTORE	NEW	BORDER	CONTINUE	DIM	REM	FOR	GOTO	GOSUB	INPUT	LOAD
	LIST	LET	PAUSE	NEXT	POKE	PRINT	PLOT	RUN	SAVE	RANDOMIZE	IF	CLS	DRAW	CLEAR	RETURN	COPY'''
	printf "\x5C\b"
	printf "XXX\n50\nXXX\n" >&9
	tokens+=(${zx_tokens})
	#
	tokexp=("s/_?0x0e.{25}//g")
	tokexp+=("s/_?0x08/\x1B[D/g")
	tokexp+=("s/_?0x0d//g")
	tokexp+=("s/_?0x10_0x.0/\x1B[3${cols[0]}m/g")	# INK
	tokexp+=("s/_?0x10_0x.1/\x1B[3${cols[1]}m/g")
	tokexp+=("s/_?0x10_0x.2/\x1B[3${cols[2]}m/g")
	tokexp+=("s/_?0x10_0x.3/\x1B[3${cols[3]}m/g")
	tokexp+=("s/_?0x10_0x.4/\x1B[3${cols[4]}m/g")
	tokexp+=("s/_?0x10_0x.5/\x1B[3${cols[5]}m/g")
	tokexp+=("s/_?0x10_0x.6/\x1B[3${cols[6]}m/g")
	tokexp+=("s/_?0x10_0x.7/\x1B[3${cols[7]}m/g")
	tokexp+=("s/_?0x10_0x.8/\x1B[3${cols[7]}m/g")	# INK
	tokexp+=("s/_?0x11_0x.0/\x1B[4${cols[0]}m/g")	# PAPER
	tokexp+=("s/_?0x11_0x.1/\x1B[4${cols[1]}m/g")
	tokexp+=("s/_?0x11_0x.2/\x1B[4${cols[2]}m/g")
	tokexp+=("s/_?0x11_0x.3/\x1B[4${cols[3]}m/g")
	tokexp+=("s/_?0x11_0x.4/\x1B[4${cols[4]}m/g")
	tokexp+=("s/_?0x11_0x.5/\x1B[4${cols[5]}m/g")
	tokexp+=("s/_?0x11_0x.6/\x1B[4${cols[6]}m/g")
	tokexp+=("s/_?0x11_0x.7/\x1B[4${cols[7]}m/g")
	tokexp+=("s/_?0x11_0x.8/\x1B[3${cols[0]}m/g")	# PAPER
	tokexp+=("s/_?0x12_0x.0/\x1B[25m/g")		# FLASH
	tokexp+=("s/_?0x12_0x.1/\x1B[5m/g")
	tokexp+=("s/_?0x13_0x.0/\x1B[22m/g")		# BRIGHT
	tokexp+=("s/_?0x13_0x.1/\x1B[1m/g")
	tokexp+=("s/_?0x14_0x../\x1B[7m/g")		# INVERSE
	tokexp+=("s/_?0x15_0x.0/\x1B[24m/g")		# OVER
	tokexp+=("s/_?0x15_0x.1/\x1B[4m/g")
	tokexp+=("s/_?0x16_0x.(.)_0x.(.)/\x1B[\1;\2H/g") # AT
	tokexp+=("s/_?0x00//g")
	printf "|\b"
	printf "XXX\n60\nXXX\n" >&9
	for i in {32..127}	# 20..7F
	do
		tokexp+=(`printf "s/_?0x%02x/\x5Cx%02x/g" $i $i`)
	done
	printf "/\b"
	printf "XXX\n70\nXXX\n" >&9
	for i in {128..162}	# 80..A2
	do
		tokexp+=(`printf "s/_?0x%02x/${tokens[$i]}/g" $i`)
	done
	printf "\x2D\b"
	printf "XXX\n80\nXXX\n" >&9
	for i in {163..255}	# A3..FF
	do
		tokexp+=(`printf "s/_?0x%02x/${tokens[$i]}\x5Cx20/g" $i`)
	done
}

function tap_screen_prepare {
	#	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
	# 2580	▀	▁	▂	▃	▄	▅	▆	▇	█	▉	▊	▋	▌	▍	▎	▏
	# 2590	▐	░	▒	▓	▔	▕	▖	▗	▘	▙	▚	▛	▜	▝	▞	▟
	# 80	\U2588	\U2599	\U259F	\U2583	\U259B	\U258B	\U259E	\U2596	\U259C	\U259A	\U2590	\U2587	\2580	\U2598	\U259D	\U0020
	pseudex=()
	pseudex+=(s/$'\U281B'/$'\U2580'/g)
	pseudex+=(s/$'\U28C0'/$'\U2581'/g)
	pseudex+=(s/$'\U28E4'/$'\U2582'/g)
	pseudex+=(s/$'\U28E2'/$'\U2584'/g)
	pseudex+=(s/$'\U28F6'/$'\U2586'/g)
	pseudex+=(s/$'\U2847'/$'\U258B'/g)
	pseudex+=(s/$'\U2844'/$'\U2596'/g)
	pseudex+=(s/$'\U28A0'/$'\U2597'/g)
	pseudex+=(s/$'\U2803'/$'\U2598'/g)
	pseudex+=(s/$'\U28E7'/$'\U2599'/g)
	pseudex+=(s/$'\U28A3'/$'\U259A'/g)
	pseudex+=(s/$'\U285F'/$'\U259B'/g)
	pseudex+=(s/$'\U289B'/$'\U259C'/g)
	pseudex+=(s/$'\U2818'/$'\U259D'/g)
	pseudex+=(s/$'\U285C'/$'\U259E'/g)
	pseudex+=(s/$'\U28FC'/$'\U259F'/g)
	pseudex+=(s/$'\U28FF'/$'\U2587'/g)
}

function Prepares {
	if [ $all_ready != true ]
	then
		printf "  \e[5mMoment\e[0m\r\x5C\r"
		printf "XXX\n10\nXXX\n" >&9
		tap_screen_prepare
		tap_assm_prepare
		tap_basic_prepare
		printf "XXX\n100\nXXX\n" >&9
		printf "\r"
		all_ready=true
	fi
}

function Gauge {
	printf "%s\n%s - %s\nXXX\n" $1 "$progress_name" "$2" >&9
	printf "\e[s\e[999;999H\b\b\b\b%3d%%\e[u" $1 >&2
}

function Gauges {
	printf "%d\nXXX\n%s\nXXX\n" $percents "$progress_name" >&9
	printf "\e[s\e[999;999H\b\b\b\b%3d%%\e[u" $percents >&2
}

### Disassembler of ZX-Spectrum's Basic-listings inline machine code
function tap_disassm {
	local string=$(xxd -e -s $(($2+1)) -l 6 -g 2 "$1" | cut -d " " -f 2-17 | tr "\n" " " | sed -E "s/([0-9a-f]+)/16#\1/g")
	local words=(${string})
	local codes=$(xxd -s $(($2+7)) -l $((${words[2]})) -g 1 "$1" | sed -E "s/^.{9}(.{3,48}).*$/\1/g" | sed -E "s/([0-9a-f]+)/0x\1/g" )
	local dump=(${codes})
	local cmd=$(IFS=";"; echo "${mnemox[*]}")
	local instr prefix command
	local rix='I[XY]'
	local prix='\(I[XY]\)'
	if [ $((${dump[0]})) -eq 234 ] && [ $((${dump[1]}|${dump[2]}|${dump[3]}|${dump[4]}|${dump[5]}|${dump[6]}|${dump[7]}|${dump[8]})) -gt 127 ]
	then
		echo "; Inline z80-assembly"
		xxd -s $(($2+7)) -l $((${words[2]})) -g 1 "$1"
		if [ $((${words[2]})) -lt 128 ] || [ $discover == true ]
		then
			dump=(${dump[@]:1})
			local prog=`echo -n ${dump[@]} | sed 's/ /_/g'`
			local limit=${#prog}
			while [ "$prog" != "" ]
			do
				local percent=$((100*(limit-${#prog})/$limit))
				Gauge $percent "Disassembling"
				instr=`echo ${prog} | sed -E ${cmd}`
				if [[ "${instr}" =~ $rix ]]
				then
					prefix=`echo $instr | sed -E 's/[^IXY]+//g'`
				else
					instr=`echo $instr | sed -E "s/HL/$prefix/"`
					if [[ "${instr}" =~ $prix ]]
					then
						instr=`echo $instr | sed -E 's/(I[XY])([^#]*)#_0x(..)/\1+\x24\3\2#/'`
					fi
					prefix="HL"
					echo $instr | sed -E 's/#.*//' | sed -E 's/_/\t/g'
				fi
				prog=`echo $instr | sed -E 's/^.*#//'`
			done
			Gauges
			printf "\n"
		fi
	fi
}

### Decoder of ZX-Spectrum's Basic-listings
function tap_basic {
	local string=$(xxd -e -s $(($2)) -l 4 -g 2 "$1" | cut -d " " -f 2-17 | tr "\n" " " | sed -E "s/([0-9a-f]+)/16#\1/g")
	local words=(${string})
	local codes=$(xxd -s $(($2+2)) -l $((${words[0]})) -g 1 "$1" | sed -E "s/^.{9}(.{3,48}).*$/\1/g" | sed -E "s/([0-9a-f]+)/0x\1/g" )
	local dump=(${codes})
	local cmd=$(IFS=";"; echo "${tokexp[*]}")
	local commands
	local addr=$(($2+3))
	dump=(${dump[@]:1})
	local limit=${#dump[@]}
	while [ ${#dump[@]} -gt 2 ]
	do
		local bas_line=$((${dump[0]}*256+${dump[1]}))
		local bas_size=$((${dump[3]}*256+${dump[2]}))
		local bas_text=(${dump[@]:4:$bas_size})
		printf "%4d " $bas_line
		commands=`echo ${dump[@]:4:$bas_size} \
			| sed 's/ /_/g' \
				| sed -E 's/(0x3[0-9])(_0x0e.{25}_0x[a-f].)/\1_0x20\2/g' \
					| exec sed -E "$cmd"`
		printf "%s\e[0m\n" "$commands"
		if [ $((bas_line)) -gt 9999 ] || [ $bas_size -gt ${#dump[@]} ]
		then
			echo ${dump[@]}
		fi
		dump=(${dump[@]:$((4+$bas_size))})
		let addr+=$(($bas_size))
	done
	printf "\n"
	#xxd -s $(($2)) -l $((${words[0]})) -g 1 "$1"
}

function tap_screen_full {
	local cols=(0 4 1 5 2 6 3 7)
	local dump=$(xxd -s $(($2)) -l 6912 -g 1 "$1" | sed -E "s/^.{9}(.{3,48}).*$/\1/g" | sed -E "s/([0-9a-f]+)/0x\1/g" )
	local bytes=(${dump})
	local i x y xy
	local attr addr
	local bitl bitr bits0 bits1 bits2 bits3 bits4 bits5 bits6 bits7
	local top bottom
	local wrap=false
	local invert=0x00
	local invert_wrap=0xFF
	local attribute flash bright
	local ansi paper ink
	local attr_top
	local attr_bottom
	local attr_top_last=""
	local attr_bottom_last=""
	local percent
	[ "${screen_wrap}" == "true" ] && wrap=true
	printf "" >"${ansies[0]}"
	for i in {6144..6911}
	do
		trap "break" SIGINT
		xy=$((i-6144))
		percent=$((100*($xy)/767))
		Gauge $((percent)) "Screen$"
		x=$((xy&31))
		y=$((xy/32))
		if [[ $x -eq 0 ]] && [[ $y -gt 0 ]] && [[ "$top"!="" ]] && [[ "$bottom"!="" ]]
		then
			printf "$top\e[0m\n" >>"${ansies[0]}"
			printf "$bottom\e[0m\n" >>"${ansies[0]}"
			top=""
			bottom=""
			attr_top_last=""
			attr_bottom_last=""
		fi
		attr=$((${bytes[i]}))
		ansi="\e[0;"
		[ $((attr&128)) -gt 0 ] && ansi="\e[5;"
		[ $((attr&64)) -gt 0 ] && ansi=${ansi}"1;"
		ink=${ansi}"3${cols[$((attr&7))]};4${cols[$((attr/8%8))]}m"
		paper=${ansi}"4${cols[$((attr&7))]};3${cols[$((attr/8%8))]}m"
		addr=$(((xy&255)+((xy/256)*2048)))
		summ0=0; braille0=0; byte0=$((${bytes[$((addr))]}))
		summ1=0; braille1=0; byte1=$((${bytes[$((addr+256))]}))
		summ2=0; braille2=0; byte2=$((${bytes[$((addr+512))]}))
		summ3=0; braille3=0; byte3=$((${bytes[$((addr+768))]}))
		summ4=0; braille4=0; byte4=$((${bytes[$((addr+1024))]}))
		summ5=0; braille5=0; byte5=$((${bytes[$((addr+1280))]}))
		summ6=0; braille6=0; byte6=$((${bytes[$((addr+1536))]}))
		summ7=0; braille7=0; byte7=$((${bytes[$((addr+1792))]}))
		if [ $((byte0&0x80)) -gt 0 ]; then ((braille0+=0x01)); ((summ0++)); fi
		if [ $((byte1&0x80)) -gt 0 ]; then ((braille0+=0x02)); ((summ0++)); fi
		if [ $((byte2&0x80)) -gt 0 ]; then ((braille0+=0x04)); ((summ0++)); fi
		if [ $((byte3&0x80)) -gt 0 ]; then ((braille0+=0x40)); ((summ0++)); fi
		if [ $((byte0&0x40)) -gt 0 ]; then ((braille0+=0x08)); ((summ0++)); fi
		if [ $((byte1&0x40)) -gt 0 ]; then ((braille0+=0x10)); ((summ0++)); fi
		if [ $((byte2&0x40)) -gt 0 ]; then ((braille0+=0x20)); ((summ0++)); fi
		if [ $((byte3&0x40)) -gt 0 ]; then ((braille0+=0x80)); ((summ0++)); fi
		if [ $((byte0&0x20)) -gt 0 ]; then ((braille1+=0x01)); ((summ1++)); fi
		if [ $((byte1&0x20)) -gt 0 ]; then ((braille1+=0x02)); ((summ1++)); fi
		if [ $((byte2&0x20)) -gt 0 ]; then ((braille1+=0x04)); ((summ1++)); fi
		if [ $((byte3&0x20)) -gt 0 ]; then ((braille1+=0x40)); ((summ1++)); fi
		if [ $((byte0&0x10)) -gt 0 ]; then ((braille1+=0x08)); ((summ1++)); fi
		if [ $((byte1&0x10)) -gt 0 ]; then ((braille1+=0x10)); ((summ1++)); fi
		if [ $((byte2&0x10)) -gt 0 ]; then ((braille1+=0x20)); ((summ1++)); fi
		if [ $((byte3&0x10)) -gt 0 ]; then ((braille1+=0x80)); ((summ1++)); fi
		if [ $((byte0&0x08)) -gt 0 ]; then ((braille2+=0x01)); ((summ2++)); fi
		if [ $((byte1&0x08)) -gt 0 ]; then ((braille2+=0x02)); ((summ2++)); fi
		if [ $((byte2&0x08)) -gt 0 ]; then ((braille2+=0x04)); ((summ2++)); fi
		if [ $((byte3&0x08)) -gt 0 ]; then ((braille2+=0x40)); ((summ2++)); fi
		if [ $((byte0&0x04)) -gt 0 ]; then ((braille2+=0x08)); ((summ2++)); fi
		if [ $((byte1&0x04)) -gt 0 ]; then ((braille2+=0x10)); ((summ2++)); fi
		if [ $((byte2&0x04)) -gt 0 ]; then ((braille2+=0x20)); ((summ2++)); fi
		if [ $((byte3&0x04)) -gt 0 ]; then ((braille2+=0x80)); ((summ2++)); fi
		if [ $((byte0&0x02)) -gt 0 ]; then ((braille3+=0x01)); ((summ3++)); fi
		if [ $((byte1&0x02)) -gt 0 ]; then ((braille3+=0x02)); ((summ3++)); fi
		if [ $((byte2&0x02)) -gt 0 ]; then ((braille3+=0x04)); ((summ3++)); fi
		if [ $((byte3&0x02)) -gt 0 ]; then ((braille3+=0x40)); ((summ3++)); fi
		if [ $((byte0&0x01)) -gt 0 ]; then ((braille3+=0x08)); ((summ3++)); fi
		if [ $((byte1&0x01)) -gt 0 ]; then ((braille3+=0x10)); ((summ3++)); fi
		if [ $((byte2&0x01)) -gt 0 ]; then ((braille3+=0x20)); ((summ3++)); fi
		if [ $((byte3&0x01)) -gt 0 ]; then ((braille3+=0x80)); ((summ3++)); fi
		if [ $((byte4&0x80)) -gt 0 ]; then ((braille4+=0x01)); ((summ4++)); fi
		if [ $((byte5&0x80)) -gt 0 ]; then ((braille4+=0x02)); ((summ4++)); fi
		if [ $((byte6&0x80)) -gt 0 ]; then ((braille4+=0x04)); ((summ4++)); fi
		if [ $((byte7&0x80)) -gt 0 ]; then ((braille4+=0x40)); ((summ4++)); fi
		if [ $((byte4&0x40)) -gt 0 ]; then ((braille4+=0x08)); ((summ4++)); fi
		if [ $((byte5&0x40)) -gt 0 ]; then ((braille4+=0x10)); ((summ4++)); fi
		if [ $((byte6&0x40)) -gt 0 ]; then ((braille4+=0x20)); ((summ4++)); fi
		if [ $((byte7&0x40)) -gt 0 ]; then ((braille4+=0x80)); ((summ4++)); fi
		if [ $((byte4&0x20)) -gt 0 ]; then ((braille5+=0x01)); ((summ5++)); fi
		if [ $((byte5&0x20)) -gt 0 ]; then ((braille5+=0x02)); ((summ5++)); fi
		if [ $((byte6&0x20)) -gt 0 ]; then ((braille5+=0x04)); ((summ5++)); fi
		if [ $((byte7&0x20)) -gt 0 ]; then ((braille5+=0x40)); ((summ5++)); fi
		if [ $((byte4&0x10)) -gt 0 ]; then ((braille5+=0x08)); ((summ5++)); fi
		if [ $((byte5&0x10)) -gt 0 ]; then ((braille5+=0x10)); ((summ5++)); fi
		if [ $((byte6&0x10)) -gt 0 ]; then ((braille5+=0x20)); ((summ5++)); fi
		if [ $((byte7&0x10)) -gt 0 ]; then ((braille5+=0x80)); ((summ5++)); fi
		if [ $((byte4&0x08)) -gt 0 ]; then ((braille6+=0x01)); ((summ6++)); fi
		if [ $((byte5&0x08)) -gt 0 ]; then ((braille6+=0x02)); ((summ6++)); fi
		if [ $((byte6&0x08)) -gt 0 ]; then ((braille6+=0x04)); ((summ6++)); fi
		if [ $((byte7&0x08)) -gt 0 ]; then ((braille6+=0x40)); ((summ6++)); fi
		if [ $((byte4&0x04)) -gt 0 ]; then ((braille6+=0x08)); ((summ6++)); fi
		if [ $((byte5&0x04)) -gt 0 ]; then ((braille6+=0x10)); ((summ6++)); fi
		if [ $((byte6&0x04)) -gt 0 ]; then ((braille6+=0x20)); ((summ6++)); fi
		if [ $((byte7&0x04)) -gt 0 ]; then ((braille6+=0x80)); ((summ6++)); fi
		if [ $((byte4&0x02)) -gt 0 ]; then ((braille7+=0x01)); ((summ7++)); fi
		if [ $((byte5&0x02)) -gt 0 ]; then ((braille7+=0x02)); ((summ7++)); fi
		if [ $((byte6&0x02)) -gt 0 ]; then ((braille7+=0x04)); ((summ7++)); fi
		if [ $((byte7&0x02)) -gt 0 ]; then ((braille7+=0x40)); ((summ7++)); fi
		if [ $((byte4&0x01)) -gt 0 ]; then ((braille7+=0x08)); ((summ7++)); fi
		if [ $((byte5&0x01)) -gt 0 ]; then ((braille7+=0x10)); ((summ7++)); fi
		if [ $((byte6&0x01)) -gt 0 ]; then ((braille7+=0x20)); ((summ7++)); fi
		if [ $((byte7&0x01)) -gt 0 ]; then ((braille7+=0x80)); ((summ7++)); fi
		if ([ $summ0 -gt 7 ] && $wrap)
			then attr_top=${paper}
				((braille0^=$invert_wrap))
			else attr_top=${ink}
		fi
		if [ "${attr_top}" != "${attr_top_last}" ]
		then
			attr_top_last=${attr_top}
			top=${top}${attr_top}"\U`printf %04x $((10240+braille0))`"
		else
			top=${top}"\U`printf %04x $((10240+braille0))`"
		fi
		if ([ $summ1 -gt 7 ] && $wrap)
			then attr_top=${paper}
				((braille1^=$invert_wrap))
			else attr_top=${ink}
		fi
		if [ "${attr_top}" != "${attr_top_last}" ]
		then
			attr_top_last=${attr_top}
			top=${top}${attr_top}"\U`printf %04x $((10240+braille1))`"
		else
			top=${top}"\U`printf %04x $((10240+braille1))`"
		fi
		if ([ $summ2 -gt 7 ] && $wrap)
			then attr_top=${paper}
				((braille2^=$invert_wrap))
			else attr_top=${ink}
		fi
		if [ "${attr_top}" != "${attr_top_last}" ]
		then
			attr_top_last=${attr_top}
			top=${top}${attr_top}"\U`printf %04x $((10240+braille2))`"
		else
			top=${top}"\U`printf %04x $((10240+braille2))`"
		fi
		if ([ $summ3 -gt 7 ] && $wrap)
			then attr_top=${paper}
				((braille3^=$invert_wrap))
			else attr_top=${ink}
		fi
		if [ "${attr_top}" != "${attr_top_last}" ]
		then
			attr_top_last=${attr_top}
			top=${top}${attr_top}"\U`printf %04x $((10240+braille3))`"
		else
			top=${top}"\U`printf %04x $((10240+braille3))`"
		fi
		if ([ $summ4 -gt 7 ] && $wrap)
			then attr_bottom=${paper}
				((braille4^=$invert_wrap))
			else attr_bottom=${ink}
		fi
		if [ "${attr_bottom}" != "${attr_bottom_last}" ]
		then
			attr_bottom_last=${attr_bottom}
			bottom=${bottom}${attr_bottom}"\U`printf %04x $((10240+braille4))`"
		else
			bottom=${bottom}"\U`printf %04x $((10240+braille4))`"
		fi
		if ([ $summ5 -gt 7 ] && $wrap)
			then attr_bottom=${paper}
				((braille5^=$invert_wrap))
			else attr_bottom=${ink}
		fi
		if [ "${attr_bottom}" != "${attr_bottom_last}" ]
		then
			attr_bottom_last=${attr_bottom}
			bottom=${bottom}${attr_bottom}"\U`printf %04x $((10240+braille5))`"
		else
			bottom=${bottom}"\U`printf %04x $((10240+braille5))`"
		fi
		if ([ $summ6 -gt 7 ] && $wrap)
			then attr_bottom=${paper}
				((braille6^=$invert_wrap))
			else attr_bottom=${ink}
		fi
		if [ "${attr_bottom}" != "${attr_bottom_last}" ]
		then
			attr_bottom_last=${attr_bottom}
			bottom=${bottom}${attr_bottom}"\U`printf %04x $((10240+braille6))`"
		else
			bottom=${bottom}"\U`printf %04x $((10240+braille6))`"
		fi
		if ([ $summ7 -gt 7 ] && $wrap)
			then attr_bottom=${paper}
				((braille7^=$invert_wrap))
			else attr_bottom=${ink}
		fi
		if [ "${attr_bottom}" != "${attr_bottom_last}" ]
		then
			attr_bottom_last=${attr_bottom}
			bottom=${bottom}${attr_bottom}"\U`printf %04x $((10240+braille7))`"
		else
			bottom=${bottom}"\U`printf %04x $((10240+braille7))`"
		fi
	done
	Gauges
	trap - SIGINT
	printf "$top\e[0m\n" >>"${ansies[0]}"
	printf "$bottom\e[0m\n" >>"${ansies[0]}"
	printf "\r"
	local dots=$(IFS=";"; echo "${pseudex[*]}")
	if [ $discover != true ]
	then
		if [ "$screen_block" == "true" ]
		then
			cat "${ansies[0]}" | exec sed -E $dots
		else
			cat "${ansies[0]}"
		fi
	fi
}

function tap_screen_quad {
	local cols=(0 4 1 5 2 6 3 7)
	local dump=$(xxd -s $(($2)) -l 6912 -g 1 "$1" | sed -E "s/^.{9}(.{3,48}).*$/\1/g" | sed -E "s/([0-9a-f]+)/0x\1/g" )
	local bytes=(${dump})
	local i x y xy
	local attr addr
	local bitl bitr bits0 bits1 bits2 bits3 bits4 bits5 bits6 bits7
	local top bottom
	local wrap=false
	local invert=0x00
	local invert_wrap=0xFF
	local attribute flash bright
	local ansi paper ink
	local attr_top
	local attr_bottom
	local attr_top_last=""
	local attr_bottom_last=""
	local percent
	[ "${screen_wrap}" == "true" ] && wrap=true
	printf "" >"${ansies[0]}"
	for i in {6144..6911}
	do
		trap "break" SIGINT
		xy=$((i-6144))
		percent=$((100*($xy)/767))
		Gauge $((percent)) "Screen$"
		x=$((xy&31))
		y=$((xy/32))
		if [[ $x -eq 0 ]] && [[ $y -gt 0 ]] && [[ "$top"!="" ]]
		then
			printf "$top\e[0m\n" >>"${ansies[0]}"
			top=""
		fi
		attr=$((${bytes[i]}))
		ansi="\e[0;"
		[ $((attr&128)) -gt 0 ] && ansi="\e[5;"
		[ $((attr&64)) -gt 0 ] && ansi=${ansi}"1;"
		ink=${ansi}"3${cols[$((attr&7))]};4${cols[$((attr/8%8))]}m"
		paper=${ansi}"4${cols[$((attr&7))]};3${cols[$((attr/8%8))]}m"
		addr=$(((xy&255)+((xy/256)*2048)))
		summ0=0; braille0=0;
		summ1=0; braille1=0;
		byte0=$((${bytes[$((addr))]}|${bytes[$((addr+256))]}))
		byte2=$((${bytes[$((addr+512))]}|${bytes[$((addr+768))]}))
		byte4=$((${bytes[$((addr+1024))]}|${bytes[$((addr+1280))]}))
		byte6=$((${bytes[$((addr+1536))]}|${bytes[$((addr+1792))]}))
		if [ $((byte0&0xC0)) -gt 0 ]; then ((braille0+=0x01)); ((summ0++)); fi
		if [ $((byte2&0xC0)) -gt 0 ]; then ((braille0+=0x02)); ((summ0++)); fi
		if [ $((byte4&0xC0)) -gt 0 ]; then ((braille0+=0x04)); ((summ0++)); fi
		if [ $((byte6&0xC0)) -gt 0 ]; then ((braille0+=0x40)); ((summ0++)); fi
		if [ $((byte0&0x30)) -gt 0 ]; then ((braille0+=0x08)); ((summ0++)); fi
		if [ $((byte2&0x30)) -gt 0 ]; then ((braille0+=0x10)); ((summ0++)); fi
		if [ $((byte4&0x30)) -gt 0 ]; then ((braille0+=0x20)); ((summ0++)); fi
		if [ $((byte6&0x30)) -gt 0 ]; then ((braille0+=0x80)); ((summ0++)); fi
		if [ $((byte0&0x0C)) -gt 0 ]; then ((braille1+=0x01)); ((summ1++)); fi
		if [ $((byte2&0x0C)) -gt 0 ]; then ((braille1+=0x02)); ((summ1++)); fi
		if [ $((byte4&0x0C)) -gt 0 ]; then ((braille1+=0x04)); ((summ1++)); fi
		if [ $((byte6&0x0C)) -gt 0 ]; then ((braille1+=0x40)); ((summ1++)); fi
		if [ $((byte0&0x03)) -gt 0 ]; then ((braille1+=0x08)); ((summ1++)); fi
		if [ $((byte2&0x03)) -gt 0 ]; then ((braille1+=0x10)); ((summ1++)); fi
		if [ $((byte4&0x03)) -gt 0 ]; then ((braille1+=0x20)); ((summ1++)); fi
		if [ $((byte6&0x03)) -gt 0 ]; then ((braille1+=0x80)); ((summ1++)); fi
		if ([ $summ0 -gt 7 ] && $wrap)
			then attr_top=${paper}
				((braille0^=$invert_wrap))
			else attr_top=${ink}
		fi
		if [ "${attr_top}" != "${attr_top_last}" ]
		then
			attr_top_last=${attr_top}
			top=${top}${attr_top}"\U`printf %04x $((10240+braille0))`"
		else
			top=${top}"\U`printf %04x $((10240+braille0))`"
		fi
		if ([ $summ1 -gt 7 ]  && $wrap)
			then attr_top=${paper}
				((braille1^=$invert_wrap))
			else attr_top=${ink}
		fi
		if [ "${attr_top}" != "${attr_top_last}" ]
		then
			attr_top_last=${attr_top}
			top=${top}${attr_top}"\U`printf %04x $((10240+braille1))`"
		else
			top=${top}"\U`printf %04x $((10240+braille1))`"
		fi
	done
	Gauges
	printf "$top\e[0m\n" >>"${ansies[0]}"
	trap - SIGINT
	printf "\r"
	if [ $discover != true ]
	then
		if [ "$screen_block" == "true" ]
		then
			cat "${ansies[0]}" | exec sed -E $dots
		else
			cat "${ansies[0]}"
		fi
	fi
}

function tap_screen {
	if [ "$screen_resolution" == "high" ] || [ $discover == true ]
		then tap_screen_full "$1" "$2"
	elif [ "$screen_resolution" == "low" ]
		then tap_screen_quad "$1" "$2"
	else
		if [ $(tput cols) -gt 127 ] && [ $(tput lines) -gt 47 ]
			then tap_screen_full "$1" "$2"
			else tap_screen_quad "$1" "$2"
		fi
	fi
}

function tap_block {
	# https://sudonull.com/post/69756-Tape-recorder-emulator-for-ZX-Spectrum
	# https://habrastorage.org/web/8ad/dd4/66c/8addd466c3944b3981e699f79a525b8e.PNG
	# _____________________________________________________________
	#        Pilot-tone      | Synch |       "1"        |   "0"   |
	# ~~~~~~~~~~~~____________~~~____~~~~~~~~~~__________~~~~~_____
	#     2168        2168    667 735   1710      1710    855  855
	# -------------------------------------------------------------
	# ZX-Spectrum intervals
	local zx_pause=65536	# Pause before pilot-tone
	local zx_head=2048	# Header pilot-tone duration
	local zx_data=1536	# Data pilot-tone duration
	local zx_pilot=2168	# Interval of pilot-tone
	local zx_synch=667	# Synchro-bit interval
	local zx_start=735	# Interval of data start bit
	local zx_bit_0=855	# Interval of "0"
	local zx_bit_1=1710	# Interval of "1"
	#
	local factor=$((3570000/zx_tape_hz))
	local pilot=$((zx_pilot/factor))
	local synch=$((zx_synch/factor))
	local start=$((zx_begin/factor))
	local upper=$((zx_bit_1/factor))
	local lower=$((zx_bit_0/factor))
	local bit=(\
		$(printf "~%.0s" $(seq 1 $lower); printf "z%.0s" $(seq 1 $lower))
		$(printf "~%.0s" $(seq 1 $upper); printf "z%.0s" $(seq 1 $upper))
		$(printf "~%.0s" $(seq 1 $synch); printf "z%.0s" $(seq 1 $start))
		$(printf "~%.0s" $(seq 1 $pilot); printf "z%.0s" $(seq 1 $pilot)))
	local head_pilot=$(printf "~%.0s" $(seq 0 $zx_pause);printf "${bit[3]}%.0s" $(seq 1 $zx_head))
	local data_pilot=$(printf "~%.0s" $(seq 0 $zx_pause);printf "${bit[3]}%.0s" $(seq 1 $zx_data))
	local address=0
	local raws=0
	local is_screen=false
	local is_picture=false
	local pilot_tone
	local new_line=false
	local show_screen
	if [ "$debug_mode" == "true" ]
	then
		printf "### ZX-Spectrum ###\n### %s\n" "$1" > "${1/.tap/_bas.txt}"
		if [ "$disassm_mode" == "true" ]
		then
			printf "### ZX-Spectrum ###\n### %s\n" "$1" > "${1/.tap/_asm.txt}"
		fi
	elif [ $discover == true ]
	then
		printf "### ZX-Spectrum ###\n### %s\n" "$1" > "${1/.tap/_bas.txt}"
		printf "### ZX-Spectrum ###\n### %s\n" "$1" > "${1/.tap/_asm.txt}"
	fi
	printf "\n\n\n" >&9
	while :
	do {
		trap "break" SIGINT
		trap "break" SIGQUIT
		trap "break" SIGWINCH
		show_screen=false
		local is_basic has_basic
		local listing
		percents=$((100*$address/$(stat -c%s "$1")))
		local string=$(xxd -s $address -l 18 -g 1 "$1" | cut -d " " -f 2-17 \
			| tr "\n" " " | sed -E "s/([0-9a-f]+)/16#\1/g")
		local bytes=(${string})
		local string=$(xxd -e -s $address -l 18 -g 2 "$1" | cut -d " " -f 2-9 \
			| tr "\n" " " | sed -E "s/([0-9a-f]+)/16#\1/g")
		local words=(${string})
		local header_size=$((${words[0]}))
		local header_flag=$((${bytes[2]}))
		local header_type=$((${bytes[3]}))
		local parameter_1=$((${words[7]}))
		local parameter_2=$((${words[8]}))
		[ $new_line == true ] && echo
		new_line=false
		if [ $header_size -eq 0 ]
		then
			break
		fi
		if [ $header_flag -eq 0 ]
		then
			pilot_tone="$head_pilot"
			has_basic=${is_basic}
			is_basic=false
			new_line=true
			local header_name=$(xxd -s $((address+4)) -l 16 -g 1 "$1" | cut -c 60-69)
			{
			case $header_type in
			0*)
				is_basic=true
				has_basic=true
				if [ $parameter_2 -lt 32768 ]
				then
					printf "\rProgram: %-10s line %d" "$header_name" $parameter_2
				else
					printf "\rProgram: %-10s" "$header_name"
				fi
				progress_name=`printf "Program: %s" "$header_name"`
				;;
			1*)
				printf "\rNumber array: %-10s" "$header_name"
				progress_name=`printf "Number array: %s" "$header_name"`
				;;
			2*)
				printf "\rCharacters array: %-10s" "$header_name"
				progress_name=`printf "Character array: %s" "$header_name"`
				;;
			3*)
				printf "\rBytes: %-10s [$%04x:%d]" "$header_name" $parameter_2 $parameter_1
				progress_name=`printf "Bytes: %s" "$header_name"`
				if [ $parameter_2 -eq 16384 ]
				then
					printf " Screen\$hot"
					is_screen=true
					is_picture=false
				elif [ $parameter_1 -gt 6000 ] && [ $parameter_1 -lt 8704 ]
				then
					printf " Screen$"
					is_screen=true
				fi
				;;
			*)
				printf "\rHeader#%02X: %-10s" $header_type "$header_name"
				progress_name=`printf "Nonsense: %s" "$header_name"`
				if [ "$debug_mode" == "true" ]
				then
					( xxd -s $address -l $((header_size+2)) -g 1 "$1") >&6
				fi
				;;
			esac
			printf "\e[s\e[999C\b\b\b\b%3d%%\e[u" $percents >&1
			} >&4
			raws=0
		else
			if [ "$is_basic" == "true" ]
			then
				listing="`tap_basic "$1" $((address)) $((header_size+2))`"
				if [ $discover == true ] || [ "$debug_mode" == "true" ]
				then
					printf "\nProgram: %s\n" "$header_name" >> "${1/.tap/_bas.txt}"
					echo "${listing}" >> "${1/.tap/_bas.txt}"
				fi
				echo "${listing}" >&4
				if [ $discover == true ]
				then
					(local disassm="`tap_disassm "$1" $((address)) $((header_size+2))`"
					echo "${disassm}" >> "${1/.tap/_asm.txt}"
					echo "${disassm}" >&4
					)
				elif [ "$debug_mode" == "true" ] || [ "$disassm_mode" == "true" ]
				then
					(local disassm="`tap_disassm "$1" $((address)) $((header_size+2))`"
					echo "${disassm}" >> "${1/.tap/_asm.txt}"
					echo "${disassm}" >&4
					) &
				fi
				is_basic=false
			fi
			pilot_tone="$data_pilot"
			if ([ $header_size -gt 6912 ] && [ $header_size -lt 49387 ] && [ $is_picture != true ])
			then
				if [ $is_screen != true ]
				then
					printf "\rRaw Screen: %5d bytes\n" $header_size >&4
				fi
				is_picture=true
				show_screen=true
			fi
			if [ $is_screen == true ] && [ $is_picture != true ]
			then
				is_picture=true
				show_screen=true
			fi
			is_screen=false
		fi
		if [ $raws -gt 1 ]
		then
			[ "$debug_mode" == "true" ] && printf "Raws: %5d bytes\n" $header_size >&4
			if ([ $header_size -gt 6912 ] && [ $header_size -lt 49387 ] && [ $is_picture != true ])
			then
				is_picture=true
				show_screen=true
			elif [ "$disassm_mode" == "true" ] && [ $header_flag -gt 0 ]
			then 
				echo tap_disassm "$1" $((address+3)) 16 >&4
			fi
		fi
		if [ "$show_screen" == "true" ]
		then
			{
				if [ $discover == true ]
				then
					tap_screen "$1" $((address+3))
				else
					tap_screen "$1" $((address+3)) &
				fi
			} >&5
		fi
		if [ "$debug_mode" == "true" ] && [ "$has_basic" != "true" ]
		then
			if [ $header_size -lt 128 ]
			then
				{ echo; xxd -s $address -l $((header_size+2)) -g 1 "$1"; } >&4
			else
				{ echo; xxd -s $address -l 64 -g 1 "$1"; } >&4
			fi
			if [ "$disassm_mode" == "true" ] && [ $header_flag -gt 0 ]
			then 
				tap_disassm "$1" $((address+3)) 16 >&4
			fi
		fi
		Gauges
		local bits=$(xxd -s $address -l $((header_size+2)) -b "$1" \
			| cut -d " " -f 2-7 | tr "\n" " " | sed -E "s/ //g")
		if [ "$debug_mode" != "true" ] || [ "$dialog_mode" == "true" ]
		then
			if [ $discover != true ]
			then
				(printf "%s%s%s" $pilot_tone ${bit[2]}\
					$(echo $bits | sed -e "s/0/${bit[0]}/g" -e "s/1/${bit[1]}/g"))\
					| `printf "$(echo "$player_zx")" $zx_tape_hz` 2>/dev/null
			fi
		fi
		if [ $header_flag -eq 0 ] || [ $raws -gt 1 ]
		then
			echo >/dev/null
		fi
		raws+=1
		((address+=header_size+2))
		if [ "$screen_only" == "true" ] && [ $is_picture == true ]
		then
			sleep 15
			break
		fi
	} >&6
	done
	progress_name="$1"
	Gauge 100 "Ready"
	echo
	echo 0>&9
	trap - SIGINT
	trap - SIGQUIT
	trap - SIGWINCH
}

function Options {
	local	content words bytes dump length offset
	local	Items=()
	if [[ "${1,,}" =~ \.txt$ ]]
	then
		return 1
	elif [[ "${1,,}" =~ \.tap$ ]]
	then
		Prepares
		discover=true
		return 0
	elif [[ "${1,,}" =~ \.gam$|\.rk$|\.rkr$ ]]
	then
		offset=0
		[[ "${1,,}" =~ \.gam$ ]] && offset=1
		content=$(xxd -s $offset -l 4 -g 2 "$1" | cut -d " " -f 2-17 | tr "\n" " " | sed -E "s/([0-9a-f]+):?/16#\1/g")
		words=(${content})
		length=$((${words[1]}-${words[0]}+1))
		Items+=("`printf "Start  %04X" $((${words[0]}))`")
		Items+=("`printf "Finish %04X" $((${words[1]}))`")
		Items+=("`printf "Length %04X / %d bytes" $length $length`")
		offset=7
		[[ "${1,,}" =~ \.gam$ ]] && offset=8
		content=$(xxd -s $((length+$offset)) -l 2 -g 2 "$1" | cut -d " " -f 2-17 | tr "\n" " " | sed -E "s/([0-9a-f]+):?/16#\1/g")
		words=(${content})
		Items+=("`printf "CRC    %04X" $((${words[0]}))`")
		(IFS="_"; echo `echo "${Items[*]}" | sed 's/_/\n/g'` >&6 >&1)
		read
	fi
	return 1
}

### Configurate from mmand line / "./.conf"
function configure {
	local options=()
	local values=()
	local intervals=()

	while [ $# -gt 0 ]
	do
		if [ ${1:0:2} == "--" ]
		then
			options+=("${1%=*}")
			values+=("${1#*=}")
		elif [ ${1:0:1} == "-" ] && [ -n ${1//-[[:digit:]]/} ] # [ "${1//-[[:digit:]]/}" != "" ]
		then
			for key in $(echo ${1:1} | sed -E "s/([+-]?[0-9]+|.)/\1\n/g" )
			do
				if [ -z ${key//[[:digit:]]/} ]
				then
					options+=($key)
				else
					options+=("-$key")
				fi
			done
		else
			files+=("$1")
		fi
		shift 1
	done

	while [ ${#options[@]} -gt 0 ]
	do
		dummy=false
		[ "${options[0]:0:2}" != "--" ] && dummy=true
		if [ $dummy != true ]
		then
			value=${values[0]}
			values=("${values[@]:1}")
		else
			value=${files[0]}
		fi
		###
		case "${options[0]}" in
		-h|--help)
			Usage
			exit
			;;
		-a|--ansi)
			ansi=${ansies[-1]}
			length=$((${#ansies[*]}-1))
			ansies=(${ansies[@]:0:$length} ${value} ${ansi})
			;;
		--debug-mode)
			debug_mode=true
			;;
		--ansi-resolution)
			screen_resolution=${value,,}
			;;
		--ansi-wrap)
			screen_wrap=true
			;;
		-s|--screen-only)
			screen_only=true
			;;
		--settings)
			settings_mode=true
			;;
		--player)
			case "${value,,}" in
			alsa)
				player_rk="$player_rk_alsa"	# Player for *.rk files
				player_zx="$player_zx_alsa"	# Player for *.tap files
			;;
			pulse)
				if dpkg -l pulseaudio >/dev/null 2>/dev/null
				then
					player_rk="$player_rk_pulse"	# Player for *.rk files
					player_zx="$player_zx_pulse"	# Player for *.tap files
				else
					echo "PulseAudio not installed" >&2
					exit 1
				fi
			;;
			vlc)
				if dpkg -l vlc >/dev/null 2>/dev/null
				then
					player_rk=`echo """$player_rk_vlc""" | sed "s/-A //;s/<>/  /" `	# Player for *.rk files
					player_zx=`echo """$player_zx_vlc""" | sed "s/-A //;s/<>/  /" `	# Player for *.tap files
				else
					echo "VLC not installed" >&2
					exit 1
				fi
			;;
			vlc-*)
				if dpkg -l vlc >/dev/null 2>/dev/null
				then
					if [ ${value,,} == "vlc-pulse" ]
					then
						if ! dpkg -l pulseaudio >/dev/null 2>/dev/null
						then
							echo "PulseAudio not installed" >&2
							exit 1
						fi
					fi
					player_rk=`echo """$player_rk_vlc""" | sed "s/-A/-A ${value#*-}/;s/<>/  /" `	# Player for *.rk files
					player_zx=`echo """$player_zx_vlc""" | sed "s/-A/-A ${value#*-}/;s/<>/  /" `	# Player for *.tap files
				else
					echo "VLC not installed" >&2
					exit 1
				fi
			esac
			;;
		-v|--version)
			echo "v1.00 2022.05.09 by Alikberov" >&1 >&2
			exit 100
			;;
		-z|--z80-disassm)
			disassm_mode=true
			dummy=false
			;;
		-*)
			dummy=false
			;;
		esac
		[ "${dummy}" == "true" ] && files=("${files[@]:1}")
		options=("${options[@]:1}")
	done
}

### Try for default custom configuration from "./.conf"
[ -f "./.conf" ] && configure $( cat "./.conf" | sed -E 's/\s*[#;].*$//g;s/^([^#-])/--\1/g' )

configure $@

[ $settings_mode == true ] && Settings
[ ${#files[*]} -eq 0 ] && dialog_mode=true

last_item=1

while :
do
	discover=false
	if [ ${dialog_mode} == true ]
	then
		let i=0 # define counting variable
		W=() # define working array
		while read -r line; do # process file by file
			let i=$i+1
			W+=($i "$line")
		done < <( ls -1 *.{gam,rk,rkr,tap,txt} 2>/dev/null )
		help_file=$(mktemp)
		trap "rm ${help_file}" SIGINT
		help_rows=$(cat "$0" | grep -n -E "^:(HELP|PLEH):$" | cut -d: -f1 | sed -E "s/\n/ /g")
		help_range=(${help_rows})
		tail -n +$((1+${help_range[0]})) "$0" |\
			head -c -22 -n $((${help_range[1]}-${help_range[0]}-1)) |\
			sed -z "$ s/\n$//" > $help_file
		FILE=$(dialog \
			--hfile $help_file \
			--backtitle "Tape player" \
			--extra-button \
			--extra-label "Options" \
			--title "List of ZX-Spectrum / Paguo-86PK tapes" \
			--default-item "$last_item" \
			--menu "[F1] for HELP" 50 48 50 "${W[@]}" 3>&2 2>&1 1>&3) # show dialog and store output
		flag="$?"
		rm ${help_file}
		trap - SIGINT
		
		if [ "$FILE" != "" ]
		then
			F=$(readlink -f "$(ls -1 *.{gam,rk,rkr,tap,txt} 2>/dev/null | sed -n "`echo "$FILE p" | sed 's/ //'`")")
		fi
		case $flag in
		1)	exit
			;;
		3)	if [ $FILE -eq $last_item ]
			then
				Settings
				continue
			else
				Prepares
				Options "$F"
				[[ $? -eq 1 ]] && continue
			fi
			;;
		esac
		clear
		last_item=$FILE
		if [ "$FILE" != "" ]
		then
			if [[ "${F,,}" =~ \.txt$ ]]
			then
				cat "$F"
				read
				continue
			fi
		else
			break
		fi
	fi

	while true
	do
		if [ ${#files[*]} -gt 0 ]
		then
			F="${files[0]}"
			files=("${files[@]:1}")
		fi
		if [[ "${F,,}" =~ \.tap$ ]]
		then
			Prepares
			([ $discover == true ] || [ $screen_only == true ]) && ansies=("${F/.tap/_scr.txt}" "${ansies[@]}")
			tap_block "$F"
			if [ ${#ansies[*]} -gt 1 ]
			then
				ansies=("${ansies[@]:1}")
			fi
		else
			echo $F
			sleep 2
			the_E6="\xE6"
			[[ "${F,,}" =~ \.gam$ ]] && the_E6=""
			( printf "%256s" | sed -e 's/ /\x00/g'; printf "${the_E6}"; cat "$F" ) | xxd -b | cut -d" " -f 2-7 | tr "\n" " " | sed 's/ //g' | sed -e 's/0/zzzzzzzz~~~~~~~~/g' -e 's/1/~~~~~~~~zzzzzzzz/g' | `printf "$(echo ${player_rk})"` 2>/dev/null
		fi
		[ ${#files[*]} -eq 0 ] && break
	done
	[ ${#files[*]} -eq 0 ] && [ ${dialog_mode} == false ] && break
	sleep 1
done
exit

"""
:HELP:
========================
*** Tape 86 ZX v 1.0 ***
========================

1. Waveforming TAP-files
2. Brailizer for Screen$
3. Basic listings viewer
4. Disassembly Z80-codes
________________________
= (C)2022 by Alikberov =
~~~~~~~~~~~~~~~~~~~~~~~~
:PLEH:
"""
