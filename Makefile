# This file is protected by Copyright. Please refer to the COPYRIGHT file
# distributed with this source distribution.
#
# This file is part of OpenCPI <http://www.opencpi.org>
#
# OpenCPI is free software: you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# OpenCPI is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

##########################################################################################
ifneq ($(filter show help clean% distclean%,$(MAKECMDGOALS)),)
  ifndef OCPI_CDK_DIR
    export OCPI_CDK_DIR:=$(CURDIR)/bootstrap
  endif
else
  ifndef OCPI_CDK_DIR
    export OCPI_CDK_DIR:=$(CURDIR)/cdk
  endif
  ifeq ($(wildcard exports),)
    $(info Exports have never been set up for this tree  Doing it now.)
    $(info $(shell ./scripts/makeExportLinks.sh - -))
  endif
endif

include $(OCPI_CDK_DIR)/include/util.mk
$(eval $(OcpiEnsureToolPlatform))
override \
RccPlatforms:=$(call Unique,\
                $(or $(strip $(RccPlatforms) $(RccPlatform) $(Platforms) $(Platform)),\
	             $(OCPI_TOOL_PLATFORM)))
export RccPlatforms
DoExports=for p in $(RccPlatforms); do ./scripts/makeExportLinks.sh $$p; done
DoTests=for p in $(RccPlatforms); do ./scripts/test-opencpi.sh $$p; done
# Get macros and rcc platform/target processing
include $(OCPI_CDK_DIR)/include/rcc/rcc-make.mk

##########################################################################################
# Goals that are not about projects
.PHONY: exports      framework      projects      driver      testframework \
        cleanexports cleanframework cleanprojects cleandriver clean
all framework:
	$(AT)$(MAKE) -C build/autotools install Platforms="$(RccPlatforms)"
	$(AT)$(DoExports)

cleanframework:
	$(AT)$(MAKE) -C build/autotools clean Platforms="$(RccPlatforms)"

# This still relies on the projects being built, and runs lots of things,
# but does not run unit tests in the non-core projects
testframework:
	$(AT)$(DoTests)

exports:
	$(AT)echo Updating exports for platforms: $(RccPlatforms)
	$(AT)$(DoExports)

cleanexports:
	$(AT)rm -r -f exports

driver:
	$(AT)set -e;\
	     $(foreach p,$(RccPlatforms),\
	       $(foreach t,$(RccTarget_$p),\
	         $(foreach o,$(call RccOs,$t),\
	           if test -d os/$o/driver; then \
	             echo Building the $o kernel driver for $(call RccRealPlatform,$p); \
	             (source $(OCPI_CDK_DIR)/scripts/ocpitarget.sh $p; \
		      $(MAKE) -C os/$o/driver); \
	           else \
	             echo There is no kernel driver for the OS '"'$o'"', so none built. ; \
	           fi;))) \
	     $(DoExports) \

cleandriver:
	$(AT)set -e;\
	     $(foreach p,$(RccPlatforms),\
	       $(foreach t,$(RccTarget_$p),\
	         $(foreach o,$(call RccOs,$t),\
	           if test -d os/$o/driver; then \
	             echo Cleaning the $o kernel driver for $(call RccRealPlatform,$p); \
	             (source $(OCPI_CDK_DIR)/scripts/ocpitarget.sh $p; \
		      $(MAKE) -C os/$o/driver topclean); \
	           else \
	             echo There is no kernel driver for the OS '"'$o'"', so none cleaned. ; \
	           fi;))) \

# Clean that respects platforms
clean: cleanframework cleanprojects

# Super clean, but not git clean, based on our patterns, not sub-make cleaning
cleaneverything distclean: clean cleandriver
	$(AT)rm -r -f exports
	$(AT)find . -depth -a ! -name .git -a \( \
             -name '*~' -o -name '*.dSym' -o -name timeData.raw -o -name 'target-*' -o \
             -name gen -o \
	     \( -name lib -a -type d -a ! -path "*/rcc/platforms/*" \)  \
             \) -exec rm -r {} \;
	$(AT)for p in projects/*; do make -C $p cleaneverything; done

##########################################################################################
# Goals, variables and macros that are about exporting the CDK, whether tarball, rpm, etc.

##### Perform platform filtering (for tarball and rpm)
# Set variables to exclude platforms that are not specified, supporting tar, find, and cp
# Use environment so that they are available in any scripts or tools
# Assume exclusions relative to being in the CDK dir
export OCPI_EXCLUDED_PLATFORMS:=
export OCPI_EXCLUDE_FOR_TAR:=
export OCPI_EXCLUDE_FOR_FIND:=
export OCPI_EXCLUDE_FOR_CP:=
# Build the platform exclusion lists for various tools
define filterPlatforms
$(foreach p,$(notdir $(patsubst %/,%,$(dir $(wildcard cdk/*/bin)))),\
  $(if $(filter $p,$(RccPlatforms)),,\
    $(eval OCPI_EXCLUDED_PLATFORMS+=$p)\
    $(eval OCPI_EXCLUDE_FOR_TAR+=--exclude "./$p" --exclude "./$p/*") \
    $(eval OCPI_EXCLUDE_FOR_FIND+=-a ! -path ./$p/\*) \
    $(eval OCPI_EXCLUDE_FOR_CP:=$$(OCPI_EXCLUDE_FOR_CP)|^$p$$$$)))
endef
##### Set variables that affect the naming of the release packages
# The general package naming scheme is:
# <base>[-sw-platform-<platform>]-<version>-<release>[_<tag>][_J<job>][_<branch>][<dist>]
# where:
# <base> is our core package name
# <platform> is a cross target when we are releasing packages per platform
# <version> is our normally versioning scheme v1.2.3
# <release> is a label that defaults to "snapshot" if not overridden with OcpiRelease
# These are only applied if not a specific versioned release:
# <tag> is a sequence number/timestamp within a release cycle (when not a specific release)
# <job> is a jenkins job reference
# <branch> is a git branch reference
# <dist> for RPM, e.g. el.
base=opencpi
# cross: value is the target platform or null if not cross
# arg 1 is a single platform
cross=$(strip $(foreach r,$(call RccRealPlatforms,$1),\
        $(if $(filter $(call RccRealPlatform,$(OCPI_TOOL_PLATFORM)),$r),,$r)))
name=$(base)$(and $(call cross,$1),-sw-platform-$(call cross,$1))
release=$(or $(OcpiRelease),snapshot)
# This changes every 6 minutes which is enough for updated releases (snapshots).
# It is rebased after a release so it is relative within its release cycle
# FIXME:automate this...
timestamp:=_$(shell printf %05d $(shell expr `date -u +"%s"` / 360 - 4172750))
##### Set variables based on what git can tell us
# Get the git branch and clean it up from various prefixes and suffixes tacked on
# If somebody checks in between Jenkins builds, it will sometimes get "develop^2~37" etc,
# The BitBucket prefix of something like "bugfix--" is also stripped if present.
git_branch :=$(notdir $(shell git name-rev --name-only HEAD | \
                              perl -pe 's/[~^\d]*$$//' | perl -pe 's/^.*?--//'))
git_version:=$(shell echo $(branch) | perl -ne '/^v[\.\d]+$$/ && print')
git_hash   :=$(shell h=`(git tag --points-at HEAD | grep github | head -n1) 2>/dev/null`;\
                     [ -z "$$h" ] && h=`git rev-list --max-count=1 HEAD`; echo $$h)
git_tag    :=$(if $(git_version),\
               $(if $(BUILD_NUMBER),_J$(BUILD_NUMBER))\
               $(if $(filter-out undefined develop,$(git_branch)),_$(subst -,_,$(git_branch))))
##### Set final variables that depend on git variables
# FIXME: automate this explicitly elsewhere
version:=$(or $(git_version),1.3.0)
tag:=$(and $(git_version),$(timestamp))

check_export: exports
	@echo Preparing to export for platforms: $(RccPlatforms)$(filterPlatforms)
	$(AT)cd cdk; bad=0; \
	 for l in `find . -follow -type l`; do bad=1; echo Dead exports link found: $$l; done;\
	 exit $$bad

test_export: check_export
	@echo OCPI_EXCLUDED_PLATFORMS: ==$$OCPI_EXCLUDED_PLATFORMS==
	@echo OCPI_EXCLUDE_FOR_TAR: ==$$OCPI_EXCLUDE_FOR_TAR==
	@echo OCPI_EXCLUDE_FOR_FIND: ==$$OCPI_EXCLUDE_FOR_FIND==
	@echo OCPI_EXCLUDE_FOR_CP: ==$$OCPI_EXCLUDE_FOR_CP==
	$(AT)set -vx;rm -r -f tmpexport; mkdir tmpexport && cd cdk && \
	 echo cp -R -L $$(ls -d1 *| egrep -v "/$$OCPI_EXCLUDE_FOR_CP") $(CURDIR)/tmpexport
	$(AT)set -vx; eval tar -v -z -h -c -f tmpexport/tar.tgz $$OCPI_EXCLUDE_FOR_TAR -C cdk .
	$(AT)set -vx; cd cdk; eval find -L . -type f $$OCPI_EXCLUDE_FOR_FIND

# Make a tarball of exports
.PHONY: tar
opencpi-cdk-latest.tgz tar: check_export
	$(AT)set -e; mydate=`date +%G%m%d%H%M%S`;\
	     file=opencpi-cdk-$$mydate.tgz; \
	     echo Creating tar export file: $$file; \
	     eval tar -z -h -f $$file -c $$OCPI_EXCLUDE_FOR_TAR -C cdk .; \
	     rm -f opencpi-cdk-latest.tgz; \
	     ln -s $$file opencpi-cdk-latest.tgz; \
	     ls -l $$file; \
	     ls -l opencpi-cdk-latest.tgz

# Create a relocatable RPM from what is exported for the given platforms
# Feed in the various naming components
# redefine _rpmdir and _build_name_fmt to simply output the RPMs here
.PHONY: rpm
first_real_platform:=$(word 1,$(RccPlatforms))
rpm: check_export
	$(AT)! command -v rpmbuild >/dev/null 2>&1 && \
	     echo "Error: Cannot build an RPM: rpmbuild (rpm-build package) is not available." && exit 1 || :
	$(AT)[ $(words $(call Unique,$(call RccRealPlatforms,$(RccPlatforms)))) != 1 ] && \
	     echo Error: Cannot build an RPM for more than one platform at a time. && exit 1 || :
	$(AT)echo "Creating an RPM file from the current built CDK for platform(s):" $(RccPlatforms)
	$(AT)$(eval first:=$(word 1,$(RccPlatforms))) \
	     source $(OCPI_CDK_DIR)/scripts/ocpitarget.sh $(first) &&\
	     echo $$OCPI_CROSS_BUILD_BIN_DIR/$$OCPI_CROSS_HOST &&\
	     rpmbuild $(if $(RpmVerbose),-vv,--quiet) -bb\
		      --define="RPM_BASENAME    $(base)"\
		      --define="RPM_NAME        $(call name,$(first))"\
		      --define="RPM_RELEASE     $(release)$(tag)$(commit)"\
		      --define="RPM_VERSION     $(version)" \
		      --define="RPM_HASH        $(git_hash)" \
		      $(foreach c,$(call cross,$(first)),\
		        --define="RPM_CROSS $c") \
		      --define "_rpmdir $(CURDIR)"\
		      --define "_build_name_fmt %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm"\
		      build/cdk.spec
	$(AT)rpm=`ls -1t *.rpm|head -1` && echo Created RPM file: $$rpm && ls -l $$rpm

# Convenience here in the Makefile.
# This forces the rebuild each time, although the downloads are cached.  It is not
# a "make" dependency of building the framework.
.PHONY: prerequisites
prerequisites:
	$(AT)for p in $(call RccRealPlatforms,$(RccPlatforms)); do\
                ./scripts/install-prerequisites.sh $$p;\
             done
##########################################################################################
# Goals that are about projects
# A convenience to run various goals on all the projects that are here
# Unfortunately, we need to know the order here.
Projects=core assets inactive
ProjectGoals=cleanhdl cleanrcc cleanocl rcc ocl hdl applications run runtest hdlprimitives \
             components cleancomponents test
# These are not done in parallel since we do not know the dependencies
DoProjects=set -e; $(foreach p,$(Projects),\
                     echo Performing $1 on project $p && \
                     $(MAKE) -C projects/$p $(if $(filter build,$1),,$1) &&) :
.PHONY: $(ProjectGoals)
$(ProjectGoals):
	$(AT)$(call DoProjects,$@)

projects:
	$(AT)$(call DoProjects,build)
	$(AT)$(call DoProjects,test)

cleanprojects:
	$(AT)$(call DoProjects,clean)

rcc ocl hdl: exports

##########################################################################################
# Help
define help
This top-level Makefile builds and/or tests the framework and built-in projects ($(Projects))

The valid goals that accept platforms (using RccPlatform(s) or Platforms(s)) are:
   Make goals for framework (core of Opencpi):
     framework(default) - Build the framework for platfors and export them
     cleanframework     - Clean the specific platforms
     exports            - Redo exports, including for indicated platforms
                        - This is cumulative;  previous exports are not removed
                        - This does not export projects
     driver             - Build the driver(s) for the platform(s)
     testframework      - Test the framework, requires the projects be built
                        - Runs component unit tests in core project, but not in others
                        - Clean the driver(s) for the platform(s)
     cleandriver        - Clean the driver(s) for the platform(s)
     tar                - Create the tarball for the current cdk exports
     rpm                - Create the binary/relocatable CDK RPM for the platforms
   Make goals for projects:
     projects           - Build the projects for the platforms
     cleanprojects      - Clean all projects
     exportprojects     - Export all projects
   Other goals:
     clean              - clean framework and projects, respecting Platforms and Projects
     cleaneverything    - Clean as much as we can (framework and projects) without git cleaning
                        - also distclean does this for historical/compatible reasons
                        - ignores the Platform and Projects variables
     prerequisites      - Forces a (re)build of the prerequisites for the specified platforms.
                        - Downloads will be downloaded if they are not present already.

Variables that are useful for most goals:

Platforms/Platform/RccPlatforms/RccPlatform: all specify software platforms
  -- Useful for goals:  framework(default), exports, cleanframework, projects, exportprojects,
                        driver, cleandriver, tar, rpm
  -- These platforms can have build options/letters after a hyphen: d=dynamic, o=optimized 
     <platform>:    default static, debug build
     <platform>-d:  dynamic library, debug build
     <platform>-o:  static library, optimized build
     <platform>-do: dynamic library, optimized build

Projects: specify projects (default is: $(Projects))
  -- Useful for goals:  projects, cleanprojects, exportprojects, testprojects

The projects for project-related goals use the Projects variable.
The default is all the built-in projects (including inactive) in order: $(Projects)
These various project-related goals simply perform the goal in all projects:
   rcc ocl hdl applications test run runtest hdlprimitives components
   cleanhdl cleanrcc cleanocl
Variables that only affect project building can also be used, like HdlPlatforms.
endef
$(OcpiHelp)

 
