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

#include "spim.h"
#include "inst.h"
#include "reg.h"
#include "mem.h"
#include "mips-syscall.h"
#include "cl-mem.h"
#include "cl-tlb.h"


struct tlb_entry {
 unsigned int upper, lower;
};


/* Exported Variables: */

int tlb_on;			/* !0 -> tlb handling is on */


/* Local Functions: */
#ifdef __STDC__
unsigned int find_page (unsigned int vpn);
#else
unsigned int find_page ();
#endif


#define TLB_SIZE 64		/* tlb size */
#define PT_INCR 100		/* increment size for external page table */
#define tlb_VPN(i) (((TLB[i].upper) >> 12) & 0xfffff)
#define tlb_PID(i) (((TLB[i].upper) >> 6) & (0x3f))
#define tlb_PFN(i) (((TLB[i].lower) >> 12) & (0xfffff))
#define tlb_N(i) (((TLB[i].lower) >> 11) & 0x1)
#define tlb_D(i) (((TLB[i].lower) >> 10) & 0x1)
#define tlb_V(i) (((TLB[i].lower) >> 9) & 0x1)
#define tlb_G(i) (((TLB[i].lower) >> 8) & 0x1)

#define tlb_u_update(i, VPN, PID)          \
{ TLB[i].upper = ((VPN << 12) | ((PID & 0x3f) << 6)); }

#define tlb_l_update(i, PFN, N, D, V, G)   \
{ TLB[i].lower = ((PFN << 12) | (N << 11) | (D << 10) | (V << 9) | (G << 1)); }

#define tbl_update(i, VPN, PID, PFN, N, D, V, G)  \
{ tlb_u_update(i, VPN, PID);                      \
  tlb_l_update(i, PFN, N, D, V, G);               \
}


/* local variables */

static struct tlb_entry TLB[TLB_SIZE];	/* tlb's register-based page table */
static struct tlb_entry *PT = NULL;	/* external page table information */
static int pt_high;
static int pt_size;



#ifdef __STDC__
void
tlb_init (void)
#else
void
tlb_init ()
#endif
{
  int i;

  for (i=1; i < TLB_SIZE; i++) {
    TLB[i].upper = 0;
    TLB[i].lower = 0;
  }

  Random = 63 << 8;

  free (PT);
  PT = NULL;
  pt_high = 0;
  pt_size = 0;
}


/* Virtual Address Translation  -- See Kane Ch. 4*/
/* VPN is in the low order 20 bits of the variable vpn */
/* PID is in the low order 6 bits of the variable pid */
#ifdef __STDC__
int
tlb_vat (mem_addr addr, unsigned int pid, int l_or_s, mem_addr *paddr)
#else
int
tlb_vat(addr, pid, l_or_s, paddr)
  mem_addr addr, *paddr;
  unsigned int pid;
  int l_or_s;
#endif
{
  int i, msb;
  mem_addr temp_badvaddr;
  unsigned int vpn;

  if (!tlb_on) {
    *paddr = addr;
    return CACHEABLE;
  }

  vpn = addr >> 12;
  temp_badvaddr = BadVAddr;
  BadVAddr = addr & 0xfffff000;

  msb = (vpn >> 19) & 0x1;


  if (msb & (Status_Reg & 0x2))
    return ((l_or_s) ? ADDRL_EXCPT : ADDRS_EXCPT);


  for (i=0; i < TLB_SIZE; i++) {
    if (tlb_VPN(i) == vpn)
      break;
  }

  if (i >= TLB_SIZE)  {
    return ((l_or_s) ? TLBL_EXCPT : TLBS_EXCPT);
  }


  if ((!tlb_G(i)) && (tlb_PID(i) != pid))
    return ((l_or_s) ? TLBL_EXCPT : TLBS_EXCPT);


  if (!(tlb_V(i))) {
    return ((l_or_s) ? TLBL_EXCPT : TLBS_EXCPT);
  }

  if (!(tlb_D(i)) && !(l_or_s)) {
    return (MOD_EXCPT);
  }

  BadVAddr = temp_badvaddr;
  *paddr = (tlb_PFN(i) << 12) | (addr & 0xfff);

  return ((tlb_N(i)) ? CACHEABLE : NOT_CACHEABLE);
}




/* TLB Probe */

#ifdef __STDC__
void
tlbp (void)
#else
void
tlbp ()
#endif
{
  int vpn, pid;
  int i;

  vpn = EntryHI >> 12;
  pid = (EntryHI >> 6) & 0x3f;

  for (i=0; i < TLB_SIZE; i++)
    if (tlb_VPN(i) == vpn)
      break;

  if ((i == TLB_SIZE) || (tlb_PID(i) != pid))
    /* no match found */
    Index = (1 << 31);
  else
    Index = (i << 8);
}


/* TLB Read */

#ifdef __STDC__
void
tlbr (void)
#else
void
tlbr ()
#endif
{
  int index;

  index = (Index >> 8) & 0x3f;
  EntryHI = TLB[index].upper;
  EntryLO = TLB[index].lower;
}


/* TLB Write Indexed */

#ifdef __STDC__
void
tlbwi (void)
#else
void
tlbwi ()
#endif
{
  int index;

  index = (Index >> 8) & 0x3f;
  TLB[index].upper = EntryHI;
  TLB[index].lower = EntryLO;
}


/* TLB Write Random */

#ifdef __STDC__
void
tlbwr (void)
#else
void
tlbwr ()
#endif
{
  int index;

  index = (Random >> 8) & 0x3f;
  TLB[index].upper = EntryHI;
  TLB[index].lower = EntryLO;
}



/* Service a TLB miss */

#ifdef __STDC__
void
tlb_service (unsigned int pid, int l_or_s)
#else
void
tlb_service (pid, l_or_s)
  unsigned int pid;
  int l_or_s;
#endif
{
  unsigned int vpn, pfn;

  vpn = (BadVAddr >> 12) & 0xfffff;
  pfn = find_page(vpn);
  EntryHI = ((vpn << 12) | (pid << 6));
  EntryLO = ((pfn << 12) | (1 << 11) | (!l_or_s << 10) | (1 << 9));

  tlbp();
  if (Index >> 31)
    /* No match found */
    tlbwr();
  else
    tlbwi();

}


#ifdef __STDC__
unsigned int
find_page (unsigned int vpn)
#else
unsigned int find_page (vpn)
  unsigned int vpn;
#endif
{
  int i;

  for (i = 0; i < pt_high; i++)
    if ((((PT[i].upper >> 12) & 0xfffff) == vpn) &&
	((PT[i].lower >> 9) & 0x1))
      {
	return i;
      }

  if (pt_high >= pt_size) {
    PT = (struct tlb_entry *)
      realloc(PT, (pt_size + PT_INCR) * sizeof(struct tlb_entry));
    if (PT == NULL) printf("Realloc in find_page failed -- %d\n",
			   (pt_size+PT_INCR) * sizeof(struct tlb_entry));

    /* initialize entries in new_space, that is, make them invalid. */
    for (i=pt_high; i < pt_size; i++)
      PT[i].lower = 0;

    pt_size += PT_INCR;
  }

  PT[pt_high].upper = vpn << 12;
  PT[pt_high].lower = 1 << 9;
  return pt_high++;

}






