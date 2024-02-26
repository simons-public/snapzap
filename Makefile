#
#
#

CC := gcc

CFLAGS := -Wall -Wextra -Werror \
          -D_FILE_OFFSET_BITS=64 \
		  -D_LARGEFILE_SOURCE \
		  -D_LARGEFILE64_SOURCE \
		  # -DDEBUG
LDFLAGS := -lzfs -lnvpair -luutil
INCLUDES := -I/usr/include -I/usr/include/libzfs -I/usr/include/libspl

ifeq ($(CC),clang)
    CFLAGS += -std=c11
else ifeq ($(CC),gcc)
    CFLAGS += -std=gnu11
else
    $(error Unsupported compiler: $(CC))
endif

.PHONY: all clean check tidy install \
	check_git_tools check_cmake_tools \
	check_clang_tools check_cppcheck_tools 

all: build/snapzap check_cmake_tools

build/snapzap: src/snapzap.c
	mkdir -p build && cd build && cmake --fresh .. && $(MAKE)
	@touch $@

snapzap: src/snapzap.c
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $^ $(LDFLAGS)

clean: check_git_tools
	git clean -d -f -x -e tests/testpool

check: check_cppcheck_tools
	cppcheck $(INCLUDES) --enable=all --force ./src

tidy: check_clang_tools
	clang-format -i src/snapzap.c
	clang-tidy src/snapzap.c -- $(CFLAGS) $(INCLUDES)

install: check_cmake_tools build/snapzap
	cd build && make install

check_git_tools:
	@which git >/dev/null || (echo "Error: git not found in PATH"; exit 1)

check_cmake_tools:
	@which cmake >/dev/null || (echo "Error: cmake not found in PATH"; exit 1)

check_clang_tools:
	@which clang-format >/dev/null || (echo "Error: clang-format not found in PATH"; exit 1)
	@which clang-tidy >/dev/null || (echo "Error: clang-tidy not found in PATH"; exit 1)

check_cppcheck_tools:
	@which cppcheck >/dev/null || (echo "Error: cppcheck not found in PATH"; exit 1)
	
