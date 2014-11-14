#
#  This file is part of OpenCPI (www.opencpi.org).
#     ____                   __________   ____
#    / __ \____  ___  ____  / ____/ __ \ /  _/ ____  _________ _
#   / / / / __ \/ _ \/ __ \/ /   / /_/ / / /  / __ \/ ___/ __ `/
#  / /_/ / /_/ /  __/ / / / /___/ ____/_/ / _/ /_/ / /  / /_/ /
#  \____/ .___/\___/_/ /_/\____/_/    /___/(_)____/_/   \__, /
#      /_/                                             /____/
#
#  OpenCPI is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Lesser General Public License as published
#  by the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  OpenCPI is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public License
#  along with OpenCPI.  If not, see <http://www.gnu.org/licenses/>.
#
########################################################################### #
# This makefile is for building a set of assemblies, each in there own subdirectory

include $(OCPI_CDK_DIR)/include/hdl/hdl-make.mk

# We make this sort of like building a component library because
# for each application we are indeed making a "worker", and then we go
# on to make bitstreams for platforms.
LibDir=$(OutDir)lib
GenDir=$(OutDir)gen
ifndef OutDir
ifdef OCPI_OUTPUT_DIR 
PassOutDir=OutDir=$(call AdjustRelative,$(OutDir:%/=%))/$@
endif
endif
ComponentLibrariesInternal:=$(call HdlAdjustLibraries,$(ComponentLibraries))
all: $(Assemblies)

.PHONY: $(Assemblies) $(Platforms) $(Targets) clean

# We use the "internal" versions of variables to allow subsidiary makefiles to
# simply set those variables again
$(Assemblies):
	$(AT)echo =============Building assembly $@
	$(AT)$(MAKE) -L -C $@ \
               $(HdlPassTargets) $(if $(HdlPlatforms)$(HdlPlatform),,HdlPlatforms=ml605) \
	       LibDir=$(call AdjustRelative,$(LibDir)) \
	       GenDir=$(call AdjustRelative,$(GenDir)) \
	       ComponentLibrariesInternal="$(ComponentLibrariesInternal)" \
	       HdlLibraries="$(call HdlAdjustLibraries,$(HdlLibraries))" \
               XmlIncludeDirsInternal="$(call AdjustRelative,$(XmlIncludeDirs))" \
	       $(PassOutDir)

clean:
	$(AT)set -e;for a in $(Assemblies); do \
		echo Cleaning $$a ; \
		$(MAKE) -C $$a clean; \
		done
	$(AT)rm -r -f $(LibDir) $(GenDir)

