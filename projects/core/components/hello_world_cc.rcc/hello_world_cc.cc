/*
 * This file is protected by Copyright. Please refer to the COPYRIGHT file
 * distributed with this source distribution.
 *
 * This file is part of OpenCPI <http://www.opencpi.org>
 *
 * OpenCPI is free software: you can redistribute it and/or modify it under the
 * terms of the GNU Lesser General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) any
 * later version.
 *
 * OpenCPI is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * THIS FILE WAS ORIGINALLY GENERATED ON Sat Feb 14 17:53:11 2015 EST
 * BASED ON THE FILE: hello_world_cc.xml
 * YOU *ARE* EXPECTED TO EDIT IT
 *
 * This file contains the implementation skeleton for the hello_world_cc worker in C++
 */

#include "hello_world_cc-worker.hh"

using namespace OCPI::RCC; // for easy access to RCC data types and constants
using namespace Hello_world_ccWorkerTypes;

class Hello_world_ccWorker : public Hello_world_ccWorkerBase {
  RCCResult run(bool /*timedout*/) {
    printf("Hello World!\n");
    return RCC_DONE;
  }
};

HELLO_WORLD_CC_START_INFO
// Insert any static info assignments here (memSize, memSizes, portInfo)
// e.g.: info.memSize = sizeof(MyMemoryStruct);
HELLO_WORLD_CC_END_INFO
