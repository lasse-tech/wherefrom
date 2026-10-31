ADDON := Wherefrom

REQUIRED  := clean distclean debug install uninstall deploy lint
HELP_VARS := WOW_RETAIL_ADDON_FOLDER WOW_DIR FLAVOR WOW_UI_SIM TAG DRY_RUN CONFIRM

## WOW_RETAIL_ADDON_FOLDER: Interface/AddOns of the retail client (used when FLAVOR=_retail_)
WOW_RETAIL_ADDON_FOLDER ?=

## WOW_DIR: World of Warcraft folder, overrides auto-detection
WOW_DIR ?=

## FLAVOR: client folder below WOW_DIR
FLAVOR ?= _retail_

## WOW_UI_SIM: wow-ui-sim checkout for make test
WOW_UI_SIM ?= $(HOME)/git/wow-ui-sim

TOC     := $(ADDON)_Mainline.toc
VERSION := $(shell sed -n 's/^## Version: //p' $(TOC))

INSTALL_FILES := $(TOC) CHANGELOG.md LICENSE
INSTALL_DIRS  := Core UI Locales Media
LUA_DIRS      := Core UI Locales

DIST_DIR := dist
ZIP      := $(DIST_DIR)/$(ADDON)-$(VERSION).zip

GITHUB_URL := git@github.com:lasse-tech/wherefrom.git

## TAG: release tag make github exports
TAG ?= v$(VERSION)

## DRY_RUN: 1 = make github commits in dist/github, pushes nothing
DRY_RUN ?= 0

## CONFIRM: yes = make purge deletes the SavedVariables
CONFIRM ?=

# public export: one commit per release tag
PUBLIC_DIR   := $(DIST_DIR)/public
PUBLIC_PATHS := $(INSTALL_FILES) $(INSTALL_DIRS) README.md .pkgmeta github Makefile Makefile.bat scripts tools \
	tests .luacheckrc .gitignore
PUBLIC_NAME  := Lars Gossard
PUBLIC_EMAIL := lars@lasse-tech.de

WOW_CANDIDATES := \
	"$$PROGRAMFILES/World of Warcraft" \
	"C:/Program Files (x86)/World of Warcraft" \
	"C:/Program Files/World of Warcraft" \
	"/games/battlenet/drive_c/Program Files (x86)/World of Warcraft" \
	"D:/World of Warcraft" \
	"C:/Games/World of Warcraft"

# WOW_RETAIL_ADDON_FOLDER only names the retail folder; another FLAVOR derives the root from it
FIND_ADDONS = if [ "$(FLAVOR)" = _retail_ ] && [ -n "$(WOW_RETAIL_ADDON_FOLDER)" ]; then \
	echo "$(WOW_RETAIL_ADDON_FOLDER)"; \
	elif [ -n "$(WOW_DIR)" ]; then echo "$(WOW_DIR)/$(FLAVOR)/Interface/AddOns"; \
	else retail_root=""; \
	if [ -n "$(WOW_RETAIL_ADDON_FOLDER)" ]; then \
	retail_root=$$(dirname "$$(dirname "$$(dirname "$(WOW_RETAIL_ADDON_FOLDER)")")"); fi; \
	for d in $(WOW_CANDIDATES) "$$retail_root"; do \
	if [ -n "$$d" ] && [ -d "$$d/$(FLAVOR)" ]; then echo "$$d/$(FLAVOR)/Interface/AddOns"; break; fi; \
	done; fi

NO_ADDONS_MSG = echo "AddOns folder not found. Set WOW_RETAIL_ADDON_FOLDER=/path/to/Interface/AddOns or WOW_DIR=/path/to/World of Warcraft"

.DEFAULT_GOAL := help

.PHONY: help version check check-toc check-locales ruff lint test install debug uninstall purge \
	dist deploy release public github clean distclean

##@ General

## help: list targets and variables
help:
	@echo "$(ADDON) $(VERSION)"
	@$(foreach v,$(HELP_VARS),$(v)='$($(v))') awk -f scripts/make-help.awk $(firstword $(MAKEFILE_LIST))

## version: print the addon version
version:
	@echo "$(VERSION)"

##@ Checks

# luac only parses; without luacheck the lint fails
## check: luacheck over Core, UI, Locales and tests, any warning fails
check:
	@files=$$(find $(LUA_DIRS) tests -name '*.lua' | sort); \
	if command -v luacheck >/dev/null 2>&1; then \
		luacheck $$files || exit 1; \
	elif command -v luac >/dev/null 2>&1; then \
		luac -p $$files || exit 1; \
		echo "luac: all files parse"; \
		echo "  luacheck is not installed - this only checked syntax."; \
		echo "  install it with: sudo apt install lua-check  (or: luarocks install luacheck)"; \
		exit 1; \
	else \
		echo "no Lua available (install lua/luac and luacheck)"; exit 1; \
	fi

## check-toc: every file the TOC lists exists, every Lua/XML file is listed
check-toc:
	@missing=0; \
	for f in $$(sed -n 's/\r$$//; s|\\|/|g; /^[A-Za-z].*\.\(lua\|xml\)$$/p' $(TOC)); do \
		[ -f "$$f" ] || { echo "  MISSING $$f (listed in the TOC)"; missing=1; }; \
	done; \
	[ $$missing -eq 0 ] || exit 1; \
	echo "toc: every listed file exists"
	@untracked=0; \
	for f in $$(find $(LUA_DIRS) -name '*.lua' -o -name '*.xml' | sort); do \
		grep -qF "$$(echo $$f | tr '/' '\\')" $(TOC) || { echo "  UNLISTED $$f"; untracked=1; }; \
	done; \
	[ $$untracked -eq 0 ] || exit 1; \
	echo "toc: every file is listed"

## check-locales: every L["..."] the code asks for exists in both locales
check-locales:
	@python3 tools/check-locales.py

## ruff: Python checks on tools/, any finding fails
ruff:
	@command -v ruff >/dev/null 2>&1 || { echo "ruff not found (pipx install ruff)"; exit 1; }
	@ruff check --no-cache -q tools/*.py && echo "ruff: no findings"

## lint: luacheck, TOC, locales, ruff, Makefile comments (BLOCKER)
lint: check check-toc check-locales ruff
	@awk -v required="$(REQUIRED)" -f scripts/make-lint.awk $(firstword $(MAKEFILE_LIST))
	@awk -v required="$(REQUIRED)" -v bat=1 -f scripts/make-lint.awk Makefile.bat
	@echo "make: comments ok"

##@ Testing

# addon, TestFramework and the binary are staged under dist/sim; WOW_SIM_WOW_PATH stays unset
SIM_BIN := $(WOW_UI_SIM)/target/release/wow-sim
SIM_DIR := $(DIST_DIR)/sim

## test: run tests/ headless in wow-ui-sim
test:
	@[ -x "$(SIM_BIN)" ] || { echo "wow-sim not found at $(SIM_BIN)"; \
		echo "build it: cd $(WOW_UI_SIM) && cargo build --release --no-default-features --features casc,client-retail --bin wow-sim"; \
		exit 1; }
	@rm -rf "$(SIM_DIR)"
	@out="$(SIM_DIR)/Interface/AddOns/$(ADDON)"; mkdir -p "$$out"; \
	for d in $(INSTALL_DIRS) tests; do cp -r "$$d" "$$out/"; done; \
	cp $(TOC) "$$out/"; \
	cp -r "$(WOW_UI_SIM)/Interface/AddOns/TestFramework" "$(SIM_DIR)/Interface/AddOns/"; \
	ln -f "$(SIM_BIN)" "$(SIM_DIR)/wow-sim" 2>/dev/null || cp "$(SIM_BIN)" "$(SIM_DIR)/wow-sim"
	@cd "$(SIM_DIR)" && env -u WOW_SIM_WOW_PATH ./wow-sim --no-saved-vars run-tests $(ADDON)

##@ Client

## install: copy the addon into the client
install:
	@addons=$$($(FIND_ADDONS)); \
	if [ -z "$$addons" ]; then $(NO_ADDONS_MSG); exit 1; fi; \
	target="$$addons/$(ADDON)"; \
	echo "installing $(ADDON) $(VERSION) -> $$target"; \
	mkdir -p "$$target" || exit 1; \
	for d in $(INSTALL_DIRS); do rm -rf "$$target/$$d"; cp -r "$$d" "$$target/" || exit 1; done; \
	for f in $(INSTALL_FILES); do cp "$$f" "$$target/" || exit 1; done; \
	for x in tests tools scripts .claude .git dist README.md CLAUDE.md .gitignore .pkgmeta .luacheckrc \
		Makefile Makefile.bat; do \
		if [ -e "$$target/$$x" ]; then \
			echo "  removing stray $$x (not part of the addon)"; \
			rm -rf "$$target/$$x"; \
		fi; \
	done; \
	echo "done - /reload in game"

## debug: install with tests/ and print the in-game debug switches
debug:
	@$(MAKE) --no-print-directory install
	@addons=$$($(FIND_ADDONS)); target="$$addons/$(ADDON)"; \
	cp -r tests "$$target/" || exit 1; \
	echo "  tests/ included"
	@echo ""
	@echo "In game:"
	@echo "  /console scriptErrors 1     show Lua errors instead of swallowing them"
	@echo "  /wf status                  what is recorded and indexed"
	@echo "  /wf index                   rebuild the drop index now"
	@echo "  set 'Announce every recorded item in chat' to watch captures live"

## uninstall: remove the addon, SavedVariables stay
uninstall:
	@addons=$$($(FIND_ADDONS)); \
	if [ -z "$$addons" ]; then $(NO_ADDONS_MSG); exit 1; fi; \
	target="$$addons/$(ADDON)"; \
	if [ ! -d "$$target" ]; then echo "not installed: $$target"; exit 0; fi; \
	rm -rf "$$target"; \
	echo "removed $$target"; \
	echo "SavedVariables kept - 'make purge CONFIRM=yes' deletes them"

## purge: uninstall and delete the SavedVariables (needs CONFIRM=yes)
purge:
	@if [ "$(CONFIRM)" != "yes" ]; then \
		echo "refusing to delete SavedVariables without CONFIRM=yes"; \
		echo "   make purge CONFIRM=yes"; exit 1; fi
	@$(MAKE) --no-print-directory uninstall
	@addons=$$($(FIND_ADDONS)); \
	if [ -z "$$addons" ]; then $(NO_ADDONS_MSG); exit 1; fi; \
	flavor_dir=$$(dirname "$$(dirname "$$addons")"); \
	found=0; \
	for f in "$$flavor_dir"/WTF/Account/*/SavedVariables/$(ADDON).lua*; do \
		[ -e "$$f" ] || continue; \
		echo "  deleting $$f"; rm -f "$$f"; found=1; \
	done; \
	[ $$found -eq 1 ] || echo "  no SavedVariables found"

##@ Release

## dist: build dist/Wherefrom-<version>.zip
dist:
	@rm -rf $(DIST_DIR)/$(ADDON); rm -f $(ZIP)
	@mkdir -p $(DIST_DIR)/$(ADDON)
	@for d in $(INSTALL_DIRS); do cp -r "$$d" $(DIST_DIR)/$(ADDON)/; done
	@for f in $(INSTALL_FILES); do cp "$$f" $(DIST_DIR)/$(ADDON)/; done
	@rm -f $(DIST_DIR)/$(ADDON)/Media/README.md $(DIST_DIR)/$(ADDON)/Media/Icon.svg
	@if command -v zip >/dev/null 2>&1; then \
		( cd $(DIST_DIR) && zip -qr "$(ADDON)-$(VERSION).zip" $(ADDON) ); \
	else \
		tar -a -c -f "$(ZIP)" -C "$(DIST_DIR)" "$(ADDON)"; \
	fi
	@rm -rf $(DIST_DIR)/$(ADDON)
	@echo "built $(ZIP)"

## deploy: none - installation: README.md, section Installation
deploy:
	@echo "No deploy: see README.md, section Installation"

## release: print the commands that tag v<version> and push it to Forgejo (exported to GitHub)
release:
	@echo "git tag v$(VERSION) && git push origin main v$(VERSION)"

# github/gitattributes: renamed on export (git archive would apply it to github/)
# $(call public-tree,<ref>,<out dir>)
define public-tree
	rm -rf "$(2)" && mkdir -p "$(2)"
	git archive "$(1)" $(PUBLIC_PATHS) | tar -x -C "$(2)"
	cp -r "$(2)/github/." "$(2)/" && rm -r "$(2)/github"
	mv "$(2)/gitattributes" "$(2)/.gitattributes"
endef

## public: build the public export of HEAD into dist/public
public:
	$(call public-tree,HEAD,$(PUBLIC_DIR))
	@cd $(PUBLIC_DIR) && find . -type f | sort

## github: export TAG to GitHub as one commit and tag it
github:
	@git rev-parse -q --verify "refs/tags/$(TAG)" >/dev/null || { echo "tag $(TAG) not found"; exit 1; }
	@! git ls-remote --exit-code --tags $(GITHUB_URL) "refs/tags/$(TAG)" >/dev/null || { echo "$(TAG) is on GitHub already"; exit 1; }
	$(call public-tree,$(TAG),$(PUBLIC_DIR))
	rm -rf $(DIST_DIR)/github && git clone -q $(GITHUB_URL) $(DIST_DIR)/github
	@cd $(DIST_DIR)/github && git checkout -q -B main \
		&& find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + \
		&& cp -r ../public/. . && git add -A \
		&& GIT_AUTHOR_NAME="$(PUBLIC_NAME)" GIT_AUTHOR_EMAIL="$(PUBLIC_EMAIL)" \
		GIT_COMMITTER_NAME="$(PUBLIC_NAME)" GIT_COMMITTER_EMAIL="$(PUBLIC_EMAIL)" \
		git commit -qm "$(ADDON) $(TAG:v%=%)" && git tag "$(TAG)" \
		&& git show --format="%h %s" --stat=100 HEAD | sed '$$d'
	@if [ "$(DRY_RUN)" = "1" ]; then echo "DRY_RUN=1: nothing pushed, see $(DIST_DIR)/github"; \
	else cd $(DIST_DIR)/github && git push -q origin main "refs/tags/$(TAG)" && echo "pushed $(TAG) to GitHub"; fi

##@ Housekeeping

## clean: remove dist/
clean:
	@rm -rf $(DIST_DIR)
	@echo "cleaned"

## distclean: clean and drop editor leftovers (*.orig, *.rej)
distclean: clean
	@find . -name '*.orig' -o -name '*.rej' | xargs -r rm -f
	@echo "distclean"
