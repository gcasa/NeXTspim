#ifndef NEXTSPIM_SPIM_H
#define NEXTSPIM_SPIM_H

/* SPIM S20 MIPS simulator.
   Definitions for the SPIM S20.
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


/* $Header: /home/primost/larus/RCS/spim.h,v 3.18 1993/01/18 16:05:36 larus Exp larus $
*/

#import <string.h>
#import <stdlib.h>

#ifndef NULL
#define NULL 0
#endif

#define SPIM_VERSION "5.0"
#define DEFAULT_TRAP_HANDLER "trap.handler"

#define streq(s1, s2) !strcmp(s1, s2)


/* Round V to next greatest B boundary */

#define ROUND(V, B) (((int) V + (B-1)) & ~(B-1))


/* Sign-extend a short to a long */

#define SIGN_EX(X) ((X) & 0x8000 ? (X) | 0xffff0000 : (X))

#ifndef MIN
#define MIN(A, B) ((A) < (B) ? (A) : (B))
#endif

#ifndef MAX
#define MAX(A, B) ((A) > (B) ? (A) : (B))
#endif

#define K 1024

/* Useful and pervasive declarations: */

/*
void bzero (void *, size_t);
void bcopy (const void *, void *, size_t);
*/

#define QSORT_FUNC int(*)(const void *, const void *)

/* Type of a memory address. */

typedef unsigned long mem_addr;


#define BYTES_PER_WORD 4	/* On the MIPS processor */


/* Sizes of memory segments. */

/* Initial size of text segment. */

#ifndef TEXT_SIZE
#define TEXT_SIZE	256*K	/* 1/4 MB */
#endif

/* Initial size of k_text segment. */

#ifndef K_TEXT_SIZE
#define K_TEXT_SIZE	64*K	/* 64 KB */
#endif

/* The data segment must be larger than 64K since we immediate grab
   64K for the small data segment pointed to by $gp. The data segment is
   expanded by an sbrk system call. */

/* Initial size of data segment. */

#ifndef DATA_SIZE
#define DATA_SIZE	256*K	/* 1/4 MB */
#endif

/* Maximum size of data segment. */

#ifndef DATA_LIMIT
#define DATA_LIMIT	1000*K	/* 1 MB */
#endif

/* Initial size of k_data segment. */

#ifndef K_DATA_SIZE
#define K_DATA_SIZE	64*K	/* 64 KB */
#endif

/* Maximum size of k_data segment. */

#ifndef K_DATA_LIMIT
#define K_DATA_LIMIT	1000*K	/* 1 MB */
#endif

/* The stack grows down automatically. */

/* Initial size of stack segment. */

#ifndef STACK_SIZE
#define STACK_SIZE	64*K	/* 64 KB */
#endif

/* Maximum size of stack segment. */

#ifndef STACK_LIMIT
#define STACK_LIMIT	256*K	/* 1 MB */
#endif


/* Name of the function to invoke at start up */

#define DEFAULT_RUN_LOCATION "__start"


/* Default number of instructions to execute. */

#define DEFAULT_RUN_STEPS 2147483647


/* Address to branch to when exception occurs */

#define EXCEPTION_ADDR 0x80000080


/* Maximum size of object stored in the small data segment pointed to by
   $gp */

#define SMALL_DATA_SEG_MAX_SIZE 8

#ifndef DIRECT_MAPPED
#define DIRECT_MAPPED 0
#define TWO_WAY_SET 1
#endif


/* Interval (in instructions) at which memory-mapped IO registers are
   checked and updated.*/

#define IO_INTERVAL 100


/* Number of instructions that a character remains in receiver buffer
   if another character is available. (Should be multiple of IO_INTERVAL.) */

#define RECV_LATENCY (10*IO_INTERVAL)


/* Number of instructions that it takes to write a character. (Should
   be multiple of IO_INTERVAL.)*/

#define TRANS_LATENCY (IO_INTERVAL)



/* Triple containing a string and two integers.	 Used in tables
   mapping from a name to values. */

typedef struct strint
{
  char *name;
  int value1;
  int value2;
} inst_info;



/* Exported functions (from spim.c or xspim.c): */

#ifndef SEEK_SET
#include <stdio.h>
#endif

int console_input_available (void);
void control_c_seen (int);
void error (char *fmt, ...);
void fatal_error (char *fmt, ...);
char get_console_char (void);
void put_console_char (char c);
void read_input (char *str, int n);
int run_error (char *fmt, ...);
void write_output (char *fmt, ...);


/* Exported variables: */

extern int bare_machine;	/* Simulate bare instruction set */
extern int quiet;		/* No warning messages */
extern int source_file;		/* Program is source, not binary */

/* Actual type of structure pointed to depends on X/terminal interface */
extern int message_out, console_out, console_in;

extern int mapped_io;		/* Non-zero => activate memory-mapped IO */

#ifdef CL_SPIM
extern int pipe_out;
extern int cycle_level;         /* non-zero => cycle level mode */
extern int ptrace;
#endif

extern mem_addr program_starting_address;

extern long initial_text_size;

extern long initial_data_size;

extern long initial_data_limit;

extern long initial_stack_size;

extern long initial_stack_limit;

extern long initial_k_text_size;

extern long initial_k_data_size;

extern long initial_k_data_limit;

#endif /* NEXTSPIM_SPIM_H */
