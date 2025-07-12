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

#define CACHE_MISS 20
#define CACHE_HIT -1

#define DATA_CACHE 1
#define INST_CACHE 0

#define LOAD 0
#define STORE 1
#define ILOAD 2

#define MAX_INTERLEAVING 16
#define MAX_CACHE_SIZE 512


/* Requried Types Memory */
struct memory {
  int available;                   /* per module -- >0 no, 0 pending reply,
                                        < 0 available */
  int req_number;                  /* number of request in progress. */
  int req_type;                    /* LOAD or STORE or SLOAD */
  unsigned int last_page;     	   /* last page referenced */
};
typedef struct memory *MAIN_MEM;


/* cache memory bus queues */
struct dcq {
  mem_addr addr;
  int status;                      /* CLEAR, READY, or PENDING */
  unsigned int req_num;            /* request number, return to CPU when */
				   /* request is finshed. */
};
typedef struct dcq *DCQ;
typedef struct dcq *ICQ;



struct bus_desc {
  int busy;                        /* 0 bus not busy, 1 bus busy but free */
				   /* on next cycle, > 1 bus busy */
  int direction;                   /* MEM_TO_CPU or CPU_TO_MEM */
  unsigned int request;            /* number of request/reply in progress */
  int module;                      /* memory module */
  int arb_winner;                  /* Number of next request/reply to service*/
                                   /* 0 - no pending requests, DCRQ, DCWB */
                                   /* 4-(4 + interleaving -1) Memory Module */
                                   /* 4+interleaving - 4+2*interleaving-1 */
				   /* PFB queues */
};
typedef struct bus_desc *BUS;



struct cache_entry {
  int block_num;
  unsigned int lru;           /* for set-associative caches */
  short state;                /* bit 0 == 1 => dirty, bit 1 == 1 => valid */
};
typedef struct cache_entry CACHE[MAX_CACHE_SIZE];


struct mem_sys {
  BUS bus;
  struct memory main[MAX_INTERLEAVING];
  DCQ read_buffer;
  DCQ write_buffer;
  ICQ inst_buffer;
  CACHE dcache;
  CACHE icache;
};
typedef struct mem_sys *MEM_SYSTEM;


/* Exported Functions */
#ifdef __STDC__
void cache_wt_init (void);
void stat_init (void);
void stat_print (void);
unsigned int bus_service (MEM_SYSTEM mem_system);
MEM_SYSTEM mem_sys_init (void);
void print_mem_sys_status (int finished, MEM_SYSTEM mem_system);
void cache_init (MEM_SYSTEM mem_system, int type);
int cache_service (MEM_SYSTEM mem_system, mem_addr addr, int type, unsigned int
		   *req_num);
int cache_probe (CACHE cache, mem_addr addr, int type);
void print_cache_stats (char *buf, int type);
char *print_write_buffer (void);
void print_cache_data (char *buf, int type);
#else
void cache_wt_init ();
void stat_init ();
void stat_print ();
unsigned int bus_service ();
MEM_SYSTEM mem_sys_init ();
void print_mem_sys_status ();
void cache_init ();
int cache_service ();
int cach_probe ();
void print_cache_stats ();
char *print_write_buffer ();
void print_cache_data ();
#endif


/* Exported Variables: */
extern MEM_SYSTEM mem_system;
extern int dcache_modified, icache_modified;
extern int line_size;
extern int dcache_on, icache_on;
extern unsigned int statistics[10];