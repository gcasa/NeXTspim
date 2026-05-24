#import <AppKit/AppKit.h>
#import "SPIMInterface.h"

@class TextView;

@interface BreakpointsPanel : NSPanel
{
	mem_addr *addrlist;
	TextView *bkptList;
	NSTextField *addressText;
}

- setup;
- showBkpts;
- button:sender;
- addBreakpoint;
- removeBreakpoint;
- removeAllBreak;

@end
