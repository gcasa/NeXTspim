/* SPIM S20 MIPS Cycle Level simulator.
   Definitions for the SPIM S20 Cycle Level Simulator (SPIM-CL).
   Copyright (C) 1991-1992 by Anne Rogers (amr@cs.princeton.edu) and
   Scott Rosenberg (scottr@cs.princeton.edu)
   ALL RIGHTS RESERVED.

   SPIM-CL is distributed under the following conditions:

     You may make copies of SPIM-CL for your own use and modify those copies.

     All copies of SPIM-CL must retain our names and copyright notice.

     You may not sell SPIM-CL or distributed SPIM-CL in conjunction with a
     commerical product or service without the expressed written consent of
     Anne Rogers.

   THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
   IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
   WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
   PURPOSE.
*/

/* Translation Lookaside Buffer simulation module header */

/* Exported Functions */
#ifdef __STDC__
void tlb_init (void);
int tlb_vat (mem_addr addr, unsigned int pid, int l_or_s, mem_addr *paddr);
void tlbp (void);
void tlbr (void);
void tlbwi (void);
void tlbwr (void);
void tlb_service (unsigned int pid, int l_or_s);
#else
void tlb_init ();
int tlb_vat ();
void tlbp ();
void tlbr ();
void tlbwi ();
void tlbwr ();
void tlb_service ();
#endif


/* Exported Variables: */

extern int tlb_on;		/* !0 -> tlb handling is on */
