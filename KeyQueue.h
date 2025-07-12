
/* by Mark Gritter
   January 11, 1994
   Object holds characters entered one by one, then releases them
   either individually, all at once, or split between carriage rets. 
   Meant to be used for keyboard buffering.  See ConsoleText object. 
   Includes mutex so that separate threads can access it.  */

#import <objc/Object.h>
#import <cthreads.h>

#define DEFAULT_MAX_BUFFER 1024
#define MAX_INCREASE 16

@interface KeyQueue:Object
{
	char *buffer;
	int bufEnd;
	int bufSize;
	struct mutex *KeyMutex;
}

- init;
- free;
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
