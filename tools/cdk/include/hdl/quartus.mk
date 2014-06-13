# #####
#
#  This file is part of OpenCPI (www.opencpi.org).
#     ____                   __________   ____
#    / __ \____  ___  ____  / ____/ __ \ /  _/ ____  _________ _
#   / / / / __ \/ _ \/ __ \/ /   / /_/ /c / /  / __ \/ ___/ __ `/
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

# This file has the HDL tool details for altera quartus

include $(OCPI_CDK_DIR)/include/hdl/altera.mk

################################################################################
# $(call HdlToolLibraryFile,target,libname)
# Function required by toolset: return the file to use as the file that gets
# built when the library is built or touched when the library is changed or rebuilt.
#
# For quartus, no precompilation is available, so it is just a directory
# full of links whose name is the name of the library
HdlToolLibraryFile=$2
################################################################################
# Function required by toolset: given a list of targets for this tool set
# Reduce it to the set of library targets.
#
# For quartus, it is generic since there is no processing
HdlToolLibraryTargets=altera
################################################################################
# Variable required by toolset: HdlBin
# What suffix to give to the binary file result of building a core
HdlBin=.qxp
HdlBin_quartus=.qxp
################################################################################
# Variable required by toolset: HdlToolRealCore
# Set if the tool can build a real "core" file when building a core
# I.e. it builds a singular binary file that can be used in upper builds.
# If not set, it implies that only a library containing the implementation is
# possible
HdlToolRealCore=yes
HdlToolRealCore_quartus=yes
################################################################################
# Variable required by toolset: HdlToolNeedBB=yes
# Set if the tool set requires a black-box library to access a core
HdlToolNeedBB=
################################################################################
# Function required by toolset: $(call HdlToolCoreRef,coreref)
# Modify a stated core reference to be appropriate for the tool set
HdlToolCoreRef=$1
HdlToolCoreRef_quartus=$1
################################################################################
# Function required by toolset: $(call HdlToolLibRef,libname)
# This is the name after library name in a path
# It might adjust (genericize?) the target
#
HdlToolLibRef=$(or $3,$(call HdlGetFamily,$2))

# This kludgery is because it seems that Quartus cannot support entities and architectures in 
# separate files, so we have to combine them - UGH UGH UGH - I hope I'm wrong...
QuartusVHDLWorker=$(and $(findstring worker,$(HdlMode)),$(findstring VHDL,$(HdlLanguage)))
ifdef QuartusVHDLWorkerx
QuartusCombine=$(OutDir)target-$(HdlTarget)/$(Worker)-combine.vhd
QuartusSources=$(filter-out $(Worker).vhd $(ImplHeaderFiles),$(HdlSources)) $(QuartusCombine)
$(QuartusCombine): $(ImplHeaderFiles) $(Worker).vhd
	cat $(ImplHeaderFiles) $(Worker).vhd > $@
else
QuartusSources=$(filter-out %.vh,$(HdlSources))
endif

# Libraries can be built for specific targets, which just is for syntax checking
# Note that a library can be designed for a specific target
QuartusFamily_stratix4:=Stratix IV
QuartusFamily_stratix5:=Stratix V
QuartusMakePart1=$(firstword $1)$(word 3,$1)$(word 2,$1)
QuartusMakePart=$(call QuartusMakePart1,$(subst -, ,$1))

# Make the file that lists the files in order when we are building a library
QuartusMakeExport= \
 $(and $(findstring library,$(HdlMode)), \
   (echo '\#' Source files in order for $(strip \
     $(if $(findstring $(HdlMode),library),library: $(LibName),core: $(Core))); \
    $(foreach s,$(QuartusSources),echo $(notdir $s);) \
   ) > $(LibName)-sources.mk;)

QuartusMakeFamily=$(QuartusFamily_$(call HdlGetFamily,$1))
QuartusMakeDevice=$(strip $(if $(findstring $(HdlMode),platform config container),\
                     $(foreach x,$(call ToUpper,$(call QuartusMakePart,$(HdlPart_$1))),$(xxinfo GOT:$x)$x),\
		     $(xxinfo GOTZ:AUTO:$(HdlMode))AUTO))

# arg 1 is hdltarget arg2 is platform
QuartusMakeDevices=\
  echo set_global_assignment -name FAMILY '\"'$(QuartusFamily_$(call HdlGetFamily,$1))'\"'; \
  echo set_global_assignment -name DEVICE \
      $(strip $(if $(findstring $(HdlMode),platform config container),\
                  $(foreach x,$(call ToUpper,$(call QuartusMakePart,$(HdlPart_$2))),$(xxinfo GOT:$x)$x),\
		  $(zxinfo GOTZ:AUTO:$(HdlMode))AUTO));

# Make the settings file
# Note that the local source files use notdir names and search paths while the
# remote libraries use pathnames so that you can have files with the same names.
QuartusMakeQsf=\
 if test -f $(Core).qsf; then cp $(Core).qsf $(Core).qsf.bak; fi; \
 $(and $(findstring $(HdlMode),library),\
   $(X Fake top module so we can compile libraries anyway for syntax errors) \
   echo 'module onewire(input  W_IN, output W_OUT); assign W_OUT = W_IN; endmodule' > onewire.v;) \
 $(X From here we generate qsf file contents, e.g. "settings") \
 (\
  echo '\#' Common assignments whether a library or a core; \
  $(call QuartusMakeDevices,$(HdlTarget),$(HdlPlatform)) \
  echo set_global_assignment -name TOP_LEVEL_ENTITY $(or $(Top),$(Core)); \
  \
  $(and $(SubCores),echo '\#' Import QXP file for each core;) \
  $(foreach c,$(SubCores),\
    echo set_global_assignment -name QXP_FILE \
      '\"'$(call FindRelative,$(TargetDir),$(call HdlCoreRef,$c,$(HdlTarget)))'\"';\
    $(foreach w,$(call HdlRmRv,$(basename $(notdir $c))),\
      $(foreach d,$(dir $c),\
        $(foreach f,$(or $(call HdlExists,$d../gen/$w-defs.vhd),\
                         $(call HdlExists,$d../$w.vhd)),\
          echo set_global_assignment -name VHDL_FILE -library $w '\"'$(call FindRelative,$(TargetDir),$f)'\"';))))\
  echo '\# Search path(s) for local files'; \
  $(foreach d,$(call Unique,$(patsubst %/,%,$(dir $(QuartusSources)) $(VerilogIncludeDirs))), \
    echo set_global_assignment -name SEARCH_PATH '\"'$(strip \
     $(call FindRelative,$(TargetDir),$d))'\"';) \
  \
  $(and $(HdlLibrariesInternal),echo '\#' Assignments for adding libraries to search path;) \
  $(foreach l,$(HdlLibrariesInternal),\
    $(foreach hlr,$(call HdlLibraryRefDir,$l,$(HdlTarget)),\
      $(if $(realpath $(hlr)),,$(error No altera library for $l at $(abspath $(hlr))))\
      echo set_global_assignment -name SEARCH_PATH '\"'$(call FindRelative,$(TargetDir),$(hlr))'\"'; \
      $(foreach f,$(wildcard $(hlr)/*_pkg.vhd),\
        echo set_global_assignment -name VHDL_FILE -library $(notdir $l) '\"'$f'\"';\
        $(foreach b,$(subst _pkg.vhd,_body.vhd,$f),\
          $(and $(wildcard $b),\
	     echo set_global_assignment -name VHDL_FILE -library $(notdir $l) '\"'$b'\"';))))) \
  \
  echo '\#' Assignment for local source files using search paths above; \
  $(foreach s,$(QuartusSources), \
    echo set_global_assignment -name $(if $(filter %.vhd,$s),VHDL_FILE -library $(LibName),$(if $(filter %.sv,$s),SYSTEMVERILOG_FILE,VERILOG_FILE)) \
        '\"'$(notdir $s)'\"';) \
  \
  $(if $(findstring $(HdlMode),core worker platform assembly container),\
    echo '\#' Assignments for building cores; \
    echo set_global_assignment -name AUTO_EXPORT_INCREMENTAL_COMPILATION on; \
    echo set_global_assignment -name INCREMENTAL_COMPILATION_EXPORT_FILE $(Core)$(HdlBin); \
    echo set_global_assignment -name INCREMENTAL_COMPILATION_EXPORT_NETLIST_TYPE POST_SYNTH;) \
  $(if $(findstring $(HdlMode),library),\
    echo '\#' Assignments for building libraries; \
    echo set_global_assignment -name SYNTHESIS_EFFORT fast;) \
  $(if $(findstring $(HdlMode),container),\
    echo '\#' Include the platform-related assignments. ;\
    echo source $(HdlPlatformsDir)/$(HdlPlatform)/$(HdlPlatform).qsf;) \
 ) > $(Core).qsf;

# Be safe for now - remove all previous stuff
HdlToolCompile=\
  echo '  'Creating $@ with top == $(Top)\; details in $(TargetDir)/quartus-$(Core).out.;\
  rm -r -f db incremental_db $(Core).qxp $(Core).*.rpt $(Core).*.summary $(Core).qpf $(Core).qsf $(notdir $@); \
  $(QuartusMakeExport) $(QuartusMakeQsf) cat -n $(Core).qsf;\
  set -e; $(call OcpiDbgVar,HdlMode,xc) \
  $(if $(findstring $(HdlMode),core worker platform assembly config container),\
    $(call DoAltera,quartus_map,--write_settings_files=off $(Core),$(Core),map); \
    $(call DoAltera,quartus_cdb,--merge --write_settings_files=off $(Core),$(Core),merge); \
    $(call DoAltera,quartus_cdb,--incremental_compilation_export --write_settings_files=off $(Core),$(Core),export)) \
  $(if $(findstring $(HdlMode),library),\
    $(call DoAltera,quartus_map,--analysis_and_elaboration --write_settings_files=off $(Core),$(Core),map)); \

# When making a library, quartus still wants a "top" since we can't precompile 
# separately from synthesis (e.g. it can't do what vlogcomp can with isim)
# Need to be conditional on libraries
ifeq ($(HdlMode),library)
ifndef Core
Core=onewire
Top=onewire
endif
endif

HdlToolFiles=\
  $(foreach f,$(QuartusSources),\
     $(call FindRelative,$(TargetDir),$(dir $f))/$(notdir $f))

# To create the "library result", we create a directory full of source files
# that have the quartus library directive inserted as the first line to
# force them into the correct library when they are "discovered" via SEARCH_PATH.
ifeq ($(HdlMode),library)
HdlToolPost=\
  if test $$HdlExit = 0; then \
    if ! test -d $(LibName); then \
      mkdir $(LibName); \
    else \
      rm -f $(LibName)/*; \
    fi;\
    for s in $(HdlToolFiles); do \
      if [[ $$s == *.vhd ]]; then \
        echo -- synthesis library $(LibName) | cat - $$s > $(LibName)/`basename $$s`; \
      else \
        ln -s ../$$s $(LibName); \
      fi; \
    done; \
  fi;
endif

BitFile_quartus=$1.sof

QuartusMakeBits=\
	cp $1-top.qsf $1-top.qsf.pre-fit && \
	$(call DoAltera,quartus_map,$1-top,$1-top,map) && \
	$(call DoAltera,quartus_fit,$1-top,$1-top,fit) && \
	cp $1-top.qsf $1-top.qsf.post-fit && \
	$(call DoAltera,quartus_asm,$1-top,$1-top,asm) && \
	cp $1-top.sof $2.sof

# Invoke the tool-specific build with: <target-dir>,<assy-name>,<core-file-name>,<config>,<platform>
define HdlToolDoPlatform_quartus
$1/$3.sof: 
	$(AT)echo Building Quartus Bit file: $$@.  Assembly $2 on platform $5.
	$(AT)cd $1 && \
	rm -r -f db incremental_db *-top.* && \
	(echo \# Common assignments whether a library or a core; \
	 echo set_global_assignment -name FAMILY '"'$$(call QuartusMakeFamily,$(HdlPart_$5))'"'; \
	 echo set_global_assignment -name DEVICE $$(call QuartusMakeDevice,$5); \
	 echo set_global_assignment -name TOP_LEVEL_ENTITY $4; \
	 echo set_global_assignment -name QXP_FILE '"'$4.qxp'"'; \
	 echo set_global_assignment -name SDC_FILE '"'$(HdlPlatformsDir)/$5/$5.sdc'"'; \
	 echo source $(HdlPlatformsDir)/$5/$5.qsf \
	 ) > $4-top.qsf && \
	cp $4-top.qsf $4-top.qsf.pre-fit && \
	$(call DoAltera1,quartus_map,$4-top,$4-top,map) && \
	$(call DoAltera1,quartus_fit,$4-top,$4-top,fit) && \
	cp $4-top.qsf $4-top.qsf.post-fit && \
	$(call DoAltera1,quartus_asm,$4-top,$4-top,asm) && \
	cp $4-top.sof $3.sof

endef

ifneq (,)
-----junk from here-----
#	QuartusStatus=$$$$? ; echo QuartusStatus after fit is $$$$QuartusStatus; \
# From when we had a dangling container?
#	$(call DoAltera,quartus_cdb,--merge=on --override_partition_netlist_type=container=import --write_settings_files=off $4-top,$4) && \

xxx=$(and $(ComponentLibraries),echo '\#' Search paths for component libraries;) \
    $(foreach l,$(ComponentLibraries),\
      echo set_global_assignment -name SEARCH_PATH '\"'$(strip \
      $(foreach found,\
        $(foreach t,$(sort $(HdlTarget) $(call HdlGetFamily,$(HdlTarget))),\
	  $(realpath $l/lib/hdl/$t)), \
        $(if $(found),\
          $(call FindRelative,$(TargetDir),$(found))'\"';,\
	  $(error No component library at $(abspath $t)))))) \
    $(eval HdlWorkers:=$$(strip $$(foreach i,$$(shell grep -v '\\\#' $$(ImplWorkersFile)),\
                         $$(if $$(filter $$(firstword $$(subst :, ,$$i)),$$(HdlPlatformWorkers)),,$$i))))
  # $(and $(findstring $(HdlMode),platform),\
  #   echo '\#' Make sure the container is defined as an empty partition. ;\
  #   echo set_instance_assignment -name PARTITION_HIERARCHY container -to '\"mkFTop_alst4:ftop|mkCTop4B:ctop|mkOCApp4B:app\"' \
  #     -section_id '\"'container'\"'; \
  #   echo set_global_assignment -name PARTITION_NETLIST_TYPE -section_id '\"'container'\"' EMPTY; \
  #   echo set_instance_assignment -name PARTITION_HIERARCHY root_partition -to '|' \
  #     -section_id Top; \
  #   echo set_global_assignment -name PARTITION_NETLIST_TYPE -section_id '\"'Top'\"' POST_SYNTH; ) \
  #
################################################################################
# Final bitstream building support, given that the "container" core is built
QuartusMakeTopQsf=\

# echo set_global_assignment -name QXP_FILE '"'$(ContainerModule)$(HdlBin)'"'; \
#  echo set_instance_assignment -name PARTITION_HIERARCHY db/container -to '"'fpgaTop|mkFTop_alst4:ftop|mkCTop4B:ctop|mkOCApp4B:app'"' \
        -section_id container; \
#  echo set_instance_assignment -name PARTITION_ALWAYS_USE_QXP_NETLIST -to '"'fpgaTop|mkFTop_alst4:ftop|mkCTop4B:ctop|mkOCApp4B:app'"' -section_id container On\
#  echo set_global_assignment -name PARTITION_IMPORT_FILE '"'$(ContainerModule)$(HdlBin)'"' \
        -section_id container; \
#  echo set_instance_assignment -name PARTITION_HIERARCHY db/container -to '"'mkFTop_alst4:ftop|mkCTop4B:ctop|mkOCApp4B:app'"' \
        -section_id container; \
#  echo set_global_assignment -name PARTITION_IMPORT_FILE '"'$(HdlPlatformsDir)/$1/target-$(call HdlGetPart,$1)/$1$(HdlBin)'"' \
        -section_id Top; \
#  echo set_instance_assignment -name PARTITION_HIERARCHY db/top -to '|' -section_id Top; \
# echo 'module onewire(input  W_IN, output W_OUT); assign W_OUT = W_IN; endmodule' > onewire.v; \
#  echo set_global_assignment -name VERILOG_FILE onewire.v; \
#  echo set_global_assignment -name PARTITION_IMPORT_FILE '"'$(ContainerModule)$(HdlBin)'"' -section_id "app"; \
  echo set_global_assignment -name PARTITION_HIERARCHY dp/app -to '"mkFTop_alst4:ftop|mkCTop4B:ctop|mkOCApp4B:app"' -section_id "app"; \
  echo set_global_assignment -name PARTITION_IMPORT_FILE '"'$(HdlPlatformsDir)/$1/target-$(call HdlGetPart,$1)/$1$(HdlBin)'"' -section_id "plat"; \
  echo set_global_assignment -name PARTITION_HIERARCHY db/plat -to '"fpgaTop"' -section_id "plat" ; \
QuartusCmd=\
	set -e; \
	rm -r -f db incremental_db ; \
	$(call QuartusMakeTopQsf,$1) ; \
	cp $(call AppName,$1).qsf $(call AppName,$1).qsf.pre-fit ; \
	$(call DoAltera,quartus_map $(call AppName,$1)); \
	$(call DoAltera,quartus_cdb --merge=on --override_partition_netlist_type=container=import --write_settings_files=off $(call AppName,$1)); \
	$(call DoAltera,quartus_fit $(call AppName,$1)); \
	QuartusStatus=$$$$? ; echo QuartusStatus after fit is $$$$QuartusStatus; \
	cp $(call AppName,$1).qsf $(call AppName,$1).qsf.post-fit; \
	$(call DoAltera,quartus_asm $(call AppName,$1))

endif
