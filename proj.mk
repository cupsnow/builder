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

$(info proj.mk ... PWD: $(PWD))
$(info proj.mk ... PROJDIR: $(PROJDIR))
$(info proj.mk ... MAKECMDGOALS: $(MAKECMDGOALS))

ifeq ("$(or $(MSYSTEM),$(OS))","Windows_NT")
MMWSDK_HOST_PLATFORM=windows
MMWSDK_HOST_SHEXT=.bat
else
MMWSDK_HOST_PLATFORM=unix
MMWSDK_HOST_SHEXT=.sh
endif

#------------------------------------
#
MKDIR=mkdir -p
CP=cp -dpR
RM=rm -rf
DOXYGEN=doxygen

DEP=$(1).d
DEPFLAGS=-MM -MF $(call DEP,$(1)) -MT $(1)

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
#
define COMPONENT_BUILD1
$(1): $(1)_ ;
$(1)%:
	$$(MAKE) PROJDIR=$$(PROJDIR) DESTDIR=$$(DESTDIR) $(3) -C $(2) \
	  $$(patsubst _%,%,$$(@:$(1)%=%))
.PHONY: $(1) $(1)%
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
$1: $$($(1)_APP) $$($(1)_LIB)

$$($(1)_APP): $$($(1)_OBJGEN) | $$($(1)_INOBJ)
	$$(MKDIR) $$(dir $$@)
	$$(or $$($(1)_LD),$$(if $$(filter %.cpp,$$($1)),$$(BUILD2_C++),$$(BUILD2_CC))) \
	  -o $$@ -Wl,--start-group $$($(1)_OBJGEN) $$($(1)_INOBJ) -Wl,--end-group \
	  $$(BUILD2_CPPFLAGS) $$(if $$(filter %.cpp,$$($1)),$$(BUILD2_CXXFLAGS),$$(BUILD2_CFLAGS)) \
	  $$(BUILD2_LDFLAGS)

$$($(1)_LIB): $$($(1)_OBJGEN)
	$$(MKDIR) $$(dir $$@)
	$$(BUILD2_AR) $$(BUILD2_ARFLAGS) $$@ $$($(1)_OBJGEN)

$(1)_clean:
	$$(RM) $$($(1)_OBJGEN) $$(addsuffix $$(DEP),$$($(1)_OBJGEN))

-include $$(addsuffix $$(DEP),$$($(1)_OBJGEN))
endef

define BUILD2_OBJGEN
$$(sort $$($(or $(1),BUILD2_BUILDDIR)_OBJGEN)): $$(BUILDDIR)/$(1:%=%/)%.o: %
	$$(MKDIR) $$(dir $$@)
	$$(if $$(filter %.cpp,$$<),$$(BUILD2_C++),$$(BUILD2_CC)) \
	  -c -o $$@ $$< $$(BUILD2_CPPFLAGS) \
	  $$(if $$(filter %.cpp,$$<),$$(BUILD2_CXXFLAGS),$$(BUILD2_CFLAGS))
	$$(if $$(filter %.cpp,$$<),$$(BUILD2_C++),$$(BUILD2_CC)) \
	  -E -o $$(call DEP,$$@) $$(call DEPFLAGS,$$@) $$< $$(BUILD2_CPPFLAGS) \
	  $$(if $$(filter %.cpp,$$<),$$(BUILD2_CXXFLAGS),$$(BUILD2_CFLAGS))
endef

#------------------------------------
#------------------------------------
#------------------------------------
#------------------------------------
