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
static char default_trap_path_storage[4096];

static void DetermineHandlerPath(char *path)
{
	NSString *trap = [[NSBundle mainBundle] pathForResource:@"trap" ofType:@"handler"];
	NSString *resourceDir = [trap stringByDeletingLastPathComponent];
	const char *resourcePath = [resourceDir fileSystemRepresentation];
	int x = 0, last = 0;

	if (resourcePath != NULL) {
		strncpy(default_trap_path_storage, resourcePath, sizeof(default_trap_path_storage) - 2);
		default_trap_path_storage[sizeof(default_trap_path_storage) - 2] = 0;
		if (default_trap_path_storage[strlen(default_trap_path_storage) - 1] != '/')
			strcat(default_trap_path_storage, "/");
		default_trap_path = default_trap_path_storage;
		return;
	}

	while (path[x] != 0) {
		if (path[x] == '/') last = x;
		x++;
	}
	if (last != 0) {
		strncpy(default_trap_path_storage, path, last + 1);
		default_trap_path_storage[last + 1] = 0;
	} else {
		default_trap_path_storage[0] = 0;
	}
	default_trap_path = default_trap_path_storage;
}

int main(int argc, char *argv[])
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSApplication *app = [NSApplication sharedApplication];
	NSString *iconPath = [[NSBundle mainBundle] pathForResource:@"spim" ofType:@"tiff"];
	NSImage *icon = nil;
	SPIMInterface *interface = [[SPIMInterface alloc] init];
	[app setDelegate:interface];
	if (iconPath != nil) {
		icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
		if (icon != nil) {
			[app setApplicationIconImage:icon];
			[icon release];
		}
	}
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
