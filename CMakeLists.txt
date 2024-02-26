# CMakeLists.txt

cmake_minimum_required(VERSION 3.0)
project(snapzap C)

set(CMAKE_C_STANDARD 11)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wextra -Werror")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D_FILE_OFFSET_BITS=64")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D_LARGEFILE_SOURCE")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D_LARGEFILE64_SOURCE")

# Uncomment the line below to enable debug
# set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DDEBUG")

# Find required libraries
find_library(LIBZFS NAMES zfs)
find_library(LIBNVPAIR NAMES nvpair)
find_library(LIBUUTIL NAMES uutil)

# Include directories
include_directories(/usr/include/libzfs /usr/include/libspl)

# Source files
set(SOURCE_FILES
    src/snapzap.c
)

# Executable
add_executable(snapzap ${SOURCE_FILES})

# Link required libraries
target_link_libraries(snapzap ${LIBZFS} ${LIBNVPAIR} ${LIBUUTIL})

# Specify installation targets
install(TARGETS snapzap DESTINATION bin)
