/* SPIM S20 MIPS simulator.
   Interface to misc. routines for SPIM.
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


/* $Header: /home/primost/larus/RCS/spim-utils.h,v 1.4 1992/10/30 19:00:59 larus Exp $
*/


/* Exported functions: */

void add_breakpoint (mem_addr addr);
void delete_breakpoint (mem_addr addr);
void delete_all_breakpoints(void);
void fatal_error (char *fmt, ...);
void initialize_registers (void);
void initialize_run_stack (int argc, char **argv);
void initialize_world (int load_trap_handler);
void list_breakpoints (void);
inst_info *map_int_to_inst_info (inst_info tbl[], int tbl_len, int num);
inst_info *map_string_to_inst_info (inst_info tbl[], int tbl_len, char *id);
int read_assembly_file (char *name);
int run_program (mem_addr pc, int steps, int display, int cont_bkpt);
mem_addr starting_address (void);
char *str_copy (char *str);
void write_startup_message (void);
void *xmalloc (int);
void *zmalloc (int);
