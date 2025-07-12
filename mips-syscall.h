/* SPIM S20 MIPS simulator.
   Execute SPIM syscalls, both in simulator and bare mode.
   Copyright (C) 1990-1992 by James Larus (larus@cs.wisc.edu).
   ALL RIGHTS RESERVED.
   Improved by Emin Gun Sirer.

   SPIM is distributed under the following conditions:

     You may make copies of SPIM for your own use and modify those copies.

     All copies of SPIM must retain my name and copyright notice.
     ALL RIGHTS RESERVED.

     You may not sell SPIM or distributed SPIM in conjunction with a
     commerical product or service without the expressed written consent of
     James Larus.

   THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
   IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
   WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
   PURPOSE. */


/* $Header: /home/primost/larus/RCS/mips-syscall.h,v 1.9 1992/09/02 16:48:00 larus Exp $/
*/


/* Exported variables, so that StatsWindow.m can read the usage table. */

extern int syscall_usage[];
extern int max_syscall;

typedef struct {
  int syscall_num;
  int syscall_type;
  int arg0;
  int arg1;
  int arg2;
  int arg3;
  int arg4;
  char *syscall_name;
} syscall_desc;

extern syscall_desc syscall_table[];

/* Exported functions. */

#ifdef __STDC__
int do_syscall (void);
void handle_exception (void);
void initialize_prog_fds (void);
void kill_prog_fds (void);
void print_syscall_usage (void);
#else
int do_syscall ();
void handle_exception ();
void initialize_prog_fds ();
void kill_prog_fds ();
void print_syscall_usage ();
#endif

