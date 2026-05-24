#import "CodeView.h"

@implementation CodeView

- initFrame:(NSRect)frameRect
{
	self = [super initFrame:frameRect];
	if (self) {
		[self setHasHorizontalScroller:YES];
		[[[self idText] textContainer] setWidthTracksTextView:NO];
		[[self idText] setHorizontallyResizable:YES];
		[[self idText] setEditable:NO];
	}
	return self;
}

@end
