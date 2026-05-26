#import "TextView.h"

static NSDictionary *NeXTspimTextAttributes(NSTextView *text)
{
	NSFont *font = [text font];
	if (font != nil) {
		return [NSDictionary dictionaryWithObjectsAndKeys:
			font, NSFontAttributeName,
			[NSColor blackColor], NSForegroundColorAttributeName,
			nil];
	}
	return [NSDictionary dictionaryWithObject:[NSColor blackColor]
	                                  forKey:NSForegroundColorAttributeName];
}

@implementation NSTextView (NeXTspimLegacyText)

- neXTspimSetCString:(const char *)txt
{
	NSString *s = [NSString stringWithUTF8String:(txt ? txt : "")];
	NSAttributedString *attr = [[[NSAttributedString alloc] initWithString:s
	                                                            attributes:NeXTspimTextAttributes(self)] autorelease];
	[[self textStorage] setAttributedString:attr];
	return self;
}

- neXTspimAddCString:(const char *)txt
{
	NSString *s = [NSString stringWithUTF8String:(txt ? txt : "")];
	[[self textStorage] appendAttributedString:[[[NSAttributedString alloc] initWithString:s
	                                                                            attributes:NeXTspimTextAttributes(self)] autorelease]];
	[self scrollRangeToVisible:NSMakeRange([[self string] length], 0)];
	return self;
}

- (int)neXTspimTextLength
{
	return (int)[[self string] length];
}

- neXTspimSetSelectionFrom:(int)start to:(int)end
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

- neXTspimReplaceSelectionWithCString:(const char *)txt
{
	NSString *s = [NSString stringWithUTF8String:(txt ? txt : "")];
	NSAttributedString *attr = [[[NSAttributedString alloc] initWithString:s
	                                                            attributes:NeXTspimTextAttributes(self)] autorelease];
	[[self textStorage] replaceCharactersInRange:[self selectedRange]
	                         withAttributedString:attr];
	return self;
}

- (int)neXTspimPositionFromLine:(int)line
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

- (int)neXTspimLineFromPosition:(int)position
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
		[theText setTextColor:[NSColor blackColor]];
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
	[text setDrawsBackground:YES];
	[text setBackgroundColor:[NSColor whiteColor]];
	[text setTextColor:[NSColor blackColor]];
	[text setTypingAttributes:NeXTspimTextAttributes(text)];
	[text setInsertionPointColor:[NSColor blackColor]];
	return text;
}

- idText { return theText; }

- setText:(char *)txt
{
	[theText neXTspimSetCString:txt];
	return self;
}

- addText:(char *)txt
{
	[theText neXTspimAddCString:txt];
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
	NSUInteger pos = [theText neXTspimPositionFromLine:line];
	[theText scrollRangeToVisible:NSMakeRange(pos, 0)];
	return self;
}

@end
