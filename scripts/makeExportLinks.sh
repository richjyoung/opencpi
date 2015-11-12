#!/bin/sh

# Populate the exports tree with the links that will be needed for later build stages,
# and links that are only dependent on stable, non-generated source files etc.
# we will initially populate a exports.temp directory and if all is well, we will
# rename it to exports and remove the previous one.
#
# This script is done in the context of a particular target, as its first argument.
#
# This script must be tolerant of things not existing, and it is called repeatedly as
# more things get built
# We use the term "facilities" as basic subdirectories where stuff gets built.
# This script does not care or drive how these things get built.
# It only needs the Facilities file, if present.
#
# These are the categories of links we will create.
# Libraries generated by library facilities
# Drivers generated by driver facilities
#   FIXME: put drivers in a seaprate place and distinguish them from libaries? to avoid name collisions?
# Main programs generated by library facilities

# Check the exclusion in $1 against the path in $2
# The exclusion might be shorter than the path
# No wild carding here (yet)
function match_filter {
  # echo match_filter $1 $2
  local -a edirs pdirs
  edirs=(${1//\// })
  pdirs=(${2//\// })
  for ((i=0; i<${#pdirs[*]}; i++)); do
    # echo MF:$i:${edirs[$i]}:${pdirs[$i]}:
    if [[ "${edirs[$i]}" == "" ]]; then
      return 0
    elif [[ "${edirs[$i]}" == target-* ]]; then
      if [[ "${pdirs[$i]}" != target-* ]]; then
	return 1
      fi
    elif [[ "${edirs[$i]}" != "${pdirs[$i]}" ]]; then
      return 1
    fi
  done 
  return 0   
}

function make_relative_link {
  # echo make_relative_link $1 $2
  # Figure out what the relative prefix should be
  up=$(echo $2 | sed 's-[^/]*$--' | sed 's-[^/]*/-../-g')
  link=${up}$1
  if [ -L $2 ]; then
    L=$(ls -l $2|sed 's/^.*-> *//')
    if [ "$L" = "$link" ]; then
      # echo Symbolic link already correct from $2 to $1.
      return 0
    else
      echo Symbolic link wrong from $2 to $1 wrong \(was $L\), replacing it.
      rm $2
    fi
  elif [ -e $2 ]; then
    if [ -d $2 ]; then
      echo Link $2 already exists, as a directory.
    else
      echo Link $2 already exists, as a regular file.
    fi
    echo '   ' when trying to link to $1
    exit 1
  fi
  mkdir -p $(dirname $2)
  # echo ln -s $link $2
  ln -s $link $2
}

# link to source ($1) from link($2) if neither are filtered
# $3 is the type of object
# exclusions can be filtered by source or target
function make_filtered_link {
  local e;
  local -a edirs
  for e in $exclusions; do
    declare -a both=($(echo $e | tr : ' '))
    # echo EXBOTH=${both[0]}:${both[1]}:$3:$1:$2
    [ "${both[1]}" != "" -a "${both[1]}" != $3 ] && continue
    # echo EXBOTH1=${both[0]}:${both[1]}:$3:$1:$2
    edirs=(${both[0]/\// })
    if [ ${edirs[0]} = exports ]; then
       if match_filter ${both[0]} $2; then return; fi
    else
       if match_filter ${both[0]} $1; then return; fi
    fi
  done
  # No exclusions matched.  Make the directory for the link
  make_relative_link $1 $2
}

os=$(echo $1 | sed 's/^\([^-]*\).*$/\1/')
dylib=$(if [ $os = macos ]; then echo dylib; else echo so; fi)
set -e
#rm -r -f exports
mkdir -p exports
exclusions=$(test -f Project.exports && grep '^[ 	]*-' Project.exports | sed 's/^[ 	]*-[ 	]*\([^ 	#]*\)[ 	]*\([^ 	#]*\).*$/\1:\2/') || true
additions=$(test -f Project.exports && grep '^[ 	]*+' Project.exports | sed 's/^[ 	]*+[ 	]*\([^ 	#]*\)[ 	]*\([^ 	#]*\).*$/\1:\2/') || true
facilities=$(test -f Project.exports &&  grep -v '^[ 	]*[-+#]' Project.exports) || true

for f in $facilities; do
  # Make links to main programs
  mains=$(find $f -name '*_main.c' -o -name '*_main.cxx' | sed 's-^.*/\([^/]*\)_main\..*$-\1-')
  for m in $mains; do
    exe=$f/target-$1/$m
    if [ ! -e $exe ]; then
      exe=target-$1/$m
      if [ ! -e $exe ]; then
        echo Executable $m not found in $f/target-$1/$m nor target-$1/$m
        continue
      fi    
    fi
    make_filtered_link $exe exports/bin/$1/$m main
  done

  # Make links to facility libraries
  foundlib=
  for s in .$dylib _s.$dylib .a; do
    lib=lib$2$(basename $f)$s
    libpath=$f/target-$1/$lib
    if [ ! -e $libpath ]; then
      libpath=target-$1/$lib
      if [ ! -e $libpath ]; then
        continue
      fi
    fi
    foundlib=$libpath
    make_filtered_link $libpath exports/lib/$1/$lib library
  done
  if [ "$foundlib" = "" ]; then
    echo Library lib$2$(basename $f) not found in $f/target-$1/\* nor target-$1/\*
#    exit 1
  fi
  # Make links to facility scripts
  shopt -s nullglob
  for s in $f/scripts/*; do
    script=$(basename $s)
    make_filtered_link $f/scripts/$script exports/scripts/$script scripts
  done

  # Make links to API include files
  for i in $(find $f -name '*Api.h*'); do
    make_filtered_link $i exports/include/$(basename $i) include
  done
done
# Add hdl platforms
for p in hdl/platforms/*; do
  name=$(basename $p)
  if [ -d $p -a -f $p/Makefile -a -f $p/$(basename $p).xml ]; then
    make_filtered_link $p/lib exports/lib/platforms/$name platform
  fi
done
[ -f hdl/platforms/platforms.mk ] &&
  make_filtered_link hdl/platforms/platforms.mk exports/lib/platforms/platforms.mk platform
[ -d hdl/platforms/specs ] &&
  make_filtered_link hdl/platforms/specs exports/lib/platforms/specs platform
# Add component libraries at top level and under hdl
for d in * hdl/*; do
  [ ! -d $d -o  ! -f $d/Makefile ] && continue
  grep -q '^[ 	]*include[ 	]*.*/include/lib.mk' $d/Makefile || continue
  make_filtered_link $d/lib exports/lib/$(basename $d) component
done

# Add hdl primitives: they must be there before they are built
# since they depend on each other
if [ -d hdl/primitives -a -f hdl/primitives/Makefile ]; then
  for p in hdl/primitives/*; do
    [ ! -d $p -o ! -f $p/Makefile ] && continue
    grep -q '^[ 	]*include[ 	]*.*/include/hdl/hdl-.*\.mk' $p/Makefile || continue
    name=$(basename $p)
    make_filtered_link hdl/primitives/lib/${name} exports/lib/hdl/$name primitive
    grep -q '^[ 	]*include[ 	]*.*/include/hdl/hdl-core.*\.mk' $p/Makefile || continue
    make_filtered_link hdl/primitives/lib/${name}_bb exports/lib/hdl/${name}_bb primitive
  done
fi

# Add the ad-hoc export links
for a in $additions; do
  declare -a both=($(echo $a | tr : ' '))
  src=${both[0]//<target>/$1}
  if [ -e $src ]; then
    after=
    if [[ ${both[1]} =~ /$ || ${both[1]} == "" ]]; then
      after=$(basename ${both[0]})
    fi
    make_relative_link $src exports/${both[1]//<target>/$1}$after
  else
    echo Warning: link source $src does not '(yet?)' exist.
  fi
done
