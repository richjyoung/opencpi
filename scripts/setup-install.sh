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

# Arguments to this source'd file are:
# $1 is the target platform (required, but can be "")
# $2 the name of the prerequisite
# $3 the download file
# $4 the download directory url
# $5 the local directory resulting from unpacking the file
# $6 set to enable cross compilation

set +o posix
platform=$1
package=$2
file=$3
url=$4
directory=$5
cross=$6
# ensure exports
source ./scripts/core-init.sh
# setup CDK and OCPI_TOOL_*
OCPI_BOOTSTRAP=`pwd`/exports/scripts/ocpibootstrap.sh; source $OCPI_BOOTSTRAP
# setup OCPI_TARGET_*
source tools/cdk/scripts/ocpitarget.sh "$platform"
platform=$OCPI_TARGET_PLATFORM
if test "$OCPI_TARGET_PLATFORM" != "$OCPI_TOOL_PLATFORM" -a "$cross" != "1"; then
 echo We do not crossbuild $package for non-development environments so skipping building it.
 exit 0
fi
source scripts/setup-prereq-dirs.sh
echo ====== Starting installation of package \"$package\" for platform \"$platform\".
echo ========= It will be downloaded/built in $OCPI_PREREQUISITES_BUILD_DIR/$package
echo ========= It will be installed in $OCPI_PREREQUISITES_INSTALL_DIR/$package/$OCPI_TARGET_DIR
set -e
# Create and enter the directory where we will download and build
cd $OCPI_PREREQUISITES_BUILD_DIR
mkdir -p $package
cd $package
# Create the directory where the package will be installed
mkdir -p $OCPI_PREREQUISITES_INSTALL_DIR/$package/$OCPI_TARGET_DIR
# If a download file is provided...
if [ -n "$url" ]; then
  if [[ "$url" == *.git ]]; then
    if [ -d $directory ]; then
      echo The git repo directory for $package, $directory, exists and is being '(re)'used.
      echo Remove `pwd`/$directory if you want to download it again.
      echo It will be updated now
      cd $directory
      git fetch
    else
      echo Downloading/cloning the distribution/repo for $package: $url
      git clone $url
      echo Download/clone complete.
      [ -d $directory ] || {
	  echo The directory $directory was not created when git repo cloned from $url.
	  exit 1
      }
      cd $directory
    fi
    git checkout $file
  else
    if [ -f "$file" ]; then
      echo The distribution file for $package, $file, exists and is being '(re)'used.
      echo Remove `pwd`/$file if you want to download it again.
    else
      echo Downloading the distribution file: $file
      curl -O -L $url/$file
      echo Download complete.  Removing any existing build directories.
      rm -r -f $directory
    fi
    if test -d $directory; then
      echo The distribution directory $directory exists, using it for this target:'  '$platform.
    else
      echo Unpacking download file $file into $directory.
      case $file in
      (*.tar.gz) tar xzf $file;;
      (*.tar.xz) tar -x --xz -f $file;;
      (*.zip) unzip $file;;
      (*) echo Unknown suffix in $file.  Cannot unpack it.; exit 1
      esac
    fi
    cd $directory
  fi
fi
if test -d ocpi-build-$OCPI_TARGET_DIR; then
   echo Removing existing build directory for $OCPI_TARGET_DIR, for rebuilding.
   rm -r -f ocpi-build-$OCPI_TARGET_DIR
fi
mkdir -p ocpi-build-$OCPI_TARGET_DIR
cd ocpi-build-$OCPI_TARGET_DIR
if test "$OCPI_TARGET_PLATFORM" != "$OCPI_TOOL_PLATFORM"; then
  if test -z "$OCPI_CROSS_BUILD_BIN_DIR" -o -z "$OCPI_CROSS_HOST"; then
      echo "Missing cross compilation variables (OCPI_CROSS_BUILD_BIN_DIR or OCPI_CROSS_HOST)."
      exit 1
  fi
  # This is for configure scripts that want to use --host
  PATH=$OCPI_CROSS_BUILD_BIN_DIR:$PATH
  # This is for raw scripts that just need to know where the tools are
  CC=$OCPI_CROSS_BUILD_BIN_DIR/$OCPI_CROSS_HOST-gcc
  CXX=$OCPI_CROSS_BUILD_BIN_DIR/$OCPI_CROSS_HOST-c++
  LD=$OCPI_CROSS_BUILD_BIN_DIR/$OCPI_CROSS_HOST-c++
  AR=$OCPI_CROSS_BUILD_BIN_DIR/$OCPI_CROSS_HOST-ar
else
  CC=gcc
  CXX=c++
  LD=c++
  AR=ar
fi
echo ====== Building package \"$package\" for platform \"$platform\" in `pwd`.

# Make a relative link from the install dir to the build dir
# args are the two args to ln (to from)
# replace the link if it exists
function relative_link {
  local from=$2
  [ -d $2 ] || from=$(dirname $2)
 # [ -d $1 ] && echo Bad relative symlink to a directory: $1 && exit 1
  local to=$(python -c "import os.path; print os.path.relpath('$(dirname $1)', '$from')")
  [ -d $2 -a -L $2/$(basename $1) ] && rm $2/$(basename $1)
  ln -s -f $to/$(basename $1) $2
}
