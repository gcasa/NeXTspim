/* Thread-safe character queue for simulated console input. */

#import "KeyQueue.h"
#import <stdlib.h>

@implementation KeyQueue

- init
{
	self = [super init];
	if (self) {
		buffer = malloc(DEFAULT_MAX_BUFFER * sizeof(char));
		bufSize = DEFAULT_MAX_BUFFER;
		buffer[0] = 0;
		bufEnd = 0;
		KeyMutex = SPIMMutexCreate();
	}
	return self;
}

- (void)dealloc
{
	free(buffer);
#if !__has_feature(objc_arc)
	[super dealloc];
#endif
}

- addChar:(char)c
{
	mutex_lock(KeyMutex);
	if (bufEnd + 1 >= bufSize) {
		bufSize += MAX_INCREASE;
		buffer = (void *)realloc(buffer, bufSize * sizeof(char));
	}
	buffer[bufEnd++] = c;
	buffer[bufEnd] = 0;
	mutex_unlock(KeyMutex);
	return self;
}

- deleteChar
{
	mutex_lock(KeyMutex);
	if (bufEnd > 0) buffer[--bufEnd] = 0;
	mutex_unlock(KeyMutex);
	return self;
}

- (BOOL)bufferEmpty
{
	BOOL r;
	mutex_lock(KeyMutex);
	r = (bufEnd == 0) ? YES : NO;
	mutex_unlock(KeyMutex);
	return r;
}

- (BOOL)fullLine
{
	int x;
	BOOL r = NO;
	mutex_lock(KeyMutex);
	for (x = bufEnd; x >= 0; x--) {
		if (buffer[x] == '\n') { r = YES; break; }
	}
	mutex_unlock(KeyMutex);
	return r;
}

- (char)getChar
{
	char c;
	int x;
	mutex_lock(KeyMutex);
	c = buffer[0];
	for (x = 0; x < bufEnd; x++) buffer[x] = buffer[x + 1];
	if (bufEnd > 0) bufEnd--;
	mutex_unlock(KeyMutex);
	return c;
}

- (int)textLength
{
	int r;
	mutex_lock(KeyMutex);
	r = bufEnd + 1;
	mutex_unlock(KeyMutex);
	return r;
}

- (int)lineLength
{
	int x, r = 0;
	mutex_lock(KeyMutex);
	for (x = 0; x < bufEnd; x++) {
		if (buffer[x] == '\n') { r = x + 1; break; }
	}
	mutex_unlock(KeyMutex);
	return r;
}

- putTextInto:(char *)dest
{
	int x;
	mutex_lock(KeyMutex);
	for (x = 0; x <= bufEnd; x++) dest[x] = buffer[x];
	bufEnd = 0;
	buffer[0] = 0;
	mutex_unlock(KeyMutex);
	return self;
}

- putLineInto:(char *)dest
{
	int x, y;
	mutex_lock(KeyMutex);
	for (x = 0; buffer[x] != 0 && buffer[x] != '\n'; x++)
		dest[x] = buffer[x];
	dest[x] = 0;
	if (buffer[x] == '\n') x++;
	for (y = 0; x + y <= bufEnd; y++)
		buffer[y] = buffer[y + x];
	bufEnd -= x;
	if (bufEnd < 0) bufEnd = 0;
	mutex_unlock(KeyMutex);
	return self;
}

- (BOOL)putTextInto:(char *)dest max:(int)mx
{
	int x, y;
	mutex_lock(KeyMutex);
	for (x = 0; x <= bufEnd && x < mx - 1; x++) dest[x] = buffer[x];
	if (x >= mx - 1 && x <= bufEnd) {
		dest[mx - 1] = 0;
		for (y = 0; y <= bufEnd - mx + 1; y++)
			buffer[y] = buffer[y + mx - 1];
		bufEnd -= mx - 1;
		mutex_unlock(KeyMutex);
		return YES;
	}
	bufEnd = 0;
	buffer[0] = 0;
	mutex_unlock(KeyMutex);
	return NO;
}

- (BOOL)putLineInto:(char *)dest max:(int)mx
{
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

- flush
{
	mutex_lock(KeyMutex);
	bufEnd = 0;
	buffer[0] = 0;
	mutex_unlock(KeyMutex);
	return self;
}

@end
