APP = NeXTspim

OBJC_SOURCES = \
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

C_SOURCES = \
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

OBJECTS = $(OBJC_SOURCES:.m=.o) $(C_SOURCES:.c=.o)

COMMON_CPPFLAGS = -D_DARWIN_C_SOURCE -D_DEFAULT_SOURCE
COMMON_CFLAGS = -Wall -Wno-parentheses -Wno-format -Wno-pointer-sign -Wno-unused-variable -Wno-unused-function -Wno-implicit-function-declaration -Wno-int-conversion

UNAME_S := $(shell uname -s)
GNUSTEP_CONFIG := $(shell command -v gnustep-config 2>/dev/null)

ifeq ($(UNAME_S),Darwin)
CC ?= clang
OBJC ?= clang
CPPFLAGS += $(COMMON_CPPFLAGS)
CFLAGS += $(COMMON_CFLAGS) -std=gnu89
OBJCFLAGS += $(COMMON_CFLAGS) -fobjc-exceptions
LDLIBS += -framework AppKit -framework Foundation
TARGET = $(APP)
else ifneq ($(GNUSTEP_CONFIG),)
CC ?= clang
OBJC ?= clang
CPPFLAGS += $(COMMON_CPPFLAGS) $(shell gnustep-config --objc-flags)
CFLAGS += $(COMMON_CFLAGS) -std=gnu89
OBJCFLAGS += $(COMMON_CFLAGS) $(shell gnustep-config --objc-flags) -fobjc-exceptions
LDLIBS += $(shell gnustep-config --gui-libs) -pthread
TARGET = $(APP)
else
$(error GNUstep was not found. Install gnustep-base, gnustep-gui, and gnustep-make.)
endif

.PHONY: all clean run

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(OBJC) $(OBJECTS) $(LDLIBS) -o $@

%.o: %.m
	$(OBJC) $(CPPFLAGS) $(OBJCFLAGS) -c $< -o $@

%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

run: $(TARGET)
	./$(TARGET)

clean:
	rm -f $(TARGET) $(OBJECTS) cl-cache.o cl-cycle.o cl-except.o cl-tlb.o
