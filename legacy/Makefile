mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))

.SILENT:

MODULE := $(lastword $(subst ., ,$(current_dir)))
PREFIX ?= ~/.hammerspoon
MODPATH = hs
HS_APPLICATION ?= /Applications

SRC_FILES = ${wildcard src/*.lua}

# special vars for uninstall
space :=
space +=
comma := ,

all:
	@echo nothing to do

install:
	mkdir -p $(PREFIX)/$(MODPATH)
	install -m 0644 $(SRC_FILES) $(PREFIX)/$(MODPATH)

uninstall:
	rm -v -f $(PREFIX)/$(MODPATH)/{$(subst $(space),$(comma),$(notdir $(SRC_FILES)))}
	rmdir -p $(PREFIX)/$(MODPATH) ; exit 0

.PHONY: all install uninstall

