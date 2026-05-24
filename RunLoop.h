/* Portable run loop support for Cocoa/GNUstep builds. */

#ifndef NEXTSPIM_RUNLOOP_H
#define NEXTSPIM_RUNLOOP_H

#include <pthread.h>
#include "spim.h"

#ifdef __OBJC__
#import <objc/objc.h>
#else
typedef signed char BOOL;

#ifndef YES
#define YES ((BOOL)1)
#define NO  ((BOOL)0)
#endif
#endif

#define LOOP_STOP	0
#define LOOP_RUN	1
#define LOOP_STEP	2
#define LOOP_QUIT	128

typedef struct SPIMMutex {
	pthread_mutex_t mutex;
} SPIMMutex;

typedef struct SPIMCondition {
	pthread_cond_t condition;
} SPIMCondition;

extern SPIMMutex *RunMutex, *RegisterMutex, *DisplayMutex;
extern SPIMCondition *RunCondition;
extern int RunFlag;
extern mem_addr RunPC;
extern int RunSteps, RunDisplay, RunContBkpt;
extern BOOL DisplayNeedsUpdate, ChangeStartStopButton, ChangeHighlight, OpenContinueWindow;

SPIMMutex *SPIMMutexCreate(void);
void SPIMMutexLock(SPIMMutex *mutex);
void SPIMMutexUnlock(SPIMMutex *mutex);
SPIMCondition *SPIMConditionCreate(void);
void SPIMConditionWait(SPIMCondition *condition, SPIMMutex *mutex);
void SPIMConditionSignal(SPIMCondition *condition);
void SPIMYield(void);

#define mutex_lock(m) SPIMMutexLock(m)
#define mutex_unlock(m) SPIMMutexUnlock(m)
#define condition_wait(c, m) SPIMConditionWait((c), (m))
#define condition_signal(c) SPIMConditionSignal(c)

void InitLoop(void);
void RunLoop(void *arg);
void StartRunLoop(void);
void StopRunLoop(void);
void StepRunLoop(void);
void BreakpointStopLoop(void);

#undef PC

#endif
