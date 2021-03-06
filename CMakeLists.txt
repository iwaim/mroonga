# Copyright(C) 2012 Kouhei Sutou <kou@clear-code.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

cmake_minimum_required(VERSION 2.6)
project(mroonga)

file(READ ${CMAKE_SOURCE_DIR}/version        MRN_VERSION)
file(READ ${CMAKE_SOURCE_DIR}/version_major  MRN_VERSION_MAJOR)
file(READ ${CMAKE_SOURCE_DIR}/version_minor  MRN_VERSION_MINOR)
file(READ ${CMAKE_SOURCE_DIR}/version_micro  MRN_VERSION_MICRO)
file(READ ${CMAKE_SOURCE_DIR}/version_in_hex MRN_VERSION_IN_HEX)
file(READ ${CMAKE_SOURCE_DIR}/plugin_version MRN_PLUGIN_VERSION)

set(MRN_PACKAGE_STRING "${PROJECT_NAME} ${MRN_VERSION}")

include(${CMAKE_SOURCE_DIR}/build/cmake_modules/ReadFileList.cmake)

read_file_list(${CMAKE_CURRENT_SOURCE_DIR}/sources.am MROONGA_SOURCES)
read_file_list(${CMAKE_CURRENT_SOURCE_DIR}/lib/libmrn_no_mysql_sources.am
  LIBMRN_NO_MYSQL_SOURCES)
string(REGEX REPLACE "([^;]+)" "lib/\\1"
  LIBMRN_NO_MYSQL_SOURCES "${LIBMRN_NO_MYSQL_SOURCES}")
read_file_list(${CMAKE_CURRENT_SOURCE_DIR}/lib/libmrn_need_mysql_sources.am
  LIBMRN_NEED_MYSQL_SOURCES)
string(REGEX REPLACE "([^;]+)" "lib/\\1"
  LIBMRN_NEED_MYSQL_SOURCES "${LIBMRN_NEED_MYSQL_SOURCES}")

set(MYSQL_SOURCE_DIR "PATH" CACHE PATH "MySQL source directory")
set(MYSQL_INCLUDE_DIRS
  "${MYSQL_SOURCE_DIR}/sql"
  "${MYSQL_SOURCE_DIR}/include"
  "${MYSQL_SOURCE_DIR}/regex"
  "${MYSQL_SOURCE_DIR}"
  CACHE INTERNAL "MySQL include directories")

set(MYSQL_BUILD_DIR ${MYSQL_SOURCE_DIR} CACHE PATH "MySQL build directory")

set(MYSQL_CONFIG "PATH" CACHE PATH "mysql-config command path")
find_path(MYSQL_CONFIG "${MYSQL_CONFIG}")

macro(SET_MYSQL_CONFIG_VALUE OPTION VARIABLE)
  execute_process(COMMAND "${MYSQL_CONFIG}" ${OPTION}
    OUTPUT_VARIABLE MYSQL_CONFIG_OUTPUT)
  string(STRIP ${MYSQL_CONFIG_OUTPUT} ${VARIABLE})
endmacro()

set_mysql_config_value("--plugindir" MYSQL_PLUGIN_DIR)
set_mysql_config_value("--cflags" MYSQL_CFLAGS)
set_mysql_config_value("--version" MYSQL_VERSION)

include(FindPkgConfig)
pkg_check_modules(GROONGA REQUIRED "groonga >= 2.0.0")

include_directories(
  "${PROJECT_BINARY_DIR}"
  "${PROJECT_SOURCE_DIR}"
  "${PROJECT_SOURCE_DIR}/lib"
  ${MYSQL_INCLUDE_DIRS}
  ${GROONGA_INCLUDE_DIRS}
  )

link_directories(
  ${GROONGA_LIBRARY_DIRS}
  )

# TODO: set VERSIONINFO for Microsoft Visual C++.
#       http://msdn.microsoft.com/en-us/library/aa381058%28VS.85%29.aspx
add_library(ha_mroonga MODULE
  ${MROONGA_SOURCES}
  ${LIBMRN_NO_MYSQL_SOURCES}
  ${LIBMRN_NEED_MYSQL_SOURCES})
set_source_files_properties(${MROONGA_SOURCES} PROPERTIES
  COMPILE_FLAGS
  "${MYSQL_CFLAGS} -Werror -fno-implicit-templates -fno-exceptions -fno-rtti -felide-constructors")
set_target_properties(ha_mroonga PROPERTIES
  COMPILE_DEFINITIONS "MYSQL_DYNAMIC_PLUGIN"
  PREFIX ""
  OUTPUT_NAME "ha_mroonga")

set(DEFAULT_PARSER "TokenBigram" CACHE STRING "The default fulltext parser")
set_property(TARGET ha_mroonga APPEND PROPERTY
  COMPILE_DEFINITIONS "MRN_PARSER_DEFAULT=\"${DEFAULT_PARSER}\"")

target_link_libraries(ha_mroonga ${GROONGA_LIBRARIES})

option(WITH_DEBUG "Enable debug options" OFF)
if(WITH_DEBUG)
  set_property(TARGET ha_mroonga APPEND PROPERTY
    COMPILE_DEFINITIONS "SAFE_MUTEX")
endif()

option(WITH_DEBUG_FULL "Enable full debug options" OFF)
if(WITH_DEBUG_FULL)
  set_property(TARGET ha_mroonga APPEND PROPERTY
    COMPILE_DEFINITIONS "SAFE_MUTEX" "SAFEMALLOC")
endif()

option(DISABLE_FAST_MUTEXES "Force disabling fast mutex" OFF)
if(DISABLE_FAST_MUTEXES)
  set_property(TARGET ha_mroonga APPEND PROPERTY
    COMPILE_DEFINITIONS "FORCE_FAST_MUTEX_DISABLED=1")
endif()

install(TARGETS ha_mroonga DESTINATION "${MYSQL_PLUGIN_DIR}")

configure_file(
  "${PROJECT_SOURCE_DIR}/mrn_version.h.in"
  "${PROJECT_BINARY_DIR}/mrn_version.h"
  )

configure_file(
  "${PROJECT_SOURCE_DIR}/config.sh.in"
  "${PROJECT_BINARY_DIR}/config.sh"
  )

configure_file(
  "${PROJECT_SOURCE_DIR}/test/sql/suite/mroonga_storage/r/information_schema.result.in"
  "${PROJECT_SOURCE_DIR}/test/sql/suite/mroonga_storage/r/information_schema.result"
  )
