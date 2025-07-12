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

#import "PrefsPanel.h"
#import <appkit/Button.h>
#import <appkit/TextField.h>
#import "SPIMInterface.h"
#import "RunLoop.h"
#import <defaults.h>
#import <stdio.h>
#import <stdlib.h>

extern int print_gpr_hex;		/* Print GPRs in hex/decimal */
extern int print_fpr_hex;		/* Print FPRs in hex/floating point */
extern float TimeBetweenUpdate;
extern id idPrefsPanel;

extern void KillUpdateDisplayLoop(void);
extern void InitUpdateDisplayLoop(void);

static char DefOwner[] = "NeXTspimFromGAC";

static int GetBooleanPref(const char *name) {
	const char *c = NXGetDefaultValue(DefOwner, name);
	if (c[0] == 'Y' || c[0] == 'y') return 1;
	return 0;
}

#define BSTR(x) ((x) ? "Y" : "N")
  
@implementation PrefsPanel

+ initialize {
	static NXDefaultsVector NeXTspimDefaults = {
		{"BareMachine","N"},
		{"DefaultTrapHandler","N"},
		{"HexGPRs","N"},
		{"HexFPRs","N"},
		{"MemoryMappedIO","N"},
#ifdef CL_SPIM
		{"InstCache","N"},
		{"DataCache","N"},
		{"TLB", "N"},
		{"CycleLevel", "N"},
#endif
		{"Update","0.3"},
		{NULL}
	};
	NXRegisterDefaults(DefOwner, NeXTspimDefaults);
	return self;
}

- loadPrefs {
	bare_machine = GetBooleanPref("BareMachine");
	load_trap_handler = GetBooleanPref("DefaultTrapHandler");
	print_gpr_hex = GetBooleanPref("HexGPRs");
	print_fpr_hex = GetBooleanPref("HexFPRs");
	mapped_io = GetBooleanPref("MemoryMappedIO");
#ifdef CL_SPIM
	icache_on = GetBooleanPref("InstCache");
	dcache_on = GetBooleanPref("DataCache");
	tlb_on = GetBooleanPref("TLB");
	cycle_level = GetBooleanPref("CycleLevel");
#endif
	TimeBetweenUpdate = atof(NXGetDefaultValue(DefOwner, "Update"));
	[[contentView findViewWithTag:101] setState:bare_machine];
	[[contentView findViewWithTag:102] setState:load_trap_handler];
	[[contentView findViewWithTag:103] setState:print_gpr_hex];
	[[contentView findViewWithTag:104] setState:print_fpr_hex];
	[[contentView findViewWithTag:105] setState:mapped_io];
#ifdef CL_SPIM
	[[contentView findViewWithTag:106] setState:icache_on];
	[[contentView findViewWithTag:107] setState:dcache_on];
	[[contentView findViewWithTag:108] setState:tlb_on];
	[[contentView findViewWithTag:109] setState:cycle_level];
#endif
	[[contentView findViewWithTag:200] setFloatValue:TimeBetweenUpdate];
	return self;
}

- savePrefs:sender {
	char buf[10];
	NXDefaultsVector newDefaults = {
		{"BareMachine",		BSTR(bare_machine)},
		{"DefaultTrapHandler",	BSTR(load_trap_handler)},
		{"HexGPRs",			BSTR(print_gpr_hex)},
		{"HexFPRs",			BSTR(print_fpr_hex)},
		{"MemoryMappedIO",	BSTR(mapped_io)},
#ifdef CL_SPIM
		{"InstCache",		BSTR(icache_on)},
		{"DataCache",		BSTR(dcache_on)},
		{"TLB",				BSTR(tlb_on)},
		{"CycleLevel",		BSTR(cycle_level)},
#endif
		{"Update",			buf},
		{NULL}
	};
	sprintf(buf, "%2.2f", TimeBetweenUpdate);
	NXWriteDefaults(DefOwner, newDefaults);
	return self;
}

- switch:sender
{
	switch ([sender selectedTag]) {
		case 101:
			bare_machine = [sender state];
			break;
		case 102:
			load_trap_handler = [sender state];
			break;
		case 103:
			print_gpr_hex = [sender state];
			mutex_lock(DisplayMutex);
			DisplayNeedsUpdate = TRUE;
			mutex_unlock(DisplayMutex);
			break;
		case 104:
			print_fpr_hex = [sender state];
			mutex_lock(DisplayMutex);
			DisplayNeedsUpdate = TRUE;
			mutex_unlock(DisplayMutex);
			break;
		case 105:
			mapped_io = [sender state];
			break;
#ifdef CL_SPIM
		case 106:
			icache_on = [sender state];
			if (icache_on) cache_init(mem_system, INST_CACHE);
			break;
		case 107:
			dcache_on = [sender state];
			if (dcache_on) cache_init(mem_system, DATA_CACHE);
			break;
		case 108:
			tlb_on = [sender state];
			if (tlb_on) tlb_init();
			break;
		case 109:
			cycle_level = [sender state];
			cl_initialize_world(0);
			break;
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

/* I do so hate doing this, but I need to call this object before
   SpimInterface's appDidInit gets called. */
   
- initContent:(const NXRect *)contentRect style:(int)aStyle backing:(int)bufferingType buttonMask:(int)mask defer:(BOOL)flag {
	idPrefsPanel = self;
	return [super initContent:contentRect style:aStyle backing:bufferingType buttonMask:mask defer:flag];
}

@end
