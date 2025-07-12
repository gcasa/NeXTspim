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

#include <cthreads.h>

#define LOOP_STOP	0
#define LOOP_RUN	1
#define LOOP_STEP	2
#define LOOP_QUIT	128

extern struct mutex *RunMutex, *RegisterMutex, *DisplayMutex;
extern struct condition *RunCondition;
extern int RunFlag;
extern mem_addr RunPC;
extern int RunSteps, RunDisplay, RunContBkpt;
extern BOOL DisplayNeedsUpdate, ChangeStartStopButton, ChangeHighlight, OpenContinueWindow;

void InitLoop(void);
void RunLoop(any_t arg);
void StartRunLoop(void);
void StopRunLoop(void);
void StepRunLoop(void);
void BreakpointStopLoop(void);
#undef PC
