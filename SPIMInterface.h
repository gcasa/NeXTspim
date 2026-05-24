/* Main Cocoa/GNUstep interface for NeXTspim. */

#ifndef NEXTSPIM_SPIMINTERFACE_H
#define NEXTSPIM_SPIMINTERFACE_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

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

#define BYTES_PER_LINE 16
#define IO_BUFFSIZE 	10000

void execute_program(mem_addr pc, int steps, int display, int cont_bkpt);
void read_file(char *name, int assembly_file);
void start_program(mem_addr addr);
void write_output(char *fmt, ...);

extern int load_trap_handler;
extern id idMainInterface, idPrefsPanel;

@class KeyQueue;

@interface SPIMInterface : NSObject <NSApplicationDelegate>
{
	id Registers;
	id MainRegisters;
	id Messages;
	id TextSegments;
	id DataSegments;
	id idOpenPanel;
	id MainWindow;
	id idStartStopCell;
	id MessageWindow;
	id ICacheStats;
	id ICacheData;
	id DCacheStats;
	id DCacheData;
	id Pipeline;
	id Prefs;
	id Breakpoints;
	int KernelStartLine;
	id registersMain[7], registersGeneral[32], registersFloat[32];
	NSTimer *updateTimer;
}

- init;
- appDidInit:sender;

- buildMainMenu;
- openPreferences:sender;
- showAbout:sender;
- loadFile;
- run:(BOOL)step :(BOOL)cont_bkpt;
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

- (void)startDisplayTimer;
- (void)stopDisplayTimer;

@end

#endif
