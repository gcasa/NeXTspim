#import "PrefsPanel.h"
#import "SPIMInterface.h"
#import "RunLoop.h"

extern int print_gpr_hex;
extern int print_fpr_hex;
extern float TimeBetweenUpdate;
extern id idPrefsPanel;

extern void KillUpdateDisplayLoop(void);
extern void InitUpdateDisplayLoop(void);

static NSString *DefOwner = @"NeXTspimFromGAC";

static BOOL GetBooleanPref(NSString *name)
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *key = [NSString stringWithFormat:@"%@.%@", DefOwner, name];
	return [defaults boolForKey:key];
}

static void SetBooleanPref(NSString *name, BOOL value)
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *key = [NSString stringWithFormat:@"%@.%@", DefOwner, name];
	[defaults setBool:value forKey:key];
}

@implementation PrefsPanel

+ initialize
{
	if (self == [PrefsPanel class]) {
		NSDictionary *defs = [NSDictionary dictionaryWithObjectsAndKeys:
			@"NO", @"NeXTspimFromGAC.BareMachine",
			@"NO", @"NeXTspimFromGAC.DefaultTrapHandler",
			@"NO", @"NeXTspimFromGAC.HexGPRs",
			@"NO", @"NeXTspimFromGAC.HexFPRs",
			@"NO", @"NeXTspimFromGAC.MemoryMappedIO",
			@"NO", @"NeXTspimFromGAC.InstCache",
			@"NO", @"NeXTspimFromGAC.DataCache",
			@"NO", @"NeXTspimFromGAC.TLB",
			@"NO", @"NeXTspimFromGAC.CycleLevel",
			@"0.3", @"NeXTspimFromGAC.Update",
			nil];
		[[NSUserDefaults standardUserDefaults] registerDefaults:defs];
	}
}

- init
{
	self = [super initWithContentRect:NSMakeRect(160, 160, 300, 300)
	                        styleMask:(NSTitledWindowMask | NSClosableWindowMask)
	                          backing:NSBackingStoreBuffered
	                            defer:NO];
	if (self) {
		NSArray *items = [NSArray arrayWithObjects:
			@"Bare machine", @"Load default trap handler", @"Hex GPRs",
			@"Hex FPRs", @"Memory mapped I/O",
#ifdef CL_SPIM
			@"Instruction cache", @"Data cache", @"TLB", @"Cycle level",
#endif
			nil];
		NSArray *tags = [NSArray arrayWithObjects:
			[NSNumber numberWithInt:101], [NSNumber numberWithInt:102],
			[NSNumber numberWithInt:103], [NSNumber numberWithInt:104],
			[NSNumber numberWithInt:105],
#ifdef CL_SPIM
			[NSNumber numberWithInt:106], [NSNumber numberWithInt:107],
			[NSNumber numberWithInt:108], [NSNumber numberWithInt:109],
#endif
			nil];
		NSView *content = [self contentView];
		NSUInteger i;
		for (i = 0; i < [items count]; i++) {
			NSButton *button = [[[NSButton alloc] initWithFrame:NSMakeRect(18, 250 - (i * 24), 240, 22)] autorelease];
			[button setButtonType:NSSwitchButton];
			[button setTitle:[items objectAtIndex:i]];
			[button setTag:[[tags objectAtIndex:i] intValue]];
			[button setTarget:self];
			[button setAction:@selector(switch:)];
			[content addSubview:button];
		}
		NSTextField *label = [[[NSTextField alloc] initWithFrame:NSMakeRect(18, 30, 120, 22)] autorelease];
		[label setStringValue:@"Update interval"];
		[label setEditable:NO];
		[label setBordered:NO];
		[label setDrawsBackground:NO];
		[content addSubview:label];
		NSTextField *field = [[[NSTextField alloc] initWithFrame:NSMakeRect(150, 30, 70, 22)] autorelease];
		[field setTag:200];
		[field setTarget:self];
		[field setAction:@selector(switch:)];
		[content addSubview:field];
		NSButton *save = [[[NSButton alloc] initWithFrame:NSMakeRect(225, 28, 60, 26)] autorelease];
		[save setTitle:@"Save"];
		[save setTarget:self];
		[save setAction:@selector(savePrefs:)];
		[content addSubview:save];
		[self setTitle:@"Preferences"];
		idPrefsPanel = self;
	}
	return self;
}

- loadPrefs
{
	bare_machine = GetBooleanPref(@"BareMachine");
	load_trap_handler = GetBooleanPref(@"DefaultTrapHandler");
	print_gpr_hex = GetBooleanPref(@"HexGPRs");
	print_fpr_hex = GetBooleanPref(@"HexFPRs");
	mapped_io = GetBooleanPref(@"MemoryMappedIO");
#ifdef CL_SPIM
	icache_on = GetBooleanPref(@"InstCache");
	dcache_on = GetBooleanPref(@"DataCache");
	tlb_on = GetBooleanPref(@"TLB");
	cycle_level = GetBooleanPref(@"CycleLevel");
#endif
	TimeBetweenUpdate = [[[NSUserDefaults standardUserDefaults] stringForKey:@"NeXTspimFromGAC.Update"] floatValue];
	if (TimeBetweenUpdate <= 0.0) TimeBetweenUpdate = 0.3;
	[[[self contentView] viewWithTag:101] setState:bare_machine];
	[[[self contentView] viewWithTag:102] setState:load_trap_handler];
	[[[self contentView] viewWithTag:103] setState:print_gpr_hex];
	[[[self contentView] viewWithTag:104] setState:print_fpr_hex];
	[[[self contentView] viewWithTag:105] setState:mapped_io];
#ifdef CL_SPIM
	[[[self contentView] viewWithTag:106] setState:icache_on];
	[[[self contentView] viewWithTag:107] setState:dcache_on];
	[[[self contentView] viewWithTag:108] setState:tlb_on];
	[[[self contentView] viewWithTag:109] setState:cycle_level];
#endif
	[[[self contentView] viewWithTag:200] setFloatValue:TimeBetweenUpdate];
	return self;
}

- savePrefs:sender
{
	(void)sender;
	SetBooleanPref(@"BareMachine", bare_machine);
	SetBooleanPref(@"DefaultTrapHandler", load_trap_handler);
	SetBooleanPref(@"HexGPRs", print_gpr_hex);
	SetBooleanPref(@"HexFPRs", print_fpr_hex);
	SetBooleanPref(@"MemoryMappedIO", mapped_io);
#ifdef CL_SPIM
	SetBooleanPref(@"InstCache", icache_on);
	SetBooleanPref(@"DataCache", dcache_on);
	SetBooleanPref(@"TLB", tlb_on);
	SetBooleanPref(@"CycleLevel", cycle_level);
#endif
	[[NSUserDefaults standardUserDefaults] setFloat:TimeBetweenUpdate forKey:@"NeXTspimFromGAC.Update"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	return self;
}

- switch:sender
{
	switch ([sender tag]) {
		case 101: bare_machine = [sender state]; break;
		case 102: load_trap_handler = [sender state]; break;
		case 103:
			print_gpr_hex = [sender state];
			mutex_lock(DisplayMutex); DisplayNeedsUpdate = YES; mutex_unlock(DisplayMutex);
			break;
		case 104:
			print_fpr_hex = [sender state];
			mutex_lock(DisplayMutex); DisplayNeedsUpdate = YES; mutex_unlock(DisplayMutex);
			break;
		case 105: mapped_io = [sender state]; break;
#ifdef CL_SPIM
		case 106: icache_on = [sender state]; if (icache_on) cache_init(mem_system, INST_CACHE); break;
		case 107: dcache_on = [sender state]; if (dcache_on) cache_init(mem_system, DATA_CACHE); break;
		case 108: tlb_on = [sender state]; if (tlb_on) tlb_init(); break;
		case 109: cycle_level = [sender state]; cl_initialize_world(0); break;
#endif
		case 200:
			TimeBetweenUpdate = [sender floatValue];
			if (TimeBetweenUpdate < 0.1) TimeBetweenUpdate = 0.1;
			if (TimeBetweenUpdate > 1.0) TimeBetweenUpdate = 1.0;
			[sender setFloatValue:TimeBetweenUpdate];
			KillUpdateDisplayLoop();
			InitUpdateDisplayLoop();
			break;
	}
	return self;
}

@end
