/* Keyboard input buffer used by the console view. */

#import <Foundation/Foundation.h>
#import "RunLoop.h"

#define DEFAULT_MAX_BUFFER 1024
#define MAX_INCREASE 16

@interface KeyQueue : NSObject
{
	char *buffer;
	int bufEnd;
	int bufSize;
	SPIMMutex *KeyMutex;
}

- init;
- (void)dealloc;
- addChar:(char)c;
- deleteChar;
- (BOOL)bufferEmpty;
- (BOOL)fullLine;
- (int)textLength;
- (int)lineLength;
- putTextInto:(char *)dest;
- putLineInto:(char *)dest;
- (BOOL)putTextInto:(char *)dest max:(int)mx;
- (BOOL)putLineInto:(char *)dest max:(int)mx;
- (char)getChar;
- flush;

@end
