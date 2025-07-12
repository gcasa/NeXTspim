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

#include <stdio.h>
#include <setjmp.h>
#include <stdarg.h>

#import "SPIMInterface.h"
#import "RunLoop.h"
#import "BreakpointsPanel.h"

extern id idMainInteface;
extern jmp_buf spim_top_level_env; /* For ^C */
extern int spim_is_running;
struct mutex *RunMutex, *RegisterMutex, *DisplayMutex;
struct condition *RunCondition;

int RunFlag = 0;
mem_addr RunPC;
int RunSteps, RunDisplay, RunContBkpt;
BOOL DisplayNeedsUpdate = TRUE;
BOOL ChangeStartStopButton = FALSE, ChangeHighlight = TRUE;
BOOL OpenContinueWindow = FALSE;

void InitLoop(void) {
	RunFlag = LOOP_STOP;
	RunMutex = mutex_alloc();
	RegisterMutex = mutex_alloc();
	DisplayMutex = mutex_alloc();
	RunCondition = condition_alloc();
	cthread_detach(cthread_fork((cthread_fn_t)RunLoop, (any_t)0));
}

void RunLoop(any_t arg) {
	do {
		mutex_lock(RunMutex);
		if (RunFlag == LOOP_STEP) RunFlag = LOOP_STOP;
		spim_is_running = 0;
		while (RunFlag == LOOP_STOP)
			condition_wait(RunCondition, RunMutex);
		mutex_lock(DisplayMutex);
		ChangeStartStopButton = TRUE;
		spim_is_running = 1;
		mutex_unlock(DisplayMutex);
		mutex_unlock(RunMutex);
		mutex_lock(RegisterMutex);
		do {
			if (!setjmp(spim_top_level_env)) {
#ifdef CL_SPIM
				if (cycle_level) cl_run_program(RunPC, RunSteps, 0);
				else
#endif
				if (run_program(RunPC, RunSteps, RunDisplay, RunContBkpt)) {
					BreakpointStopLoop();
				}
			} else StopRunLoop();
			mutex_lock(DisplayMutex);
			DisplayNeedsUpdate = TRUE;
			mutex_unlock(DisplayMutex);
			if (PC == 0) {
				StopRunLoop();
				write_output("\nEnd of program execution.\n");
			}
			
			RunPC = PC;
		} while (RunFlag == LOOP_RUN);
		mutex_unlock(RegisterMutex);
		mutex_lock(DisplayMutex);
		DisplayNeedsUpdate = TRUE;
		mutex_unlock(DisplayMutex);
	} while (RunFlag != LOOP_QUIT);
}

void StartRunLoop(void) {
	mutex_lock(RunMutex);
	RunFlag = LOOP_RUN;
	mutex_unlock(RunMutex);
	mutex_lock(DisplayMutex);
	DisplayNeedsUpdate = TRUE;
	ChangeStartStopButton = TRUE;
	mutex_unlock(DisplayMutex);
	condition_signal(RunCondition);
}

void StopRunLoop(void) {
	mutex_lock(RunMutex);
	RunFlag = LOOP_STOP;
	mutex_unlock(RunMutex);
	mutex_lock(DisplayMutex);
	spim_is_running = 0;
	DisplayNeedsUpdate = TRUE;
	ChangeStartStopButton = TRUE;
	ChangeHighlight = TRUE;
	mutex_unlock(DisplayMutex);
}

void StepRunLoop(void) {
	mutex_lock(RunMutex);
	RunFlag = LOOP_STEP;
	mutex_unlock(RunMutex);
	condition_signal(RunCondition);
}

void BreakpointStopLoop(void) {
	mutex_lock(DisplayMutex);
	OpenContinueWindow = TRUE;
	mutex_unlock(DisplayMutex);
	StopRunLoop();
}

	