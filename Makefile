NVIDIA_VERSION = 440.100
NVIDIA_VERSION_DEB = 1

NVIDIA_BETA_VERSION = 440.66.17
NVIDIA_BETA_PKG = nvidia-graphics-drivers-$(NVIDIA_BETA_VERSION)
NVIDIA_BETA_TAR = nvidia-graphics-drivers_$(NVIDIA_BETA_VERSION)
NVIDIA_BETA_URL = https://developer.nvidia.com/vulkan-beta-$(subst .,,$(NVIDIA_BETA_VERSION))-linux
NVIDIA_BETA_SRC = NVIDIA-Linux-x86_64-$(NVIDIA_BETA_VERSION).run

.PHONY: all
all: $(NVIDIA_BETA_PKG)

$(NVIDIA_BETA_PKG).orig-amd64/$(NVIDIA_BETA_SRC): $(shell mkdir -p $(NVIDIA_BETA_PKG).orig-amd64)
	wget --content-disposition $(NVIDIA_BETA_URL) -O $@
$(NVIDIA_BETA_PKG).orig-amd64:
	mkdir -p $@
$(NVIDIA_BETA_TAR).orig-amd64.tar.gz: $(NVIDIA_BETA_PKG).orig-amd64 $(NVIDIA_BETA_PKG).orig-amd64/$(NVIDIA_BETA_SRC)
	tar --owner=root --group=src --mode=+x -czvf $(@F) -C $(@D) $<

$(NVIDIA_BETA_PKG).orig:
	mkdir -p $@
$(NVIDIA_BETA_TAR).orig.tar.gz: $(NVIDIA_BETA_PKG).orig
	tar --owner=root --group=src --mode=+x -czvf $(@F) -C $(@D) $<

nvidia-graphics-drivers-$(NVIDIA_VERSION):
	apt source nvidia-driver=$(NVIDIA_VERSION)-$(NVIDIA_VERSION_DEB)

$(NVIDIA_BETA_PKG): nvidia-graphics-drivers-$(NVIDIA_VERSION) $(NVIDIA_BETA_TAR).orig.tar.gz $(NVIDIA_BETA_TAR).orig-amd64.tar.gz
	rm -rf $@
	cd nvidia-graphics-drivers-$(NVIDIA_VERSION) && uupdate -b -f -v $(NVIDIA_BETA_VERSION)
	cp kernel-5.6.patch "$@/debian/patches/" && echo kernel-5.6.patch >> "$@/debian/patches/series-postunpack"
	cp kernel-5.7.patch "$@/debian/patches/" && echo kernel-5.7.patch >> "$@/debian/patches/series-postunpack"
	# Remove patch incompatible with beta
	rm "$@/debian/module/debian/patches/kernel-5.7.0-set-memory-array.patch" && sed -i '/kernel-5.7.0-set-memory-array.patch/d' "$@/debian/module/debian/patches/series.in"
	-cd "$@" && (make -f debian/rules nv-readme.ids; cp nv-readme.ids debian)
	cd "$@" && dpkg-buildpackage -j12 --build=binary --post-clean
	cd "$@" && dpkg-buildpackage -j12 -a i386 --build=any --post-clean

	# remove legacy/non-glvnd packages
	rm libegl1-nvidia_$(NVIDIA_BETA_VERSION)-1_amd64.deb \
	   nvidia-nonglvnd-vulkan-common_$(NVIDIA_BETA_VERSION)-1_amd64.deb \
	   nvidia-nonglvnd-vulkan-common_$(NVIDIA_BETA_VERSION)-1_i386.deb \
	   nvidia-libopencl1_$(NVIDIA_BETA_VERSION)-1_amd64.deb \
	   nvidia-libopencl1_$(NVIDIA_BETA_VERSION)-1_i386.deb \
	   nvidia-driver_$(NVIDIA_BETA_VERSION)-1_i386.deb \
	   nvidia-smi_$(NVIDIA_BETA_VERSION)-1_i386.deb \
	   xserver-xorg-video-nvidia_$(NVIDIA_BETA_VERSION)-1_i386.deb

	@echo "Now run 'sudo make install' to install all the packages."

.PHONY: clean
clean:
	rm -rf nvidia-graphics-drivers*
	rm -f *.deb

.PHONY: install
install: dpkg-install apt-hold

.PHONY: dpkg-install
dpkg-install:
	dpkg -i *$(NVIDIA_BETA_VERSION)-1_*.deb

.PHONY: apt-hold
apt-hold:
	apt-mark hold $$(ls -1 *$(NVIDIA_BETA_VERSION)-1_*.deb | perl -ne '/^([\w-]*)_[\d-\.]*_(\w*)\.deb$$/ && print "$$1:$$2\n"')

.PHONY: apt-unhold
apt-unhold:
	apt-mark unhold $$(ls -1 *$(NVIDIA_BETA_VERSION)-1_*.deb | perl -ne '/^([\w-]*)_[\d-\.]*_(\w*)\.deb$$/ && print "$$1:$$2\n"')
