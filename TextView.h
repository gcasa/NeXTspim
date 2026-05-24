#import <AppKit/AppKit.h>

@interface NSTextView (NeXTspimLegacyText)
- setText:(const char *)txt;
- addText:(const char *)txt;
- (int)textLength;
- setSel:(int)start :(int)end;
- replaceSel:(const char *)txt;
- (int)positionFromLine:(int)line;
- (int)lineFromPosition:(int)position;
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
