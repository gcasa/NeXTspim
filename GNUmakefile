#
# GNUstep build file for NeXTspim.
#
# Build with:
#   make -f GNUmakefile
#

ifeq ($(GNUSTEP_MAKEFILES),)
GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif

ifeq ($(GNUSTEP_MAKEFILES),)
$(error GNUstep makefiles were not found. Install gnustep-make and ensure gnustep-config is in PATH)
endif

include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = NeXTspim

NeXTspim_OBJC_FILES = \
	BreakpointsPanel.m \
	CodeView.m \
	ConsoleText.m \
	ConsoleView.m \
	ContinuePanel.m \
	KeyQueue.m \
	NeXTspim_main.m \
	PrefsPanel.m \
	RunLoop.m \
	SPIMInterface.m \
	StatsWindow.m \
	TextView.m

NeXTspim_C_FILES = \
	data.c \
	inst.c \
	lex.yy.c \
	mem.c \
	mips-syscall.c \
	read-aout.c \
	run.c \
	spim-utils.c \
	sym-tbl.c \
	y.tab.c

NeXTspim_RESOURCE_FILES = \
	Info-gnustep.plist \
	NeXTspim.desktop \
	trap.handler \
	spim.tiff \
	Documentation/NeXTspim.rtf \
	Documentation/spim.ps \
	Documentation/cycle.ps

NeXTspim_APPLICATION_ICON = spim.tiff

ADDITIONAL_CPPFLAGS += -D_DEFAULT_SOURCE
ADDITIONAL_CFLAGS += -Wall -Wno-parentheses -Wno-format -Wno-pointer-sign \
	-Wno-unused-variable -Wno-unused-function -Wno-implicit-function-declaration \
	-Wno-int-conversion -fcommon -std=gnu89
ADDITIONAL_OBJCFLAGS += -Wall -Wno-parentheses -Wno-format -Wno-pointer-sign \
	-Wno-unused-variable -Wno-unused-function -Wno-implicit-function-declaration \
	-Wno-int-conversion -fcommon -fobjc-exceptions
ADDITIONAL_LDFLAGS += -pthread

include $(GNUSTEP_MAKEFILES)/application.make
