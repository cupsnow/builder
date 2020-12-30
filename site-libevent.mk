#------------------------------------
# include $(PROJDIR:%=%/)proj.mk
#

#------------------------------------
# $(eval $(call COMPONENT_LIBEVENT))
#
define COMPONENT_LIBEVENT
libevent_BUILDROOT?=$$(BUILDDIR)/libevent
libevent_repo $$(libevent_BUILDROOT)/repo:
	[ -d $$(libevent_BUILDROOT)/repo ] || \
	  git clone https://github.com/libevent/libevent.git $$(libevent_BUILDROOT)/repo
	cd $$(libevent_BUILDROOT)/repo && \
	  ./autogen.sh

libevent_config $$(libevent_BUILDROOT)/outoftree/config.h: | $$(libevent_BUILDROOT)/repo
	[ -d $$(libevent_BUILDROOT)/outoftree ] || \
	  $$(MKDIR) $$(libevent_BUILDROOT)/outoftree
	cd $$(libevent_BUILDROOT)/outoftree && \
	  $$(libevent_BUILDROOT)/repo/configure --prefix= --host=`$$(CC) -dumpmachine` \
	    --disable-openssl

libevent: | $$(libevent_BUILDROOT)/outoftree/config.h
	$$(MAKE) DESTDIR=$$(DESTDIR) -C $$(libevent_BUILDROOT)/outoftree install
endef
