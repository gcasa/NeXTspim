#import "StatsWindow.h"
#import "TextView.h"

#include <stdio.h>
#include <string.h>

#include "spim.h"
#ifdef CL_SPIM
#include "cl-cache.h"
#include "cl-except.h"
#endif
#include "mips-syscall.h"
#include "inst.h"
#include "sym-tbl.h"

#define CACHE_STATS		0
#define EXCEPTION_STATS	1
#define SYSCALL_STATS	2
#define SYMBOL_TABLE	3
#define MAX_NAMES 4

char *names[MAX_NAMES] = {
	"Cache Statistics",
	"Exception Statistics",
	"Syscall Statistics",
	"Symbol Table"};

extern label *label_hash_table[];

@implementation StatsWindow

- initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)style backing:(NSBackingStoreType)backing defer:(BOOL)defer
{
	self = [super initWithContentRect:contentRect styleMask:style backing:backing defer:defer];
	if (self) {
		textView = [[TextView alloc] initFrame:[[self contentView] bounds]];
		[textView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[[self contentView] addSubview:textView];
	}
	return self;
}

- orderFront:sender
{
	[super orderFront:sender];
	[[textView idText] setEditable:NO];
	[self showStats:sender];
	return self;
}

- (int)whoAmI
{
	int x;
	const char *myname = [[self title] UTF8String];
	for (x = 0; x < MAX_NAMES; x++)
		if (!strncmp(myname, names[x], 5)) return x;
	fprintf(stderr, "NeXTspim: Unknown StatsWindow type '%s'\n", myname);
	return -1;
}

- showStats:sender
{
	char *buffer = malloc(8 * K);
	char *buf;
	int x, i;
	label *l;
	buffer[0] = 0;
	buf = buffer;
	switch ([self whoAmI]) {
		case CACHE_STATS:
#ifdef CL_SPIM
			sprintf(buf, "Data load hits:        %d\n", statistics[3]); buf += strlen(buf);
			sprintf(buf, "          misses:      %d\n", statistics[6]); buf += strlen(buf);
			sprintf(buf, "          page hits:   %d\n", statistics[0]); buf += strlen(buf);
			sprintf(buf, "          page misses: %d\n", statistics[6] - statistics[0]); buf += strlen(buf);
			sprintf(buf, "Inst load hits:        %d\n", statistics[5]); buf += strlen(buf);
			sprintf(buf, "          misses:      %d\n", statistics[8]); buf += strlen(buf);
			sprintf(buf, "          page hits:   %d\n", statistics[2]); buf += strlen(buf);
			sprintf(buf, "          page misses: %d\n", statistics[8] - statistics[2]); buf += strlen(buf);
			sprintf(buf, "Data Store hits:       %d\n", statistics[4]); buf += strlen(buf);
			sprintf(buf, "          misses:      %d\n", statistics[7]); buf += strlen(buf);
			sprintf(buf, "          page hits:   %d\n", statistics[1]); buf += strlen(buf);
			sprintf(buf, "          page misses: %d\n", (statistics[4] + statistics[7]) - statistics[1]); buf += strlen(buf);
#else
			sprintf(buf, "Cycle-level cache statistics are not built in this target.\n");
			buf += strlen(buf);
#endif
			break;
		case EXCEPTION_STATS:
#ifdef CL_SPIM
			sprintf(buf, "Name\t\tFrequency\n"); buf += strlen(buf);
			for (x = 0; x < MAX_EXCPTS; x++) {
				sprintf(buf, "%s\t\t%d\n", EXCPT_STR(x), EXCPT_COUNT(x)); buf += strlen(buf);
			}
#else
			sprintf(buf, "Cycle-level exception statistics are not built in this target.\n");
			buf += strlen(buf);
#endif
			break;
		case SYSCALL_STATS:
			sprintf(buf, "Call#\t\tFrequency\n"); buf += strlen(buf);
			for (x = 0; x < max_syscall; x++)
				if (syscall_usage[x] > 0) {
					sprintf(buf, "%d(%s)\t\t%d\n", x, syscall_table[x].syscall_name, syscall_usage[x]);
					buf += strlen(buf);
				}
			break;
		case SYMBOL_TABLE:
			for (i = 0; i < LABEL_HASH_TABLE_SIZE; i++)
				for (l = label_hash_table[i]; l != NULL; l = l->next) {
					sprintf(buf, "%s%s at 0x%08x\n", l->global_flag ? "g " : "\t ", l->name, l->addr);
					buf += strlen(buf);
				}
			break;
	}
	[textView setText:buffer];
	free(buffer);
	return self;
}

- resetStats:sender
{
	int x;
	switch ([self whoAmI]) {
		case CACHE_STATS:
#ifdef CL_SPIM
			stat_init();
#endif
			break;
		case EXCEPTION_STATS:
#ifdef CL_SPIM
			initialize_excpt_counts();
#endif
			break;
		case SYSCALL_STATS:
			for (x = 0; x < max_syscall; x++) syscall_usage[x] = 0;
			break;
	}
	[self showStats:self];
	return self;
}

@end
