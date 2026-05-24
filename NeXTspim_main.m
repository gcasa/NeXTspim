/* Programmatic Cocoa/GNUstep entry point. */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <stdlib.h>
#import <string.h>

#import "SPIMInterface.h"
#import "RunLoop.h"
#import "PrefsPanel.h"
#ifdef CL_SPIM
#import "cl-cycle.h"
#endif

extern void InitUpdateDisplayLoop(void);
extern void KillUpdateDisplayLoop(void);

char *default_trap_path;

static void DetermineHandlerPath(char *path)
{
	int x = 0, last = 0;
	while (path[x] != 0) {
		if (path[x] == '/') last = x;
		x++;
	}
	if (last != 0) path[last++] = '/';
	path[last] = 0;
	default_trap_path = path;
}

int main(int argc, char *argv[])
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSApplication *app = [NSApplication sharedApplication];
	SPIMInterface *interface = [[SPIMInterface alloc] init];
	[app setDelegate:interface];
#if !defined(GNUSTEP)
	[app setActivationPolicy:NSApplicationActivationPolicyRegular];
#endif
	[interface appDidInit:nil];

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
#if !defined(GNUSTEP)
	[app activateIgnoringOtherApps:YES];
#endif
	[app run];
	KillUpdateDisplayLoop();
	[interface release];
	[pool drain];
	return 0;
}
