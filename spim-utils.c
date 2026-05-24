/* SPIM S20 MIPS simulator.
   Misc. routines for SPIM.
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


/* $Header: /home/primost/larus/Software/SPIM/RCS/spim-utils.c,v 3.34 1993/08/16 15:00:19 larus Exp larus $
*/


#include <stdio.h>
#include <ctype.h>
#include <stdarg.h>
#include <string.h>

#include "spim.h"
#include "spim-utils.h"
#include "inst.h"
#include "data.h"
#include "mem.h"
#include "reg.h"
#include "scanner.h"
#include "parser.h"
#include "y.tab.h"
#include "run.h"
#include "sym-tbl.h"

#ifdef CL_SPIM
#include "cl-cache.h"
#include "cl-cycle.h"
#include "cl-tlb.h"
#include "cl-except.h"
#endif


/* Internal functions: */

static mem_addr copy_int_to_stack (int n);
static mem_addr copy_str_to_stack (char *s);
void delete_all_breakpoints (void);

/* Path for default trap handler */
extern char *default_trap_path;

/* Global Variables: */

int bare_machine = 0;		/* Non-zero => ignore assembler
				   embellishments to bare hardware */

int quiet = 0;			/* Non-zero => no message on traps. */


int message_out = 0, console_out = 0;

mem_addr program_starting_address = 0;

long initial_text_size = TEXT_SIZE;

long initial_data_size = DATA_SIZE;

long initial_data_limit = DATA_LIMIT;

long initial_stack_size = STACK_SIZE;

long initial_stack_limit = STACK_LIMIT;

long initial_k_text_size = K_TEXT_SIZE;

long initial_k_data_size = K_DATA_SIZE;

long initial_k_data_limit = K_DATA_LIMIT;



/* Initialize or reinitialize the state of the machine. */

#ifdef __STDC__
void
initialize_world (int load_trap_handler)
#else
void
initialize_world (load_trap_handler)
     int load_trap_handler;
#endif
{
  /* Allocate the floating point registers */
  if (FGR == NULL)
    FPR = (double *) xmalloc (16 * sizeof (double));
  /* Allocate the memory */
  make_memory (initial_text_size,
	       initial_data_size, initial_data_limit,
	       initial_stack_size, initial_stack_limit,
	       initial_k_text_size,
	       initial_k_data_size, initial_k_data_limit);
  initialize_registers ();
  initialize_symbol_table ();
  k_text_begins_at_point (K_TEXT_BOT);
  k_data_begins_at_point (K_DATA_BOT);
  data_begins_at_point (DATA_BOT);
  text_begins_at_point (TEXT_BOT);
  if (load_trap_handler)
    {
      int old_bare = bare_machine;
	  char filename[1024];
      bare_machine = 0;		/* Trap handler uses extended machine */
      /* Have to add path name on because NeXT programs run from
	     the workspace have directory as user's home.  We'll assume
		 that the trap handler can be found in the same directory
		 as NeXTspim */
	  sprintf(filename, "%s%s", default_trap_path, DEFAULT_TRAP_HANDLER);
	  if (read_assembly_file (filename))
		fatal_error ("Cannot read trap handler\n");
      bare_machine = old_bare;
    }
  initialize_scanner (stdin);
  delete_all_breakpoints ();
#ifdef CL_SPIM
  /* cycle level stuff */
  mem_system = mem_sys_init ();
  cycle_running = 0;
#endif
}


#ifdef __STDC__
void
write_startup_message (void)
#else
void
write_startup_message ()
#endif
{
#ifdef CL_SPIM
  write_output ("CL-SPIM %s\n", SPIM_VERSION);
  write_output ("Copyright 1990-92 by James R. Larus (larus@cs.wisc.edu).\n");
  write_output ("Copyright (C) 1991-1992 by Anne Rogers (amr@cs.princeton.edu)\n");
  write_output ("and Scott Rosenberg (scottr@cs.princeton.edu).\n");
#else
  write_output ("SPIM %s\n", SPIM_VERSION);
  write_output ("Copyright 1990-92 by James R. Larus (larus@cs.wisc.edu).\n");
#endif
  write_output ("All Rights Reserved.\n");
  write_output ("See the file README a full copyright notice.\n");
  write_output ("\nNeXT version 1.0\n");
  write_output ("Copyright (C) 1994 by Mark Gritter (mgritter@gac.edu).\n");
}



#ifdef __STDC__
void
initialize_registers (void)
#else
void
initialize_registers ()
#endif
{
  bzero (FPR, 16 * sizeof (double));
  FGR = (float *) FPR;
  FWR = (int *) FPR;
  bzero (R, 32 * sizeof (reg_word));
  R[29] = STACK_TOP - BYTES_PER_WORD - 4096; /* Initialize $sp */
  PC = 0;
  Cause = 0;
  EPC = 0;
  Status_Reg = 0;
  BadVAddr = 0;
  Context = 0;
  PRId = 0;
#ifdef CL_SPIM
  PC = 0;
  Status_Reg = (0x3 << 28) | (0x3);
#endif
}


/* Read file NAME, which should contain assembly code. Return zero if
   successful and non-zero otherwise. */

#ifdef __STDC__
int
read_assembly_file (char *name)
#else
int
read_assembly_file (name)
     char *name;
#endif
{
  FILE *file = fopen (name, "r");;

  source_file = 1;
  if (file == NULL)
    {
      error ("Cannot open file: `%s'\n", name);
      return (1);
    }
  else
    {
#ifdef mips
#include <sys/exec.h>
      unsigned short magic;

      fread (&magic, sizeof (short), 1, file);
      fclose (file);
      if (magic == MIPSEBMAGIC || magic == MIPSELMAGIC)
	{
	  error ("Source file appears to be executable: %s\n", name);
	  return (1);
	}
      fopen (name, "r");
#endif
      initialize_scanner (file);
      initialize_parser (name);
      while (yyparse ()) ;
      fclose (file);
      flush_local_labels ();
      end_of_assembly_file ();
      return (0);
    }
}


#ifdef __STDC__
mem_addr
starting_address (void)
#else
mem_addr
starting_address ()
#endif
{
  if (PC == 0)
    {
      if (program_starting_address)
	return (program_starting_address);
      else
	return (program_starting_address
		= find_symbol_address (DEFAULT_RUN_LOCATION));
    }
  else
    return (PC);
}


/* Initialize the SPIM stack with ARGC, ARGV, and ENVP data. */

#ifdef __STDC__
void
initialize_run_stack (int argc, char **argv)
#else
void
initialize_run_stack (argc, argv)
     int argc;
     char **argv;
#endif
{
  char **p;
  extern char **environ;
  int i, j = 0, env_j;
  mem_addr addrs[10000];

  R[REG_A2] = R[29];

  /* Put strings on stack: */
  for (p = environ; *p != '\0'; p++)
    addrs[j++] = copy_str_to_stack (*p);

  R[REG_A1] = R[29];
  env_j = j;
  for (i = 0; i < argc; i++)
    addrs[j++] = copy_str_to_stack (argv[i]);

  R[29] = (R[29] - 7) & ~7;	/* Double-word align */
  /* Build vectors on stack: */
  for (i = env_j - 1; i >= 0; i--)
    copy_int_to_stack (addrs[i]);
  for (i = j - 1; i >= env_j; i--)
    copy_int_to_stack (addrs[i]);

  R[REG_A0] = argc;
  R[29] = copy_int_to_stack (argc); /* Leave pointing to argc */

  R[29] = (R[29] - 7) & ~7;	/* Double-word align */
}


#ifdef __STDC__
static mem_addr
copy_str_to_stack (char *s)
#else
static mem_addr
copy_str_to_stack (s)
     char *s;
#endif
{
  mem_addr str_start;
  int i = strlen (s);

  while (i >= 0)
    {
      SET_MEM_BYTE (R[29], s[i]);
      R[29] -= 1;
      i -= 1;
    }
  str_start = (mem_addr) R[29] + 1;
  R[29] = R[29] & 0xfffffffc;	/* Round down to word boundary */
  return (str_start);
}


#ifdef __STDC__
static mem_addr
copy_int_to_stack (int n)
#else
static mem_addr
copy_int_to_stack (n)
     int n;
#endif
{
  SET_MEM_WORD (R[29], n);
  R[29] -= BYTES_PER_WORD;
  return ((mem_addr) R[29] + BYTES_PER_WORD);
}


/* Run a program starting at PC for N steps and display each
   instruction before executing if FLAG is non-zero.  If CONTINUE is
   non-zero, then step through a breakpoint.  Return non-zero if
   breakpoint is encountered. */

#ifdef __STDC__
int
run_program (mem_addr pc, int steps, int display, int cont_bkpt)
#else
int
run_program (pc, steps, display, cont_bkpt)
     mem_addr pc;
     int steps, display, cont_bkpt;
#endif
{
  if (cont_bkpt && inst_is_breakpoint (pc))
    {
      mem_addr addr = PC == 0 ? pc : PC;

      delete_breakpoint (addr);
      exception_occurred = 0;
      run_spim (addr, 1, display);
      add_breakpoint (addr);
      steps -= 1;
      pc = PC;
    }

  exception_occurred = 0;
  if (!run_spim (pc, steps, display))
    /* Can't restart program */
    PC = 0;
  if (exception_occurred && Cause == (BKPT_EXCPT << 2))
    return (1);
  else
    return (0);
}


/* Record of where a breakpoint was placed and the instruction previously
   in memory. */

typedef struct bkptrec
{
  mem_addr addr;
  instruction *inst;
  struct bkptrec *next;
} bkpt;


bkpt *bkpts = NULL;


/* Set a breakpoint at memory location ADDR. */

#ifdef __STDC__
void
add_breakpoint (mem_addr addr)
#else
void
add_breakpoint (addr)
     mem_addr addr;
#endif
{
  bkpt *b;
  bkpt *rec;
  for (b = bkpts; b != NULL; b = b->next) {
  	if (b->addr == addr) {
		error("Already a breakpoint at address 0x%08x\n", addr);
		return;
	}
  }
  rec = (bkpt *) xmalloc (sizeof (bkpt));

  rec->next = bkpts;
  rec->addr = addr;

  if ((rec->inst = set_breakpoint (addr)) != NULL)
    bkpts = rec;
  else
    {
      if (exception_occurred)
	error ("Cannot put a breakpoint at address 0x%08x\n", addr);
      else
	error ("No instruction to breakpoint at address 0x%08x\n", addr);
      free (rec);
    }
}


/* Delete all breakpoints at memory location ADDR. */

#ifdef __STDC__
void
delete_breakpoint (mem_addr addr)
#else
void
delete_breakpoint (addr)
     mem_addr addr;
#endif
{
  bkpt *p, *b;
  int deleted_one = 0;

  for (p = NULL, b = bkpts; b != NULL; )
    if (b->addr == addr)
      {
	bkpt *n;

	SET_MEM_INST (addr, b->inst);
	if (p == NULL)
	  bkpts = b->next;
	else
	  p->next = b->next;
	n = b->next;
	free (b);
	b = n;
	deleted_one = 1;
      }
    else
      p = b, b = b->next;
  if (!deleted_one)
    error ("No breakpoint to delete at 0x%08x\n", addr);
}


#ifdef __STDC__
void delete_all_breakpoints (void)
#else
void
delete_all_breakpoints ()
#endif
{
  bkpt *b, *n;

  for (b = bkpts, n = NULL; b != NULL; b = n)
    {
      n = b->next;
      free (b);
    }
  bkpts = NULL;
}


/* Utility routines */

/* Print the error message then exit. */

/*VARARGS0*/
#ifdef __STDC__
void
fatal_error (char *fmt, ...)
#else
void
fatal_error (va_alist)
va_dcl
#endif
{
  va_list args;
#ifdef __STDC__
  va_start (args, fmt);
#else
  char *fmt;

  va_start (args);
  fmt = va_arg (args, char *);
#endif
  vfprintf (stderr, fmt, args);
  exit (-1);
  /*NOTREACHED*/
}


/* Return the entry in the hash TABLE of length LENGTH with key STRING.
   Return NULL if no such entry exists. */

#ifdef __STDC__
inst_info *
map_string_to_inst_info (inst_info tbl[], int tbl_len, char *id)
#else
inst_info *
map_string_to_inst_info (tbl, tbl_len, id)
     register inst_info tbl [];
     int tbl_len;
     register char *id;
#endif
{
  register int low = 0;
  register int hi = tbl_len - 1;

  while (low <= hi)
    {
      register int mid = (low + hi) / 2;
      register char *idp = id, *np = tbl[mid].name;

      while (*idp == *np && *idp != '\0') {idp ++; np ++;}

      if (*np == '\0' && *idp == '\0') /* End of both strings */
	return (& tbl[mid]);
      else if (*idp > *np)
	low = mid + 1;
      else
	hi = mid - 1;
    }

  return NULL;
}


/* Return the entry in the hash TABLE of length LENGTH with VALUE1 field NUM.
   Return NULL if no such entry exists. */

#ifdef __STDC__
inst_info *
map_int_to_inst_info (inst_info tbl[], int tbl_len, int num)
#else
inst_info *
map_int_to_inst_info (tbl, tbl_len, num)
     register inst_info tbl [];
     int tbl_len;
     register int num;
#endif
{
  register int low = 0;
  register int hi = tbl_len - 1;

  while (low <= hi)
    {
      register int mid = (low + hi) / 2;

      if (tbl[mid].value1 == num)
	return (&tbl[mid]);
      else if (num > tbl[mid].value1)
	low = mid + 1;
      else
	hi = mid - 1;
    }

  return NULL;
}


#ifdef NEED_VSPRINTF
char *
vsprintf (str, fmt, args)
     char *str, *fmt;
     va_list *args;
{
  FILE _strbuf;

  _strbuf._flag = _IOWRT+_IOSTRG;
  _strbuf._ptr = str;
  _strbuf._cnt = 32767;
  _doprnt(fmt, args, &_strbuf);
  putc('\0', &_strbuf);
  return(str);
}
#endif


#ifdef NEED_STRTOL
long
strtol (str, eptr, base)
     char *str, *eptr;
     int base;
{
  long result;

  if (base != 16)
    fatal_error ("SPIM's strtol only works for base 16 (not base %d)\n", base);
  if (*str == '0' && (*(str + 1) == 'x' || *(str + 1) == 'X'))
    str += 2;
  sscanf (str, "%lx", &result);
  return (result);
}


unsigned long
strtoul (str, eptr, base)
     char *str, *eptr;
     int base;
{
  unsigned long result;

  if (base != 16)
    fatal_error ("SPIM's strtoul only works for base 16 (not base %d)\n",
		 base);
  if (*str == '0' && (*(str + 1) == 'x' || *(str + 1) == 'X'))
    str += 2;
  sscanf (str, "%lx", &result);
  return (result);
}
#endif


#ifdef __STDC__
char *
str_copy (char *str)
#else
char *
str_copy (str)
     char *str;
#endif
{
  return (strcpy (xmalloc (strlen (str) + 1), str));
}


#ifdef __STDC__
void *
xmalloc (int size)
#else
char *
xmalloc (size)
int size;
#endif
{
#ifdef __STDC__
  void *x = (void *) malloc (size);
#else
  char *x = (char *) malloc (size);
#endif

  if (x == 0)
    fatal_error ("Out of memory at request for %d bytes.\n");
  return (x);
}


/* Allocate a zero'ed block of storage. */

#ifdef __STDC__
void *
zmalloc (int size)
#else
char *
zmalloc (size)
int size;
#endif
{
#ifdef __STDC__
  void *z = (void *) malloc (size);
#else
  char *z = (char *) malloc (size);
#endif

  if (z == 0)
    fatal_error ("Out of memory at request for %d bytes.\n");

  bzero (z, size);
  return (z);
}
