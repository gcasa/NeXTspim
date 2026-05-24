/* SPIMInterface implementation: programmatic AppKit UI plus simulator glue. */

#import "SPIMInterface.h"
#import "RunLoop.h"
#import "ContinuePanel.h"
#import "BreakpointsPanel.h"
#import "KeyQueue.h"
#import "ConsoleView.h"
#import "CodeView.h"
#import "TextView.h"
#import "PrefsPanel.h"

#include <float.h>
#include <stdio.h>
#include <setjmp.h>
#include <string.h>

jmp_buf spim_top_level_env;
int spim_is_running = 0;
reg_word R[32];
reg_word HI, LO;
mem_addr nPC, PC;
int HI_present, LO_present;
double *FPR;
float *FGR;
int *FWR;
int FP_reg_present;
int FP_reg_poison;
int FP_spec_load;
reg_word CpCond[4], CCR[4][32], CPR[4][32];

int bare_machine;
int quiet;
int source_file;
int message_out, console_out, console_in;
int mapped_io;
int pipe_out;
int cycle_level;
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
float TimeBetweenUpdate = 0.3;
int print_gpr_hex;
int print_fpr_hex;

static char *check_buf_limit(char *, int *, int *);
static char *display_values(mem_addr from, mem_addr to, char *buf, int *limit, int *n);
static char *display_insts(mem_addr from, mem_addr to, char *buf, int *limit, int *n);
static mem_addr print_partial_line(mem_addr, char *, int *, int *);
static void init_stack(char *args);

static int stack_initialized = 0;
static int BufferLength = 0;
static char **BufferedText;

void InitUpdateDisplayLoop(void)
{
	[idMainInterface startDisplayTimer];
}

void KillUpdateDisplayLoop(void)
{
	[idMainInterface stopDisplayTimer];
}

void write_output(char *fmt, ...)
{
	va_list args;
	char io_buffer[IO_BUFFSIZE];
	va_start(args, fmt);
	vsprintf(io_buffer, fmt, args);
	va_end(args);
	while (BufferLength > 20) SPIMYield();
	mutex_lock(DisplayMutex);
	BufferLength++;
	if (BufferLength == 1) BufferedText = malloc(sizeof(char *));
	else BufferedText = realloc(BufferedText, BufferLength * sizeof(char *));
	BufferedText[BufferLength - 1] = malloc(strlen(io_buffer) + 1);
	strcpy(BufferedText[BufferLength - 1], io_buffer);
	mutex_unlock(DisplayMutex);
}

void read_input(char *str, int str_size)
{
	mutex_lock(DisplayMutex);
	DisplayNeedsUpdate = YES;
	mutex_unlock(DisplayMutex);
	while ([[idMainInterface idKeyQ] fullLine] == NO) {
		mutex_unlock(RegisterMutex);
		SPIMYield();
		mutex_lock(RegisterMutex);
	}
	[[idMainInterface idKeyQ] putLineInto:str max:str_size];
	data_modified = 1;
}

int console_input_available(void)
{
	return ![[idMainInterface idKeyQ] bufferEmpty];
}

char get_console_char(void)
{
	while ([[idMainInterface idKeyQ] bufferEmpty] == YES) SPIMYield();
	return [[idMainInterface idKeyQ] getChar];
}

void put_console_char(char g)
{
	char buffer[2] = { g, 0 };
	write_output(buffer);
}

void error(char *fmt, ...)
{
	va_list args;
	char io_buffer[IO_BUFFSIZE];
	va_start(args, fmt);
	vsprintf(io_buffer, fmt, args);
	va_end(args);
	fprintf(stderr, "%s", io_buffer);
	write_output(io_buffer);
}

int run_error(char *fmt, ...)
{
	va_list args;
	char io_buffer[IO_BUFFSIZE];
	va_start(args, fmt);
	vsprintf(io_buffer, fmt, args);
	va_end(args);
	fprintf(stderr, "%s", io_buffer);
	write_output(io_buffer);
	if (spim_is_running)
		longjmp(spim_top_level_env, 1);
	return 0;
}

void read_file(char *name, int assembly_file)
{
	int error_flag = 0;
	if (*name == '\0') error_flag = 1;
	else if (assembly_file) error_flag = read_assembly_file(name);
#ifdef mips
	else {
		initialize_world(0);
#ifdef CL_SPIM
		cl_initialize_world(0);
#endif
		error_flag = read_aout_file(name);
	}
#endif
	if (!error_flag) {
		[idMainInterface redisplayText];
		[idMainInterface redisplayData];
	}
}

void execute_program(mem_addr pc, int steps, int display, int cont_bkpt)
{
	if (!setjmp(spim_top_level_env))
		run_program(pc, steps, display, cont_bkpt);
}

void start_program(mem_addr addr)
{
	execute_program(addr, DEFAULT_RUN_STEPS, 0, 0);
}

void show_running(void)
{
	[idMainInterface showRunning:YES];
}

void print_pipeline(void)
{
#ifdef CL_SPIM
	[idMainInterface displayPipeline];
#endif
}

static void init_stack(char *args)
{
	int argc = 0;
	char *argv[10000];
	char *a;
	if (stack_initialized) return;
	while (*args != '\0') {
		while (*args == ' ' || *args == '\t') args++;
		a = args;
		while (*args != ' ' && *args != '\t' && *args != '\0') args++;
		if (a != args) {
			if (*args != '\0') *args++ = '\0';
			argv[argc++] = a;
		}
	}
	initialize_run_stack(argc, argv);
	stack_initialized = 1;
}

static NSButton *MakeButton(NSString *title, NSInteger tag, id target, SEL action, NSRect frame)
{
	NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
	[button setTitle:title];
	[button setTag:tag];
	[button setTarget:target];
	[button setAction:action];
	return button;
}

@implementation SPIMInterface

- init
{
	self = [super init];
	if (self) {
		idOpenPanel = [[NSOpenPanel openPanel] retain];
		idMainInterface = self;
		[self buildInterface];
	}
	return self;
}

- (void)dealloc
{
	[self stopDisplayTimer];
#if !__has_feature(objc_arc)
	[super dealloc];
#endif
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	(void)notification;
	[MainWindow makeKeyAndOrderFront:self];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
	(void)sender;
	return YES;
}

- buildInterface
{
	NSRect frame = NSMakeRect(80, 80, 1040, 760);
	MainWindow = [[NSWindow alloc] initWithContentRect:frame
	                                        styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask)
	                                          backing:NSBackingStoreBuffered
	                                            defer:NO];
	[MainWindow setTitle:@"NeXTspim"];
	NSView *content = [MainWindow contentView];

	NSView *toolbar = [[[NSView alloc] initWithFrame:NSMakeRect(0, 720, 1040, 40)] autorelease];
	[toolbar setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
	[content addSubview:toolbar];
	[toolbar addSubview:MakeButton(@"Load", 1, self, @selector(MenuItem:), NSMakeRect(8, 7, 72, 26))];
	idStartStopCell = MakeButton(@"Run", 2, self, @selector(MenuItem:), NSMakeRect(86, 7, 72, 26));
	[toolbar addSubview:idStartStopCell];
	[toolbar addSubview:MakeButton(@"Step", 3, self, @selector(MenuItem:), NSMakeRect(164, 7, 72, 26))];
	[toolbar addSubview:MakeButton(@"Clear", 4, self, @selector(MenuItem:), NSMakeRect(242, 7, 72, 26))];
	[toolbar addSubview:MakeButton(@"Clear All", 5, self, @selector(MenuItem:), NSMakeRect(320, 7, 86, 26))];
	[toolbar addSubview:MakeButton(@"Breakpoints", 7, self, @selector(MenuItem:), NSMakeRect(414, 7, 110, 26))];

	MainRegisters = [[NSView alloc] initWithFrame:NSMakeRect(8, 500, 220, 210)];
	[MainRegisters setAutoresizingMask:NSViewMaxXMargin | NSViewMinYMargin];
	[content addSubview:MainRegisters];
	NSArray *mainNames = [NSArray arrayWithObjects:@"PC", @"EPC", @"Cause", @"BadVAddr", @"Status", @"HI", @"LO", nil];
	int i;
	for (i = 0; i < 7; i++) {
		NSTextField *label = [[[NSTextField alloc] initWithFrame:NSMakeRect(0, 182 - i * 26, 72, 20)] autorelease];
		[label setStringValue:[mainNames objectAtIndex:i]];
		[label setEditable:NO]; [label setBordered:NO]; [label setDrawsBackground:NO];
		[MainRegisters addSubview:label];
		NSTextField *field = [[[NSTextField alloc] initWithFrame:NSMakeRect(78, 178 - i * 26, 120, 22)] autorelease];
		[field setTag:10 + i];
		[MainRegisters addSubview:field];
	}

	Registers = [[NSView alloc] initWithFrame:NSMakeRect(8, 8, 220, 486)];
	[Registers setAutoresizingMask:NSViewMaxXMargin | NSViewHeightSizable];
	[content addSubview:Registers];
	for (i = 0; i < 32; i++) {
		int row = i % 16;
		int col = i / 16;
		NSTextField *field = [[[NSTextField alloc] initWithFrame:NSMakeRect(col * 108, 458 - row * 28, 100, 22)] autorelease];
		[field setTag:100 + i];
		[Registers addSubview:field];
	}

	TextSegments = [[CodeView alloc] initFrame:NSMakeRect(236, 386, 796, 324)];
	[TextSegments setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[content addSubview:TextSegments];
	DataSegments = [[TextView alloc] initFrame:NSMakeRect(236, 194, 796, 184)];
	[DataSegments setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
	[content addSubview:DataSegments];
	Messages = [[ConsoleView alloc] initFrame:NSMakeRect(236, 8, 796, 178)];
	[Messages setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
	[content addSubview:Messages];
	MessageWindow = MainWindow;

	Prefs = [[PrefsPanel alloc] init];
	Breakpoints = [[BreakpointsPanel alloc] init];
	ContinuePanel *continuePanel = [[ContinuePanel alloc] init];
	[continuePanel setBreakpointsPanel:Breakpoints];

	ICacheStats = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 1, 1)];
	DCacheStats = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 1, 1)];
	ICacheData = [[TextView alloc] initFrame:NSMakeRect(0, 0, 1, 1)];
	DCacheData = [[TextView alloc] initFrame:NSMakeRect(0, 0, 1, 1)];
	Pipeline = [[TextView alloc] initFrame:NSMakeRect(0, 0, 1, 1)];
	return self;
}

- appDidInit:sender
{
	int x;
	SEL s = @selector(registerChanged:);
	(void)sender;
	for (x = 10; x <= 16; x++) {
		registersMain[x - 10] = [MainRegisters viewWithTag:x];
		[registersMain[x - 10] setTarget:self];
		[registersMain[x - 10] setAction:s];
	}
	for (x = 100; x <= 131; x++) {
		registersGeneral[x - 100] = [Registers viewWithTag:x];
		[registersGeneral[x - 100] setTarget:self];
		[registersGeneral[x - 100] setAction:s];
	}
	for (x = 0; x < 32; x++) registersFloat[x] = nil;
	[Breakpoints setup];
	[Prefs loadPrefs];
	[[DataSegments idText] setEditable:NO];
	[[TextSegments idText] setEditable:NO];
	[[ICacheData idText] setEditable:NO];
	[[DCacheData idText] setEditable:NO];
	return self;
}

- (void)startDisplayTimer
{
	[self stopDisplayTimer];
	updateTimer = [[NSTimer scheduledTimerWithTimeInterval:TimeBetweenUpdate
	                                                target:self
	                                              selector:@selector(updateDisplayIfNeeded:)
	                                              userInfo:nil
	                                               repeats:YES] retain];
}

- (void)stopDisplayTimer
{
	if (updateTimer) {
		[updateTimer invalidate];
		[updateTimer release];
		updateTimer = nil;
	}
}

- (void)updateDisplayIfNeeded:(NSTimer *)timer
{
	int x;
	(void)timer;
	mutex_lock(DisplayMutex);
	if (DisplayNeedsUpdate) {
		[self redisplayData];
		[self redisplayText];
		[self showRunning:spim_is_running];
		DisplayNeedsUpdate = NO;
	}
	if (ChangeStartStopButton) {
		[idStartStopCell setTitle:(spim_is_running ? @"Stop" : @"Run")];
		ChangeStartStopButton = NO;
	}
	if (ChangeHighlight) {
		[self center_text_at_PC];
		ChangeHighlight = NO;
	}
	if (BufferLength > 0) {
		for (x = 0; x < BufferLength; x++) {
			[self writeOutput:BufferedText[x]];
			free(BufferedText[x]);
		}
		free(BufferedText);
		BufferLength = 0;
	}
	if (OpenContinueWindow) {
		[idContinuePanel open:PC];
		OpenContinueWindow = NO;
	}
	mutex_unlock(DisplayMutex);
}

- center_text_at_PC
{
	int line, pos1, pos2;
	id text = [TextSegments idText];
	if (PC < TEXT_BOT || (PC > text_top && (PC < K_TEXT_BOT || PC > k_text_top))) {
		[text setSel:0 :0];
		[TextSegments setVertScroll:0.0];
		return self;
	}
	if (PC < K_TEXT_BOT) line = ((PC - TEXT_BOT) / BYTES_PER_WORD);
	else line = ((PC - K_TEXT_BOT) / BYTES_PER_WORD) + KernelStartLine;
	line++;
	pos1 = [text positionFromLine:line];
	pos2 = [text positionFromLine:(line + 1)];
	[text setSel:pos1 :pos2];
	[TextSegments scrollLine:line];
	return self;
}

- displayDataSeg
{
	char *buf = NULL;
	int limit, n;
	if (!data_modified) return nil;
	buf = (char *)malloc(16 * K);
	*buf = '\0';
	limit = 16 * K;
	n = 0;
	sprintf(&buf[n], "\n\tDATA\n"); n += strlen(&buf[n]);
	buf = display_values(DATA_BOT, data_top, buf, &limit, &n);
	sprintf(&buf[n], "\n\tSTACK\n"); n += strlen(&buf[n]);
	buf = display_values(R[29], STACK_TOP - 4096, buf, &limit, &n);
	sprintf(&buf[n], "\n\tKERNEL DATA\n"); n += strlen(&buf[n]);
	buf = display_values(K_DATA_BOT, k_data_top, buf, &limit, &n);
	[DataSegments setText:buf];
	free(buf);
	data_modified = 0;
	return self;
}

long *RegAddr[7] = {(long *)&PC, &EPC, &Cause, &BadVAddr, &Status_Reg, &HI, &LO};

- displayRegisters
{
	char buf[80];
	int i;
	char *grstr, *fpstr;
	for (i = 0; i < 7; i++) {
		sprintf(buf, "%08x", (unsigned int)*(RegAddr[i]));
		[registersMain[i] setStringValue:[NSString stringWithUTF8String:buf]];
	}
	grstr = print_gpr_hex ? "%08x" : "%-10d";
	for (i = 0; i < 32; i++) {
		sprintf(buf, grstr, R[i]);
		[registersGeneral[i] setStringValue:[NSString stringWithUTF8String:buf]];
	}
	(void)fpstr;
	return self;
}

- redisplayData
{
	[self displayRegisters];
	[self displayDataSeg];
#ifdef CL_SPIM
	[self displayPipeline];
	[self displayCache:DATA_CACHE];
	[self displayCache:INST_CACHE];
#endif
	return self;
}

- redisplayText
{
	char *buf = NULL;
	int limit, n;
	int KernelStartPos;
	id text;
	if (!text_modified) return nil;
	buf = (char *)malloc(16 * K);
	*buf = '\0';
	limit = 16 * K;
	n = 0;
	buf = display_insts(TEXT_BOT, text_top, buf, &limit, &n);
	sprintf(&buf[n], "\n\tKERNEL\n"); n += strlen(&buf[n]);
	KernelStartPos = n;
	buf = display_insts(K_TEXT_BOT, k_text_top, buf, &limit, &n);
	[TextSegments setText:buf];
	free(buf);
	text = [TextSegments idText];
	KernelStartLine = [text lineFromPosition:KernelStartPos];
	text_modified = 0;
	return self;
}

- showRunning:(BOOL)r
{
	[MainWindow setTitle:(r ? @"Running..." : @"NeXTspim")];
	return self;
}

- writeOutput:(char *)string
{
	[Messages addText:string];
	return self;
}

- setEnabled:(BOOL)enable
{
	(void)enable;
	return self;
}

- StartStopCell { return idStartStopCell; }
- idKeyQ { return [Messages queue]; }

#define TAG_LOAD		1
#define TAG_RUN			2
#define TAG_STEP		3
#define TAG_CLEAR		4
#define TAG_CLEARALL	5
#define TAG_BREAKPOINT	7

- MenuItem:sender
{
	switch ([sender tag]) {
		case TAG_LOAD: [self loadFile]; break;
		case TAG_RUN:
			if (spim_is_running == 1) StopRunLoop();
			else [self run:NO :NO];
			break;
		case TAG_STEP: [self run:YES :NO]; break;
		case TAG_CLEAR: [self clear:NO]; break;
		case TAG_CLEARALL: [self clear:YES]; break;
		case TAG_BREAKPOINT: [Breakpoints makeKeyAndOrderFront:self]; break;
		default: {
			char buffer[80];
			sprintf(buffer, "Error: Tag is #%ld\n", (long)[sender tag]);
			[self writeOutput:buffer];
			break;
		}
	}
	return self;
}

- registerChanged:sender
{
	int t = (int)[sender tag];
	const char *value = [[sender stringValue] UTF8String];
	if (t >= 10 && t <= 16) {
		unsigned int v;
		sscanf(value, "%X", &v);
		*(RegAddr[t - 10]) = v;
	} else if (t >= 100 && t <= 131) {
		if (print_gpr_hex) sscanf(value, "%X", &R[t - 100]);
		else R[t - 100] = [sender intValue];
	}
	[self displayRegisters];
	return self;
}

- loadFile
{
	NSArray *types = [NSArray arrayWithObject:@"s"];
	if ([idOpenPanel runModalForTypes:types] == NSOKButton) {
		[self writeOutput:"Loading..."];
		NSString *path = [idOpenPanel filename];
		if (path != nil) read_file((char *)[path fileSystemRepresentation], 1);
		PC = starting_address();
		if (PC == 0) PC = TEXT_BOT;
		[self redisplayData];
		[self center_text_at_PC];
		init_stack("\0");
		[self writeOutput:"Done!\n"];
	}
	return self;
}

- run:(BOOL)step :(BOOL)cont_bkpt
{
	mem_addr addr;
	StopRunLoop();
	mutex_lock(DisplayMutex);
	[MessageWindow makeKeyAndOrderFront:self];
	mutex_unlock(DisplayMutex);
	[[self idKeyQ] flush];
	mutex_lock(RegisterMutex);
	addr = starting_address();
	if (addr == 0) addr = TEXT_BOT;
	RunPC = addr;
	RunSteps = step ? 1 : 100;
	RunDisplay = 0;
	RunContBkpt = cont_bkpt;
	mutex_unlock(RegisterMutex);
	if (step) StepRunLoop();
	else StartRunLoop();
	return self;
}

- clear:(BOOL)clear_world
{
	if (clear_world) {
		write_output("Memory and registers cleared.\n\n");
		initialize_world(load_trap_handler && !bare_machine);
		write_startup_message();
		stack_initialized = 0;
		init_stack("\0");
		[TextSegments setText:""];
		[Breakpoints removeAllBreak];
#ifdef CL_SPIM
		cl_initialize_world(0);
#endif
	} else {
		[self writeOutput:"Registers cleared\n\n"];
#ifdef CL_SPIM
		cl_initialize_world(0);
#else
		initialize_registers();
#endif
	}
	[self redisplayText];
	[self redisplayData];
	return self;
}

#ifdef CL_SPIM
- displayCache:(int)type
{
	char *buf;
	switch (type) {
		case DATA_CACHE: if (!dcache_modified) return self; dcache_modified = 0; break;
		case INST_CACHE: if (!icache_modified) return self; icache_modified = 0; break;
	}
	buf = (char *)malloc(16 * K);
	if (!buf) { error("Bad malloc on cache update.\n"); return self; }
	*buf = '\0';
	print_cache_stats(buf, type);
	if (type == DATA_CACHE) [DCacheStats setStringValue:[NSString stringWithUTF8String:buf]];
	else [ICacheStats setStringValue:[NSString stringWithUTF8String:buf]];
	*buf = '\0';
	print_cache_data(buf, type);
	if (type == DATA_CACHE) [DCacheData setText:buf];
	else [ICacheData setText:buf];
	free(buf);
	return self;
}

- displayPipeline
{
	char *buf = (char *)malloc(8 * K);
	*buf = '\0';
	print_pipeline_internal(buf);
	[Pipeline setText:buf];
	free(buf);
	return self;
}
#endif

@end

static char *check_buf_limit(char *buf, int *limit, int *n)
{
	*n += strlen(&buf[*n]);
	if ((*limit - *n) < 1 * K) {
		*limit = 2 * *limit;
		if ((buf = (char *)realloc(buf, *limit)) == 0)
			fatal_error("realloc failed\n");
	}
	return buf;
}

static char *display_insts(mem_addr from, mem_addr to, char *buf, int *limit, int *n)
{
	instruction *inst;
	mem_addr i;
	for (i = from; i < to; i += 4) {
		READ_MEM_INST(inst, i);
		if (inst != NULL) {
			*n += print_inst_internal(&buf[*n], 1 * K, inst, i);
			if ((*limit - *n) < 1 * K) {
				*limit = 2 * *limit;
				if ((buf = (char *)realloc(buf, *limit)) == 0)
					fatal_error("realloc failed\n");
			}
		}
	}
	return buf;
}

static char *display_values(mem_addr from, mem_addr to, char *buf, int *limit, int *n)
{
	mem_word val;
	mem_addr i = ROUND(from, BYTES_PER_WORD);
	int j;
	i = print_partial_line(i, buf, limit, n);
	for (; i < to;) {
		for (j = 0; i + j < to; j += BYTES_PER_WORD) {
			READ_MEM_WORD(val, i + j);
			if (val != 0) break;
		}
		if (i + j < to) j -= BYTES_PER_WORD;
		if (j >= 4 * BYTES_PER_WORD) {
			sprintf(&buf[*n], "[0x%08x]...[0x%08x]\t0x00000000\n", i, i + j);
			buf = check_buf_limit(buf, limit, n);
			i = i + j;
			i = print_partial_line(i, buf, limit, n);
		} else {
			sprintf(&buf[*n], "[0x%08x]\t      ", i);
			*n += strlen(&buf[*n]);
			do {
				READ_MEM_WORD(val, i);
				sprintf(&buf[*n], "  0x%08x", val);
				*n += strlen(&buf[*n]);
				i += BYTES_PER_WORD;
			} while (i % BYTES_PER_LINE != 0);
			sprintf(&buf[*n], "\n");
			check_buf_limit(buf, limit, n);
		}
	}
	return buf;
}

static mem_addr print_partial_line(mem_addr i, char *buf, int *limit, int *n)
{
	mem_word val;
	if ((i % BYTES_PER_LINE) != 0) {
		sprintf(&buf[*n], "[0x%08x]\t      ", i);
		buf = check_buf_limit(buf, limit, n);
		for (; (i % BYTES_PER_LINE) != 0; i += BYTES_PER_WORD) {
			READ_MEM_WORD(val, i);
			sprintf(&buf[*n], "  0x%08x", val);
			buf = check_buf_limit(buf, limit, n);
		}
		sprintf(&buf[*n], "\n");
		check_buf_limit(buf, limit, n);
	}
	return i;
}
