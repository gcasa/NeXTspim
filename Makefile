APP = NeXTspim
APP_WRAPPER = $(APP).app
RESOURCES = trap.handler spim.tiff Documentation/NeXTspim.rtf Documentation/spim.ps Documentation/cycle.ps

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
COMMON_CFLAGS = -Wall -Wno-parentheses -Wno-format -Wno-pointer-sign -Wno-unused-variable -Wno-unused-function -Wno-implicit-function-declaration -Wno-int-conversion -fcommon

UNAME_S := $(shell uname -s)
GNUSTEP_CONFIG := $(shell command -v gnustep-config 2>/dev/null)
CLANG := $(shell command -v clang 2>/dev/null)

ifeq ($(UNAME_S),Darwin)
CC ?= clang
OBJC ?= clang
CPPFLAGS += $(COMMON_CPPFLAGS)
CFLAGS += $(COMMON_CFLAGS) -std=gnu89
OBJCFLAGS += $(COMMON_CFLAGS) -fobjc-exceptions
LDLIBS += -framework AppKit -framework Foundation
TARGET = $(APP)
BUNDLE_TARGET = macos-app
else ifneq ($(GNUSTEP_CONFIG),)
ifeq ($(CLANG),)
CC = cc
OBJC = cc
# GNUstep may emit clang-only flags; drop them when building with non-clang compilers.
GNUSTEP_OBJC_FLAGS := $(filter-out -fobjc-runtime=gnustep-2.2 -fblocks,$(shell gnustep-config --objc-flags))
else
CC = clang
OBJC = clang
GNUSTEP_OBJC_FLAGS := $(shell gnustep-config --objc-flags)
endif
CPPFLAGS += $(COMMON_CPPFLAGS) $(GNUSTEP_OBJC_FLAGS)
CFLAGS += $(COMMON_CFLAGS) -std=gnu89
OBJCFLAGS += $(COMMON_CFLAGS) $(GNUSTEP_OBJC_FLAGS) -fobjc-exceptions
LDLIBS += $(shell gnustep-config --gui-libs) -pthread
TARGET = $(APP)
BUNDLE_TARGET = gnustep-app
else
$(error GNUstep was not found. Install gnustep-base, gnustep-gui, and gnustep-make.)
endif

.PHONY: all clean run macos-app gnustep-app

all: $(BUNDLE_TARGET)

$(TARGET): $(OBJECTS)
	$(OBJC) $(OBJECTS) $(LDLIBS) -o $@

%.o: %.m
	$(OBJC) $(CPPFLAGS) $(OBJCFLAGS) -c $< -o $@

%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

macos-app: $(TARGET) Info.plist NeXTspim.icns $(RESOURCES)
	mkdir -p $(APP_WRAPPER)/Contents/MacOS $(APP_WRAPPER)/Contents/Resources/Documentation
	cp $(TARGET) $(APP_WRAPPER)/Contents/MacOS/$(APP)
	cp Info.plist $(APP_WRAPPER)/Contents/Info.plist
	cp NeXTspim.icns $(APP_WRAPPER)/Contents/Resources/NeXTspim.icns
	cp spim.tiff trap.handler $(APP_WRAPPER)/Contents/Resources/
	cp Documentation/NeXTspim.rtf Documentation/spim.ps Documentation/cycle.ps $(APP_WRAPPER)/Contents/Resources/Documentation/
	printf 'APPL????' > $(APP_WRAPPER)/Contents/PkgInfo

gnustep-app: $(TARGET) Info-gnustep.plist NeXTspim.desktop $(RESOURCES)
	mkdir -p $(APP_WRAPPER)/Resources/Documentation
	cp $(TARGET) $(APP_WRAPPER)/$(APP)
	cp Info-gnustep.plist $(APP_WRAPPER)/Resources/Info-gnustep.plist
	cp NeXTspim.desktop $(APP_WRAPPER)/Resources/NeXTspim.desktop
	cp spim.tiff trap.handler $(APP_WRAPPER)/Resources/
	cp Documentation/NeXTspim.rtf Documentation/spim.ps Documentation/cycle.ps $(APP_WRAPPER)/Resources/Documentation/

run: all
ifeq ($(UNAME_S),Darwin)
	./$(APP_WRAPPER)/Contents/MacOS/$(APP)
else
	./$(APP_WRAPPER)/$(APP)
endif

clean:
	rm -rf $(APP_WRAPPER)
	rm -f $(TARGET) $(OBJECTS) cl-cache.o cl-cycle.o cl-except.o cl-tlb.o
