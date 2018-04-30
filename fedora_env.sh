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

trap "trap - ERR; break" ERR; for i in 1; do
. ./env/start.sh

#fully qualified location to the Xilinx installation
#if /opt/Xilinx/14.7/ISE_DS/ is the location then
export OCPI_XILINX_DIR= #/opt/Xilinx
export OCPI_XILINX_VERSION= #14.7
export OCPI_XILINX_LICENSE_FILE= #$OCPI_XILINX_DIR/OCPI_XILINX_VERSION/License.lic
. ./env/xilinx.sh

#fully qualified location to the Altera installation
#if /opt/Altera/15.1
export OCPI_ALTERA_DIR= #/opt/Altera
export OCPI_ALTERA_VERSION= #15.1
export OCPI_ALTERA_LICENSE_FILE= #$OCPI_ALTERA_DIR/License.dat
. ./env/altera.sh

# #### Location of the Modelsim tools ####################################### #

#fully qualified location to the ModelSim installation
#if /opt/Modelsim/modelsim_dlx/bin
export OCPI_MODELSIM_DIR= #/opt/Modelsim/modelsim_dlx
export OCPI_MODELSIM_LICENSE_FILE= #$OCPI_MODELSIM_DIR/../license.txt

# Enable this if you want to, and have, installed OPENCV
# export OCPI_OPENCV_HOME=/opt/opencpi/prerequisites/opencv/linux-c6-x86_64

. ./env/finish.sh
done; trap - ERR
