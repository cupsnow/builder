#------------------------------------
# include $(PROJDIR:%=%/)proj.mk
#
PWD:=$(abspath .)
PROJDIR?=$(PWD)
BUILDDIR?=$(PROJDIR)/build
DESTDIR?=$(PROJDIR)/destdir
COMMA:=,
EMPTY:=#
SPACE:=$(empty) $(empty)

$(info proj.mk ... MAKECMDGOALS: $(MAKECMDGOALS), PWD: $(PWD), \
  PROJDIR: $(PROJDIR), PLATFORM: $(PLATFORM))

$(foreach i,else-if,$(if $(filter $i,$(.FEATURES)),,$(warning '$i' not support, might ignore)))

ifeq ("$(or $(MSYSTEM),$(OS))","Windows_NT")
MMWSDK_HOST_PLATFORM=windows
MMWSDK_HOST_SHEXT=.bat
else
MMWSDK_HOST_PLATFORM=unix
MMWSDK_HOST_SHEXT=.sh
endif

#------------------------------------
#
C++ =$(CROSS_COMPILE)g++
CC=$(CROSS_COMPILE)gcc
AR=$(CROSS_COMPILE)ar
LD=$(CROSS_COMPILE)ld
MKDIR=mkdir -p
#CP=cp -dpR
CP=rsync -a --info=progress2
RM=rm -rf
OBJDUMP=$(CROSS_COMPILE)objdump
OBJCOPY=$(CROSS_COMPILE)objcopy
NM=$(CROSS_COMPILE)nm
SIZE=$(CROSS_COMPILE)size
DOXYGEN=doxygen
CC_TARGET_HELP=$(CC) $(PLATFORM_CFLAGS) $(PLATFORM_LDFLAGS) -Q --help=target
ANSI_SGR=\033[$(1)m
ANSI_RED=$(call ANSI_SGR,31)
ANSI_GREEN=$(call ANSI_SGR,32)
ANSI_BLUE=$(call ANSI_SGR,34)
ANSI_CYAN=$(call ANSI_SGR,36)
ANSI_YELLOW=$(call ANSI_SGR,33)
ANSI_MAGENTA=$(call ANSI_SGR,35)
ANSI_COLOR0=$(ANSI_SGR)

DEP=$(1).d
DEPFLAGS=-MM -MF $(call DEP,$(1)) -MT $(1)

#------------------------------------
# EXTRA_PATH+=$(TOOLCHAIN_PATH:%=%/bin) $(TEST26DIR:%=%/tool/bin)
# export PATH:=$(call ENVPATH,$(EXTRA_PATH))
#
ENVPATH=$(subst $(SPACE),:,$(call UNIQ,$1) $(PATH))

#------------------------------------
# $(info AaBbccXXDF TOLOWER: $(call TOLOWER,AaBbccXXDF))
# $(info AaBbccXXDF TOUPPER: $(call TOUPPER,AaBbccXXDF))
#
MAPTO=$(subst $(firstword $1),$(firstword $2),$(if $(firstword $1),$(call MAPTO,$(filter-out $(firstword $1),$1),$(filter-out $(firstword $2),$2),$3),$3))
UPPERCASECHARACTERS=A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
LOWERCASECHARACTERS=a b c d e f g h i j k l m n o p q r s t u v w x y z
TOLOWER=$(call MAPTO,$(UPPERCASECHARACTERS),$(LOWERCASECHARACTERS),$1)
TOUPPER=$(call MAPTO,$(LOWERCASECHARACTERS),$(UPPERCASECHARACTERS),$1)

#------------------------------------
# $(call UNIQ,b b a a) # -> b a
#
UNIQ=$(if $1,$(strip $(firstword $1) $(call UNIQ,$(filter-out $(firstword $1),$1))))

#------------------------------------
# define $(1) and $(1)% cause trouble
#
define COMPONENT_BUILD1
$(1): $$($(1)_DEP)
	$$(MAKE) PROJDIR=$$(PROJDIR) DESTDIR=$$(DESTDIR) -C $(2)
$(1)_%: $$($(1)_DEP)
	$$(MAKE) PROJDIR=$$(PROJDIR) DESTDIR=$$(DESTDIR) -C $(2) \
	  $$(patsubst _%,%,$$(@:$(1)%=%))
.PHONY: $(1) $(1)_%
endef

#------------------------------------
#
define BUILD1
$1+=$2
$(1)_BUILDDIR?=$$(BUILDDIR)
$(1)_OBJ_C+=$$(patsubst %.c,$$($(1)_BUILDDIR)/%.o,$$(filter %.c,$$($1)))
$(1)_OBJ_CPP+=$$(patsubst %.cpp,$$($(1)_BUILDDIR)/%.o,$$(filter %.cpp,$$($1)))
$(1)_OBJ_ASM+=$$(patsubst %.s,$$($(1)_BUILDDIR)/%.o,$$(filter %.s,$$($1)))
$(1)_LIBS+=$$(filter %.a,$$($1))
$(1)_LINKER_CMD?=$$(firstword $$(filter %.ld,$$($1)))
$(1)_LDFLAGS+=$$($(1)_LINKER_CMD:%=-T %) $$(addprefix -l,$$(sort $$($(1)_LIBS)))

BUILD1_OBJ_C+=$$($(1)_OBJ_C)
BUILD1_OBJ_CPP+=$$($(1)_OBJ_CPP)
BUILD1_OBJ_ASM+=$$($(1)_OBJ_ASM)

$$($(1)_BUILD_APP) $$($(1)_BUILD_LIB): BUILD1_CPPFLAGS+=$$($(1)_CPPFLAGS)
$$($(1)_BUILD_APP) $$($(1)_BUILD_LIB): BUILD1_CFLAGS+=
$$($(1)_BUILD_APP) $$($(1)_BUILD_LIB): BUILD1_CXXFLAGS+=
$$($(1)_BUILD_APP) $$($(1)_BUILD_LIB): BUILD1_C++ =$$(or $$($(1)_C++),$$(C++))
$$($(1)_BUILD_APP) $$($(1)_BUILD_LIB): BUILD1_CC =$$(or $$($(1)_CC),$$(CC))
$$($(1)_BUILD_APP): BUILD1_LDFLAGS+=$$($(1)_LDFLAGS)
$$($(1)_BUILD_LIB): BUILD1_ARFLAGS?=$$(or $$($(1)_ARFLAGS),rcs)
$$($(1)_BUILD_LIB): BUILD1_AR =$$(or $$($(1)_BUILD_AR),$$(AR))

$$($(1)_BUILD_LIB): $$($(1)_OBJ_C) $$($(1)_OBJ_CPP) $$($(1)_OBJ_ASM)
	$$(MKDIR) $$(dir $$@)
	$$(BUILD1_AR) $$(BUILD1_ARFLAGS) $$@ \
	  $$($(1)_OBJ_C) $$($(1)_OBJ_CPP) $$($(1)_OBJ_ASM)

$$($(1)_BUILD_APP): $$($(1)_OBJ_C) $$($(1)_OBJ_CPP) $$($(1)_OBJ_ASM) $$($(1)_LIBS)
	$$(MKDIR) $$(dir $$@)
	$$(if $$($(1)_OBJ_CPP),$$(BUILD1_C++),$$(BUILD1_CC)) -o $$@ \
	  $$($(1)_OBJ_C) $$($(1)_OBJ_CPP) $$($(1)_OBJ_ASM) $$($(1)_LIBS) \
	  $$(BUILD1_CPPFLAGS) $$(if $$($(1)_OBJ_CPP),$$(BUILD1_CXXFLAGS),$$(BUILD1_CFLAGS)) \
	  $$(BUILD1_LDFLAGS)

$(1)_clean:
	$$(RM) $$($(1)_OBJ_C) $$($(1)_OBJ_CPP) $$($(1)_OBJ_ASM) \
	  $$(addsuffix $$(DEP),$$($(1)_OBJ_C) $$($(1)_OBJ_CPP))

-include $$(addsuffix $$(DEP),$$($(1)_OBJ_C) $$($(1)_OBJ_CPP))
endef

define BUILD1_COMPILE
$$(sort $$($(1)_OBJ_C)): $$($(1)_BUILDDIR)/%.o: %.c
	$$(MKDIR) $$(dir $$@)
	$$(BUILD1_CC) -c -o $$@ $$< $$(BUILD1_CPPFLAGS) $$(BUILD1_CFLAGS)
	$$(BUILD1_CC) -E $$(call DEPFLAGS,$$@) $$< $$(BUILD1_CPPFLAGS) $$(BUILD1_CFLAGS)

$$(sort $$($(1)_OBJ_CPP)): $$($(1)_BUILDDIR)/%.o: %.cpp
	$$(MKDIR) $$(dir $$@)
	$$(BUILD1_C++) -c -o $$@ $$< $$(BUILD1_CPPFLAGS) $$(BUILD1_CXXFLAGS)
	$$(BUILD1_C++) -E $$(call DEPFLAGS,$$@) $$< $$(BUILD1_CPPFLAGS) $$(BUILD1_CXXFLAGS)

$$(sort $$($(1)_OBJ_ASM)): $$($(1)_BUILDDIR)/%.o: %.s
	$$(MKDIR) $$(dir $$@)
	$$(BUILD1_CC) -c -o $$@ $$< $$(BUILD1_CPPFLAGS) $$(BUILD1_CFLAGS)

-include $$(addsuffix $$(DEP),$$(sort $$($(1)_OBJ_C) $$($(1)_OBJ_CPP)))
endef

#------------------------------------
# $(call BUILD2,<name>, <objgen>, <src>)
#
define BUILD2
$1+=$3
$(1)_OBJGEN+=$$(patsubst %,$$(BUILDDIR)/$(2:%=%/)%.o,$$(filter %.cpp %.c %.S,$$($1)))
$(1)_INOBJ+=$$(filter %.a %.o,$$($1))
$(1)_LDSCRIPT+=$$(filter %.ld,$$($1))
$(1)_LDFLAGS+=$$($(1)_LDSCRIPT:%=-T %)
$(or $(2),BUILD2_BUILDDIR)_OBJGEN+=$$($(1)_OBJGEN)

$$($(1)_APP) $$($(1)_LIB): BUILD2_CPPFLAGS+=$$($(1)_CPPFLAGS) 
$$($(1)_APP) $$($(1)_LIB): BUILD2_CFLAGS+=$$($(1)_CFLAGS)
$$($(1)_APP) $$($(1)_LIB): BUILD2_CXXFLAGS+=$$($(1)_CXXFLAGS)
$$($(1)_APP) $$($(1)_LIB): BUILD2_CC?=$$(or $$($(1)_CC),$$(CC))
$$($(1)_APP) $$($(1)_LIB): BUILD2_C++ ?=$$(or $$($(1)_C++),$$(C++))
$$($(1)_APP): BUILD2_LDFLAGS+=$$($(1)_LDFLAGS)
$$($(1)_LIB): BUILD2_ARFLAGS?=$$(or $$($(1)_ARFLAGS),rcs)
$$($(1)_LIB): BUILD2_AR?=$$(or $$($(1)_AR),$$(AR))

$$($(1)_APP): $$($(1)_OBJGEN) | $$($(1)_INOBJ)
	$$(MKDIR) $$(dir $$@)
	$$(or $$($(1)_LD),$$(if $$(filter %.cpp,$$($1)),$$(BUILD2_C++),$$(BUILD2_CC))) \
	  -o $$@ -Wl,--start-group $$($(1)_OBJGEN) $$($(1)_INOBJ) -Wl,--end-group \
	  $$(BUILD2_CPPFLAGS) $$(if $$(filter %.cpp,$$($1)),$$(BUILD2_CXXFLAGS),$$(BUILD2_CFLAGS)) \
	  $$(BUILD2_LDFLAGS)

$$($(1)_LIB): $$($(1)_OBJGEN) | $$($(1)_INOBJ)
	$$(MKDIR) $$(dir $$@)
	$$(BUILD2_AR) $$(BUILD2_ARFLAGS) $$@ $$($(1)_OBJGEN)

$(1)_clean:
	$$(RM) $$($(1)_OBJGEN) $$(addsuffix $$(DEP),$$($(1)_OBJGEN))

-include $$(addsuffix $$(DEP),$$($(1)_OBJGEN))
endef

define BUILD2_OBJGEN
$$(sort $$($(or $(1),BUILD2_BUILDDIR)_OBJGEN)): $$(BUILDDIR)/$(or $(2:%=%/),$(1:%=%/))%.o: %
	$$(MKDIR) $$(dir $$@)
	$$(if $$(filter %.cpp,$$<),$$(BUILD2_C++),$$(BUILD2_CC)) \
	  -c -o $$@ $$< $$(BUILD2_CPPFLAGS) \
	  $$(if $$(filter %.cpp,$$<),$$(BUILD2_CXXFLAGS),$$(BUILD2_CFLAGS))
	$$(if $$(filter %.cpp,$$<),$$(BUILD2_C++),$$(BUILD2_CC)) \
	  -E -o $$(call DEP,$$@) $$(call DEPFLAGS,$$@) $$< $$(BUILD2_CPPFLAGS) \
	  $$(if $$(filter %.cpp,$$<),$$(BUILD2_CXXFLAGS),$$(BUILD2_CFLAGS))
endef

#------------------------------------
define GITPROJ_DIST
$(or $(1),dist): DISTNAME=$(or $(strip $(2)),$$(or $$(shell PATH=$$(PATH) && git describe),master-$$(shell date '+%s')))
$(or $(1),dist):
	$$(RM) $$(BUILDDIR)/$$(DISTNAME)
	$$(MKDIR) $$(BUILDDIR)
	git clone --recurse-submodules ` ( cd $$(PROJDIR) && git remote get-url origin ) ` $$(BUILDDIR)/$$(DISTNAME)
	cd $$(BUILDDIR)/$$(DISTNAME) && \
	  git submodule foreach " ( rm -rf .git .gitmodules .gitignore ) "; rm -rf .git .gitmodules .gitignore playground
	$$(MKDIR) $$(DESTDIR)
	tar -Jcvf $$(DESTDIR)/$$(DISTNAME).tar.xz -C $$(BUILDDIR) $$(DISTNAME)
	$$(RM) $$(BUILDDIR)/$$(DISTNAME)
endef

#------------------------------------
#------------------------------------
#------------------------------------
