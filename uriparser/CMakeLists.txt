cmake_minimum_required(VERSION 2.4.4)
set(CMAKE_ALLOW_LOOSE_LOOP_CONSTRUCTS ON)

project(uriparser C)

set(VERSION "0.8.0.1")

option(ASM686 "Enable building i686 assembly implementation")
option(AMD64 "Enable building amd64 assembly implementation")

set(INSTALL_BIN_DIR "${CMAKE_INSTALL_PREFIX}/bin" CACHE PATH "Installation directory for executables")
set(INSTALL_LIB_DIR "${CMAKE_INSTALL_PREFIX}/lib" CACHE PATH "Installation directory for libraries")
set(INSTALL_INC_DIR "${CMAKE_INSTALL_PREFIX}/include" CACHE PATH "Installation directory for headers")
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

if(NOT MINGW)
    set(URIPARSER_DLL_SRCS
#        win32/uriparser1.rc # If present will override custom build rule below.
    )
endif()

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

# parse the full version number from UriBase.h and include in URIPARSER_FULL_VERSION
#file(READ ${CMAKE_CURRENT_SOURCE_DIR}/uriparser/UriBase.h _uriparser_h_contents)
#string(REGEX REPLACE ".*#define[ \t]+URIPARSER_VERSION[ \t]+\"([-0-9A-Za-z.]+)\".*"
    #"\\1" URIPARSER_FULL_VERSION ${_uriparser_h_contents})
    
set(URIPARSER_FULL_VERSION "0.8.0.1")

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

#add_library(uriparser SHARED ${URIPARSER_SRCS} ${URIPARSER_ASMS} ${URIPARSER_DLL_SRCS} ${URIPARSER_PUBLIC_HDRS} ${URIPARSER_PRIVATE_HDRS})
add_library(uriparser SHARED ${URIPARSER_SRCS} ${URIPARSER_ASMS} ${URIPARSER_DLL_SRCS} ${URIPARSER_PUBLIC_HDRS} ${URIPARSER_PRIVATE_HDRS})
add_library(uriparserstatic STATIC ${URIPARSER_SRCS} ${URIPARSER_ASMS} ${URIPARSER_PUBLIC_HDRS} ${URIPARSER_PRIVATE_HDRS})
set_target_properties(uriparser PROPERTIES DEFINE_SYMBOL URIPARSER_DLL)
set_target_properties(uriparser PROPERTIES SOVERSION 1)

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
    # On unix-like platforms the library is almost always called libz
   set_target_properties(uriparser uriparserstatic PROPERTIES OUTPUT_NAME z)
   if(NOT APPLE)
     set_target_properties(uriparser PROPERTIES LINK_FLAGS "-Wl,--version-script,\"${CMAKE_CURRENT_SOURCE_DIR}/uriparser.map\"")
   endif()
elseif(BUILD_SHARED_LIBS AND WIN32)
    # Creates uriparser1.dll when building shared library version
    set_target_properties(uriparser PROPERTIES SUFFIX "1.dll")
endif()

if(NOT SKIP_INSTALL_LIBRARIES AND NOT SKIP_INSTALL_ALL )
    install(TARGETS uriparser uriparserstatic
        RUNTIME DESTINATION "${INSTALL_BIN_DIR}"
        ARCHIVE DESTINATION "${INSTALL_LIB_DIR}"
        LIBRARY DESTINATION "${INSTALL_LIB_DIR}" )
endif()
if(NOT SKIP_INSTALL_HEADERS AND NOT SKIP_INSTALL_ALL )
    install(FILES ${URIPARSER_PUBLIC_HDRS} DESTINATION "${INSTALL_INC_DIR}")
endif()
if(NOT SKIP_INSTALL_FILES AND NOT SKIP_INSTALL_ALL )
    install(FILES uriparser.3 DESTINATION "${INSTALL_MAN_DIR}/man3")
endif()
if(NOT SKIP_INSTALL_FILES AND NOT SKIP_INSTALL_ALL )
    install(FILES ${URIPARSER_PC} DESTINATION "${INSTALL_PKGCONFIG_DIR}")
endif()

#============================================================================
# Example binaries
#============================================================================

#add_executable(example test/example.c)
#target_link_libraries(example uriparser)
#add_test(example example)

#add_executable(minigzip test/minigzip.c)
#target_link_libraries(minigzip uriparser)

#if(HAVE_OFF64_T)
    #add_executable(example64 test/example.c)
    #target_link_libraries(example64 uriparser)
    #set_target_properties(example64 PROPERTIES COMPILE_FLAGS "-D_FILE_OFFSET_BITS=64")
    #add_test(example64 example64)

    #add_executable(minigzip64 test/minigzip.c)
    #target_link_libraries(minigzip64 uriparser)
    #set_target_properties(minigzip64 PROPERTIES COMPILE_FLAGS "-D_FILE_OFFSET_BITS=64")
#endif()
