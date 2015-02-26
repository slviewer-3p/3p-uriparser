cmake_minimum_required(VERSION 2.4.4)
set(CMAKE_ALLOW_LOOSE_LOOP_CONSTRUCTS ON)

project(uriparser C)

option(ASM686 "Enable building i686 assembly implementation")
option(AMD64 "Enable building amd64 assembly implementation")

set(INSTALL_BIN_DIR "${CMAKE_INSTALL_PREFIX}/bin" CACHE PATH "Installation directory for executables")
set(INSTALL_LIB_DIR "${CMAKE_INSTALL_PREFIX}/lib" CACHE PATH "Installation directory for libraries")
set(INSTALL_INC_DIR "${CMAKE_INSTALL_PREFIX}/include/uriparser" CACHE PATH "Installation directory for headers")
set(INSTALL_MAN_DIR "${CMAKE_INSTALL_PREFIX}/share/man" CACHE PATH "Installation directory for manual pages")
set(INSTALL_PKGCONFIG_DIR "${CMAKE_INSTALL_PREFIX}/share/pkgconfig" CACHE PATH "Installation directory for pkgconfig (.pc) files")

include(CheckTypeSize)
include(CheckFunctionExists)
include(CheckIncludeFile)
include(CheckCSourceCompiles)

#enable_testing()

check_include_file(sys/types.h HAVE_SYS_TYPES_H)
check_include_file(stdint.h    HAVE_STDINT_H)
check_include_file(stddef.h    HAVE_STDDEF_H)

#
# Check to see if we have large file support
#
set(CMAKE_REQUIRED_DEFINITIONS -D_LARGEFILE64_SOURCE=1)
# We add these other definitions here because CheckTypeSize.cmake
# in CMake 2.4.x does not automatically do so and we want
# compatibility with CMake 2.4.x.
if(HAVE_SYS_TYPES_H)
    list(APPEND CMAKE_REQUIRED_DEFINITIONS -DHAVE_SYS_TYPES_H)
endif()
if(HAVE_STDINT_H)
    list(APPEND CMAKE_REQUIRED_DEFINITIONS -DHAVE_STDINT_H)
endif()
if(HAVE_STDDEF_H)
    list(APPEND CMAKE_REQUIRED_DEFINITIONS -DHAVE_STDDEF_H)
endif()
check_type_size(off64_t OFF64_T)
if(HAVE_OFF64_T)
   add_definitions(-D_LARGEFILE64_SOURCE=1)
endif()
set(CMAKE_REQUIRED_DEFINITIONS) # clear variable

#
# Check for fseeko
#
check_function_exists(fseeko HAVE_FSEEKO)
if(NOT HAVE_FSEEKO)
    add_definitions(-DNO_FSEEKO)
endif()

#
# Check for unistd.h
#
check_include_file(unistd.h Z_HAVE_UNISTD_H)

if(MSVC)
    set(CMAKE_DEBUG_POSTFIX "d")
    add_definitions(-D_CRT_SECURE_NO_DEPRECATE)
    add_definitions(-D_CRT_NONSTDC_NO_DEPRECATE)
    include_directories(${CMAKE_CURRENT_SOURCE_DIR})
endif()

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)

set(URIPARSER_PC ${CMAKE_CURRENT_BINARY_DIR}/uriparser.pc)
configure_file( ${CMAKE_CURRENT_SOURCE_DIR}/uriparser.pc.cmakein
        ${URIPARSER_PC} @ONLY)
include_directories(${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})


#============================================================================
# uriparser
#============================================================================

set(URIPARSER_PUBLIC_HDRS
    include/uriparser/Uri.h
    include/uriparser/UriBase.h
    include/uriparser/UriDefsAnsi.h
    include/uriparser/UriDefsConfig.h
    include/uriparser/UriDefsUnicode.h 
    include/uriparser/UriIp4.h  
)
set(URIPARSER_PRIVATE_HDRS
    src/UriCommon.h
    src/UriIp4Base.h
    src/UriNormalizeBase.h
    src/UriParseBase.h
)
set(URIPARSER_SRCS
    src/UriCommon.c
    src/UriCompare.c
    src/UriEscape.c
    src/UriFile.c
    src/UriIp4.c
    src/UriIp4Base.c
    src/UriNormalize.c
    src/UriNormalizeBase.c
    src/UriParse.c
    src/UriParseBase.c
    src/UriQuery.c
    src/UriRecompose.c
    src/UriResolve.c
    src/UriShorten.c
)

if(CMAKE_COMPILER_IS_GNUCC)
    if(ASM686)
        set(URIPARSER_ASMS contrib/asm686/match.S)
    elseif (AMD64)
        set(URIPARSER_ASMS contrib/amd64/amd64-match.S)
    endif ()

    if(URIPARSER_ASMS)
        add_definitions(-DASMV)
        set_source_files_properties(${URIPARSER_ASMS} PROPERTIES LANGUAGE C COMPILE_FLAGS -DNO_UNDERLINE)
    endif()
endif()

if(MSVC)
    if(ASM686)
        ENABLE_LANGUAGE(ASM_MASM)
        set(URIPARSER_ASMS
            contrib/masmx86/inffas32.asm
            contrib/masmx86/match686.asm
        )
    elseif (AMD64)
        ENABLE_LANGUAGE(ASM_MASM)
        set(URIPARSER_ASMS
            contrib/masmx64/gvmat64.asm
            contrib/masmx64/inffasx64.asm
        )
    endif()

    if(URIPARSER_ASMS)
        add_definitions(-DASMV -DASMINF)
    endif()
endif()

# get the full version number 
FILE(READ ${CMAKE_INSTALL_PREFIX}/VERSION.txt URIPARSER_FULL_VERSION)

if(MINGW)
    # This gets us DLL resource information when compiling on MinGW.
    if(NOT CMAKE_RC_COMPILER)
        set(CMAKE_RC_COMPILER windres.exe)
    endif()

    add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/uriparser1rc.obj
                       COMMAND ${CMAKE_RC_COMPILER}
                            -D GCC_WINDRES
                            -I ${CMAKE_CURRENT_SOURCE_DIR}
                            -I ${CMAKE_CURRENT_BINARY_DIR}
                            -o ${CMAKE_CURRENT_BINARY_DIR}/uriparser1rc.obj)
                            #-i ${CMAKE_CURRENT_SOURCE_DIR}/win32/uriparser1.rc)
    set(URIPARSER_DLL_SRCS ${CMAKE_CURRENT_BINARY_DIR}/uriparser1rc.obj)
endif(MINGW)

if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
  set(DARWIN 1)
  
  # Xcode 6.1 using 10.10 (Yosemite), minimum OS 10.7 (Lion)
  set(XCODE_VERSION 6.1)
  set(CMAKE_OSX_DEPLOYMENT_TARGET 10.7)
  set(CMAKE_OSX_SYSROOT /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.10.sdk/)

  set(CMAKE_XCODE_ATTRIBUTE_GCC_VERSION "com.apple.compilers.llvm.clang.1_0")
  set(CMAKE_XCODE_ATTRIBUTE_GCC_OPTIMIZATION_LEVEL 3)
  set(CMAKE_XCODE_ATTRIBUTE_GCC_STRICT_ALIASING NO)
  set(CMAKE_XCODE_ATTRIBUTE_GCC_FAST_MATH YES)
  set(CMAKE_XCODE_ATTRIBUTE_CLANG_X86_VECTOR_INSTRUCTIONS ssse3)
  set(CMAKE_XCODE_ATTRIBUTE_CLANG_CXX_LIBRARY "libstdc++")
  set(CMAKE_XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT dwarf-with-dsym)
  # Build only for i386 by default, system default on MacOSX 10.6+ is x86_64
  set(CMAKE_OSX_ARCHITECTURES i386)

endif (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")

add_library(uriparser STATIC ${URIPARSER_SRCS} ${URIPARSER_ASMS} ${URIPARSER_PUBLIC_HDRS} ${URIPARSER_PRIVATE_HDRS})

if(NOT CYGWIN)
    # This property causes shared libraries on Linux to have the full version
    # encoded into their final filename.  We disable this on Cygwin because
    # it causes cygz-${URIPARSER_FULL_VERSION}.dll to be created when cygz.dll
    # seems to be the default.
    #
    # This has no effect with MSVC, on that platform the version info for
    # the DLL comes from the resource file win32/uriparser1.rc
    set_target_properties(uriparser PROPERTIES VERSION ${URIPARSER_FULL_VERSION})
endif()

if(UNIX)
   if(NOT APPLE)
     set_target_properties(uriparser PROPERTIES LINK_FLAGS "-Wl,--version-script,\"${CMAKE_CURRENT_SOURCE_DIR}/uriparser.map\"")
   endif()
endif()

if(NOT SKIP_INSTALL_LIBRARIES AND NOT SKIP_INSTALL_ALL )
    install(TARGETS uriparser 
        RUNTIME DESTINATION "${INSTALL_BIN_DIR}"
        ARCHIVE DESTINATION "${INSTALL_LIB_DIR}"
        LIBRARY DESTINATION "${INSTALL_LIB_DIR}" )
endif()
if(NOT SKIP_INSTALL_HEADERS AND NOT SKIP_INSTALL_ALL )
    install(FILES ${URIPARSER_PUBLIC_HDRS} DESTINATION "${INSTALL_INC_DIR}")
endif()

