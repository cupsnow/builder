#------------------------------------
# .DEFAULT_GOAL=all
# export MMWAVE_SDK_DEVICE?=awr16xx
# export MMWAVE_SECDEV_INSTALL_PATH=/home/joelai/02_dev
# export MMWAVE_SECDEV_HSIMAGE_CFG=$(MMWAVE_SECDEV_INSTALL_PATH)/hs_image_creator/hsimage.cfg
# include $(PROJDIR:%=%/)site-mmw.mk
#
export MMWAVE_SDK_DEVICE?=awr16xx
ifeq ("$(OS)","Windows_NT")
  export MMWAVE_SDK_TOOLS_INSTALL_PATH?=c:\\ti
else
  export MMWAVE_SDK_TOOLS_INSTALL_PATH?=/home/joelai/ti
#  export MMWAVE_SECDEV_INSTALL_PATH?=/media/sf_dc/03_arad/proj
endif

#export MMWAVE_SDK_INSTALL_PATH?=$(MMWAVE_SDK_TOOLS_INSTALL_PATH)/mmwave_sdk_02_00_00_04/packages
export MMWAVE_SDK_INSTALL_PATH?=$(lastword $(sort $(wildcard $(MMWAVE_SDK_TOOLS_INSTALL_PATH)/mmwave_sdk_*/packages)))

#export MMWAVE_SECDEV_HSIMAGE_CFG=${MMWAVE_SECDEV_INSTALL_PATH}/hs_image_creator/hsimage.cfg

include $(MMWAVE_SDK_INSTALL_PATH)/scripts/$(MMWSDK_HOST_PLATFORM)/setenv.mak
include $(MMWAVE_SDK_INSTALL_PATH)/ti/common/mmwave_sdk.mak

$(info site-mmw.mk ... MMWAVE_SDK_DEVICE: $(MMWAVE_SDK_DEVICE), \
  MMWAVE_SDK_INSTALL_PATH: $(MMWAVE_SDK_INSTALL_PATH))

#------------------------------------
# override mmw sdk
#
ifeq ("$(or $(MSYSTEM),$(OS))","MINGW64")
MKDIR=mkdir -p
CP=cp -dpR
RM=rm -rf
else ifeq ("$(or $(MSYSTEM),$(OS))","Windows_NT")
MKDIR=$(XDC_INSTALL_PATH)/bin/mkdir -p
CP=$(XDC_INSTALL_PATH)/bin/cp -dpR
RM=$(XDC_INSTALL_PATH)/bin/rm -rf
else
MKDIR=mkdir -p
CP=cp -dpR
RM=rm -rf
endif

#------------------------------------
#dss_RTSCPREFIX=dss_mmw
#$(eval $(call DSS_RTSC_BUILD1,dss))
#
define MSS_RTSC_BUILD1
$(1)_RTSCDIR?=rtsc_$$(MMWAVE_SDK_DEVICE_TYPE)
$(1)_RTSCPREFIX?=rtsc
$(1)_XSFLAGS+=$$(R4F_XSFLAGS)
$$($(1)_RTSCDIR): $$($(1)_RTSCPREFIX).cfg
	$$(XS) --xdcpath="$$(XDCPATH)" xdc.tools.configuro $$($(1)_XSFLAGS) \
	  -o $$@ $$($(1)_RTSCPREFIX).cfg
endef

define DSS_RTSC_BUILD1
$(1)_RTSCDIR?=rtsc_$$(MMWAVE_SDK_DEVICE_TYPE)
$(1)_RTSCPREFIX?=rtsc
$(1)_XSFLAGS+=$$(C674_XSFLAGS)
$$($(1)_RTSCDIR): $$($(1)_RTSCPREFIX).cfg
	$$(XS) --xdcpath="$$(XDCPATH)" xdc.tools.configuro $$($(1)_XSFLAGS) \
	  -o $$@ $$($(1)_RTSCPREFIX).cfg
endef

#------------------------------------
# BUILD1_CPPFLAGS
# --diag_suppress=179
#   error #179: variable "XXXXX" was declared but never referenced ...
#   error #552: variable "XXXXX" was set but never used ...
#   error #112: statement is unreachable
#   error #187: dynamic initialization in unreachable
#   error #225-D: function "XXX" declared implicitly
#
# BUILD1_LDFLAGS+=--verbose_diagnostics
#

#------------------------------------
#
define DSS_BUILD1
$1+=$2

$(1)_BUILDDIR?=$$(PLATFORM_OBJDIR)
$(1)_OBJ_C+=$$(patsubst %.c,$$($(1)_BUILDDIR)/%.$$(C674_OBJ_EXT),$$(filter %.c,$$($1)))
$(1)_OBJ_CPP+=$$(patsubst %.cpp,$$($(1)_BUILDDIR)/%.$$(C674_OBJ_EXT),$$(filter %.cpp,$$($1)))
$(1)_OBJ_ASM+=$$(patsubst %.asm,$$($(1)_BUILDDIR)/%.$$(C674_OBJ_EXT),$$(filter %.asm,$$($1)))
$(1)_LIBS+=$$(filter %.$$(C674_LIB_EXT),$$($1)) $$(wildcard \
  $$(C674x_MATHLIB_INSTALL_PATH)/packages/ti/mathlib/lib/mathlib.$$(C674_LIB_EXT) \
  $$(C64Px_DSPLIB_INSTALL_PATH)/packages/ti/dsplib/lib/dsplib.ae64P \
  $$(MMWAVE_SDK_INSTALL_PATH)/ti/drivers/osal/lib/libosal_$$(MMWAVE_SDK_DEVICE_TYPE).$$(C674_LIB_EXT))
$(1)_LINKER_CMD?=$$(if $$(filter c674x_linker.cmd %/c674x_linker.cmd,$$($1)),,$$(PLATFORM_C674X_LINK_CMD)) \
  $$(filter %linker.cmd,$$($1))
$(1)_CPPFLAGS+=-I$$(PWD) -I$$(PWD)/include -I$$(PWD)/inc \
  -I$$(PROJDIR) -I$$(PROJDIR)/common -I$$(PROJDIR)/include \
  -I$$(C674x_MATHLIB_INSTALL_PATH)/packages \
  -I$$(C64Px_DSPLIB_INSTALL_PATH)/packages/ti/dsplib/src/DSP_fft16x16/c64P \
  -I$$(C64Px_DSPLIB_INSTALL_PATH)/packages/ti/dsplib/src/DSP_fft32x32/c64P \
  $$(if $$($(1)_RTSCDIR),--cmd_file=$$($(1)_RTSCDIR)/compiler.opt) \
  $$(C674_CFLAGS)
$(1)_LDFLAGS+=$(C674_LDFLAGS) \
  $$(if $$($(1)_RTSCDIR),-l$$($(1)_RTSCDIR)/linker.cmd) \
  $$(addprefix -l,$$(sort $$($(1)_LIBS)))

DSS_BUILD1_OBJ_C+=$$($(1)_OBJ_C)
DSS_BUILD1_OBJ_CPP+=$$($(1)_OBJ_CPP)
DSS_BUILD1_OBJ_ASM+=$$($(1)_OBJ_ASM)

$$($(1)_BUILD_APP) $$($(1)_BUILD_LIB): DSS_BUILD1_CPPFLAGS+=$$($(1)_CPPFLAGS)
$$($(1)_BUILD_APP) $$($(1)_BUILD_LIB): DSS_BUILD1_CFLAGS+=$$($(1)_CFLAGS)
$$($(1)_BUILD_APP) $$($(1)_BUILD_LIB): DSS_BUILD1_CXXFLAGS+=$$($(1)_CXXFLAGS)
$$($(1)_BUILD_APP): DSS_BUILD1_LDFLAGS+=$$($(1)_LDFLAGS)
$$($(1)_BUILD_LIB): DSS_BUILD1_ARFLAGS?=$$(or $$($(1)_ARFLAGS),$$(C674_AR_OPTS))

$$($(1)_BUILD_LIB): $$($(1)_OBJ_C) $$($(1)_OBJ_CPP) $$($(1)_OBJ_ASM)
	$$(MKDIR) $$(dir $$@)
	$$(C674_AR) $$(DSS_BUILD1_ARFLAGS) $$@ \
	  $$($(1)_OBJ_C) $$($(1)_OBJ_CPP) $$($(1)_OBJ_ASM)

$$($(1)_BUILD_APP): $$($(1)_OBJ_C) $$($(1)_OBJ_CPP) $$($(1)_OBJ_ASM) $$($(1)_LIBS)
	$$(MKDIR) $$(dir $$@)
	$$(C674_LD) --list_directory=$$(dir $$@) \
	  $$(DSS_BUILD1_LDFLAGS) \
	  --map_file=$$($(1)_BUILDDIR)/$$(notdir $$@).map --mapfile_contents=all \
	  $$($(1)_OBJ_C) $$($(1)_OBJ_CPP) $$($(1)_OBJ_ASM) \
	  $$($(1)_LINKER_CMD) $$(C674_LD_RTS_FLAGS) \
	  -o $$@

$(1)_clean:
	$(RM) $$($(1)_OBJ_C) $$($(1)_OBJ_CPP) $$($(1)_OBJ_ASM)

endef

define DSS_BUILD1_COMPILE
$$(sort $$($(1)_OBJ_C)): $$($(1)_BUILDDIR)/%.$$(C674_OBJ_EXT): %.c
	$$(MKDIR) $$(@D)
	$$(C674_CC) -c --list_directory=$$(dir $$@) \
	  $$(DSS_BUILD1_CPPFLAGS) $$(DSS_BUILD1_CFLAGS) \
	  "-ppd=$(basename $$@).$(C674_DEP_EXT)" "$$<" --output_file $$@

$$(sort $$($(1)_OBJ_CPP)): $$($(1)_BUILDDIR)/%.$$(C674_OBJ_EXT): %.cpp
	$$(MKDIR) $$(@D)
	$$(C674_CC) -c $$(DSS_BUILD1_CPPFLAGS) $$(DSS_BUILD1_CXXFLAGS) \
	  "-ppd=$(basename $$@).$(C674_DEP_EXT)" "$$<" --output_file $$@

-include $$(addsuffix .$$(C674_DEP_EXT),$$(basename $$(sort $$($(1)_OBJ_C) $$($(1)_OBJ_CPP))))
endef

#------------------------------------
#
define MSS_BUILD1
$1+=$2

$(1)_BUILDDIR?=$$(PLATFORM_OBJDIR)
$(1)_OBJ_C+=$$(patsubst %.c,$$($(1)_BUILDDIR)/%.$$(R4F_OBJ_EXT),$$(filter %.c,$$($1)))
$(1)_OBJ_CPP+=$$(patsubst %.cpp,$$($(1)_BUILDDIR)/%.$$(R4F_OBJ_EXT),$$(filter %.cpp,$$($1)))
$(1)_OBJ_ASM+=$$(patsubst %.asm,$$($(1)_BUILDDIR)/%.$$(R4F_OBJ_EXT),$$(filter %.asm,$$($1)))
$(1)_LIBS+=$$(filter %.$$(R4F_LIB_EXT),$$($1)) $$(wildcard \
  $$(MMWAVE_SDK_INSTALL_PATH)/ti/drivers/osal/lib/libosal_$$(MMWAVE_SDK_DEVICE_TYPE).$$(R4F_LIB_EXT))
$(1)_LINKER_CMD?=$$(if $$(filter r4f_linker.cmd %/r4f_linker.cmd,$$($1)),,$$(PLATFORM_R4F_LINK_CMD)) \
  $$(filter %linker.cmd,$$($1))
$(1)_CPPFLAGS+=-I$$(PWD) -I$$(PWD)/include -I$$(PWD)/inc \
  -I$$(PROJDIR) -I$$(PROJDIR)/common -I$$(PROJDIR)/include \
  $$(if $$($(1)_RTSCDIR),--cmd_file=$$($(1)_RTSCDIR)/compiler.opt) \
  $$(R4F_CFLAGS) --display_error_number
$(1)_LDFLAGS+=$(R4F_LDFLAGS) \
  $$(if $$($(1)_RTSCDIR),-l$$($(1)_RTSCDIR)/linker.cmd) \
  $$(addprefix -l,$$(sort $$($(1)_LIBS)))

MSS_BUILD1_OBJ_C+=$$($(1)_OBJ_C)
MSS_BUILD1_OBJ_CPP+=$$($(1)_OBJ_CPP)
MSS_BUILD1_OBJ_ASM+=$$($(1)_OBJ_ASM)

$$($(1)_BUILD_APP) $$($(1)_BUILD_LIB): MSS_BUILD1_CPPFLAGS+=$$($(1)_CPPFLAGS)
$$($(1)_BUILD_APP) $$($(1)_BUILD_LIB): MSS_BUILD1_CFLAGS+=$$($(1)_CFLAGS)
$$($(1)_BUILD_APP) $$($(1)_BUILD_LIB): MSS_BUILD1_CXXFLAGS+=$$($(1)_CXXFLAGS)
$$($(1)_BUILD_APP): MSS_BUILD1_LDFLAGS+=$$($(1)_LDFLAGS)
$$($(1)_BUILD_APP): MSS_BUILD1_LDFLAGS2+=$$($(1)_LDFLAGS2)
$$($(1)_BUILD_LIB): MSS_BUILD1_ARFLAGS+=$$(or $$($(1)_ARFLAGS),$$(R4F_AR_OPTS))

$$($(1)_BUILD_LIB): $$($(1)_OBJ_C) $$($(1)_OBJ_CPP) $$($(1)_OBJ_ASM)
	$$(MKDIR) $$(dir $$@)
	$$(R4F_AR) $$(MSS_BUILD1_ARFLAGS) $$@ \
	  $$($(1)_OBJ_C) $$($(1)_OBJ_CPP) $$($(1)_OBJ_ASM)

$$($(1)_BUILD_APP): $$($(1)_OBJ_C) $$($(1)_OBJ_CPP) $$($(1)_OBJ_ASM) $$($(1)_LIBS)
	$$(MKDIR) $$(dir $$@)
	$$(R4F_LD) --list_directory=$$(dir $$@) \
	  $$(MSS_BUILD1_LDFLAGS)  \
	  --map_file=$$($(1)_BUILDDIR)/$$(notdir $$@).map --mapfile_contents=all \
	  $$($(1)_OBJ_C) $$($(1)_OBJ_CPP) $$($(1)_OBJ_ASM) \
	  $$($(1)_LINKER_CMD) $$(R4F_LD_RTS_FLAGS) \
	  -o $$@ $$(MSS_BUILD1_LDFLAGS2) || \
	  ($$(RM) $$@ && false)

$(1)_clean:
	$(RM) $$($(1)_OBJ_C) $$($(1)_OBJ_CPP) $$($(1)_OBJ_ASM)

endef

define MSS_BUILD1_COMPILE
$$(sort $$($(1)_OBJ_C)): $$($(1)_BUILDDIR)/%.$$(R4F_OBJ_EXT): %.c
	$$(MKDIR) $$(@D)
	$$(R4F_CC) -c --list_directory=$$(dir $$@) \
	  $$(MSS_BUILD1_CPPFLAGS) $$(MSS_BUILD1_CFLAGS) \
	  "-ppd=$$(basename $$@).$$(R4F_DEP_EXT)" "$$<" --output_file $$@ \

$$(sort $$($(1)_OBJ_CPP)): $$($(1)_BUILDDIR)/%.$$(R4F_OBJ_EXT): %.cpp
	$$(MKDIR) $$(@D)
	$$(R4F_CC) -c $$(MSS_BUILD1_CPPFLAGS) $$(MSS_BUILD1_CXXFLAGS) \
	  "-ppd=$$(basename $$@).$$(R4F_DEP_EXT)" "$$<" --output_file $$@

$$(sort $$($(1)_OBJ_ASM)): $$($(1)_BUILDDIR)/%.$$(R4F_OBJ_EXT): %.asm
	$$(MKDIR) $$(@D)
	$$(R4F_CC) -c $$(MSS_BUILD1_CPPFLAGS) $$(MSS_BUILD1_CFLAGS) \
	  "-ppd=$$(basename $$@).$$(R4F_DEP_EXT)" "$$<" --output_file $$@

-include $$(addsuffix .$$(R4F_DEP_EXT),$$(basename $$(sort $$($(1)_OBJ_C) $$($(1)_OBJ_CPP) $$($(1)_OBJ_ASM))))
endef

#------------------------------------
#
define MMW_GENIMG
$(or $(1),genimg): image=$(or $(strip $(2)),$$(DESTDIR)/image.bin)
$(or $(1),genimg): mss_EXE=$(or $(strip $(3)),$$(DESTDIR)/mss_$$(MMWAVE_SDK_DEVICE_TYPE).$$(R4F_EXE_EXT))
$(or $(1),genimg): bss_bin?=$(or $(strip $(4)),$$($$(call TOUPPER,$$(MMWAVE_SDK_DEVICE_TYPE))_RADARSS_IMAGE_BIN))
$(or $(1),genimg): dss_EXE=$(or $(strip $(5)),$(or $(2),$$(DESTDIR)/dss_$$(MMWAVE_SDK_DEVICE_TYPE).$$(C674_EXE_EXT)))
$(or $(1),genimg):
	$$(MKDIR) $$(BUILDDIR)/genimg $$(dir $$(image))
  ifneq ("$$(strip $$(wildcard $$(GENERATE_BIN)))","")
    ifneq ("$$(filter-out NULL,$$(dss_EXE))","")
	$$(GENERATE_BIN) $$(dss_EXE) \
	  $$(BUILDDIR)/genimg/$$(basename $$(notdir $$(dss_EXE))).bin
    endif
	$$(GENERATE_BIN) $$(mss_EXE) \
	  $$(BUILDDIR)/genimg/$$(basename $$(notdir $$(mss_EXE))).bin
	$$(GENERATE_METAIMAGE) $$(abspath $$(image)) 0x00000006 \
	  $$(BUILDDIR)/genimg/$$(basename $$(notdir $$(mss_EXE))).bin \
	  $$(if $$(filter-out NULL,$$(bss_bin)),$$(bss_bin),NULL) \
	  $$(if $$(filter-out NULL,$$(dss_EXE)),$$(BUILDDIR)/genimg/$$(basename $$(notdir $$(dss_EXE))).bin,NULL)
	-cd $$(BUILDDIR)/genimg && $$(GENERATE_HS_METAIMAGE) \
	  $$(basename $$(abspath $$(image))).sbin 0x00000006 $$(mss_EXE) \
	  $$(if $$(filter-out NULL,$$(bss_bin)),$$(bss_bin),NULL) \
	  $$(if $$(filter-out NULL,$$(dss_EXE)),$$(dss_EXE),NULL) \
	  $$(MMWAVE_SECDEV_HSIMAGE_CFG)
  else
	$$(GENERATE_METAIMAGE) $$(abspath $$(image)) $$(SHMEM_ALLOC) $$(mss_EXE) \
	  $$(if $$(filter-out NULL,$$(bss_bin)),$$(bss_bin),NULL) \
	  $$(if $$(filter-out NULL,$$(dss_EXE)),$$(dss_EXE),NULL)
	-cd $$(BUILDDIR)/genimg && $$(GENERATE_HS_METAIMAGE) \
	  $$(basename $$(abspath $$(image))).sbin $$(SHMEM_ALLOC) $$(mss_EXE) \
	  $$(if $$(filter-out NULL,$$(bss_bin)),$$(bss_bin),NULL) \
	  $$(if $$(filter-out NULL,$$(dss_EXE)),$$(dss_EXE),NULL) \
	  $$(MMWAVE_SECDEV_HSIMAGE_CFG)
  endif
	$$(RM) $$(BUILDDIR)/genimg
endef

# when error about database
# rm -rf /home/joelai/.ti/TICloudAgent
define MMW_FLASH
$(or $(1),flash): image=$(or $(strip $(2)),$$(DESTDIR)/image.sbin)
$(or $(1),flash): sbl=$(or $(strip $(3)),$$(wildcard ext/xwr16xx_sbl_secure.sbin))
$(or $(1),flash): port=$(or $(strip $(4)),$$(firstword $$(wildcard /dev/ttyACM* /dev/ttyUSB*)))
$(or $(1),flash): ccxml=$(or $(strip $(5)),$$(UNIFLASH_USER_PATH)/$$(or \
  $$(if $$(filter awr16xx,$$(MMWAVE_SDK_DEVICE)),awr1642.ccxml), \
  $$(if $$(filter iwr68xx,$$(MMWAVE_SDK_DEVICE)),iwr6843.ccxml)))
$(or $(1),flash): UNIFLASH_BASE_PATH=$$(lastword $$(wildcard /home/joelai/ti/uniflash/deskdb/content/TICloudAgent/linux/ccs_base))
$(or $(1),flash): UNIFLASH_USER_PATH=$$(HOME)/02_dev/uniflash_userdata
$(or $(1),flash):
	[ ! -e "$$(port)" ] && echo "Missing port: $$(port)" && false || true
	{ lsof $$(port) > /dev/null; } && echo "Occupied port: $$(port)" && false || true
	PATH=$$(UNIFLASH_BASE_PATH)/common/bin:$$$$PATH \
	  $$(UNIFLASH_BASE_PATH)/DebugServer/bin/DSLite flash \
	  --config=$$(ccxml) \
	  --load-settings=$$(UNIFLASH_USER_PATH)/settings.ufsettings \
	  --setting=COMPort=$$(port) --setting=FlashVerboseMode=true \
	  --list-settings=.* --verbose \
	  $$(and $$(filter-out NULL,$$(image)),"$$(abspath $$(image))"$$(COMMA)1) \
	  $$(and $$(filter-out NULL,$$(sbl)),"$$(abspath $$(sbl))"$$(COMMA)4)
endef

#------------------------------------
#------------------------------------
#------------------------------------
#------------------------------------
