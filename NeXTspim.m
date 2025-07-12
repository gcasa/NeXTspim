/* SPIM S20 MIPS simulator.
   NeXT interface to SPIM
   (Derived from X windows version)
   Copyright (C) 1990-1992 by James Larus (larus@cs.wisc.edu).
   NeXT code by Mark Gritter, 1993.
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


/* $Header: /home/primost/larus/Software/SPIM/RCS/xspim.c,v 3.70 1993/06/28 22:26:52 larus Exp larus $
 */

#include <stdio.h>
#include <setjmp.h>
#ifdef __STDC__
#include <stdarg.h>
#else
#include <varargs.h>
#endif

#include "spim.h"
#include "spim-utils.h"
#include "inst.h"
#include "mem.h"
#include "reg.h"
#include "y.tab.h"
#include "buttons.h"
#include "windows.h"
#include "read-aout.h"
#include "xspim.h"

#ifdef CL_SPIM
#include "cl-cache.h"
#include "cl-except.h"
#include "cl-tlb.h"
#include "cl-cycle.h"
#endif


typedef struct _AppResources
{
  String textFont;
  Boolean bare;
  Boolean asmm;
  Boolean trap;
  Boolean quiet;
  Boolean mapped_io;
#ifdef CL_SPIM
  Boolean cycle;
  Boolean icache;
  Boolean dcache;
  Boolean tlb;
#endif
  char *filename;
  char *ex_filename;
  char *display2;
  Boolean hex_gpr;
  Boolean hex_fpr;
  char *initial_data_limit;
  char *initial_data_size;
  char *initial_k_data_limit;
  char *initial_k_data_size;
  char *initial_k_text_size;
  char *initial_stack_limit;
  char *initial_stack_size;
  char *initial_text_size;
} AppResources;


/* Exported variables: */

/* Not local, but not export so all files don't need setjmp.h */
jmp_buf spim_top_level_env; /* For ^C */
reg_word R[32];
reg_word HI, LO;
int HI_present, LO_present;
mem_addr PC, nPC;
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

XtAppContext app_con;
Widget message, console;
#ifdef CL_SPIM
Widget pipeline;
#endif
XtAppContext app_context;
XFontStruct *text_font;
Dimension button_width;
int load_trap_handler;
Pixmap mark;


/* Local functions: */

#ifdef __STDC__
static void center_text_at_PC (void);
static char *check_buf_limit (char *, int *, int *);
static void display_data_seg (void);
static char *display_values (mem_addr from, mem_addr to, char *buf, int *limit,
			     int *n);
static char *display_insts (mem_addr from, mem_addr to, char *buf, int *limit,
			    int *n);
static void display_registers (void);
static void initialize (AppResources app_res);
static mem_addr print_partial_line (mem_addr, char *, int *, int *);
static void show_running (void);
static void syntax (char *program_name);
static void write_text_to_window (Widget w, char *s);

#ifdef CL_SPIM
static void display_pipeline (void);
static void display_cache (Widget stats, Widget data, int type);
#endif

#else
static void center_text_at_PC ();
static char *check_buf_limit ();
static void display_data_seg ();
static char *display_values ();
static char *display_insts ();
static void display_registers ();
static void initialize ();
static mem_addr print_partial_line ();
static void show_running ();
static void syntax ();
static void write_text_to_window ();

#ifdef CL_SPIM
static void display_pipeline ();
static void display_cache ();
#endif
#endif

static String fallback_resources[] =
{
  "*font:		*-courier-medium-r-normal--12-*-75-*",
  "*Label*font:		*-adobe-helvetica-bold-r-*-*-12-*-75-*",
  "*panel*font:		*-adobe-helvetica-medium-r-*-*-12-*-75-*",
  "*ShapeStyle:		Oval",
  "*dialog*value.translations: #override \\n <Key>Return: confirm()",
  "*.translations: #override \\n <Ctrl>C: control_c_seen()",
  "*Form*left:		ChainLeft",
  "*Form*right:		ChainLeft",
  "*Form*top:		ChainTop",
  "*Form*bottom:	ChainTop",
  "*console.label:	SPIM Console",
  "*Shell1*iconName:	SPIM Console",
#ifdef CL_SPIM
  "*terminal3.label:	SPIM Pipeline",
  "*Shell3*iconName:	SPIM Pipeline",
  "*terminal4.label:	SPIM Data Cache",
  "*Shell4*iconName:	SPIM Data Cache",
  "*terminal5.label:	SPIM Inst Cache",
  "*Shell5*iconName:	SPIM Inst Cache",
#endif
  NULL,
};


static XtActionsRec actionTable[2] =
{
  {"confirm", (XtActionProc) confirm},
  {"control_c_seen", (XtActionProc) control_c_seen},
};


static XtResource resources[23] =
{
  {XtNfont, XtCFont, XtRString, sizeof (char *),
     XtOffset (AppResources *, textFont), XtRString, NULL},
  {"bare", "Bare", XtRBoolean, sizeof (Boolean),
     XtOffset (AppResources *, bare), XtRImmediate, False},
  {"asm",  "Asm",  XtRBoolean, sizeof (Boolean),
     XtOffset (AppResources *, asmm), XtRImmediate, False},
  {"trap", "Trap", XtRBoolean, sizeof (Boolean),
     XtOffset (AppResources *, trap), XtRImmediate, (XtPointer) True},
  {"quiet", "Quiet", XtRBoolean, sizeof (Boolean),
     XtOffset (AppResources *, quiet), XtRImmediate, False},
  {"mapped_io", "Mapped_IO", XtRBoolean, sizeof (Boolean),
     XtOffset (AppResources *, mapped_io), XtRImmediate, False},

#ifdef CL_SPIM
  {"cycle", "Cycle", XtRBoolean, sizeof (Boolean),
     XtOffset (AppResources *, cycle), XtRImmediate, False},
  {"dcache", "DataCache", XtRBoolean, sizeof (Boolean),
     XtOffset (AppResources *, dcache), XtRImmediate, False},
  {"icache", "InstCache", XtRBoolean, sizeof (Boolean),
     XtOffset (AppResources *, icache), XtRImmediate, False},
  {"tlb", "TLB", XtRBoolean, sizeof (Boolean),
     XtOffset (AppResources *, tlb), XtRImmediate, False},
#endif

  {"filename", "Filename", XtRString, sizeof (char *),
     XtOffset (AppResources *, filename), XtRString, NULL},
  {"ex_filename", "Ex_Filename", XtRString, sizeof (char *),
     XtOffset (AppResources *, ex_filename), XtRString, NULL},
  {"display2", "Display2", XtRString, sizeof (char *),
     XtOffset (AppResources *, display2), XtRString, NULL},
  {"hexGpr", "DisplayHex", XtRBoolean, sizeof (Boolean),
     XtOffset (AppResources *, hex_gpr), XtRImmediate, (XtPointer) True},
  {"hexFpr", "DisplayHex", XtRBoolean, sizeof (Boolean),
     XtOffset (AppResources *, hex_fpr), XtRImmediate, False},

  {"stext", "Stext", XtRString, sizeof (char *),
     XtOffset (AppResources *, initial_text_size), XtRString, NULL},
  {"sdata", "Sdata", XtRString, sizeof (char *),
     XtOffset (AppResources *, initial_data_size), XtRString, NULL},
  {"ldata", "Ldata", XtRString, sizeof (char *),
     XtOffset (AppResources *, initial_data_limit), XtRString, NULL},
  {"sstack", "Sstack", XtRString, sizeof (char *),
     XtOffset (AppResources *, initial_stack_size), XtRString, NULL},
  {"lstack", "Lstack", XtRString, sizeof (char *),
     XtOffset (AppResources *, initial_stack_limit), XtRString, NULL},
  {"sktext", "Sktext", XtRString, sizeof (char *),
     XtOffset (AppResources *, initial_k_text_size), XtRString, NULL},
  {"skdata", "Skdata", XtRString, sizeof (char *),
     XtOffset (AppResources *, initial_k_data_size), XtRString, NULL},
  {"lkdata", "Lkdata", XtRString, sizeof (char *),
     XtOffset (AppResources *, initial_k_data_limit), XtRString, NULL}
};


static XrmOptionDescRec options[] =
{
  {"-bare",   "bare", XrmoptionNoArg, "True"},
  {"-asm",    "asmm",  XrmoptionNoArg, "True"},
  {"-trap",   "trap", XrmoptionNoArg, "True"},
  {"-notrap", "trap", XrmoptionNoArg, "False"},
  {"-quiet",  "quiet", XrmoptionNoArg, "True"},
  {"-noquiet","quiet", XrmoptionNoArg, "False"},
  {"-mapped_io",  "mapped_io", XrmoptionNoArg, "True"},
  {"-nomapped_io","mapped_io", XrmoptionNoArg, "False"},

#ifdef CL_SPIM
  {"-cycle",  "cycle", XrmoptionNoArg, "True"},
  {"-dcache", "dcache", XrmoptionNoArg, "True"},
  {"-nodcache", "dcache", XrmoptionNoArg, "False"},
  {"-icache", "icache", XrmoptionNoArg, "True"},
  {"-noicache", "icache", XrmoptionNoArg, "False"},
  {"-tlb",    "tlb", XrmoptionNoArg, "True"},
  {"-notlb",  "tlb", XrmoptionNoArg, "False"},
#endif

  {"-file",   "filename", XrmoptionSepArg, NULL},
  {"-execute","ex_filename", XrmoptionSepArg, NULL},
  {"-d2",     "display2", XrmoptionSepArg, NULL},
  {"-hexgpr", "hexGpr", XrmoptionNoArg, "True"},
  {"-nohexgpr", "hexGpr", XrmoptionNoArg, "False"},
  {"-hexfpr", "hexFpr", XrmoptionNoArg, "True"},
  {"-nohexfpr", "hexFpr", XrmoptionNoArg, "False"},
  {"-stext", "stext", XrmoptionSepArg, NULL},
  {"-sdata", "sdata", XrmoptionSepArg, NULL},
  {"-ldata", "ldata", XrmoptionSepArg, NULL},
  {"-sstack", "sstack", XrmoptionSepArg, NULL},
  {"-lstack", "lstack", XrmoptionSepArg, NULL},
  {"-sktext", "sktext", XrmoptionSepArg, NULL},
  {"-skdata", "skdata", XrmoptionSepArg, NULL},
  {"-lkdata", "lkdata", XrmoptionSepArg, NULL}
};


#define TICK_WIDTH 10

#define TICK_HEIGHT 10

static char tick_bits[] = {
  0x00, 0x00, 0x00, 0x02, 0x00, 0x03, 0x80, 0x01, 0xc1, 0x00, 0x63, 0x00,
  0x36, 0x00, 0x1c, 0x00, 0x08, 0x00, 0x00, 0x00};


/* Flags to control the way that registers are displayed. */

static int print_gpr_hex;		/* Print GPRs in hex/decimal */
static int print_fpr_hex;		/* Print FPRs in hex/floating point */


/* Local variables: */

static Dimension app_width;
static Dimension button_height;
static Dimension command_height;
static Dimension command_hspace;
static Dimension command_vspace;
static int console_is_visible;
static Dimension display_height;
static char *ex_file_name = NULL;
static char *file_name = NULL;
static Dimension reg_min_height;
static Dimension reg_max_height;
static Dimension segment_height;
static Widget shell1;
static int spim_is_running = 0;
static Widget toplevel;

#ifdef CL_SPIM
static Widget shell3;
static Widget toplevel_cache;
static Widget dcache_stats, icache_stats, dcache_data, icache_data;
static int pipeline_is_visible;
static int dcache_is_visible;
static int icache_is_visible;
#endif



#ifdef __STDC__
static void
initialize (AppResources app_res)
#else
static void
initialize (app_res)
     AppResources app_res;
#endif
{
  if (app_res.bare)
    bare_machine = 1;
  if (app_res.asmm)
    bare_machine = 0;
  if (app_res.trap)
    load_trap_handler = 1;
  else
    load_trap_handler = 0;

  if (app_res.quiet)
    quiet = 1;
  else
    quiet = 0;

  if (app_res.mapped_io)
    mapped_io = 1;
  else
    mapped_io = 0;

#ifdef CL_SPIM
  if (app_res.cycle)
    {
      cycle_level = 1;
      bare_machine = 1;
      load_trap_handler = 0;
    }
  else
    cycle_level = 0;
  if (app_res.dcache)
    dcache_on = 1;
  else
    dcache_on = 0;
  if (app_res.icache)
    icache_on = 1;
  else
    icache_on = 0;
  if (app_res.tlb)
    tlb_on = 1;
  else
    tlb_on = 0;
#endif

  if (app_res.filename)
    file_name = app_res.filename;
  if (app_res.ex_filename)
    {
      ex_file_name = app_res.ex_filename;
      load_trap_handler = 0;
    }

  if (app_res.textFont == NULL)
    app_res.textFont = XtNewString ("8x13");
  if (!(text_font = XLoadQueryFont (XtDisplay (toplevel), app_res.textFont)))
    fatal_error ("Cannot open font %s\n", app_res.textFont);

  mark = XCreateBitmapFromData (XtDisplay (toplevel),
				RootWindowOfScreen (XtScreen (toplevel)),
				tick_bits, TICK_WIDTH, TICK_HEIGHT);

  button_height = TEXTHEIGHT * 1.6;
  button_width = TEXTWIDTH * 12;
  app_width = 6 * (button_width + 16);
  if (app_width < TEXTWIDTH * 4 * 22) /* Register display width */
    app_width = TEXTWIDTH * 4 * 22;
  command_hspace = 8;
  command_vspace = 8;
#ifndef CL_SPIM
  command_height = (button_height * 2) + (command_vspace * 3) + 2;
#else
  command_height = (button_height * 3) + (command_vspace * 4) + 2;
#endif
  reg_min_height = 19 * TEXTHEIGHT + 4;
  reg_max_height = reg_min_height + 8 * TEXTHEIGHT + 4;
  segment_height = 10 * TEXTHEIGHT + 4;
  display_height = 8 * TEXTHEIGHT + 4;
  print_gpr_hex = app_res.hex_gpr;
  print_fpr_hex = app_res.hex_fpr;
}


#ifdef __STDC__
int
main (int argc, char **argv)
#else
int
main (argc, argv)
     int argc;
     char **argv;
#endif
{
  Widget toplevel2, pane1;
#ifdef CL_SPIM
  Widget toplevel3, pane3;
#endif
  AppResources app_res;
  Display *display;
  Arg args[10];
  Cardinal n;

  toplevel = XtAppInitialize (&app_context, "Xspim", options,
			      XtNumber (options), &argc, argv,
			      fallback_resources, NULL, ZERO);

  if (argc != 1)
    syntax (argv[0]);

  XtGetApplicationResources (toplevel, (XtPointer) &app_res, resources,
			     XtNumber (resources), NULL, ZERO);

  if (app_res.display2 == NULL)
    display = XtDisplay (toplevel);
  else
    display = XtOpenDisplay (app_context, app_res.display2, "xspim",
			     "Xspim", NULL, ZERO, &argc, argv);

  toplevel2 = XtAppCreateShell ("xspim","Xspim",applicationShellWidgetClass,
				display, NULL, ZERO);

#ifdef CL_SPIM
  toplevel3 = XtAppCreateShell ("xspim","Xspim",applicationShellWidgetClass,
				display, NULL, ZERO);
  toplevel_cache = XtAppCreateShell ("xspim","Xspim",
				     applicationShellWidgetClass, display,
				     NULL, ZERO);
#endif

  XtAppAddActions (app_context, actionTable, XtNumber (actionTable));

  initialize (app_res);

  /* Console window */

  shell1 = XtCreatePopupShell ("Shell1", topLevelShellWidgetClass,
			       toplevel, NULL, ZERO);
  pane1 = XtCreateManagedWidget ("pane1", panedWidgetClass, shell1,
				 NULL, ZERO);
  n = 0;
  XtSetArg (args[n], XtNeditType, XawtextAppend); n++;
  XtSetArg (args[n], XtNscrollVertical, XawtextScrollWhenNeeded); n++;
  XtSetArg (args[n], XtNpreferredPaneSize, TEXTHEIGHT * 24); n++;
  XtSetArg (args[n], XtNwidth, TEXTWIDTH * 80); n++;
  console = XtCreateManagedWidget ("console", asciiTextWidgetClass, pane1,
				   args, n);
  XawTextEnableRedisplay (console);
  console_out = (int) console;

#ifdef CL_SPIM
  /* Pipeline window */

  shell3 = XtCreatePopupShell ("Shell3", topLevelShellWidgetClass,
			       toplevel3, NULL, ZERO);
  pane3 = XtCreateManagedWidget ("pane3", panedWidgetClass, shell3,
				 NULL, ZERO);
  n = 0;
  XtSetArg (args[n], XtNtype, XawAsciiString); n++;
  XtSetArg (args[n], XtNeditType, XawtextRead); n++;
  XtSetArg (args[n], XtNpreferredPaneSize, TEXTHEIGHT * 20); n++;
  XtSetArg (args[n], XtNwidth, TEXTWIDTH * 70); n++;
  XtSetArg (args[n], XtNstring, ""); n++;
  XtSetArg (args[n], XtNborderWidth, 0); n++;
  XtSetArg (args[n], XtNdisplayCaret, False); n++;
  pipeline = XtCreateManagedWidget ("pipeline", asciiTextWidgetClass, pane3,
				    args, n);
#endif

  create_sub_windows (toplevel, app_width, reg_min_height, reg_max_height,
		      command_height, command_hspace, command_vspace,
		      button_height, segment_height, display_height);

  XtRealizeWidget (toplevel);

  if (app_res.initial_text_size != NULL)
    initial_text_size = atoi (app_res.initial_text_size);
  if (app_res.initial_data_size != NULL)
    initial_data_size = atoi (app_res.initial_data_size);
  if (app_res.initial_data_limit != NULL)
    initial_data_limit = atoi (app_res.initial_data_limit);
  if (app_res.initial_stack_size != NULL)
    initial_stack_size = atoi (app_res.initial_stack_size);
  if (app_res.initial_stack_limit != NULL)
    initial_stack_limit = atoi (app_res.initial_stack_limit);
  if (app_res.initial_k_text_size != NULL)
    initial_k_text_size = atoi (app_res.initial_k_text_size);
  if (app_res.initial_k_data_size != NULL)
    initial_k_data_size = atoi (app_res.initial_k_data_size);
  if (app_res.initial_k_data_limit != NULL)
    initial_k_data_limit = atoi (app_res.initial_k_data_limit);
  initialize_world (load_trap_handler);
  write_startup_message ();
#ifdef CL_SPIM
  cl_initialize_world ();
#endif

  if (file_name)
    {
      read_file (file_name, 1);
      record_file_name_for_prompt (file_name);
    }
  else if (ex_file_name)
    {
      initialize_world (0);	/* Don't have a trap handler loaded. */
#ifdef CL_SPIM
      cl_initialize_world (0);
#endif
      read_file (ex_file_name, 0);
      record_file_name_for_prompt (ex_file_name);
    }
  else
    {
      redisplay_text ();
      redisplay_data ();
    }

  XtAppMainLoop (app_context);
  return (0);
}


#ifdef __STDC__
static void
syntax (char *program_name)
#else
static void
syntax (program_name)
     char *program_name;
#endif
{
  XtDestroyApplicationContext (app_context);
  fprintf (stderr, "Usage:\n %s", program_name);
  fprintf (stderr, "\t[ -bare/-asm ] [ -trap/-notrap ] [ -quiet/noquiet ]\n");
  fprintf (stderr, "\t[ -mapped_io/-nomapped_io ]\n");
  fprintf (stderr, "\t[ -d2 <display> ] [ -file/-execute <filename> ]\n");
  fprintf (stderr, "\t[ -s<seg> <size>] [ -l<seg> <size>]\n");
  exit (1);
}


#ifdef __STDC__
void
control_c_seen (int arg)
#else
void
control_c_seen (arg)
int arg;
#endif
{
  write_output (message_out, "\nExecution interrupted\n");
  redisplay_data ();
  continue_prompt (1);
  if (spim_is_running)
    longjmp (spim_top_level_env, 1);
}


#ifdef __STDC__
void
popup_console (Widget w, XtPointer client_data, XtPointer call_data)
#else
void
popup_console (w, client_data, call_data)
     Widget w;
     XtPointer client_data, call_data;
#endif
{
  if (console_is_visible)
    {
      console_is_visible = 0;
      XtPopdown (shell1);
    }
  else
    {
      console_is_visible = 1;
      XtPopup (shell1, XtGrabNone);
    }
}


#ifdef CL_SPIM
#ifdef __STDC__
void
popup_pipeline (Widget w, XtPointer client_data, XtPointer call_data)
#else
void
popup_pipeline (w, client_data, call_data)
     Widget w;
     XtPointer client_data, call_data;
#endif
{
  if (pipeline_is_visible)
    {
      pipeline_is_visible = 0;
      XtPopdown (shell3);
    }
  else
    {
      pipeline_is_visible = 1;
      XtPopup (shell3, XtGrabNone);
      display_pipeline ();
    }
}


#ifdef __STDC__
void
pop_dcache (Widget w, XtPointer client_data, XtPointer call_data)
#else
void
pop_dcache (w, client_data, call_data)
     Widget w;
     XtPointer client_data, call_data;
#endif
{
  static Widget shell = NULL;
  Widget pane;
  Arg args[10];
  int n;

  if (dcache_is_visible)
    {
      dcache_is_visible = 0;
      XtDestroyWidget (shell);
    }
  else
    {
      dcache_is_visible = 1;

      shell = XtCreatePopupShell ("SPIM Data Cache", topLevelShellWidgetClass,
				  toplevel_cache, NULL, ZERO);
      pane = XtCreateManagedWidget ("Pane", panedWidgetClass, shell,
				    NULL, ZERO);

      n = 0;
      XtSetArg (args[n], XtNtype, XawAsciiString); n++;
      XtSetArg (args[n], XtNeditType, XawtextRead); n++;
      XtSetArg (args[n], XtNpreferredPaneSize, TEXTHEIGHT * 3); n++;
      XtSetArg (args[n], XtNwidth, TEXTWIDTH*35); n++;
      XtSetArg (args[n], XtNstring, ""); n++;
      XtSetArg (args[n], XtNborderWidth, 0); n++;
      XtSetArg (args[n], XtNdisplayCaret, False); n++;
      dcache_stats = XtCreateManagedWidget ("dcache_stats",
					    asciiTextWidgetClass,pane,args,n);

      n = 0;
      XtSetArg (args[n], XtNtype, XawAsciiString); n++;
      XtSetArg (args[n], XtNeditType, XawtextRead); n++;
      XtSetArg (args[n], XtNscrollVertical, XawtextScrollWhenNeeded); n++;
      XtSetArg (args[n], XtNpreferredPaneSize, TEXTHEIGHT * 15); n++;
      XtSetArg (args[n], XtNwidth, TEXTWIDTH*35); n++;
      XtSetArg (args[n], XtNstring, ""); n++;
      XtSetArg (args[n], XtNborderWidth, 0); n++;
      XtSetArg (args[n], XtNdisplayCaret, False); n++;
      dcache_data = XtCreateManagedWidget ("dcache_data",
					   asciiTextWidgetClass,pane,args,n);
      XtPopup (shell, XtGrabNone);

      dcache_modified = 1;
      display_cache (dcache_stats, dcache_data, DATA_CACHE);
    }
}


#ifdef __STDC__
void
pop_icache (Widget w, XtPointer client_data, XtPointer call_data)
#else
void
pop_icache (w, client_data, call_data)
     Widget w;
     XtPointer client_data, call_data;
#endif
{
  static Widget shell = NULL;
  Widget pane;
  Arg args[10];
  int n;

  if (icache_is_visible)
    {
      icache_is_visible = 0;
      XtDestroyWidget (shell);
    }
  else
    {
      icache_is_visible = 1;

      shell = XtCreatePopupShell ("SPIM Instruction Cache",
				  topLevelShellWidgetClass, toplevel_cache,
				  NULL, ZERO);
      pane = XtCreateManagedWidget ("Pane", panedWidgetClass, shell,
				    NULL, ZERO);

      n = 0;
      XtSetArg (args[n], XtNtype, XawAsciiString); n++;
      XtSetArg (args[n], XtNeditType, XawtextRead); n++;
      XtSetArg (args[n], XtNpreferredPaneSize, TEXTHEIGHT * 3); n++;
      XtSetArg (args[n], XtNwidth, TEXTWIDTH*35); n++;
      XtSetArg (args[n], XtNstring, ""); n++;
      XtSetArg (args[n], XtNborderWidth, 0); n++;
      XtSetArg (args[n], XtNdisplayCaret, False); n++;
      icache_stats = XtCreateManagedWidget ("icache_stats",
					    asciiTextWidgetClass,pane,args,n);

      n = 0;
      XtSetArg (args[n], XtNtype, XawAsciiString); n++;
      XtSetArg (args[n], XtNeditType, XawtextRead); n++;
      XtSetArg (args[n], XtNscrollVertical, XawtextScrollWhenNeeded); n++;
      XtSetArg (args[n], XtNpreferredPaneSize, TEXTHEIGHT * 15); n++;
      XtSetArg (args[n], XtNwidth, TEXTWIDTH*35); n++;
      XtSetArg (args[n], XtNstring, ""); n++;
      XtSetArg (args[n], XtNborderWidth, 0); n++;
      XtSetArg (args[n], XtNdisplayCaret, False); n++;
      icache_data = XtCreateManagedWidget ("icache_data",
					   asciiTextWidgetClass,pane,args,n);
      XtPopup (shell, XtGrabNone);

      icache_modified = 1;
      display_cache (icache_stats, icache_data, INST_CACHE);
    }
}
#endif


#ifdef __STDC__
void
read_file (char *name, int assembly_file)
#else
void
read_file (name, assembly_file)
     char *name;
     int assembly_file;
#endif
{
  int error_flag;

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
      redisplay_text ();
      redisplay_data ();
    }
}


#ifdef __STDC__
void
start_program (mem_addr addr)
#else
void
start_program (addr)
     mem_addr addr;
#endif
{
  if (addr == 0)
    addr = starting_address ();

  if (addr != 0)
    execute_program (addr, DEFAULT_RUN_STEPS, 0, 0);
}


#ifdef __STDC__
void
execute_program (mem_addr pc, int steps, int display, int cont_bkpt)
#else
void
execute_program (pc, steps, display, cont_bkpt)
     mem_addr pc;
     int steps, display, cont_bkpt;
#endif
{
  if (!setjmp (spim_top_level_env))
    {
      spim_is_running = 1;
      show_running ();
#ifdef CL_SPIM
      if (cycle_level == 1)
	{
	  cl_run_program (pc, steps, 0 /*display*/);
	}
      else
#endif
      if (run_program (pc, steps, display, cont_bkpt))
	continue_prompt (0);
    }
  spim_is_running = 0;
  center_text_at_PC ();
  redisplay_data ();
}


#ifdef __STDC__
static void
show_running (void)
#else
static void
show_running ()
#endif
{
  Arg args[1];

  XtSetArg (args[0], XtNstring, "Running.....");
  XtSetValues (register_window, args, ONE);
}


/* Redisplay the contents of the registers and, if modified, the data
   and stack segments. */

#ifdef __STDC__
void
redisplay_data (void)
#else
void
redisplay_data ()
#endif
{
  display_registers ();
  display_data_seg ();
#ifdef CL_SPIM
  if (pipeline_is_visible) display_pipeline ();
  if (dcache_is_visible)
    display_cache (dcache_stats, dcache_data, DATA_CACHE);
  if (icache_is_visible)
    display_cache (icache_stats, icache_data, INST_CACHE);
#endif
}


/* Redisplay the contents of the registers in a wide variety of
   formats. */

#ifdef __STDC__
static void
display_registers (void)
#else
static void
display_registers ()
#endif
{
  int i;
  static String buf = NULL;
  String bufp;
  char *grstr, *fpstr;
  char *grfill, *fpfill;
  Arg args [2];
  static char *reg_names[] = {"r0", "at", "v0", "v1", "a0", "a1", "a2", "a3",
			      "t0", "t1", "t2", "t3", "t4", "t5", "t6", "t7",
			      "s0", "s1", "s2", "s3", "s4", "s5", "s6", "s7",
			      "t8", "t9", "k0", "k1", "gp", "sp", "s8", "ra"};

  if (buf == NULL)
    buf = (String) malloc (8 * K);
  *buf = '\0';
  bufp = buf;

  sprintf (bufp, " PC     = %08x    ", PC); bufp += strlen (bufp);
  sprintf (bufp, " EPC    = %08x    ", EPC); bufp += strlen (bufp);
  sprintf (bufp, " Cause  = %08x    ", Cause); bufp += strlen (bufp);
  sprintf (bufp, " BadVAddr= %08x\n", BadVAddr); bufp += strlen (bufp);
  sprintf (bufp, " Status = %08x    ", Status_Reg); bufp += strlen (bufp);
  sprintf (bufp, " HI     = %08x    ", HI); bufp += strlen (bufp);
  sprintf (bufp, " LO     = %08x\n", LO); bufp += strlen (bufp);

  if (print_gpr_hex)
    grstr = "R%-2d (%2s) = %08x", grfill = "  ";
  else
    grstr = "R%-2d (%2s) = %-10d", grfill = " ";
  sprintf (bufp, "\t\t\t\t General Registers\n"); bufp += strlen (bufp);
  for (i = 0; i < 8; i++)
    {
      sprintf (bufp, grstr, i, reg_names[i], R[i]);
      bufp += strlen (bufp);
      sprintf (bufp, grfill); bufp += strlen (bufp);
      sprintf (bufp, grstr, i+8, reg_names[i+8], R[i+8]);
      bufp += strlen (bufp);
      sprintf (bufp, grfill); bufp += strlen (bufp);
      sprintf (bufp, grstr, i+16, reg_names[i+16], R[i+16]);
      bufp += strlen (bufp);
      sprintf (bufp, grfill); bufp += strlen (bufp);
      sprintf (bufp, grstr, i+24, reg_names[i+24], R[i+24]);
      bufp += strlen (bufp);
      sprintf (bufp, "\n");
      bufp += 1;
    }

  if (print_fpr_hex)
    fpstr = "FP%-2d=%08x,%08x", fpfill = " ";
  else
    fpstr = "FP%-2d = %-10.4f", fpfill = "  ";
  sprintf (bufp, "\t\t\t      Double Floating Point Registers\n");
  bufp += strlen (bufp);
  if (print_fpr_hex)
    for (i = 0; i < 4; i += 1)
      {
	int *r1, *r2;

	/* Use pointers to cast to ints without invoking float->int conversion
	   so we can just print the bits. */
	r1 = (int *)&FGR[i]; r2 = (int *)&FGR[i+1];
	sprintf (bufp, fpstr, 2*i, *r1, *r2); bufp += strlen (bufp);
	sprintf (bufp, fpfill); bufp += strlen (bufp);

	r1 = (int *)&FGR[i+4]; r2 = (int *)&FGR[i+4+1];
	sprintf (bufp, fpstr, 2*i+8, *r1, *r2); bufp += strlen (bufp);
	sprintf (bufp, fpfill); bufp += strlen (bufp);

	r1 = (int *)&FGR[i+8]; r2 = (int *)&FGR[i+8+1];
	sprintf (bufp, fpstr, 2*i+16, *r1, *r2); bufp += strlen (bufp);
	sprintf (bufp, fpfill); bufp += strlen (bufp);

	r1 = (int *)&FGR[i+12]; r2 = (int *)&FGR[i+12+1];
	sprintf (bufp, fpstr, 2*i+24, *r1, *r2); bufp += strlen (bufp);
	sprintf (bufp, "\n"); bufp += 1;
      }
  else for (i = 0; i < 4; i += 1)
    {
      sprintf (bufp, fpstr, 2*i, FPR[i]);
      bufp += strlen (bufp);
      sprintf (bufp, fpfill); bufp += strlen (bufp);
      sprintf (bufp, fpstr, 2*i+8, FPR[i+4]);
      bufp += strlen (bufp);
      sprintf (bufp, fpfill); bufp += strlen (bufp);
      sprintf (bufp, fpstr, 2*i+16, FPR[i+8]);
      bufp += strlen (bufp);
      sprintf (bufp, fpfill); bufp += strlen (bufp);
      sprintf (bufp, fpstr, 2*i+24, FPR[i+12]);
      bufp += strlen (bufp);
      sprintf (bufp, "\n");
      bufp += 1;
    }

  if (print_fpr_hex)
    fpstr = "FP%-2d=%08x", fpfill = " ";
  else
    fpstr = "FP%-2d = %-10.4f", fpfill = "  ";
  sprintf (bufp, "\t\t\t      Single Floating Point Registers\n");
  bufp += strlen (bufp);
  if (print_fpr_hex)
    for (i = 0; i < 4; i += 1)
      {
	int *r1;

	/* Use pointers to cast to ints without invoking float->int conversion
	   so we can just print the bits. */
	r1 = (int *)&FGR[i];
	sprintf (bufp, fpstr, 2*i, *r1); bufp += strlen (bufp);
	sprintf (bufp, fpfill); bufp += strlen (bufp);

	r1 = (int *)&FGR[i+4];
	sprintf (bufp, fpstr, 2*i+8, *r1); bufp += strlen (bufp);
	sprintf (bufp, fpfill); bufp += strlen (bufp);

	r1 = (int *)&FGR[i+8];
	sprintf (bufp, fpstr, 2*i+16, *r1); bufp += strlen (bufp);
	sprintf (bufp, fpfill); bufp += strlen (bufp);

	r1 = (int *)&FGR[i+12];
	sprintf (bufp, fpstr, 2*i+24, *r1); bufp += strlen (bufp);
	sprintf (bufp, "\n"); bufp += 1;
      }
  else for (i = 0; i < 4; i += 1)
    {
      sprintf (bufp, fpstr, 2*i, FGR[2*i]);
      bufp += strlen (bufp);
      sprintf (bufp, fpfill); bufp += strlen (bufp);
      sprintf (bufp, fpstr, 2*(i+4), FGR[2*(i+4)]);
      bufp += strlen (bufp);
      sprintf (bufp, fpfill); bufp += strlen (bufp);
      sprintf (bufp, fpstr, 2*(i+8), FGR[2*(i+8)]);
      bufp += strlen (bufp);
      sprintf (bufp, fpfill); bufp += strlen (bufp);
      sprintf (bufp, fpstr, 2*(i+12), FGR[2*(i+12)]);
      bufp += strlen (bufp);
      sprintf (bufp, "\n");
      bufp += 1;
    }
  XtSetArg (args[0], XtNstring, buf);
  XtSetArg (args[1], XtNlength, 8*K);
  XtSetValues (register_window, args, TWO);
}


/* Redisplay the text segment and ktext segments. */

#ifdef __STDC__
void
redisplay_text (void)
#else
void
redisplay_text ()
#endif
{
  static String buf = NULL;
  int limit, n;
  Arg args [2];

  if (!text_modified)
    return;
  if (buf == NULL)
    buf = (String) malloc (16*K);
  *buf = '\0';
  limit = 16*K;
  n = 0;
  buf = display_insts (TEXT_BOT, text_top, buf, &limit, &n);
  sprintf (&buf[n], "\n\tKERNEL\n");
  n += strlen (&buf[n]);
  buf = display_insts (K_TEXT_BOT, k_text_top, buf, &limit, &n);

  XtSetArg (args[0], XtNstring, buf);
  XtSetArg (args[1], XtNlength, limit);
  XtSetValues (text_window, args, TWO);
  text_modified = 0;
}


/* Write a printable representation of the instructions in memory
   address FROM...TO to buffer BUF, which is of size LIMIT and whose next
   free location is N.  Return the, possible realloc'ed, buffer. */

#ifdef __STDC__
static char *
display_insts (mem_addr from, mem_addr to, char *buf, int *limit, int *n)
#else
static char *
display_insts (from, to, buf, limit, n)
     mem_addr from, to;
     char *buf;
     int *limit, *n;
#endif
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


/* Center the text window at the instruction at the current PC and
   highlight the instruction. */

#ifdef __STDC__
static void
center_text_at_PC (void)
#else
static void
center_text_at_PC ()
#endif
{
  char buf[100];
  XawTextBlock text;
  XawTextPosition start, finish;
  static mem_addr prev_PC = 0;
  XRectangle cursor_loc;
  Arg args[10];
  static Widget text_window_sink = 0;
  static int highlight_x = -1, highlight_y;
  static XawTextPosition highlight_start, highlight_finish;

  if (text_window_sink == 0)
    {
      XtSetArg (args[0], XtNtextSink, &text_window_sink);
      XtGetValues (text_window, args, ONE);
    }

  if (highlight_x != -1)
    {
      XawTextSinkDisplayText (text_window_sink,
			      highlight_x, highlight_y,
			      highlight_start, highlight_finish, 0);
      highlight_x = -1;
    }

  if (PC < TEXT_BOT || (PC > text_top && (PC < K_TEXT_BOT || PC > k_text_top)))
    return;

  sprintf (buf, "\n[0x%08x]", PC);
  text.firstPos = 0;
  text.length = strlen (buf);
  text.ptr = buf;
  text.format = FMT8BIT;

  /* Find start of line at PC: */
  start = XawTextSearch (text_window, prev_PC <= PC ? XawsdRight : XawsdLeft,
			 &text);
  if (start == XawTextSearchError)
    return;

  XawTextSetInsertionPoint (text_window, start);

  /* Find start of following line: */
  sprintf (buf, "\n[0x%08x]", PC + BYTES_PER_WORD);
  finish = XawTextSearch (text_window, XawsdRight, &text);
  if (finish == XawTextSearchError)
    return;

  /* Find PC line's location in the window: */
  XawTextSetInsertionPoint (text_window, start + 1);
  XawTextSinkGetCursorBounds (text_window_sink, &cursor_loc);
  highlight_x = cursor_loc.x + cursor_loc.width/2;
  XawTextSetInsertionPoint (text_window, start);
  XawTextSinkGetCursorBounds (text_window_sink, &cursor_loc);
  highlight_y = cursor_loc.y + cursor_loc.height;
  highlight_start = start;
  highlight_finish = finish;


  /* Highlight the line: */
  XawTextSinkDisplayText (text_window_sink,
			  highlight_x, highlight_y,
			  highlight_start, highlight_finish, 1);

  XawTextSetInsertionPoint (text_window, start);
  prev_PC = PC;
}


/* Display the contents of the data and stack segments, if they have
   been modified. */

#ifdef __STDC__
static void
display_data_seg (void)
#else
static void
display_data_seg ()
#endif
{
  static String buf = NULL;
  int limit, n;
  Arg args [2];

  if (!data_modified)
    return;
  if (buf == NULL)
    buf = (String) malloc (16*K);
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

  XtSetArg (args[0], XtNstring, buf);
  XtSetArg (args[1], XtNlength, limit);
  XtSetValues (data_window, args, TWO);
  data_modified = 0;
}


#ifdef CL_SPIM
#ifdef __STDC__
static void
display_pipeline (void)
#else
static void
display_pipeline ()
#endif
{
  char *buf;
  int limit;
  Arg args [2];

  buf = (char *) malloc (8*K);
  *buf = '\0';
  limit = 8*K;

  print_pipeline_internal (buf);
  XtSetArg (args[0], XtNstring, buf);
  XtSetArg (args[1], XtNlength, limit);
  XtSetValues (pipeline, args, TWO);
  free (buf);
}


#ifdef __STDC__
static void
display_cache (Widget stats, Widget data, int type)
#else
static void
display_cache (stats, data, type)
Widget stats, data;
#endif
{
  char *buf;
  int limit;
  Arg args [3];

  switch (type)
    {
    case DATA_CACHE:
      if (!dcache_modified) return;
      dcache_modified = 0;
      break;
    case INST_CACHE:
      if (!icache_modified) return;
      icache_modified = 0;
      break;
    }

  if (! (buf = (char *) malloc (16*K)))
    {
      error ("Bad malloc on cache update.\n");
      return;
    }
  limit = 16*K;

  *buf = '\0';
  print_cache_stats (buf, type);
  XtSetArg (args[0], XtNstring, buf);
  XtSetArg (args[1], XtNlength, limit);
  XtSetValues (stats, args, TWO);

  *buf = '\0';
  print_cache_data (buf, type);
  XtSetArg (args[0], XtNstring, buf);
  XtSetArg (args[1], XtNlength, limit);
  XtSetValues (data, args, TWO);

  free (buf);
}
#endif


#define BYTES_PER_LINE (4*BYTES_PER_WORD)


/* Write a printable representation of the data in memory address
   FROM...TO to buffer BUF, which is of size LIMIT and whose next free
   location is N.  Return the, possible realloc'ed, buffer. */

#ifdef __STDC__
static char *
display_values (mem_addr from, mem_addr to, char *buf, int *limit, int *n)
#else
static char *
display_values (from, to, buf, limit, n)
     mem_addr from, to;
     char *buf;
     int *limit, *n;
#endif
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



/* Check to see if the buffer is getting too full and, if so,
   reallocate it. */

#ifdef __STDC__
static char *
check_buf_limit (char *buf, int *limit, int *n)
#else
static char *
check_buf_limit (buf, limit, n)
     char *buf;
     int *limit, *n;
#endif
{
  *n += strlen (&buf[*n]);
  if ((*limit - *n) < 1*K)
    {
      *limit = 2 * *limit;
      if ((buf = (char *) realloc (buf, *limit)) == 0)
	fatal_error ("realloc failed\n");
    }
  return (buf);
}



/* Print out a line containing a fraction of a quadword.  */

#ifdef __STDC__
static mem_addr
print_partial_line (mem_addr i, char *buf, int *limit, int *n)
#else
static mem_addr
print_partial_line (i, buf, limit, n)
     mem_addr i;
     char *buf;
     int *limit, *n;
#endif
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




/* IO facilities: */


#ifdef __STDC__
void
write_output (long fp, char *fmt, ...)
#else
/*VARARGS0*/
void
write_output (va_alist)
va_dcl
#endif
{
  va_list args;
  Widget w;
#ifndef __STDC__
  char *fmt;
  long fp;
#endif
  char io_buffer [IO_BUFFSIZE];

#ifdef __STDC__
  va_start (args, fmt);
#else
  va_start (args);
  fp = va_arg (args, long);
  fmt = va_arg (args, char *);
#endif
  w = (Widget) fp;		/* Not too portable... */

  if (w == console && !console_is_visible)
    {
      XtPopup (shell1, XtGrabNone);
      console_is_visible = 1;
    }

  vsprintf (io_buffer, fmt, args);
  va_end (args);

  write_text_to_window (w, io_buffer);

  /* Look for keyboard input (such as ^C) */
  while (XtAppPending (app_context))
    {
      XEvent event;

      XtAppNextEvent (app_context, &event);
      XtDispatchEvent (&event);
    }
}


/* Simulate the semantics of fgets, not gets, on an x-window. */

#ifdef __STDC__
void
read_input (char *str, int str_size)
#else
void
read_input (str, str_size)
     char *str;
     int str_size;
#endif
{
  char buffer[11];
  KeySym key;
  XComposeStatus compose;
  XEvent event;
  char *ptr;

  ptr = str;
  str_size -= 1;		/* Reserve space for null */

  if (!console_is_visible)
    {
      XtPopup (shell1, XtGrabNone);
      console_is_visible = 1;
    }

  while (1)
    {
      XtAppNextEvent (app_context, &event);
      if (event.type == KeyPress)
	{
	  int chars = XLookupString (&event.xkey, buffer, 10, &key, &compose);
	  if ((key == XK_Return) || (key == XK_KP_Enter))
	    {
	      *ptr++ = '\n';
	      *ptr = '\0';
	      write_text_to_window (console, "\n");
	      return;
	    }
	  else if (*buffer == 3) /* ^C */
	    XtDispatchEvent (&event);
	  else
	    {
	      int n = (chars < str_size ? chars : str_size);

	      strncpy (ptr, buffer, n);
	      ptr += n;
	      *ptr = '\0';
	      str_size -= n;
	      buffer[chars] = '\0';
	      write_text_to_window (console, buffer);
	      if (str_size == 0)
		return;
	    }
	}
      else
	XtDispatchEvent (&event);
    }
}


#ifdef __STDC__
int
console_input_available (void)
#else
int
console_input_available ()
#endif
{
  if (mapped_io)
    return (XtAppPending (app_context));
  else
    return (0);
}


#ifdef __STDC__
char
get_console_char (void)
#else
char
get_console_char ()
#endif
{
  XEvent event;

  if (!console_is_visible)
    {
      XtPopup (shell1, XtGrabNone);
      console_is_visible = 1;
    }

  while (1)
    {
      XtAppNextEvent (app_context, &event);
      if (event.type == KeyPress)
	{
	  char buffer[11];
	  KeySym key;
	  XComposeStatus compose;
	  XLookupString (&event.xkey, buffer, 10, &key, &compose);

	  if (*buffer == 3)		       /* ^C */
	    XtDispatchEvent (&event);
	  else if (*buffer != 0)
	    return (buffer[0]);
	}
      else
	XtDispatchEvent (&event);
    }
}


#ifdef __STDC__
void
put_console_char (char c)
#else
void
put_console_char (c)
     char c;
#endif
{
  char buf[4];

  buf[0] = c;
  buf[1] = '\0';
  if (!console_is_visible)
    {
      XtPopup (shell1, XtGrabNone);
      console_is_visible = 1;
    }
  write_text_to_window (console, buf);
}



/* Print an error message. */

#ifdef __STDC__
void
error (char *fmt, ...)
#else
/*VARARGS0*/
void
error (va_alist)
va_dcl
#endif
{
  va_list args;
#ifndef __STDC__
  char *fmt;
#endif
  char io_buffer [IO_BUFFSIZE];

#ifdef __STDC__
  va_start (args, fmt);
#else
  va_start (args);
  fmt = va_arg (args, char *);
#endif
  vsprintf (io_buffer, fmt, args);
  va_end (args);
  if (message != 0)
    write_text_to_window (message, io_buffer);
  else
    fprintf (stderr, "%s", io_buffer);
}


#ifdef __STDC__
int
run_error (char *fmt, ...)
#else
/*VARARGS0*/
int
run_error (va_alist)
va_dcl
#endif
{
  va_list args;
#ifndef __STDC__
  char *fmt;
#endif
  char io_buffer [IO_BUFFSIZE];

#ifdef __STDC__
  va_start (args, fmt);
#else
  va_start (args);
  fmt = va_arg (args, char *);
#endif
  vsprintf (io_buffer, fmt, args);
  va_end (args);
  if (message != 0)
    write_text_to_window (message, io_buffer);
  else
    fprintf (stderr, "%s", io_buffer);
  if (spim_is_running)
    longjmp (spim_top_level_env, 1);
  return (0);			/* So it can be used in expressions */
}


#ifdef __STDC__
static void
write_text_to_window (Widget w, char *s)
#else
static void
write_text_to_window (w, s)
     Widget w;
     char *s;
#endif
{
  XawTextBlock textblock;
  XawTextPosition ip = XawTextGetInsertionPoint (w);

  if (!s || strlen (s) == 0) return;

  textblock.firstPos = 0;
  textblock.length = strlen (s);
  textblock.ptr = s;
  textblock.format = FMT8BIT;

  XawTextReplace (w, ip, ip, &textblock);
  XawTextSetInsertionPoint (w,
			    XawTextGetInsertionPoint (w) + textblock.length);
}
