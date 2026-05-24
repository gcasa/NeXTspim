#import <AppKit/AppKit.h>
#import "SPIMInterface.h"

extern id idContinuePanel;

@interface ContinuePanel : NSPanel
{
	mem_addr bkptAddr;
	NSTextField *bkAddressText;
	id Breakpoints;
}

- init;
- open:(mem_addr)addr;
- button:sender;
- setBreakpointsPanel:(id)panel;

@end
