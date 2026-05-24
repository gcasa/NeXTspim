#import <AppKit/AppKit.h>

@interface NSTextView (NeXTspimLegacyText)
- neXTspimSetCString:(const char *)txt;
- neXTspimAddCString:(const char *)txt;
- (int)neXTspimTextLength;
- neXTspimSetSelectionFrom:(int)start to:(int)end;
- neXTspimReplaceSelectionWithCString:(const char *)txt;
- (int)neXTspimPositionFromLine:(int)line;
- (int)neXTspimLineFromPosition:(int)position;
@end

@interface TextView : NSScrollView
{
	NSFont *theFont;
	NSTextView *theText;
	CGFloat height;
}

- initFrame:(NSRect)frameRect;
- newText:(NSRect)frameRect;
- idText;
- setText:(char *)txt;
- addText:(char *)txt;
- printPSCode:sender;
- setVertScroll:(float)val;
- scrollLine:(int)line;

@end
