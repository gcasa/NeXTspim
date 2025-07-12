
/* by Mark Gritter
   January 11, 1994
   Object holds characters entered one by one, then releases them
   either individually, all at once, or split between carriage rets. 
   Meant to be used for keyboard buffering.  See ConsoleText object. 
   Includes mutex so that separate threads can access it.  */

#import "KeyQueue.h"
#import <stdlib.h>

#define MIN(x,y) (x < y ? x : y)

/* Test code 
#import <stdio.h>

void main(void) {
	int x;
	id k;
	char buf[60];
	k = [[KeyQueue alloc] init];
	for (x = 0; x < 10; x++) [k addChar:"ABCD\nEFGHI"[x]];
	printf("bufferEmpty returns: %d\n", [k bufferEmpty]);
	printf("fullLine returns: %d\n", [k fullLine]);
	printf("textLength returns: %d\n", [k textLength]);
	printf("lineLength returns: %d\n", [k lineLength]);
	printf("getChar returns: %c\n", [k getChar]);
	[k putLineInto:buf];
	printf("putLineInto stores: %s\n", buf);
	[k putTextInto:buf max:3];
	printf("putTextInto:max: stores: %s\n", buf);
	[k putTextInto:buf];
	printf("putTextInto stores: %s\n", buf);
	printf("\nResetting Queue...\n", buf);
	for (x = 0; x < 10; x++) [k addChar:"ABCD\nEFGHI"[x]];
	printf("Emptying Queue using putLineInto:max: (max 3)\n");
	while (![k bufferEmpty]) {
		x = [k putLineInto:buf max:3];
		printf("%d: '%s'\n", x, buf);
	}
}
*/

@implementation KeyQueue

- init {
	[super init];
	buffer = malloc(DEFAULT_MAX_BUFFER * sizeof(char));
	bufSize = DEFAULT_MAX_BUFFER;
	buffer[0] = 0;
	bufEnd = 0;
	KeyMutex = mutex_alloc();
	return self;
}

- free {
	free(buffer);
	return [super free];
}

- addChar:(char)c {
	mutex_lock(KeyMutex);
	buffer[bufEnd++] = c;
	buffer[bufEnd] = 0;
	if (bufEnd == bufSize) {
		bufSize += MAX_INCREASE;
		buffer = (void *)realloc(buffer, bufSize * sizeof(char));
	}
	mutex_unlock(KeyMutex);
	return self;
}

- deleteChar {
	mutex_lock(KeyMutex);
	if (bufEnd > 0) buffer[--bufEnd] = 0;
	mutex_unlock(KeyMutex);
	return self;
}
 
- (BOOL)bufferEmpty {
	BOOL r;
	mutex_lock(KeyMutex);
	if (bufEnd == 0) r = YES; else r = NO;
	mutex_unlock(KeyMutex);
	return r;
}

- (BOOL)fullLine {
	int x;
	BOOL r = NO;
	mutex_lock(KeyMutex);
	for (x = bufEnd; x >= 0; x--) {
		if (buffer[x] == '\n') {r = YES; break;}
	}
	mutex_unlock(KeyMutex);
	return r;
}

- (char)getChar {
	char c;
	int x;
	mutex_lock(KeyMutex);
	c = buffer[0];
	for (x = 0; x < bufEnd; x++) buffer[x] = buffer[x + 1];
	mutex_unlock(KeyMutex);
	return c;
}

- (int)textLength {
	int r;
	mutex_lock(KeyMutex);
	r = bufEnd + 1;
	mutex_unlock(KeyMutex);
	return r;
}

- (int)lineLength {
	int x, r = 0;
	mutex_lock(KeyMutex);
	for (x = 0; x < bufEnd; x++) {
		if (buffer[x] == '\n') {r = x + 1; break;}
	}
	mutex_unlock(KeyMutex);
	return r;
}

- putTextInto:(char *)dest {
	int x;
	mutex_lock(KeyMutex);
	for (x = 0; x <= bufEnd; x++) dest[x] = buffer[x];
	bufEnd = 0;
	buffer[0] = 0;
	mutex_unlock(KeyMutex);
	return self;
}

- putLineInto:(char *)dest {
	int x, y;
	mutex_lock(KeyMutex);
	for (x = 0; buffer[x] != 0 && buffer[x] != '\n'; x++)
		dest[x] = buffer[x];
	dest[x] = 0;
	x++;
	for (y = 0; x + y <= bufEnd; y++) {
		buffer[y] = buffer[y + x];
	}
	mutex_unlock(KeyMutex);
	return self;
}

/* Returns FALSE if buffer empty, TRUE if it would overflow "dest"
   "mx" should be the number of chars in "dest". */
   
- (BOOL)putTextInto:(char *)dest max:(int)mx {
	int x, y;
	mutex_lock(KeyMutex);
	for (x = 0; x <= bufEnd && x < mx - 1; x++) dest[x] = buffer[x];
	if (x >= mx - 1 && x <= bufEnd) {
		dest[mx - 1] = 0;
		for (y = 0; y <= bufEnd - mx + 1; y++)
			buffer[y] = buffer[y + mx - 1];
		bufEnd -= mx;
		mutex_unlock(KeyMutex);
		return YES;
	}
	if (x < bufEnd) {
		for (y = 0; y < bufEnd - x + 1; y++)
			buffer[y] = buffer[y + x - 1];
	} else {
		bufEnd = 0;
		buffer[0] = 0;
	}
	mutex_unlock(KeyMutex);
	return NO;
}

- (BOOL)putLineInto:(char *)dest max:(int)mx {
	int x, y;
	mutex_lock(KeyMutex);
	for (x = 0; x <= bufEnd && x < mx - 1 && buffer[x] != '\n'; x++)
		dest[x] = buffer[x];
	dest[x] = 0;
	if (buffer[x] == '\n') {
		x++;
		for (y = 0; y + x <= bufEnd; y++) buffer[y] = buffer[y + x];
		bufEnd -= x;
		mutex_unlock(KeyMutex);
		return NO;
	}
	if (x >= mx - 1 && x < bufEnd) {
		for (y = 0; y + x <= bufEnd; y++) buffer[y] = buffer[y + x];
		bufEnd -= x;
		mutex_unlock(KeyMutex);
		return YES;
	} 
	bufEnd = 0;
	buffer[0] = 0;
	mutex_unlock(KeyMutex);
	return NO;
}

- flush {
	bufEnd = 0;
	buffer[0] = 0;
	return self;
}

@end
