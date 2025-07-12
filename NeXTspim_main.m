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

#import <stdlib.h>
#import <stdio.h>
#import <string.h>
#import <appkit/Application.h>
#import "SPIMInterface.h"
#import "RunLoop.h"
#import "cl-cycle.h"
#import "PrefsPanel.h"

extern void InitUpdateDisplayLoop(void);
extern void KillUpdateDisplayLoop(void);

char *default_trap_path;

/* If we start NeXTspim from the workspace, its working directory will
   be the user's home.  We use the full filename and path in argv[0] to
   figure out where the trap handler will be, assuming it's in the same
   directory as the NeXTspim executable. */
 
static void DetermineHandlerPath(char *path) {
	int x = 0, last = 0;
	while (path[x] != 0) {
		if (path[x] == '/') last = x;
		x++;
	}
	if (last != 0) path[last++] = '/';
	path[last] = 0;
	default_trap_path = path;
}

void main(int argc, char *argv[]) {
    NXApp = [Application new];
    [NXApp loadNibSection:"NeXTspim.nib" owner:NXApp];
    /* initialization from xspim main procedure 
	   and a few other necessary things */
	[idPrefsPanel loadPrefs];
	InitLoop();
	DetermineHandlerPath(argv[0]);
	initialize_world(load_trap_handler);
	write_startup_message();
	#ifdef CL_SPIM
	cl_initialize_world(0);
	if (tlb_on) tlb_init();
	if (icache_on) cache_init(mem_system, INST_CACHE);
	if (dcache_on) cache_init(mem_system, DATA_CACHE);
	#endif
	InitUpdateDisplayLoop();
	[NXApp run];
	KillUpdateDisplayLoop();
    [NXApp free];
    exit(0);
}
