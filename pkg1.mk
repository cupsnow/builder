#------------------------------------
#
$(eval $(call AC_BUILD2,fdkaac $(PKGDIR2)/fdk-aac $(BUILDDIR2)/fdkaac-$(APP_BUILD)))

#------------------------------------
#
$(eval $(call AC_BUILD2,faad2 $(PKGDIR2)/faad2 $(BUILDDIR2)/faad2-$(APP_BUILD)))

#------------------------------------
#
mdns_DIR=$(PKGDIR2)/mDNSResponder
mdns_BUILDDIR=$(BUILDDIR2)/mdns-$(APP_BUILD)
mdns_CPPFLAGS_EXTRA+=-lgcc_s -Wno-expansion-to-defined -Wno-stringop-truncation \
  -Wno-address-of-packed-member -Wno-enum-conversion

# match airplay makefile
mdns_BUILDDIR2=build/destdir

mdns_MAKE=$(MAKE) os=linux CC=$(CC) LD=$(LD) ST=$(STRIP) \
  CFLAGS_PTHREAD=-pthread LINKOPTS_PTHREAD=-pthread \
  BUILDDIR=$(mdns_BUILDDIR2) OBJDIR=build \
  CPPFLAGS_EXTRA+="$(mdns_CPPFLAGS_EXTRA)" \
  INSTBASE=$(INSTBASE) -C $(mdns_BUILDDIR)/mDNSPosix

mdns_defconfig $(mdns_BUILDDIR)/mDNSPosix/Makefile:
	[ -d $(mdns_BUILDDIR) ] || $(MKDIR) $(mdns_BUILDDIR)
	$(CP) $(mdns_DIR)/* $(mdns_BUILDDIR)

# dep: mdns
mdns_install: INSTBASE=$(BUILD_SYSROOT)
mdns_install: mdns | $(mdns_BUILDDIR)/mDNSPosix/Makefile
	$(mdns_MAKE) InstalledLib InstalledClients
	[ -d $(INSTBASE)/sbin ] || $(MKDIR) $(INSTBASE)/sbin
	$(CP) $(mdns_BUILDDIR)/mDNSPosix/$(mdns_BUILDDIR2)/mdnsd \
	  $(INSTBASE)/sbin/
	[ -d $(INSTBASE)/bin ] || $(MKDIR) $(INSTBASE)/bin
	$(CP) $(mdns_BUILDDIR)/mDNSPosix/$(mdns_BUILDDIR2)/mDNSClientPosix \
	  $(mdns_BUILDDIR)/mDNSPosix/$(mdns_BUILDDIR2)/mDNSNetMonitor \
	  $(mdns_BUILDDIR)/mDNSPosix/$(mdns_BUILDDIR2)/mDNSResponderPosix \
	  $(INSTBASE)/bin/
	[ -d $(INSTBASE)/share/man/man8 ] || $(MKDIR) $(INSTBASE)/share/man/man8
	$(CP) $(mdns_BUILDDIR)/mDNSShared/mDNSResponder.8 \
	  $(INSTBASE)/share/man/man8/mdnsd.8
	[ -d $(INSTBASE)/share/man/man1 ] || $(MKDIR) $(INSTBASE)/share/man/man1
	$(CP) $(mdns_BUILDDIR)/mDNSShared/dns-sd.1 \
	  $(INSTBASE)/share/man/man1

mdns $(mdns_BUILDDIR)/mDNSPosix/$(mdns_BUILDDIR2)/mdnsd: | $(mdns_BUILDDIR)/mDNSPosix/Makefile
	$(mdns_MAKE)

mdns_%: | $(mdns_BUILDDIR)/mDNSPosix/Makefile
	$(mdns_MAKE) $(@:mdns_%=%)

