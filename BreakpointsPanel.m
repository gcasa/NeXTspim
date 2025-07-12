/* NeXTspim 1.0
   Copyright (C) 1994 by Mark Gritter (mgritter@gac.edu).
   
   SPIM S20 MIPS simulator.
   Copyright (C) 1990-1992 by James Larus (larus@cs.wisc.edu).
   ALL RIGHTS RESERVED.

   SPIM is distributed under the following conditions:

     You may make copies of SPIM for your own use and modify those copies.

     All copies of SPIM must retain my name and copyright notice.

     You may not sell SPIM or distributed SPIM in conjunction with a
     commerical product or service without the expressed written consent of
     James Larus.

   THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
   IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
   WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
   PURPOSE. */

/* Panel to set/clear breakpoints. */

#import "BreakpointsPanel.h"
#include "spim-utils.h"
#include "data.h"
#include "run.h"
#include "sym-tbl.h"
#import <ctype.h>
#import <appkit/Button.h>

typedef struct bkptrec
{
  mem_addr addr;
  instruction *inst;
  struct bkptrec *next;
} bkpt;


extern bkpt *bkpts;

@implementation BreakpointsPanel

- setup {
	[[bkptList idText] setEditable:NO];
	[self showBkpts];
	return self;
}

- showBkpts {
	bkpt *b;
	char buffer[12];
	[bkptList setText:""];
	if (bkpts)
    	for (b = bkpts;  b != NULL; b = b->next) {
			sprintf(buffer, "0x%08x\n", b->addr);
			[bkptList addText:buffer];
		}
	else
		[bkptList setText:"No breakpoints set.\n"];
	return self;
}

- button:sender {
    switch ([sender selectedTag]) {
		case 101:
			[self removeAllBreak];
			break;
		case 102:
			[self addBreakpoint];
			break;
		case 103:
			[self removeBreakpoint];
			break;
		case 201:
			/* cont_brk = [sender state]; */
		 	break;		 	
	}
	return self;
}

- addBreakpoint {
	mem_addr addr;
	const char *breakpoint_addr;
	breakpoint_addr = [addressText stringValue];
	while (*breakpoint_addr == ' ') breakpoint_addr++;
	if (isdigit (*breakpoint_addr)) addr = strtoul(breakpoint_addr, NULL, 16);
	else addr = find_symbol_address((char *)breakpoint_addr);
	add_breakpoint(addr);
	[self showBkpts];
	return self;
}

- removeBreakpoint {
	mem_addr addr;
	const char *breakpoint_addr;
	breakpoint_addr = [addressText stringValue];
	while (*breakpoint_addr == ' ') breakpoint_addr++;
	if (isdigit (*breakpoint_addr)) addr = strtoul(breakpoint_addr, NULL, 16);
	else addr = find_symbol_address((char *)breakpoint_addr);
	delete_breakpoint(addr);
	text_modified = 1;
	[self showBkpts];
	return self;
}

- removeAllBreak {
	while (bkpts != NULL) delete_breakpoint(bkpts->addr);	
	text_modified = 1;
	[self showBkpts];
	return self;
}


@end
