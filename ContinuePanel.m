#import "ContinuePanel.h"
#import "RunLoop.h"
#import "BreakpointsPanel.h"

id idContinuePanel;

@implementation ContinuePanel

- init
{
	self = [super initWithContentRect:NSMakeRect(260, 260, 300, 120)
	                        styleMask:(NSTitledWindowMask | NSClosableWindowMask)
	                          backing:NSBackingStoreBuffered
	                            defer:NO];
	if (self) {
		NSView *content = [self contentView];
		[self setTitle:@"Breakpoint"];
		NSTextField *label = [[[NSTextField alloc] initWithFrame:NSMakeRect(16, 78, 90, 20)] autorelease];
		[label setStringValue:@"Stopped at"];
		[label setEditable:NO];
		[label setBordered:NO];
		[label setDrawsBackground:NO];
		[content addSubview:label];
		bkAddressText = [[NSTextField alloc] initWithFrame:NSMakeRect(112, 74, 120, 24)];
		[bkAddressText setEditable:NO];
		[content addSubview:bkAddressText];
		NSArray *titles = [NSArray arrayWithObjects:@"Continue", @"Step", @"Remove", nil];
		NSArray *tags = [NSArray arrayWithObjects:[NSNumber numberWithInt:101],
			[NSNumber numberWithInt:102], [NSNumber numberWithInt:103], nil];
		NSUInteger i;
		for (i = 0; i < [titles count]; i++) {
			NSButton *b = [[[NSButton alloc] initWithFrame:NSMakeRect(18 + i * 92, 24, 82, 28)] autorelease];
			[b setTitle:[titles objectAtIndex:i]];
			[b setTag:[[tags objectAtIndex:i] intValue]];
			[b setTarget:self];
			[b setAction:@selector(button:)];
			[content addSubview:b];
		}
		idContinuePanel = self;
	}
	return self;
}

- setBreakpointsPanel:(id)panel
{
	Breakpoints = panel;
	return self;
}

- open:(mem_addr)addr
{
	char buffer[20];
	sprintf(buffer, "%08x", addr);
	bkptAddr = addr;
	[bkAddressText setStringValue:[NSString stringWithUTF8String:buffer]];
	[self makeKeyAndOrderFront:self];
	return self;
}

- button:sender
{
	switch ([sender tag]) {
		case 101: [idMainInterface run:NO :YES]; break;
		case 102: [idMainInterface run:YES :YES]; break;
		case 103:
#ifdef CL_SPIM
			breakpoint_reinsert = 0;
#else
			delete_breakpoint(bkptAddr);
#endif
			[Breakpoints showBkpts];
			break;
	}
	[self close];
	return self;
}

@end
