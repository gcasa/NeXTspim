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

/* SPIMInterface.h -- Main I/O handler */

#include <stdio.h>
#include <setjmp.h>
#include <stdarg.h>

#include "spim.h"
#include "spim-utils.h"
#include "inst.h"
#include "mem.h"
#include "reg.h"
#include "read-aout.h"

#ifdef CL_SPIM
#include "cl-cache.h"
#include "cl-except.h"
#include "cl-tlb.h"
#include "cl-cycle.h"
#endif

#import <objc/Object.h>
#import <appkit/TextField.h>
#import <appkit/Text.h>
#import <appkit/ScrollView.h>
#import <appkit/Scroller.h>
#import "TextView.h"

#define BYTES_PER_LINE 16

#define IO_BUFFSIZE 	10000

/* Exported functions: */

void execute_program (mem_addr pc, int steps, int display, int cont_bkpt);
void read_file (char *name, int assembly_file);
void start_program(mem_addr addr);

/* Exported variables: */

extern int load_trap_handler;
extern id idMainInterface, idPrefsPanel;

@interface SPIMInterface:Object
{
    id	Registers;
	id  MainRegisters;
    id	Messages;
    id	TextSegments;
    id	DataSegments;
	id	idOpenPanel;
	id  MainWindow;
	id  idStartStopCell;
	id  MessageWindow;
	id	ICacheStats;
	id	ICacheData;
	id	DCacheStats;
	id	DCacheData;
	id	Pipeline;
	id  Prefs;
	id  Breakpoints;
	int KernelStartLine;
	id  registersMain[7], registersGeneral[32], registersFloat[32];
}

- init;
- appDidInit:sender;

- loadFile;
- run:(BOOL)step:(BOOL)cont_bkpt;
- clear:(BOOL)step;

- StartStopCell;
- idKeyQ;

- center_text_at_PC;
- displayDataSeg;
- displayRegisters;
- redisplayData;
- redisplayText;
- showRunning:(BOOL)r;

- setEnabled:(BOOL)enable;

- writeOutput:(char *)string;

- MenuItem:sender;
- registerChanged:sender;

#ifdef CL_SPIM
- displayCache:(int)type;
- displayPipeline;
#endif

@end
