/* NeXTspim 1.0
   Copyright (C) 1994 by Mark Gritter (mgritter@gac.edu).
   
   SPIM S20 MIPS simulator.
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

/* SPIMInterface implementation
   replaces xspim.c and buttons.c */
   
#import "SPIMInterface.h"
#import <appkit/OpenPanel.h>
#import <appkit/Application.h>
#import <string.h>
#import "RunLoop.h"
#import <dpsclient/dpsclient.h>
#import "ContinuePanel.h"
#import "BreakpointsPanel.h"
#import "KeyQueue.h"
#import "ConsoleView.h"
#import <stdio.h>
#import "PrefsPanel.h"

/* Exported variables: */

/* Not local, but not export so all files don't need setjmp.h */
jmp_buf spim_top_level_env; /* For ^C */
int spim_is_running = 0;
reg_word R[32];
reg_word HI, LO;
mem_addr nPC, PC;
int HI_present, LO_present;
double *FPR;			/* Dynamically allocate so overlay */
float *FGR;			/* is possible */
int *FWR;			/* is possible */
int FP_reg_present;		/* Presence bits for FP registers */
int FP_reg_poison;		/* Poison bits for FP registers */
int FP_spec_load;		/* Is register waiting for a speculative ld */
reg_word CpCond[4], CCR[4][32], CPR[4][32];

int bare_machine;		/* Simulate bare instruction set */
int quiet;			/* No warning messages */
int source_file;		/* Program is source, not binary */
int message_out, console_out, console_in;
int mapped_io;			/* Non-zero => activate memory-mapped IO */
int pipe_out;
int cycle_level;		/* non-zero => cycle level mode */
int ptrace;
mem_addr program_starting_address;
long initial_text_size;
long initial_data_size;
long initial_data_limit;
long initial_stack_size;
long initial_stack_limit;
long initial_k_text_size;
long initial_k_data_size;
long initial_k_data_limit;

int load_trap_handler;
id idMainInterface, idPrefsPanel;
DPSTimedEntry teUpdateDisplay;
float TimeBetweenUpdate = 0.3;


/* Local functions: */

static char *check_buf_limit (char *, int *, int *);
static char *display_values (mem_addr from, mem_addr to, char *buf, int *limit,
			     int *n);
static char *display_insts (mem_addr from, mem_addr to, char *buf, int *limit,
			    int *n);
static mem_addr print_partial_line (mem_addr, char *, int *, int *);
static void show_running (void);

void InitUpdateDisplayLoop(void);
void KillUpdateDisplayLoop(void);

/* Flags to control the way that registers are displayed. */

int print_gpr_hex;		/* Print GPRs in hex/decimal */
int print_fpr_hex;		/* Print FPRs in hex/floating point */

/* Local variables: */

/*
static int console_is_visible;  --- it doesn't matter.
static char *ex_file_name = NULL;  --- no longer used.
static char *file_name = NULL;   --- ditto.
*/
static int stack_initialized = 0;

/***************
* IO FUNCTIONS *
***************/

int BufferLength = 0;
char **BufferedText;

void write_output (char *fmt, ...)
{
	va_list args;
	char io_buffer[IO_BUFFSIZE];
	va_start(args, fmt);
	vsprintf(io_buffer, fmt, args);
	va_end(args);
	/* If the display hasn't been updated for a while, wait for it to get emptied.  */
	while (BufferLength > 20) cthread_yield();
	mutex_lock(DisplayMutex);
	BufferLength++;
	if (BufferLength == 1) BufferedText = malloc(sizeof(char **));
	else BufferedText = realloc(BufferedText, BufferLength * sizeof(char **));
	BufferedText[BufferLength - 1] = malloc((strlen(io_buffer) + 1)* sizeof(char));
	strcpy(BufferedText[BufferLength - 1], io_buffer);
	mutex_unlock(DisplayMutex);
}

void read_input (char *str, int str_size) {
	/* Wait for a full line (terminated by enter) 
	   Of course, if the user wants to stop the program now,
	   we have to let him. */
	mutex_lock(DisplayMutex);
	DisplayNeedsUpdate = TRUE;  // Might as well...
	mutex_unlock(DisplayMutex);
	while ([[idMainInterface idKeyQ] fullLine] == NO) {
		mutex_unlock(RegisterMutex);
		cthread_yield();
		mutex_lock(RegisterMutex);
	}
	[[idMainInterface idKeyQ] putLineInto:str max:str_size];
	data_modified = 1;
}

int console_input_available(void) {
	return ![[idMainInterface idKeyQ] bufferEmpty];
}

char get_console_char(void) {
	/* Wait until there is at least one keystroke */
	while ([[idMainInterface idKeyQ] bufferEmpty] == YES) {
		cthread_yield();
	}
	return [[idMainInterface idKeyQ] getChar];
}

void put_console_char(char g) {
	char buffer[2];
	buffer[0] = g;
	buffer[1] = 0;
	write_output(buffer);
}


void error(char *fmt, ...)
{
	va_list args;
	char io_buffer[IO_BUFFSIZE];
	va_start(args, fmt);
	vsprintf(io_buffer, fmt, args);
	va_end(args);
	fprintf(stderr, io_buffer);
	write_output(io_buffer);
}

int run_error(char *fmt, ...)
{
	va_list args;
	char io_buffer[IO_BUFFSIZE];
	va_start(args, fmt);
	vsprintf(io_buffer, fmt, args);
	va_end(args);
	fprintf(stderr, io_buffer);
	write_output(io_buffer);
	if (spim_is_running)
		longjmp(spim_top_level_env, 1);
	return 0;
}

/* Display Update Function 
   Called every so often. */
   
void UpdateDisplayIfNeeded(DPSTimedEntry teNumber, double now, void *vmain) {
	int x;
	KillUpdateDisplayLoop();
	mutex_lock(DisplayMutex);
	if (DisplayNeedsUpdate) {
		[idMainInterface redisplayData];
		[idMainInterface redisplayText];
		[idMainInterface showRunning:spim_is_running];
		DisplayNeedsUpdate = NO;
	}
	if (ChangeStartStopButton) {
		if (spim_is_running == 1) {
			[[idMainInterface StartStopCell] setTitle:"Stop"];
		} else {
			[[idMainInterface StartStopCell] setTitle:"Run"];
		}
		ChangeStartStopButton = FALSE;
	}
	if (ChangeHighlight) {
		[idMainInterface center_text_at_PC];
		ChangeHighlight = FALSE;
	}
	if (BufferLength > 0) {
		for (x = 0; x < BufferLength; x++) {
			[idMainInterface writeOutput:BufferedText[x]];
			free(BufferedText[x]);
		}
		free(BufferedText);
		BufferLength = 0;
	}
	if (OpenContinueWindow) {
		[idContinuePanel open:PC];
		OpenContinueWindow = FALSE;
	}
	mutex_unlock(DisplayMutex);
	InitUpdateDisplayLoop();
}

void InitUpdateDisplayLoop(void) {
	teUpdateDisplay = DPSAddTimedEntry(TimeBetweenUpdate, &UpdateDisplayIfNeeded, NULL, NX_MODALRESPTHRESHOLD);
}

void KillUpdateDisplayLoop(void) {
	DPSRemoveTimedEntry(teUpdateDisplay);
}

/* Check to see if the buffer is getting too full and, if so,
   reallocate it. */

static char * check_buf_limit (char *buf, int *limit, int *n)
{
  *n += strlen (&buf[*n]);
  if ((*limit - *n) < 1*K)
    {
      *limit = 2 * *limit;
      if ((buf = (char *) realloc (buf, *limit)) == 0)
	fatal_error("realloc failed\n");
    }
  return (buf);
}

/* Write a printable representation of the instructions in memory
   address FROM...TO to buffer BUF, which is of size LIMIT and whose next
   free location is N.  Return the, possible realloc'ed, buffer. */

static char *
display_insts (mem_addr from, mem_addr to, char *buf, int *limit, int *n)
{
  instruction *inst;
  mem_addr i;

  for (i = from; i < to; i += 4)
    {
      READ_MEM_INST (inst, i);
      if (inst != NULL)
	{
	  *n += print_inst_internal (&buf[*n], 1*K, inst, i);
	  if ((*limit - *n) < 1*K)
	    {
	      *limit = 2 * *limit;
	      if ((buf = (char *) realloc (buf, *limit)) == 0)
		fatal_error ("realloc failed\n");
	    }
	}
    }
  return (buf);
}

/* Write a printable representation of the data in memory address
   FROM...TO to buffer BUF, which is of size LIMIT and whose next free
   location is N.  Return the, possible realloc'ed, buffer. */

static char * display_values (mem_addr from, mem_addr to, char *buf, int *limit, int *n)
{
  mem_word val;
  mem_addr i = ROUND (from, BYTES_PER_WORD);
  int j;

  i = print_partial_line (i, buf, limit, n);

  for ( ; i < to; )
    {
      /* Look for a block of 4 or more zero memory words */
      for (j = 0; i + j < to; j += BYTES_PER_WORD)
	{
	  READ_MEM_WORD (val, i + j);
	  if (val != 0)
	    break;
	}
      if (i + j < to)
	j -= BYTES_PER_WORD;

      if (j >= 4 * BYTES_PER_WORD)
	{
	  sprintf (&buf[*n], "[0x%08x]...[0x%08x]	0x00000000\n",
		   i, i + j);
	  buf = check_buf_limit (buf, limit, n);
	  i = i + j;

	  i = print_partial_line (i, buf, limit, n);
	}
      else
	{
	  /* Otherwise, print the next four words on a single line */
	  sprintf (&buf[*n], "[0x%08x]		      ", i);
	  *n += strlen (&buf[*n]);
	  do
	    {
	      READ_MEM_WORD (val, i);
	      sprintf (&buf[*n], "  0x%08x", val);
	      *n += strlen (&buf[*n]);
	      i += BYTES_PER_WORD;
	    }
	  while (i % BYTES_PER_LINE != 0);
	  sprintf (&buf[*n], "\n");
	  check_buf_limit (buf, limit, n);
	}
    }
  return (buf);
}


/* initialize the stack with the text in args */

static void init_stack (char *args)
{
  int argc = 0;
  char *argv[10000];
  char *a;

  if (stack_initialized)
    return;
  while (*args != '\0')
    {
      /* Skip leading blanks */
      while (*args == ' ' || *args == '\t') args++;
      /* First non-blank char */
      a = args;
      /* Last non-blank, non-null char */
      while (*args != ' ' && *args != '\t' && *args != '\0') args++;
      /* Terminate word */
      if (a != args)
	{
	  if (*args != '\0')
	    *args++ = '\0';	/* Null terminate */
	  argv [argc++] = a;
	}
    }
  initialize_run_stack (argc, argv);
  stack_initialized = 1;
}


/* Print out a line containing a fraction of a quadword.  */

static mem_addr print_partial_line (mem_addr i, char *buf, int *limit, int *n)
{
  mem_word val;

  if ((i % BYTES_PER_LINE) != 0)
    {
      sprintf (&buf[*n], "[0x%08x]		      ", i);
      buf = check_buf_limit (buf, limit, n);

      for (; (i % BYTES_PER_LINE) != 0; i += BYTES_PER_WORD)
	{
	  READ_MEM_WORD (val, i);
	  sprintf (&buf[*n], "  0x%08x", val);
	  buf = check_buf_limit (buf, limit, n);
	}

      sprintf (&buf[*n], "\n");
      check_buf_limit (buf, limit, n);
    }

  return (i);
}

void
read_file (char *name, int assembly_file)
{
  int error_flag = 0;

  if (*name == '\0')
    error_flag = 1;
  else if (assembly_file)
    error_flag = read_assembly_file (name);
#ifdef mips
  else
    {
      initialize_world (0);
#ifdef CL_SPIM
      cl_initialize_world (0);
#endif
      error_flag = read_aout_file (name);
    }
#endif
  if (!error_flag)
    {
      [idMainInterface redisplayText];
      [idMainInterface redisplayData];
    }
}

void show_running(void) {
	[idMainInterface showRunning:YES];
}

void print_pipeline(void) {
	[idMainInterface displayPipeline];
}

@implementation SPIMInterface

- appDidInit:sender {
	int x;
	SEL s = @selector(registerChanged:);
	/* Set target on Registers' text fields */
	for (x = 10; x <= 16; x++) {
		registersMain[x - 10] = [MainRegisters findViewWithTag:x];
		[[registersMain[x - 10] setTarget:self] setAction:s];
	}
	/* Link the text fields together so that you can move with tabs. */
	for (x = 10; x <= 15; x++) {
		[registersMain[x - 10] setNextText:registersMain[x - 9]];
	}
	[registersMain[6] setNextText:registersMain[0]];
	/* Now the General Registers */
	for (x = 100; x <= 131; x++) {
		registersGeneral[x - 100] = [Registers findViewWithTag:x];
		[[registersGeneral[x - 100] setTarget:self] setAction:s];
	}
	for (x = 100; x <= 130; x++) {
		[registersGeneral[x - 100] setNextText:registersGeneral[x - 99]];
	}
	[registersGeneral[31] setNextText:registersGeneral[0]];
	/* And the Floating Point Registers */
	/* Alternate double + single FPRs in this array. */
	for (x = 200; x <= 231; x += 2) {
		registersFloat[x - 200] = [Registers findViewWithTag:x];
		registersFloat[x - 199] = [Registers findViewWithTag:x + 100];
		[[registersFloat[x - 200] setTarget:self] setAction:s];
		[[registersFloat[x - 199] setTarget:self] setAction:s];
	}
	for (x = 200; x <= 229; x += 2) {
		[registersFloat[x - 200] setNextText:registersFloat[x - 198]];
		[registersFloat[x - 199] setNextText:registersFloat[x - 197]];
	}
	[registersFloat[30] setNextText:registersFloat[0]];
	[registersFloat[31] setNextText:registersFloat[1]];
	[Breakpoints setup];
	[Prefs loadPrefs];
	[[DataSegments idText] setEditable:NO];
	[[ICacheData idText] setEditable:NO];
	[[DCacheData idText] setEditable:NO];
	return self;
}

- init {
	[super init];
	idOpenPanel = [OpenPanel new];
	/* global variable */
	idMainInterface = self;
	return self;
}

- center_text_at_PC {
  int line, pos1, pos2;
  id text = [TextSegments idText];
  if (PC < TEXT_BOT || (PC > text_top && (PC < K_TEXT_BOT || PC > k_text_top))) {
  	[text setSel:0:0];
	[TextSegments setVertScroll:0.0];
	return 0;
  }
  
  /* Find start of line at PC: */
  if (PC < K_TEXT_BOT)
  	line = ((PC - TEXT_BOT) / BYTES_PER_WORD);
  else
    line = ((PC - K_TEXT_BOT) / BYTES_PER_WORD) + KernelStartLine;

  line++;  
  /* fprintf(stderr, "Positioning line %d of %d\n", line, TextEndLine); */
  
  pos1 = [text positionFromLine:line];			/* start of PC line */
  pos2 = [text positionFromLine:(line + 1)];
  /* end of line = start of next line*/
  
  /* select that line */
  [text setSel:pos1:pos2];
  
  /* move the ScrollView to that line */
  [TextSegments scrollLine:line];
  return self;
}

- displayCache {
	return self;
}


- displayDataSeg {
  char *buf = NULL;
  int limit, n;

  if (!data_modified)
    return NULL;
  if (buf == NULL)
    buf = (char *) malloc (16*K);
  *buf = '\0';
  limit = 16*K;
  n = 0;

  sprintf (&buf[n], "\n\tDATA\n");
  n += strlen (&buf[n]);
  buf = display_values (DATA_BOT, data_top, buf, &limit, &n);
  sprintf (&buf[n], "\n\tSTACK\n");
  n += strlen (&buf[n]);
  buf = display_values (R[29],
			STACK_TOP - 4096,
			buf,
			&limit,
			&n);
  sprintf (&buf[n], "\n\tKERNEL DATA\n");
  n += strlen (&buf[n]);
  buf = display_values (K_DATA_BOT, k_data_top, buf, &limit, &n);
  [DataSegments setText:buf];
  free(buf);
  data_modified = 0;
  return self;
}

long *RegAddr[7] = {(long *)&PC, &EPC, &Cause, &BadVAddr, &Status_Reg, &HI, &LO};

- displayRegisters {
	char buf[40];
	int i;
	char *grstr, *fpstr;
	
	/* Main Registers */
	
	for (i = 0; i < 7; i++) {
		sprintf(buf, "%08x", *(RegAddr[i]));
		[registersMain[i] setStringValue:buf];
	}
	
	/* General Registers */
	
	if (print_gpr_hex)
    	grstr = "%08x";
  	else
    	grstr = "%-10d";
	for (i = 0; i < 32; i++) {
		sprintf(buf, grstr, R[i]);
		[registersGeneral[i] setStringValue:buf];
	}
	
	/* Double Floating Point Registers 
	   -- use even numbered elements of registersFloat array */
	   
	if (print_fpr_hex)
    	fpstr = "%08x,%08x";
  	else
    	fpstr = "%-10.4f";
	if (print_fpr_hex) {
		int *r1, *r2;
    	for (i = 0; i < 16; i++) {
		/* Use pointers to cast to ints without invoking float->int conversion
		   so we can just print the bits. */
			r1 = (int *)&FGR[i]; r2 = (int *)&FGR[i+1];
			sprintf(buf, fpstr, *r1, *r2);
			[registersFloat[i * 2] setStringValue:buf];
		}
	} else {
		for (i = 0; i < 16; i ++) {
			sprintf(buf, fpstr, FPR[i]);
			[registersFloat[i * 2] setStringValue:buf];
		}
	}

	/* Single Floating Point Registers 
	   -- use odd numbered elements of registersFloat array */
	
	if (print_fpr_hex)
		fpstr = "%08x";
	else
    	fpstr = "%-10.4f";
	if (print_fpr_hex) {
		int *r1;
		/* Use pointers to cast to ints without invoking float->int conversion
	   	so we can just print the bits. */
		for (i = 0; i < 16; i++) {
			r1 = (int *)&FGR[i];
			sprintf(buf, fpstr, *r1);
			[registersFloat[i * 2 + 1] setStringValue:buf];
		 }
  	} else {
		for (i = 0; i < 16; i++) {
  		    sprintf(buf, fpstr, FGR[2*i]);
			[registersFloat[i * 2 + 1] setStringValue:buf];
	    }
	}
	return self;
}

- redisplayData {
  [self displayRegisters];
  [self displayDataSeg];
#ifdef CL_SPIM
  [self displayPipeline];
  [self displayCache:DATA_CACHE];
  [self displayCache:INST_CACHE];
#endif
  return self;
}


- redisplayText {
/* Redisplay the text segment and ktext segments. */
  char *buf = NULL;
  int limit, n;
  int KernelStartPos;
  id text;
  if (!text_modified)
    return NULL;
  if (buf == NULL)
    buf = (char *) malloc (16*K);
  *buf = '\0';
  limit = 16*K;
  n = 0;
  buf = display_insts (TEXT_BOT, text_top, buf, &limit, &n);
  sprintf (&buf[n], "\n\tKERNEL\n");
  n += strlen (&buf[n]);
  KernelStartPos = n;
  buf = display_insts (K_TEXT_BOT, k_text_top, buf, &limit, &n);
  [TextSegments setText:buf];
  /* Save line of start of Kernel code -- needed in center_text_at_PC */
  free(buf);
  text = [TextSegments idText];
  KernelStartLine = [text lineFromPosition:KernelStartPos];
  text_modified = 0;
  return self;
}


- showRunning:(BOOL)r {
	if (r == YES) {
		[MainWindow setTitle:"Running..."];
	} else {
		[MainWindow setTitle:"NeXTspim"];
	}
	return self;
}

- writeOutput:(char *)string {
	[Messages addText:string];
	return self;
}

- setEnabled:(BOOL)enable {
	[[Registers vertScroller] setEnabled:enable];
	[[TextSegments vertScroller] setEnabled:enable];
	[[TextSegments horizScroller] setEnabled:enable];
	[[DataSegments vertScroller] setEnabled:enable];
	[[Messages vertScroller] setEnabled:enable];
	return self;
}

- StartStopCell {return idStartStopCell;}

- idKeyQ {return [Messages queue];}

#define TAG_LOAD		1
#define TAG_RUN			2
#define TAG_STEP		3
#define TAG_CLEAR		4
#define TAG_CLEARALL	5
#define TAG_SETVALUE	6
#define TAG_BREAKPOINT	7
#define TAG_INTERRUPT

- MenuItem:sender {
	switch ([sender selectedTag]) {
		case TAG_LOAD:
			[self loadFile];
			break;
		case TAG_RUN:
			if (spim_is_running == 1) {
				StopRunLoop();
			} else {
				[self run:NO:NO];
			}
			break;
		case TAG_STEP:
			[self run:YES:NO];
			break;
		case TAG_CLEAR:
			[self clear:NO];
			break;
		case TAG_CLEARALL:
			[self clear:YES];
			break;
		default:
			{
				char buffer[80];
				sprintf(buffer, "Error:  Tag is #%d\n", [sender selectedTag]);
				[self writeOutput:buffer];
			}
			break;
	}
	return self;
}

- registerChanged:sender {
	int t = [sender selectedTag];
	if (t >= 10 && t <= 16) {
		sscanf([sender stringValue], "%X", &RegAddr[t - 10]);	
	} else if (t >= 100 && t <= 131) {
		if (print_gpr_hex) {
			sscanf([sender stringValue], "%X", &R[t - 100]);
		} else {
			R[t - 100] = [sender intValue];
		}
	} else if (t >= 200 && t <= 230) {
			FPR[(t - 200) / 2] = [sender floatValue];
	} else if (t >= 300 && t <= 330) {
			FGR[(t - 300)] = [sender floatValue];
	} else fprintf(stderr, "NeXTspim: bad sender tag %d in registerChanged.\n", t);
	[self displayRegisters];
	return self;
}

- loadFile {
	char *fileName;
	const char *types[2] = {"s", NULL};
	if ([idOpenPanel runModalForTypes:types]) {
		[self writeOutput:"Loading..."];
		fileName = [idOpenPanel filename];
		if (fileName != NULL) read_file(fileName, 1);
		PC = starting_address();
		if (PC == 0) PC = TEXT_BOT;
		[self redisplayData];
		[self center_text_at_PC];
		init_stack("\0");
		[self writeOutput:"Done!\n"];
	}
	return self;
}

- run:(BOOL)step:(BOOL)cont_bkpt {
	mem_addr addr;
	StopRunLoop();
	/* show the Message window */
	mutex_lock(DisplayMutex);
	[MessageWindow makeKeyAndOrderFront:self];
	mutex_unlock(DisplayMutex);
	/* flush the keyboard buffer -- we dont want previous chars showing up */
	[[self idKeyQ] flush];
	mutex_lock(RegisterMutex);
	/* set the address.  starting_address never seems to work... */
	addr = starting_address();
	if (addr == 0) addr = TEXT_BOT;
	RunPC = addr;
	if (step) RunSteps = 1; else RunSteps = 100;
	RunDisplay = 0;
	RunContBkpt = cont_bkpt;
	mutex_unlock(RegisterMutex);
	/* And off we go! */
	if (step) StepRunLoop();
	else StartRunLoop();
	return self;
}

- clear:(BOOL)clear_world {

  if (clear_world)
    {
      write_output ("Memory and registers cleared.\n\n");
      initialize_world (load_trap_handler && !bare_machine);
      write_startup_message ();
      stack_initialized = 0;
	  init_stack("\0");
	  [TextSegments setText:""];
	  [Breakpoints removeAllBreak];
#ifdef CL_SPIM
      cl_initialize_world (0);
#endif
    }
  else
    {
      [self writeOutput:"Registers cleared\n\n"];
#ifdef CL_SPIM
      cl_initialize_world (0);
#else
      initialize_registers ();
#endif
    }
  [self redisplayText];
  [self redisplayData];
  return self;
}

#ifdef CL_SPIM
- displayCache:(int)type {
	char *buf;
	switch (type) {
		case DATA_CACHE:
			if (!dcache_modified) return self;
			dcache_modified = 0;
			break;
		case INST_CACHE:
			if (!icache_modified) return self;
			icache_modified = 0;
			break;
	}
	if (!(buf = (char *) malloc (16*K))) {
		error ("Bad malloc on cache update.\n");
		return self;
    }
	*buf = '\0';
	print_cache_stats (buf, type);
	switch (type) {
		case DATA_CACHE:
			[DCacheStats setStringValue:buf];
			break;
		case INST_CACHE:
			[ICacheStats setStringValue:buf];
			break;
	}
	*buf = '\0';
	print_cache_data (buf, type);
	switch (type) {
		case DATA_CACHE:
			[DCacheData setText:buf];
			break;
		case INST_CACHE:
			[ICacheData setText:buf];
			break;
	}
	free (buf);
	return self;
}

- displayPipeline {
	char *buf;
	buf = (char *) malloc(8*K);
	*buf = '\0';
	print_pipeline_internal(buf);
	[Pipeline setText:buf];
	free(buf);
	return self;
}
#endif

@end
