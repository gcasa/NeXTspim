/* NeXTspim 1.0
   Copyright (C) 1994 by Mark Gritter (mgritter@gac.edu).
   
   SPIM S20 MIPS simulator.
   Copyright (C) 1990-1992 by James Larus (larus@cs.wisc.edu).
   ALL RIGHTS RESERVED.

   SPIM is distributed under the following conditions:

     You may make copies of SPIM for your own use and modify those copies.

     All copies of SPIM must retain my name and copyright notice.

     You may not sell SPIM or distributed SPIM in conjunction with a
     commerical product or service without the expressed written consent of
     James Larus.

   THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
   IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
   WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
   PURPOSE. */

/* Window class for showing statistics (cache, syscalls, etc.), with
   a few controls added in... */

#import "StatsWindow.h"
#import "TextView.h"
#import <appkit/Text.h>

#include <stdio.h>
#include <string.h>

#include "spim.h"
#include "cl-cache.h"
#include "cl-except.h"
#include "mips-syscall.h"
#include "inst.h"
#include "sym-tbl.h"

#define CACHE_STATS		0
#define EXCEPTION_STATS	1
#define SYSCALL_STATS	2
#define SYMBOL_TABLE	3

#define MAX_NAMES 4

/* We'll figure out which stats to display based on the name of the window.
   Kinda kludgy. */
char *names[MAX_NAMES] = {
	"Cache Statistics",
	"Exception Statistics",
	"Syscall Statistics",
	"Symbol Table"};

extern label *label_hash_table[];

@implementation StatsWindow

- orderFront:sender {
	[super orderFront:sender];
	[[textView idText] setEditable:NO];
	[self showStats:sender];
	return self;
}

/* Figure out what this window's supposed to display based on its name. */
- (int)whoAmI {
	int x;
	const char *myname = [self title];
	for (x = 0; x < MAX_NAMES; x++) {
		if (!strncmp(myname, names[x], 5)) return x;
	}
	fprintf(stderr, "NeXTspim: Unknown StatsWindow type '%s'\n", myname);
	return -1;
}

- showStats:sender {
	char *buffer = malloc(8 * K);
	char *buf;
	int x, i;
	label *l;
	buffer[0] = 0;
	buf = buffer;
	switch ([self whoAmI]) {
		case CACHE_STATS:
			sprintf(buf, "Data load hits:        %d\n", statistics[3]);
			buf += strlen(buf);
			sprintf(buf, "          misses:      %d\n", statistics[6]);
			buf += strlen(buf);
			sprintf(buf, "          page hits:   %d\n", statistics[0]);
			buf += strlen(buf);
			sprintf(buf, "          page misses: %d\n", statistics[6] - statistics[0]);
			buf += strlen(buf);
			sprintf(buf, "Inst load hits:        %d\n", statistics[5]);
			buf += strlen(buf);
			sprintf(buf, "          misses:      %d\n", statistics[8]);
			buf += strlen(buf);
			sprintf(buf, "          page hits:   %d\n", statistics[2]);
			buf += strlen(buf);
			sprintf(buf, "          page misses: %d\n", statistics[8] - statistics[2]);
			buf += strlen(buf);
			sprintf(buf, "Data Store hits:       %d\n", statistics[4]);
			buf += strlen(buf);
			sprintf(buf, "          misses:      %d\n", statistics[7]);
			buf += strlen(buf);
			sprintf(buf, "          page hits:   %d\n", statistics[1]);
			buf += strlen(buf);
			sprintf(buf, "          page misses: %d\n", (statistics[4] + statistics[7]) - statistics[1]);
			buf += strlen(buf);
			break;
		case EXCEPTION_STATS:
			sprintf(buf, "Name\t\tFrequency\n");
			buf += strlen(buf);
			for (x=0; x < MAX_EXCPTS; x++) {
				sprintf(buf, "%s\t\t%d\n", EXCPT_STR(x), EXCPT_COUNT(x));
				buf += strlen(buf);
			}
			break;
		case SYSCALL_STATS:
			sprintf(buf, "Call#\t\tFrequency\n");
			buf += strlen(buf);
			for (x = 0; x < max_syscall; x ++)
				if (syscall_usage[x] > 0) {
					sprintf(buf, "%d(%s)\t\t%d\n", x, syscall_table[x].syscall_name, syscall_usage[x]);
					buf += strlen(buf);
				}
			break;
		case SYMBOL_TABLE:
			for (i = 0; i < LABEL_HASH_TABLE_SIZE; i ++)
    			for (l = label_hash_table [i]; l != NULL; l = l->next) {
      				sprintf(buf, "%s%s at 0x%08x\n",
							l->global_flag ? "g " : "	 ",
							l->name, l->addr);
					buf += strlen(buf);
				}
			break;
	}
	[textView setText:buffer];
	free(buffer);
	return self;
}

- resetStats:sender {
	int x;
	switch ([self whoAmI]) {
		case CACHE_STATS:
			stat_init();
			break;
		case EXCEPTION_STATS:
			initialize_excpt_counts();
			break;
		case SYSCALL_STATS:
			for (x = 0; x < max_syscall; x++) syscall_usage[x] = 0;
			break;
	}
	[self showStats:self];
	return self;
}


@end
