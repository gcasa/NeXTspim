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

/* Simple write through cache -- stall on all misses                 */
/* Split transaction bus simulator                                   */

#include <stdio.h>
#include <setjmp.h>

#include "spim.h"
#include "inst.h"
#include "mem.h"
#include "mips-syscall.h"
#include "cl-cache.h"
#include "cl-mem.h"
#include "cl-tlb.h"

#define TRUE 1
#define FALSE 0

#define MEM_TO_CPU 0
#define CPU_TO_MEM 1

#define CLEAR 0
#define READY 1
#define PENDING 2
#define WRITE_BLOCKED 3

#define DCRB 1
#define DCWB 2
#define ICRB 3


/* Exported Variables: */

MEM_SYSTEM mem_system;
int dcache_modified, icache_modified;
int line_size;
int dcache_on, icache_on;


extern jmp_buf spim_top_level_env;


/* Local functions for bus */

#ifdef __STDC__
static int arbitrate (MEM_SYSTEM mem_system);
static int service_request(MEM_SYSTEM);
static void rb_insert (MEM_SYSTEM mem_system, mem_addr addr, unsigned int
		       *req_num);
static void ib_insert (MEM_SYSTEM mem_system, mem_addr addr, unsigned int
		       *req_num);
static int wb_insert (MEM_SYSTEM mem_system, mem_addr addr, unsigned int
		      *req_num);
static int wb_conflict (MEM_SYSTEM mem_system, mem_addr addr);
static unsigned int wb_promote (MEM_SYSTEM mem_system);
static void cache_update (CACHE cache, mem_addr addr, int type);
#else
static int arbitrate ();
static int service_request ();
static void rb_insert ();
static void ib_insert ();
static int wb_insert ();
static int wb_conflict ();
static unsigned int wb_promote ();
static void cache_update ();
#endif


/* Macros */
#define cache_line(addr) 	((addr) >> line_size_bits)
#define cache_loc(cache,line,type)					\
  (line % (type == DATA_CACHE ? dcache_size : icache_size))
#define mem_module(addr) 	(cache_line(addr) % interleaving)
#define is_mem_available(i,mem) (mem[i].available < 0)
#define page_num(addr) 		(addr >> 14)
#define status_str(status) 	((status == CLEAR) ? "C" :         \
				 ((status == PENDING) ? "P" :  \
				  ((status == READY) ? "R" : "W")))


/* general memory stats */
int interleaving;			/* memory interleave factor */
#define MEM_LAT 	9         	/* memory latency, usually 9 */
#define PAGE_MEM_LAT	2		/* memory module page latency */
#define WB_DEPTH 	6               /* write buffer depth */
#define BUS_LINE 	(line_size/4)   /* time to move cache line on bus */
#define BUS_ADDR	1		/* time to move address to mem */
#define BUS_WORD	1		/* time to move word from mem */


/* cache stats */
/* note: variables tagged with "_bits" must change with their */
/* corresponding "_size" variables */
int line_size, line_size_bits;		/* line size for BOTH caches */
int dcache_size, dcache_size_bits;
int icache_size, icache_size_bits;
int dcache_modified, icache_modified;	/* used by xspim to note change */
int icache_on, dcache_on;


static int last_req_num = 0;            /* last request number handed out */
unsigned int statistics[10];         	/* fields explained below */


MEM_SYSTEM mem_system;


#ifdef __STDC__
void
cache_wt_init (void)
#else
void
cache_wt_init ()
#endif
{
  interleaving = 1;

  dcache_size = 512;
  dcache_size_bits = 9;
  icache_size = 512;
  icache_size_bits = 9;

  line_size = 32;
  line_size_bits = 5;
}




/* Statistics stuff */



#define page_hit(kind) (statistics[kind]++)
/* statistics[0] = page_hit(LOAD) */
/* statistics[1] = page_hit(STORE) */
/* statistics[2] = page_hit(ILOAD) */

#define hit(kind) (statistics[kind+3]++)
/* statistics[3] = cache hit(LOAD)   */
/* statistics[4] = cache hit(STORE)  */
/* statistics[5] = cache hit(ILOAD)  */

#define miss(kind) (statistics[kind+6]++)
/* statistics[6] = cache miss(LOAD)  */
/* statistics[7] = cache miss(STORE) */
/* statistics[8] = cache miss(ILOAD) */

#define write_blocked() (statistics[9]++)
/* statistics[9] = write blocked     */



#ifdef __STDC__
void
stat_init (void)
#else
void
stat_init ()
#endif
{
  int i;
  
  /* Loop used to be 8, but statistics[] is an array of 10  -- MG */
  for (i=0; i < 9; i++)
    statistics[i] = 0;
}


#ifdef __STDC__
void
stat_print (void)
#else
void
stat_print ()
#endif
{
  printf("Data load hits:        %d\n", statistics[3]);
  printf("          misses:      %d\n", statistics[6]);
  printf("          page hits:   %d\n", statistics[0]);
  printf("          page misses: %d\n", statistics[6]-statistics[0]);
  printf("Inst load hits:        %d\n", statistics[5]);
  printf("          misses:      %d\n", statistics[8]);
  printf("          page hits:   %d\n", statistics[2]);
  printf("          page misses: %d\n", statistics[8]-statistics[2]);
  printf("Data Store hits:       %d\n", statistics[4]);
  printf("          misses:      %d\n", statistics[7]);
  printf("          page hits:   %d\n", statistics[1]);
  printf("          page misses: %d\n", (statistics[4]+statistics[7])-
         statistics[1]);
}




/* service the bus queues for 1 cycle at time t */
/* Priority scheme...see arbitrate              */

#ifdef __STDC__
unsigned
int bus_service (MEM_SYSTEM mem_system)
#else
unsigned
int bus_service (mem_system)
  MEM_SYSTEM mem_system;
#endif
{
  int i;
  BUS bus;
  MAIN_MEM main;
  DCQ rb, wb, ib;
  static unsigned finished_request = 0;     /* delay announcing finished
					       request for 1 cycle */
  unsigned int prev_finished_request = finished_request;


  bus = mem_system->bus;
  main = mem_system->main;
  rb = mem_system->read_buffer;
  wb = mem_system->write_buffer;
  ib = mem_system->inst_buffer;


  /* if bus is busy */
  if (bus->busy > 1) {
    bus->busy--;
  }

  else if (bus->busy == 1) {
    /* This request will finish in this cycle */

    /* read mem request */
    if ((bus->direction == MEM_TO_CPU) && (bus->request == rb->req_num) &&
	(rb->status == PENDING)) {
      finished_request = bus->request;
      cache_update (mem_system->dcache, rb->addr, DATA_CACHE);
      rb->status = CLEAR;
    }

    /* read inst request */
    else if ((bus->direction == MEM_TO_CPU) &&
	     (bus->request == ib->req_num) && (ib->status == PENDING)) {
      finished_request = bus->request;
      cache_update (mem_system->icache, ib->addr, INST_CACHE);
      ib->status = CLEAR;
    }

    /* write request */
    else if ((bus->direction == CPU_TO_MEM) &&
	     (bus->request == wb[0].req_num) && (wb[0].status == PENDING)) {
      finished_request = wb_promote(mem_system);
      if ((wb[0].status == CLEAR) && (rb->status == WRITE_BLOCKED))
	rb->status = READY;
    }
    bus->busy--;
  }

  else if ((bus->busy == 0) && (bus->arb_winner > 0)) {
    service_request (mem_system);
    bus->arb_winner = 0;
    bus->busy = (bus->busy == 0) ? 0 : bus->busy-1;
  }

  else {
    /* arbitrate for next cycle */
    bus->arb_winner = arbitrate(mem_system);
  }

  /* update all of the mem_available times */
  for (i = 0; i < interleaving; i++) {
    if (main[i].available > 1)
      main[i].available = main[i].available - 1;
    else if (main[i].available == 1)
      if (main[i].req_type == LOAD || main[i].req_type == ILOAD)
	main[i].available = 0;
      else main[i].available = -1;  /* Stores do not send a reply */
    else /*do nothing */
      ;
  }

  return prev_finished_request;
}




#ifdef __STDC__
static int
arbitrate (MEM_SYSTEM mem_system)
#else
static int
arbitrate (mem_system)
  MEM_SYSTEM mem_system;
#endif
{
  int i;
  DCQ rb, wb, ib;

  rb = mem_system->read_buffer;
  wb = mem_system->write_buffer;
  ib = mem_system->inst_buffer;

  if ((rb->status == READY) &&
      (is_mem_available (mem_system->main, mem_module(rb->addr))))
    return DCRB;

  if ((ib->status == READY) &&
      (is_mem_available (mem_system->main, mem_module(ib->addr))))
    return ICRB;

  if ((wb[0].status == READY) &&
      (is_mem_available (mem_system->main, mem_module(wb[0].addr))))
    return DCWB;

  for (i=0; i < interleaving; i++)
    if (mem_system->main[i].available == 0)
      return i + 4;

  /* nothing ready */
  return 0;
}




#ifdef __STDC__
static int
service_request (MEM_SYSTEM mem_system)
#else
static int
service_request (mem_system)
  MEM_SYSTEM mem_system;
#endif
{
  BUS bus = mem_system->bus;
  MAIN_MEM main = mem_system->main;
  DCQ rb = mem_system->read_buffer;
  DCQ wb = mem_system->write_buffer;
  DCQ ib = mem_system->inst_buffer;

  switch (bus->arb_winner) {
  case DCRB:
    /* service read request */
    bus->module = mem_module(rb->addr);
    bus->busy = BUS_ADDR;
    bus->request = rb->req_num;
    bus->direction = CPU_TO_MEM;

    if (page_num(rb->addr) == main[bus->module].last_page) {
      page_hit(LOAD);
      main[bus->module].available =  BUS_ADDR + PAGE_MEM_LAT;
    }
    else {
      main[bus->module].available =  BUS_ADDR + MEM_LAT;
      main[bus->module].last_page = page_num(rb->addr);
    }
    main[bus->module].req_type = LOAD;
    main[bus->module].req_number = rb->req_num;

    rb->status = PENDING;
    return 0;

  case ICRB:
    /* service read inst request */
    bus->module = mem_module(ib->addr);
    bus->busy = BUS_ADDR;
    bus->request = ib->req_num;
    bus->direction = CPU_TO_MEM;

    if (page_num(ib->addr) == main[bus->module].last_page) {
      page_hit(ILOAD);
      main[bus->module].available =  BUS_ADDR + PAGE_MEM_LAT;
    }
    else {
      main[bus->module].available =  BUS_ADDR + MEM_LAT;
      main[bus->module].last_page = page_num(ib->addr);
    }
    main[bus->module].req_type = ILOAD;
    main[bus->module].req_number = ib->req_num;

    ib->status = PENDING;
    return 0;


  case DCWB:
    {
      /* service write buffer */
      bus->module = mem_module(wb[0].addr);
      bus->busy = BUS_ADDR + BUS_WORD;
      bus->request = wb[0].req_num;
      bus->direction = CPU_TO_MEM;

      if (page_num(wb[0].addr) == main[bus->module].last_page) {
	page_hit(STORE);
	main[bus->module].available = BUS_ADDR + BUS_WORD + PAGE_MEM_LAT;
      }
      else {
	main[bus->module].available = BUS_ADDR + BUS_WORD + MEM_LAT;
	main[bus->module].last_page = page_num(wb[0].addr);
      }
      main[bus->module].req_type = STORE;
      wb[0].status = PENDING;
      return 0;
    }

  default:
    bus->module = bus->arb_winner - 4;
    if ((bus->module >= 0) && (bus->module < interleaving)) {
      /* sevice memory reply -- must be LOAD or ILOAD request */
      bus->busy = BUS_LINE;
      bus->request = main[bus->module].req_number;
      bus->direction = MEM_TO_CPU;

      /* memory module is now available */
      main[bus->module].available = -1;
      return 0;
    }

    else {
      printf("Error in service request -- %d \n", bus->arb_winner);
      exit(1);
    }

  }

}






/* Read buffer insert */
#ifdef __STDC__
static void
rb_insert (MEM_SYSTEM mem_system, mem_addr addr, unsigned int *req_num)
#else
static void
rb_insert (mem_system, addr, req_num)
  MEM_SYSTEM mem_system;
  mem_addr addr;
  unsigned int *req_num;
#endif
{
  *req_num = ++last_req_num;

  mem_system->read_buffer->addr = addr;
  if (wb_conflict(mem_system, addr)) {
    write_blocked();
    mem_system->read_buffer->status = WRITE_BLOCKED;
  }
  else
    mem_system->read_buffer->status = READY;
  mem_system->read_buffer->req_num = *req_num;
}


/* Inst buffer insert */
#ifdef __STDC__
static void
ib_insert (MEM_SYSTEM mem_system, mem_addr addr, unsigned int *req_num)
#else
static void
ib_insert (mem_system, addr, req_num)
  MEM_SYSTEM mem_system;
  mem_addr addr;
  unsigned int *req_num;
#endif
{
  *req_num = ++last_req_num;

  mem_system->inst_buffer->addr = addr;
  mem_system->inst_buffer->status = READY;
  mem_system->inst_buffer->req_num = *req_num;
}



/* Write buffer insert */
#ifdef __STDC__
static int
wb_insert (MEM_SYSTEM mem_system, mem_addr addr, unsigned int *req_num)
#else
static int
wb_insert (mem_system, addr, req_num)
  MEM_SYSTEM mem_system;
  mem_addr addr;
  unsigned int *req_num;
#endif
{
  int i;

  for (i=0; i < WB_DEPTH; i++)
    /* find an open slot in the write buffer */
    if (mem_system->write_buffer[i].status == CLEAR) {
      mem_system->write_buffer[i].addr = addr;
      mem_system->write_buffer[i].status = READY;
      return TRUE;
    }

  /* only need a request number if we have to block because
     there is no more room in the write_buffer */
  *req_num = ++last_req_num;
  mem_system->write_buffer[WB_DEPTH].addr = addr;
  mem_system->write_buffer[WB_DEPTH].status = READY;
  mem_system->write_buffer[WB_DEPTH].req_num = *req_num;
  return FALSE;
}


/* Is there a pending write to addr's cache line in the write buffer */
#ifdef __STDC__
static int
wb_conflict (MEM_SYSTEM mem_system, mem_addr addr)
#else
static int
wb_conflict (mem_system, addr)
  MEM_SYSTEM mem_system;
  mem_addr addr;
#endif
{
  int i;

  for (i=0; i < WB_DEPTH; i++)
    if ((cache_line(addr) == cache_line(mem_system->write_buffer[i].addr))
	&& (mem_system->write_buffer[i].status != CLEAR))
      return TRUE;

  return FALSE;
}


#ifdef __STDC__
static unsigned int
wb_promote (MEM_SYSTEM mem_system)
#else
static unsigned int
wb_promote (mem_system)
  MEM_SYSTEM mem_system;
#endif
{
  int i;

  for (i = 1; i <= WB_DEPTH; i++)
    mem_system->write_buffer[i-1] = mem_system->write_buffer[i];

  mem_system->write_buffer[WB_DEPTH].status = CLEAR;

  if (mem_system->write_buffer[WB_DEPTH-1].status == READY)
    /* would have been write_blocked return request num to
       signal that stall is finished */
    return mem_system->write_buffer[WB_DEPTH-1].req_num;
  else return 0;
}




#ifdef __STDC__
MEM_SYSTEM
mem_sys_init (void)
#else
MEM_SYSTEM
mem_sys_init ()
#endif
{
  int i;
  MEM_SYSTEM mem_system;

  mem_system = (MEM_SYSTEM) malloc(sizeof(struct mem_sys));
  mem_system->bus = (BUS) malloc(sizeof(struct bus_desc));
  mem_system->read_buffer = (DCQ) malloc(sizeof(struct dcq));
  mem_system->write_buffer = (DCQ) malloc(sizeof(struct dcq)*(WB_DEPTH+1));
  mem_system->inst_buffer = (DCQ) malloc(sizeof(struct dcq));

  mem_system->bus->arb_winner = 0;
  mem_system->bus->busy = 0;

  mem_system->read_buffer->status = CLEAR;
  mem_system->inst_buffer->status = CLEAR;
  for (i=0; i <= WB_DEPTH; i++)
    mem_system->write_buffer[i].status = CLEAR;

  for (i=0; i < interleaving; i++) {
    mem_system->main[i].available = -1;
    mem_system->main[i].last_page = -1;
  }

  stat_init();

  /* default cache specs for cycle level spim */
  cache_wt_init ();
  cache_init (mem_system, INST_CACHE);
  cache_init (mem_system, DATA_CACHE);

  return mem_system;
}



#ifdef __STDC__
void
print_mem_sys_status (int finished, MEM_SYSTEM mem_system)
#else
void
print_mem_sys_status (finished, mem_system)
  int finished;
  MEM_SYSTEM mem_system;
#endif
{
  int i;
  BUS bus = mem_system->bus;
  MAIN_MEM main = mem_system->main;
  DCQ rb = mem_system->read_buffer;
  DCQ wb = mem_system->write_buffer;
  DCQ ib = mem_system->inst_buffer;


  printf("Finished request = %x\n", finished);
  printf("bus->busy = %d, bus->arb_winner = %d\n", bus->busy, bus->arb_winner);
  printf("direction = %s, request = %d\n\n",
	 (bus->direction == CPU_TO_MEM) ? "CPU_TO_MEM" : "MEM_TO_CPU",
	 bus->request);

  printf("DCRB -- addr = %x, status = %s, module = %d, req_num = %d\n",
	 rb->addr, status_str(rb->status), mem_module(rb->addr),
	 rb->req_num);
  printf("ICRB -- addr = %x, status = %s, module = %d, req_num = %d\n",
	 ib->addr, status_str(ib->status), mem_module(ib->addr),
	 ib->req_num);

  for (i = 0; i <= WB_DEPTH; i++) {
    if (wb[i].status == CLEAR)
      break;
    printf("DCWB[%d] -- addr = %x, status = %s, module = %d \n",
	   i,
	   wb[i].addr,
	   status_str(wb[i].status),
	   mem_module(wb[i].addr));
  }
  printf("\n");


  printf("Memory -- \n");
  printf("    ");
  for (i=0; i < interleaving; i++)
    printf("%d ", main[i].available);
  printf("\n");

  printf("    ");
  for (i=0; i < interleaving; i++)
    printf("%s ", (main[i].req_type == LOAD) ? "L" :
	   ((main[i].req_type == ILOAD) ? "IL" : "S"));
  printf("\n");

  printf("    ");
  for (i=0; i < interleaving; i++)
    printf("%d ", main[i].req_number);
  printf("\n\n");

}



/* ============================================================================== */

/* Direct mapped, physically addressed cache, write through caches */
/* Anne Rogers                              */
/* 18 June 91                               */


#define is_valid(state)  ((state) & 1)
#define set_valid(state)  ((state) = 1)
#define set_invalid(state)  ((state) = 0)

#ifdef __STDC__
void
cache_init (MEM_SYSTEM mem_system, int type)
#else
void
cache_init (mem_system, type)
  MEM_SYSTEM mem_system;
  int type;
#endif
{
  int i;

  switch (type) {
  case DATA_CACHE:
    for(i=0; i < MAX_CACHE_SIZE; i++)
      mem_system->dcache[i].state = 0;
    break;
  case INST_CACHE:
    for(i=0; i < MAX_CACHE_SIZE; i++)
      mem_system->icache[i].state = 0;
    break;
  }
}



#ifdef __STDC__
int
cache_service (MEM_SYSTEM mem_system, mem_addr addr, int type, unsigned int
	       *req_num)
#else
int
cache_service (mem_system, addr, type, req_num)
  MEM_SYSTEM mem_system;
  mem_addr addr;
  int type;
  unsigned int *req_num;
#endif
{
  int line, loc;

  switch (type) {

  case (STORE):
    if (!dcache_on) return CACHE_HIT;
    if (wb_insert(mem_system, addr, req_num)) {
      hit(STORE);
      return CACHE_HIT;
    }
    else {
      miss(STORE);
      return CACHE_MISS;
    }
    break;

  case (LOAD):
    if (!dcache_on) return CACHE_HIT;
    line = cache_line (addr);
    loc = cache_loc (mem_system->dcache, line, DATA_CACHE);

    if ((mem_system->dcache[loc].block_num == line) &&
	(is_valid(mem_system->dcache[loc].state))) {
      hit(LOAD);
      return CACHE_HIT;
    }
    else {
      miss(LOAD);
      rb_insert(mem_system, addr, req_num);
      return CACHE_MISS;
    }
    break;

  case (ILOAD):
    if (!icache_on) return CACHE_HIT;
    line = cache_line (addr);
    loc = cache_loc (mem_system->icache, line, INST_CACHE);

    if ((mem_system->icache[loc].block_num == line) &&
	(is_valid (mem_system->icache[loc].state))) {
      hit(ILOAD);
      return CACHE_HIT;
    }
    else {
      miss(ILOAD);
      ib_insert(mem_system, addr, req_num);
      return CACHE_MISS;
    }
    break;

  }
}




#ifdef __STDC__
static void
cache_update (CACHE cache, mem_addr addr, int type)
#else
static void
cache_update (cache, addr, type)
  CACHE cache;
  mem_addr addr;
  int type;
#endif
{
  int loc, line;

  line = cache_line (addr);
  loc = cache_loc (cache, line, type);
  cache[loc].block_num = line;
  set_valid(cache[loc].state);

  if (type == DATA_CACHE)
    dcache_modified = 1;
  else
    icache_modified = 1;
}


#ifdef __STDC__
int
cache_probe (CACHE cache, mem_addr addr, int type)
#else
int
cache_probe (cache, addr, type)
  CACHE cache;
  mem_addr addr;
  int type;
#endif
{
  int line, loc;

  line = cache_line(addr);
  loc = cache_loc(cache, line, type);

  if ((cache[loc].block_num == line) && (is_valid(cache[loc].state)))
    return CACHE_HIT;
  else return CACHE_MISS;
}



/* ============================================================================= */
/* Auxilliary Routines                                                           */

#ifdef __STDC__
void
print_cache_stats (char *buf, int type)
#else
void
print_cache_stats (buf, type)
  char *buf;
  int type;
#endif
{
  switch (type) {
  case DATA_CACHE:
    sprintf (buf, "%d lines; %d bytes/line", dcache_size, line_size);
    buf += strlen(buf);
    break;
  case INST_CACHE:
    sprintf (buf, "%d lines; %d bytes/line", icache_size, line_size);
    buf += strlen(buf);
    break;
  }
}


#ifdef __STDC__
void
print_cache_data (char *buf, int type)
#else
void
print_cache_data (buf, type)
  char *buf;
  int type;
#endif
{
  int x, size, size_bits;
  struct cache_entry *cache;


  if (type == DATA_CACHE) {
    cache = mem_system->dcache;
    size = dcache_size;
    size_bits = dcache_size_bits;
  }
  else {
    cache = mem_system->icache;
    size = icache_size;
    size_bits = icache_size_bits;
  }
  sprintf (buf, "LINE   VALID    TAG\n");
  buf += strlen(buf);
  for (x = 0; x < size; x++)
    {
      /* print index, valid, and real tag field */
      sprintf (buf, "%4d      %1d   0x%08x   ", x, is_valid(cache[x].state),
	       ((cache[x].block_num >> size_bits)
		<< (size_bits + line_size_bits)));
      buf += strlen(buf);
      *(buf++) = '\n';
    }
  *buf = '\0';
}


#ifdef __STDC__
char *
print_write_buffer (void)
#else
char *
print_write_buffer ()
#endif
{
  int x;
  static char str[256];
  char *buf = str;

  for (x=0; x<WB_DEPTH; x++) {
    sprintf (buf, "0x%08x ", *(int*)(mem_system->write_buffer + x*sizeof(DCQ)));
    buf += strlen(buf);
  }
  return str;
}

