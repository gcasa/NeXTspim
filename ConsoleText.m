#import "ConsoleText.h"
#import "KeyQueue.h"

@implementation ConsoleText

- (void)keyDown:(NSEvent *)event
{
	NSString *chars = [event characters];
	NSUInteger i;
	for (i = 0; i < [chars length]; i++) {
		unichar ch = [chars characterAtIndex:i];
		switch (ch) {
			case 0x08:
			case 0x7f:
				[keyBuffer deleteChar];
				break;
			case 0x03:
			case 0x0d:
				[keyBuffer addChar:'\n'];
				break;
			default:
				if (ch >= 0x20 && ch < 0x7f)
					[keyBuffer addChar:(char)ch];
				break;
		}
	}
	[super keyDown:event];
}

- setBuffer:(KeyQueue *)kq
{
	keyBuffer = kq;
	return self;
}

@end
