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

#import "ContinuePanel.h"
#import <appkit/TextField.h>
#import <appkit/Panel.h>
#import "RunLoop.h"
#import "BreakpointsPanel.h"

id idContinuePanel;

@implementation ContinuePanel

- init {
	[super init];
	idContinuePanel = self;
	return self;
}

- initContent:(const NXRect *)contentRect style:(int)aStyle backing:(int)bufferingType buttonMask:(int)mask defer:(BOOL)flag {
	[super initContent:contentRect style:aStyle backing:bufferingType buttonMask:mask defer:flag];
	idContinuePanel = self;
	return self;
}

- open:(mem_addr)addr {
	char buffer[20];
	sprintf(buffer, "%08x", addr);
	bkptAddr = addr;
	[self orderFront:self];
	[bkAddressText setStringValue:buffer];
	return self;
}

- button:sender
{
    switch ([sender selectedTag]) {
		case 101:
			[idMainInterface run:NO:YES];
			break;
		case 102:
			[idMainInterface run:YES:YES];
			break;
		case 103:
#ifdef CL_SPIM
			breakpoint_reinsert = 0;
#else
			delete_breakpoint(bkptAddr);
#endif
			[Breakpoints showBkpts];
			break;
	}
	[self close];
	return self;
}

@end
