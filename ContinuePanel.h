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

/* Panel to continue when a breakpoint is hit. */

#import <appkit/Panel.h>
#import "SPIMInterface.h"

extern id idContinuePanel;

@interface ContinuePanel:Panel
{
    mem_addr bkptAddr;
	id	bkAddressText;
	id  Breakpoints;
}

- init;
- initContent:(const NXRect *)contentRect style:(int)aStyle backing:(int)bufferingType buttonMask:(int)mask defer:(BOOL)flag;
- open:(mem_addr)addr;
- button:sender;

@end
