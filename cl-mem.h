
/* $Header: /home/primost/larus/RCS/cl-mem.h,v 1.2 1992/11/06 17:47:18 larus Exp larus $
*/


/* New Memory Macros ... have an extra argument for signalling an exception */

#ifdef __STDC__
instruction *cl_bad_text_read (mem_addr addr, int *excpt);
void cl_bad_text_write (mem_addr addr, instruction *inst, int *excpt);
mem_word cl_bad_mem_read (mem_addr addr, int mask, mem_word *dest, int *excpt);
void cl_bad_mem_write (mem_addr addr, mem_word value, int mask, int *excpt);
#else
instruction *cl_bad_text_read ();
void cl_bad_text_write ();
mem_word cl_bad_mem_read ();
void cl_bad_mem_write ();
#endif



#define CL_READ_MEM_INST(MS, LOC, ADDR, PADDR, CMISS, EXPT, RNUM)	     \
{register mem_addr _addr_ = (mem_addr) (ADDR);			             \
 unsigned int tmp;                                                           \
 tmp = tlb_vat(ADDR, 0, 1, &PADDR);					\
 if (tmp == CACHEABLE) {						\
   CMISS = cache_service (MS, PADDR, ILOAD, &RNUM);			\
   if (_addr_ >= TEXT_BOT && _addr_ < text_top && !(_addr_ & 0x3))           \
     LOC = text_seg [(_addr_ - TEXT_BOT) >> 2];		                     \
   else if (_addr_ >= K_TEXT_BOT && _addr_ < k_text_top && !(_addr_ & 0x3))  \
     LOC = k_text_seg [(_addr_ - K_TEXT_BOT) >> 2];			     \
   else cl_bad_text_read (_addr_, &EXPT);				\
   }									\
 else CL_RAISE_EXCEPTION(tmp, 0, EXPT)     				\
}


#define CL_READ_MEM_BYTE(MS, LOC, ADDR, PADDR, CMISS, EXPT, RNUM)            \
{register mem_addr _addr_ = (mem_addr) (ADDR);			             \
 unsigned int tmp;                                                           \
 tmp = tlb_vat(ADDR, 0, 1, &PADDR);                                          \
 if (tmp == CACHEABLE) {                                                     \
   CMISS = cache_service(MS, PADDR, LOAD, &RNUM);                            \
   if (_addr_ >= DATA_BOT && _addr_ < data_top)			             \
    LOC = data_seg_b [_addr_ - DATA_BOT];			             \
   else if (_addr_ >= stack_bot && _addr_ < STACK_TOP)		             \
    LOC = stack_seg_b [_addr_ - stack_bot];			             \
   else if (_addr_ >= K_DATA_BOT && _addr_ < k_data_top)	             \
    LOC = k_data_seg_b [_addr_ - K_DATA_BOT];			             \
   else cl_bad_mem_read (_addr_, 0, &LOC, &EXPT);}                           \
 else  CL_RAISE_EXCEPTION(tmp, 0, EXPT)                                      \
 }


#define CL_READ_MEM_HALF(MS, LOC, ADDR, PADDR, CMISS, EXPT, RNUM)            \
{register mem_addr _addr_ = (mem_addr) (ADDR);			             \
 unsigned int tmp;                                                           \
 tmp = tlb_vat(ADDR, 0, 1, &PADDR);                                          \
 if (tmp == CACHEABLE) {                                                     \
   CMISS = cache_service(MS, PADDR, LOAD, &RNUM);                            \
   if (_addr_ >= DATA_BOT && _addr_ < data_top && !(_addr_ & 0x1))           \
     LOC = data_seg_h [(_addr_ - DATA_BOT) >> 1];		             \
   else if (_addr_ >= stack_bot && _addr_ < STACK_TOP && !(_addr_ & 0x1))    \
     LOC = stack_seg_h [(_addr_ - stack_bot) >> 1];		             \
   else if (_addr_ >= K_DATA_BOT && _addr_ < k_data_top && !(_addr_ & 0x1))  \
     LOC = k_data_seg_h [(_addr_ - K_DATA_BOT) >> 1];		             \
   else cl_bad_mem_read (_addr_, 0x1, &LOC, &EXPT);}                         \
 else   CL_RAISE_EXCEPTION(tmp, 0, EXPT)                                     \
}



#define CL_READ_MEM_WORD(MS, LOC, ADDR, PADDR, CMISS, EXPT, RNUM)	      \
{register mem_addr _addr_ = (mem_addr) (ADDR);			              \
 unsigned int tmp;                                                            \
 tmp = tlb_vat(ADDR, 0, 1, &PADDR);                                           \
 if (tmp == CACHEABLE) {                                                      \
   CMISS = cache_service(MS, PADDR, LOAD, &RNUM);                             \
   if (_addr_ >= DATA_BOT && _addr_ < data_top && !(_addr_ & 0x3))            \
     LOC = data_seg [(_addr_ - DATA_BOT) >> 2];			              \
   else if (_addr_ >= stack_bot && _addr_ < STACK_TOP && !(_addr_ & 0x3))     \
     LOC = stack_seg [(_addr_ - stack_bot) >> 2];		              \
   else if (_addr_ >= K_DATA_BOT && _addr_ < k_data_top && !(_addr_ & 0x3))   \
     LOC = k_data_seg [(_addr_ - K_DATA_BOT) >> 2];		              \
   else cl_bad_mem_read (_addr_, 0x3, &LOC, &EXPT); }                         \
 else  CL_RAISE_EXCEPTION(tmp, 0, EXPT)                                       \
 }


#define CL_SET_MEM_INST(MS, ADDR, INST, CMISS, EXPT)		             \
{register mem_addr _addr_ = (mem_addr) (ADDR);			             \
 unsigned int tmp;                                                           \
 CMISS = CACHE_HIT;                                                          \
 text_modified = 1;						             \
 if (_addr_ >= TEXT_BOT && _addr_ < text_top && !(_addr_ & 0x3))             \
   text_seg [(_addr_ - TEXT_BOT) >> 2] = INST;		                     \
 else if (_addr_ >= K_TEXT_BOT && _addr_ < k_text_top && !(_addr_ & 0x3))    \
   k_text_seg [(_addr_ - K_TEXT_BOT) >> 2] = INST;		             \
 else cl_bad_text_write (_addr_, INST, &EXPT);}                              \
 }

#define CL_SET_MEM_BYTE(MS, ADDR, PADDR, VALUE, CMISS, EXPT, RNUM)	\
{register mem_addr _addr_ = (mem_addr) (ADDR);			        \
 unsigned int tmp;                                                      \
 tmp = tlb_vat(ADDR, 0, 0, &PADDR);                                     \
 if (tmp == CACHEABLE) {                                                \
   CMISS = cache_service(MS, PADDR, STORE, &RNUM);                      \
   data_modified = 1;						        \
   if (_addr_ >= DATA_BOT && _addr_ < data_top)			        \
     data_seg_b [_addr_ - DATA_BOT] = (unsigned char) (VALUE);	        \
   else if (_addr_ >= stack_bot && _addr_ < STACK_TOP)		        \
     stack_seg_b [_addr_ - stack_bot] = (unsigned char) (VALUE);        \
   else if (_addr_ >= K_DATA_BOT && _addr_ < k_data_top)	        \
     k_data_seg_b [_addr_ - K_DATA_BOT] = (unsigned char) (VALUE);      \
   else cl_bad_mem_write (_addr_, VALUE, 0, &EXPT);}                    \
 else  CL_RAISE_EXCEPTION(tmp, 0, EXPT)                                 \
 }


#define CL_SET_MEM_HALF(MS, ADDR, PADDR, VALUE, CMISS, EXPT, RNUM)           \
{register mem_addr _addr_ = (mem_addr) (ADDR);			             \
 unsigned int tmp;                                                           \
 tmp = tlb_vat(ADDR, 0, 0, &PADDR);                                          \
 if (tmp == CACHEABLE) {                                                     \
   CMISS = cache_service(MS, PADDR, STORE, &RNUM);                           \
   data_modified = 1;						             \
   if (_addr_ >= DATA_BOT && _addr_ < data_top && !(_addr_ & 0x1))           \
     data_seg_h [(_addr_ - DATA_BOT) >> 1] = (unsigned short) (VALUE);	     \
   else if (_addr_ >= stack_bot && _addr_ < STACK_TOP && !(_addr_ & 0x1))    \
     stack_seg_h [(_addr_ - stack_bot) >> 1] = (unsigned short) (VALUE);     \
   else if (_addr_ >= K_DATA_BOT && _addr_ < k_data_top && !(_addr_ & 0x1))  \
     k_data_seg_h [(_addr_ - K_DATA_BOT) >> 1] = (unsigned short) (VALUE);   \
   else cl_bad_mem_write (_addr_, VALUE, 0x1, &EXPT);}                       \
 else  CL_RAISE_EXCEPTION(tmp, 0, EXPT)                                      \
 }


#define CL_SET_MEM_WORD(MS, ADDR, PADDR, VALUE, CMISS, EXPT, RNUM)           \
{register mem_addr _addr_ = (mem_addr) (ADDR);			             \
 unsigned int tmp;                                                           \
 tmp = tlb_vat(ADDR, 0, 0, &PADDR);                                          \
 if (tmp == CACHEABLE) {                                                     \
   CMISS = cache_service(MS, PADDR, STORE, &RNUM);                           \
   data_modified = 1;						             \
   if (_addr_ >= DATA_BOT && _addr_ < data_top && !(_addr_ & 0x3))           \
     data_seg [(_addr_ - DATA_BOT) >> 2] = (mem_word) (VALUE);	             \
   else if (_addr_ >= stack_bot && _addr_ < STACK_TOP && !(_addr_ & 0x3))    \
     stack_seg [(_addr_ - stack_bot) >> 2] = (mem_word) (VALUE);             \
   else if (_addr_ >= K_DATA_BOT && _addr_ < k_data_top && !(_addr_ & 0x3))  \
     k_data_seg [(_addr_ - K_DATA_BOT) >> 2] = (mem_word) (VALUE);           \
   else	 cl_bad_mem_write (_addr_, VALUE, 0x3, &EXPT);}                      \
 else  CL_RAISE_EXCEPTION(tmp, 0, EXPT)                                      \
 }



/* read a word, instruction or data, and don't complain */

#define BASIC_READ_MEM_WORD(LOC, ADDR, EXPT)				\
{									\
  register mem_addr _addr_ = (mem_addr) (ADDR);			      	\
  if (_addr_ >= DATA_BOT && _addr_ < data_top && !(_addr_ & 0x3))	\
    LOC = data_seg [(_addr_ - DATA_BOT) >> 2];		                \
  else if (_addr_ >= stack_bot && _addr_ < STACK_TOP && !(_addr_ & 0x3))\
    LOC = stack_seg [(_addr_ - stack_bot) >> 2];		        \
  else if (_addr_ >= K_DATA_BOT && _addr_ < k_data_top && !(_addr_ & 0x3)) \
    LOC = k_data_seg [(_addr_ - K_DATA_BOT) >> 2];		        \
  else LOC = cl_bad_mem_read(ADDR, 0x3, &LOC, EXPT);                    \
}

