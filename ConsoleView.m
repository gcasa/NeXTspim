#import "ConsoleView.h"
#import "ConsoleText.h"
#import "KeyQueue.h"

@implementation ConsoleView

- newText:(NSRect)frameRect
{
	ConsoleText *text = [[[ConsoleText alloc] initWithFrame:frameRect] autorelease];
	[text setEditable:YES];
	[text setMinSize:NSMakeSize(0.0, frameRect.size.height)];
	[text setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
	[text setVerticallyResizable:YES];
	[text setHorizontallyResizable:NO];
	[text setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[[text textContainer] setContainerSize:NSMakeSize(frameRect.size.width, FLT_MAX)];
	[[text textContainer] setWidthTracksTextView:YES];
	kq = [[KeyQueue alloc] init];
	[text setBuffer:kq];
	return text;
}

- queue { return kq; }

@end
