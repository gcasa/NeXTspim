/* Portable background execution loop. */

#include <stdio.h>
#include <setjmp.h>
#include <stdlib.h>
#include <sched.h>

#import <Foundation/Foundation.h>
#import "SPIMInterface.h"
#import "RunLoop.h"

extern jmp_buf spim_top_level_env; /* For ^C */
extern int spim_is_running;

SPIMMutex *RunMutex, *RegisterMutex, *DisplayMutex;
SPIMCondition *RunCondition;

int RunFlag = 0;
mem_addr RunPC;
int RunSteps, RunDisplay, RunContBkpt;
BOOL DisplayNeedsUpdate = YES;
BOOL ChangeStartStopButton = NO, ChangeHighlight = YES;
BOOL OpenContinueWindow = NO;

SPIMMutex *SPIMMutexCreate(void)
{
	SPIMMutex *m = (SPIMMutex *)malloc(sizeof(SPIMMutex));
	pthread_mutex_init(&m->mutex, NULL);
	return m;
}

void SPIMMutexLock(SPIMMutex *mutex)
{
	pthread_mutex_lock(&mutex->mutex);
}

void SPIMMutexUnlock(SPIMMutex *mutex)
{
	pthread_mutex_unlock(&mutex->mutex);
}

SPIMCondition *SPIMConditionCreate(void)
{
	SPIMCondition *c = (SPIMCondition *)malloc(sizeof(SPIMCondition));
	pthread_cond_init(&c->condition, NULL);
	return c;
}

void SPIMConditionWait(SPIMCondition *condition, SPIMMutex *mutex)
{
	pthread_cond_wait(&condition->condition, &mutex->mutex);
}

void SPIMConditionSignal(SPIMCondition *condition)
{
	pthread_cond_signal(&condition->condition);
}

void SPIMYield(void)
{
	sched_yield();
}

#if !defined(GNUSTEP)
static void *RunLoopThread(void *arg)
{
	RunLoop(arg);
	return NULL;
}
#endif

#if defined(GNUSTEP)
@interface RunLoopThreadStarter : NSObject
+ (void)runLoopThread:(id)arg;
@end

@implementation RunLoopThreadStarter
+ (void)runLoopThread:(id)arg
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	RunLoop(arg);
	[pool drain];
}
@end
#endif

void InitLoop(void)
{
#if !defined(GNUSTEP)
	pthread_t thread;
#endif
	RunFlag = LOOP_STOP;
	RunMutex = SPIMMutexCreate();
	RegisterMutex = SPIMMutexCreate();
	DisplayMutex = SPIMMutexCreate();
	RunCondition = SPIMConditionCreate();
#if defined(GNUSTEP)
	[NSThread detachNewThreadSelector:@selector(runLoopThread:)
	                         toTarget:[RunLoopThreadStarter class]
	                       withObject:nil];
#else
	if (pthread_create(&thread, NULL, RunLoopThread, NULL) != 0) {
		fprintf(stderr, "NeXTspim: failed to create simulator thread\n");
		return;
	}
	pthread_detach(thread);
#endif
}

void RunLoop(void *arg)
{
	(void)arg;
	do {
		mutex_lock(RunMutex);
		if (RunFlag == LOOP_STEP) RunFlag = LOOP_STOP;
		spim_is_running = 0;
		while (RunFlag == LOOP_STOP)
			condition_wait(RunCondition, RunMutex);
		mutex_lock(DisplayMutex);
		ChangeStartStopButton = YES;
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
			DisplayNeedsUpdate = YES;
			mutex_unlock(DisplayMutex);
			if (PC == 0) {
				StopRunLoop();
				write_output("\nEnd of program execution.\n");
			}

			RunPC = PC;
		} while (RunFlag == LOOP_RUN);
		mutex_unlock(RegisterMutex);
		mutex_lock(DisplayMutex);
		DisplayNeedsUpdate = YES;
		mutex_unlock(DisplayMutex);
	} while (RunFlag != LOOP_QUIT);
}

void StartRunLoop(void)
{
	mutex_lock(RunMutex);
	RunFlag = LOOP_RUN;
	mutex_unlock(RunMutex);
	mutex_lock(DisplayMutex);
	DisplayNeedsUpdate = YES;
	ChangeStartStopButton = YES;
	mutex_unlock(DisplayMutex);
	condition_signal(RunCondition);
}

void StopRunLoop(void)
{
	mutex_lock(RunMutex);
	RunFlag = LOOP_STOP;
	mutex_unlock(RunMutex);
	mutex_lock(DisplayMutex);
	spim_is_running = 0;
	DisplayNeedsUpdate = YES;
	ChangeStartStopButton = YES;
	ChangeHighlight = YES;
	mutex_unlock(DisplayMutex);
}

void StepRunLoop(void)
{
	mutex_lock(RunMutex);
	RunFlag = LOOP_STEP;
	mutex_unlock(RunMutex);
	condition_signal(RunCondition);
}

void BreakpointStopLoop(void)
{
	mutex_lock(DisplayMutex);
	OpenContinueWindow = YES;
	mutex_unlock(DisplayMutex);
	StopRunLoop();
}
