#import "TextView.h"

@implementation NSTextView (NeXTspimLegacyText)

- setText:(const char *)txt
{
	[self setString:[NSString stringWithUTF8String:(txt ? txt : "")]];
	return self;
}

- addText:(const char *)txt
{
	NSString *s = [NSString stringWithUTF8String:(txt ? txt : "")];
	[[self textStorage] appendAttributedString:[[[NSAttributedString alloc] initWithString:s] autorelease]];
	[self scrollRangeToVisible:NSMakeRange([[self string] length], 0)];
	return self;
}

- (int)textLength
{
	return (int)[[self string] length];
}

- setSel:(int)start :(int)end
{
	NSUInteger len = [[self string] length];
	NSUInteger s = (start < 0) ? 0 : (NSUInteger)start;
	NSUInteger e = (end < 0) ? 0 : (NSUInteger)end;
	if (s > len) s = len;
	if (e > len) e = len;
	if (e < s) e = s;
	[self setSelectedRange:NSMakeRange(s, e - s)];
	return self;
}

- replaceSel:(const char *)txt
{
	[self replaceCharactersInRange:[self selectedRange]
	                     withString:[NSString stringWithUTF8String:(txt ? txt : "")]];
	return self;
}

- (int)positionFromLine:(int)line
{
	NSString *s = [self string];
	NSUInteger pos = 0, len = [s length];
	int current = 1;
	while (current < line && pos < len) {
		NSRange r = [s rangeOfString:@"\n" options:0 range:NSMakeRange(pos, len - pos)];
		if (r.location == NSNotFound) return (int)len;
		pos = r.location + 1;
		current++;
	}
	return (int)pos;
}

- (int)lineFromPosition:(int)position
{
	NSString *s = [self string];
	NSUInteger limit = MIN((NSUInteger)MAX(position, 0), [s length]);
	int line = 1;
	NSUInteger i;
	for (i = 0; i < limit; i++)
		if ([s characterAtIndex:i] == '\n') line++;
	return line;
}

@end

@implementation TextView

- initFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self) {
		[self setHasVerticalScroller:YES];
		[self setHasHorizontalScroller:NO];
		[self setBorderType:NSBezelBorder];
		[self setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		theFont = [[NSFont userFixedPitchFontOfSize:12.0] retain];
		theText = [[self newText:[[self contentView] bounds]] retain];
		[theText setFont:theFont];
		[theText setBackgroundColor:[NSColor colorWithCalibratedWhite:0.88 alpha:1.0]];
		height = 14.0;
		[self setDocumentView:theText];
	}
	return self;
}

- newText:(NSRect)frameRect
{
	NSTextView *text = [[[NSTextView alloc] initWithFrame:frameRect] autorelease];
	[text setEditable:YES];
	[text setMinSize:NSMakeSize(0.0, frameRect.size.height)];
	[text setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
	[text setVerticallyResizable:YES];
	[text setHorizontallyResizable:NO];
	[text setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[[text textContainer] setContainerSize:NSMakeSize(frameRect.size.width, FLT_MAX)];
	[[text textContainer] setWidthTracksTextView:YES];
	return text;
}

- idText { return theText; }

- setText:(char *)txt
{
	[theText setText:txt];
	return self;
}

- addText:(char *)txt
{
	[theText addText:txt];
	return self;
}

- printPSCode:sender
{
	(void)sender;
	[theText print:self];
	return self;
}

- setVertScroll:(float)val
{
	NSClipView *clip = [self contentView];
	NSRect docRect = [[self documentView] bounds];
	NSRect visible = [clip bounds];
	CGFloat y = MAX(0.0, (docRect.size.height - visible.size.height) * val);
	[clip scrollToPoint:NSMakePoint(0, y)];
	[self reflectScrolledClipView:clip];
	return self;
}

- scrollLine:(int)line
{
	NSUInteger pos = [theText positionFromLine:line];
	[theText scrollRangeToVisible:NSMakeRange(pos, 0)];
	return self;
}

@end
