#import <AppKit/AppKit.h>

@class KeyQueue;

@interface ConsoleText : NSTextView
{
	KeyQueue *keyBuffer;
}

- setBuffer:(KeyQueue *)kq;

@end
