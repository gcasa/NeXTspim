/* SPIM S20 MIPS simulator.
   Code to read a MIPS a.out file.
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


/* $Header: /home/primost/larus/Software/SPIM/RCS/read-aout.c,v 3.16 1993/05/05 13:41:43 larus Exp larus $
*/


#ifdef mips
#include <a.out.h>
#include <stdio.h>
#include <ldfcn.h>

int ldclose (LDFILE *);
char *ldgetname (LDFILE *, SYMR *);
void ldreadst (LDFILE *, int);
int ldtbread (LDFILE *, long, SYMR *);
#endif

#include "spim.h"
#include "spim-utils.h"
#include "inst.h"
#include "mem.h"
#include "data.h"
#include "parser.h"
#include "read-aout.h"
#include "sym-tbl.h"


/* Exported Variables: */

int program_break = 0;		/* Last address in data segment (edata) */


/* Imported Variables: */

extern int errno;



/* Read a MIPS executable file.  Return zero if successful and
   non-zero otherwise. */

#ifdef __STDC__
int
read_aout_file (char *file_name)
#else
int
read_aout_file (file_name)
     char *file_name;
#endif
{
#ifdef mips
  struct filehdr f_hdr;
  AOUTHDR header;
  FILE *fd;
  register int i;

  LDFILE *ldptr;
  SYMR sym;

  bare_machine = 1;		/* Before storing into memory */
  source_file = 0;

  fd = fopen (file_name, "r");
  if (fd == NULL)
    {
      error ("Cannot read the file: %s\n", file_name);
      return (1);
    }
  /* Read the filehdr: */
  if (fread (&f_hdr, 1, FILHSZ, fd) != FILHSZ)
    {
      error ("Executable file %s has bad file header\n", file_name);
      return (1);
    }
  /* Read the aouthdr: */
  if (fread (&header, 1, sizeof (AOUTHDR), fd) != sizeof (AOUTHDR))
    {
      error ("Executable file %s has bad aouthdr\n", file_name);
      return (1);
    }


  make_memory (header.tsize + header.text_start - TEXT_BOT,
	       header.dsize + header.data_start - DATA_BOT,
	       DATA_LIMIT, STACK_SIZE, STACK_LIMIT,
	       K_TEXT_SIZE, K_DATA_SIZE, K_DATA_LIMIT);

  /* Read file headers into memory. */
  fseek (fd, 0, SEEK_SET);

  text_begins_at_point (header.text_start);
  text_dir = 1;
  for (i = 0;i < header.tsize / 4; i ++)
    store_instruction (inst_decode (getw (fd)));
  text_dir = 0;
  if (feof (fd))
    {
      error ("Cannot read entire text segment: %s\n", file_name);
      return (1);
    }
  program_starting_address = header.entry;

  data_begins_at_point (header.data_start);
  for (i = 0;i < header.dsize / 4; i ++)
    store_word (getw (fd));
  if (feof (fd))
    error ("Cannot read entire data segment: %s\n", file_name);

  program_break = header.bss_start + header.bsize;

  fclose(fd);
  initialize_symbol_table ();
  if ((ldptr = ldopen (file_name, NULL)) != NULL)
    {
      if (SYMTAB(ldptr) != NULL)
	for (i = SYMHEADER (ldptr).isymMax;
	     i < SYMHEADER (ldptr).isymMax + SYMHEADER(ldptr).iextMax;
	     i++)
	  {
	    char *name;

	    ldtbread (ldptr, i, &sym);
	    name = (char *) ldgetname (ldptr, &sym);

	    record_label (name, sym.value);
	    make_label_global (name);
	  }
      ldclose(ldptr);
    }
#endif

  return (0);
}
