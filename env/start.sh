# Default settings
export OCPI_TARGET_CFLAGS="-Wall -Wfloat-equal -Wextra  -fno-strict-aliasing -Wconversion -std=c99"
export OCPI_TARGET_CXXFLAGS="-Wextra -Wall -Wfloat-equal -fno-strict-aliasing -Wconversion -Wwrite-strings -Wno-sign-conversion"

export OCPI_BASE_DIR=`pwd`
export OCPI_CDK_DIR=$OCPI_BASE_DIR/exports
# For backward compatibility, we default to explicit modelessness
export OCPI_TOOL_MODE=
export OCPI_TARGET_MODE=
if test "$OCPI_TOOL_HOST" = ""; then
  vars=($(platforms/getPlatform.sh))
  if test $? != 0; then
    echo Failed to determine runtime platform.
    return 1
  fi
  export OCPI_TOOL_OS=${vars[0]}
  export OCPI_TOOL_OS_VERSION=${vars[1]}
  export OCPI_TOOL_ARCH=${vars[2]}
  export OCPI_TOOL_HOST=${vars[3]}
  export OCPI_TOOL_PLATFORM=${vars[4]}
else
  echo "Warning!!!!!!: "you are setting up the OpenCPI build environment when it is already set.
  echo "Warning!!!!!!: "this is not guaranteed to work.  You should probably use a new shell.
  echo You can also \"source env/clean-env.sh\" to start over.
fi
export OCPI_TARGET_CFLAGS="-Wall -Wfloat-equal -Wextra  -fno-strict-aliasing -Wconversion -std=c99"
export OCPI_TARGET_CXXFLAGS="-Wextra -Wall -Wfloat-equal -fno-strict-aliasing -Wconversion"
export OCPI_GTEST_DIR=/opt/opencpi/prerequisites/gtest
export OCPI_LZMA_DIR=/opt/opencpi/prerequisites/lzma
export OCPI_DEBUG=1
export OCPI_ASSERT=1
export OCPI_SHARED_LIBRARIES_FLAGS=
export OCPI_BUILD_SHARED_LIBRARIES=0

# Set this to "1" to include the OFED IBVERBS transfer driver (for linking)
export OCPI_HAVE_IBVERBS=

# ##########OpenCL - default is that we have headers to compile against
export OCPI_OPENCL_INCLUDE_DIR=$OCPI_BASE_DIR/runtime/ocl/include
export OCPI_OPENCL_OBJS=
export OCPI_HAVE_OPENCL=0

export OCPI_SMB_SIZE=100000000

# #########  OpenCV 
#export OCPI_OPENCV_HOME=/opt/opencpi/prerequisites/opencv/darwin-x86_64
# suppress execution while allowing building

