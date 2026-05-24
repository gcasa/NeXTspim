#import "BreakpointsPanel.h"
#import "TextView.h"

#include "spim-utils.h"
#include "data.h"
#include "run.h"
#include "sym-tbl.h"
#import <ctype.h>

typedef struct bkptrec
{
	mem_addr addr;
	instruction *inst;
	struct bkptrec *next;
} bkpt;

extern bkpt *bkpts;

@implementation BreakpointsPanel

- init
{
	self = [super initWithContentRect:NSMakeRect(220, 220, 300, 260)
	                        styleMask:(NSTitledWindowMask | NSClosableWindowMask)
	                          backing:NSBackingStoreBuffered
	                            defer:NO];
	if (self) {
		NSView *content = [self contentView];
		[self setTitle:@"Breakpoints"];
		bkptList = [[TextView alloc] initFrame:NSMakeRect(12, 58, 276, 190)];
		[content addSubview:bkptList];
		addressText = [[NSTextField alloc] initWithFrame:NSMakeRect(12, 24, 118, 24)];
		[content addSubview:addressText];

		NSArray *titles = [NSArray arrayWithObjects:@"Add", @"Remove", @"Clear", nil];
		NSArray *tags = [NSArray arrayWithObjects:[NSNumber numberWithInt:102],
			[NSNumber numberWithInt:103], [NSNumber numberWithInt:101], nil];
		NSUInteger i;
		for (i = 0; i < [titles count]; i++) {
			NSButton *b = [[[NSButton alloc] initWithFrame:NSMakeRect(138 + i * 52, 22, 50, 26)] autorelease];
			[b setTitle:[titles objectAtIndex:i]];
			[b setTag:[[tags objectAtIndex:i] intValue]];
			[b setTarget:self];
			[b setAction:@selector(button:)];
			[content addSubview:b];
		}
	}
	return self;
}

- setup
{
	[[bkptList idText] setEditable:NO];
	[self showBkpts];
	return self;
}

- showBkpts
{
	bkpt *b;
	char buffer[32];
	[bkptList setText:""];
	if (bkpts) {
		for (b = bkpts; b != NULL; b = b->next) {
			sprintf(buffer, "0x%08x\n", b->addr);
			[bkptList addText:buffer];
		}
	} else {
		[bkptList setText:"No breakpoints set.\n"];
	}
	return self;
}

- button:sender
{
	switch ([sender tag]) {
		case 101: [self removeAllBreak]; break;
		case 102: [self addBreakpoint]; break;
		case 103: [self removeBreakpoint]; break;
	}
	return self;
}

- addBreakpoint
{
	mem_addr addr;
	const char *breakpoint_addr = [[addressText stringValue] UTF8String];
	while (*breakpoint_addr == ' ') breakpoint_addr++;
	if (isdigit(*breakpoint_addr)) addr = strtoul(breakpoint_addr, NULL, 16);
	else addr = find_symbol_address((char *)breakpoint_addr);
	add_breakpoint(addr);
	[self showBkpts];
	return self;
}

- removeBreakpoint
{
	mem_addr addr;
	const char *breakpoint_addr = [[addressText stringValue] UTF8String];
	while (*breakpoint_addr == ' ') breakpoint_addr++;
	if (isdigit(*breakpoint_addr)) addr = strtoul(breakpoint_addr, NULL, 16);
	else addr = find_symbol_address((char *)breakpoint_addr);
	delete_breakpoint(addr);
	text_modified = 1;
	[self showBkpts];
	return self;
}

- removeAllBreak
{
	while (bkpts != NULL) delete_breakpoint(bkpts->addr);
	text_modified = 1;
	[self showBkpts];
	return self;
}

@end
