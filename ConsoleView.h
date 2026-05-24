#import "TextView.h"

@class KeyQueue;

@interface ConsoleView : TextView
{
	KeyQueue *kq;
}

- newText:(NSRect)frameRect;
- queue;

@end
