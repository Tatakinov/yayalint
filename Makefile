PROGRAM			= yayalint.exe

LUA					= lua.exe
LUA_A				= lua54.a
LUA_CFLAGS	= -DLUA_COMPAT_5_3
LUA_LDFLAGS	=
LUA_O				= ./lua/src/lua.o
LUA_CORE_O	=	./lua/src/lapi.o ./lua/src/lcode.o ./lua/src/lctype.o ./lua/src/ldebug.o ./lua/src/ldo.o ./lua/src/ldump.o ./lua/src/lfunc.o ./lua/src/lgc.o ./lua/src/llex.o ./lua/src/lmem.o ./lua/src/lobject.o ./lua/src/lopcodes.o ./lua/src/lparser.o ./lua/src/lstate.o ./lua/src/lstring.o ./lua/src/ltable.o ./lua/src/ltm.o ./lua/src/lundump.o ./lua/src/lvm.o ./lua/src/lzio.o
LUA_LIB_O				=	./lua/src/lauxlib.o ./lua/src/lbaselib.o ./lua/src/lcorolib.o ./lua/src/ldblib.o ./lua/src/liolib.o ./lua/src/lmathlib.o ./lua/src/loadlib.o ./lua/src/loslib.o ./lua/src/lstrlib.o ./lua/src/ltablib.o ./lua/src/lutf8lib.o ./lua/src/linit.o
LUA_BASE_O	= $(LUA_CORE_O) $(LUA_LIB_O)

LUA_I				= ./lua/src

SOL_I				= ./sol

LPEG_OBJS		= ./lpeglabel/lplvm.o ./lpeglabel/lplcap.o ./lpeglabel/lpltree.o ./lpeglabel/lplcode.o ./lpeglabel/lplprint.o

CC					= clang
CFLAGS			= -I . -Wall -O2
CXX					= clang++
CXXFLAGS		= -I . -std=c++17 -Wall -O2
AR					= llvm-ar
export	NM	= llvm-nm
LD					= clang++
LDFLAGS			= -shared

SRCS				= yayalint.lua user_defined.lua class/init.lua conv/init.lua conv/windows_wrap.lua string_buffer/init.lua lpeglabel/relabel.lua argparse/src/argparse.lua
OBJS				= conv/windows.a lpeglabel.a lfs.a lua54.a
ALL					= all

.SUFFIXES: .c .cc .o

.PHONY: all
all: $(PROGRAM)

$(PROGRAM): yayalint.luastatic.c
	$(CC) -I $(LUA_I) -o $(PROGRAM) yayalint.luastatic.c conv/windows.a lpeglabel.a lfs.a lua54.a -lmsvcrt -Xlinker /NODEFAULTLIB:LIBCMT
	
yayalint.luastatic.c:$(SRCS) $(OBJS) $(LUA)
	lua.exe luastatic/luastatic.lua $(SRCS) $(OBJS) || echo 1

conv/windows.a: conv/windows.o
	$(CXX) $(CXXFLAGS) -I $(LUA_I) -I $(SOL_I) -o conv/windows.o -c conv/windows.cc
	$(AR) r conv/windows.a conv/windows.o

$(LUA): $(LUA_O) $(LUA_A)
	$(CC) -o $(LUA) $(LUA_O) $(LUA_A)

lpeglabel.a: $(LPEG_OBJS)
	$(AR) r lpeglabel.a $(LPEG_OBJS)

lfs.a: lfs/src/lfs.o
	$(AR) r lfs.a lfs/src/lfs.o

$(LUA_A): $(LUA_BASE_O)
	$(AR) r lua54.a $(LUA_BASE_O)

.c.o:
	$(CC) $(CFLAGS) $(LUA_CFLAGS) -I $(LUA_I) -o $@ -c $<

.cc.o:
	$(CXX) $(CXXFLAGS) $(LUA_CFLAGS) -I $(LUA_I) -I $(SOL_I) -o $@ -c $<

clean:
	$(RM) $(PROGRAM) $(LUA) $(LUASTATIC) $(OBJS) yayalint.lib lua.exe *.a *.exp *.lib *.o conv/*.o lua/src/*.o lpeglabel/*.o lfs/src/*.o yayalint.luastatic.c

