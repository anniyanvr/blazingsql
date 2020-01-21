#!/bin/bash
# Copyright (c) 2018, NVIDIA CORPORATION.
##############################################
# BlazingDB GPU build and test script for CI #
##############################################
set -e
NUMARGS=$#
ARGS=$*

# Logger function for build status output
function logger() {
  echo -e "\n>>>> $@\n"
}

# Arg parsing function
function hasArg {
    (( ${NUMARGS} != 0 )) && (echo " ${ARGS} " | grep -q " $1 ")
}

# Set path and build parallel level
export PATH=/conda/bin:/usr/local/cuda/bin:$PATH
export PARALLEL_LEVEL=4
export CUDA_REL=${CUDA_VERSION%.*}

# Set home to the job's workspace
export HOME=$WORKSPACE

# Parse git describe
cd $WORKSPACE
export GIT_DESCRIBE_TAG=`git describe --tags`
export MINOR_VERSION=`echo $GIT_DESCRIBE_TAG | grep -o -E '([0-9]+\.[0-9]+)'`

# Set `LIBCUDF_KERNEL_CACHE_PATH` environment variable to $HOME/.jitify-cache because
# it's local to the container's virtual file system, and not shared with other CI jobs
# like `/tmp` is.
export LIBCUDF_KERNEL_CACHE_PATH="$HOME/.jitify-cache"

################################################################################
# SETUP - Check environment
################################################################################

logger "Check environment..."
env
echo "  - blazingsql-nightly" >> /conda/.condarc

logger "Check GPU usage..."
nvidia-smi

logger "Activate conda env..."
source activate gdf
conda install "bsql-toolchain=${MINOR_VERSION}.*" "librmm=${MINOR_VERSION}.*" "libcudf=${MINOR_VERSION}.*" \
              "libnvstrings=${MINOR_VERSION}.*" "dask-cudf=${MINOR_VERSION}.*" "dask-cuda=${MINOR_VERSION}.*" \
              "open-jdk=8.0" "sasl=0.2.1" "maven" "libhdfs3" "cppzmq" "gmock" "jpype1" "netifaces" "pyhive"

logger "Check versions..."
python --version
$CC --version
$CXX --version
conda list

################################################################################
# BUILD - Build from Source
################################################################################

logger "Build BlazingSQL"
$WORKSPACE/build.sh

################################################################################
# TEST - Run Tests
################################################################################

if hasArg --skip-tests; then
    logger "Skipping Tests..."
else
    logger "Check GPU usage..."
    nvidia-smi

    logger "Running IO Unit tests..."
    cd ${WORKSPACE}/io/build
    ctest

    logger "Running Comm Unit tests..."
    cd ${WORKSPACE}/comms/build
    ctest

    logger "Running Engine Unit tests..."
    cd ${WORKSPACE}/engine/build
fi

