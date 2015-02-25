#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

URIPARSER_SOURCE_DIR="uriparser"
VERSION_HEADER_FILE="${URIPARSER_SOURCE_DIR}/include/uriparser/UriBase.h"
VERSION_MACRO="URI_VER_ANSI"


if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# load autobuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

top="$(pwd)"
stage="$top"/stage

pushd "$URIPARSER_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        "windows")
            load_vsvars

            # populate version_file
            cl /DVERSION_HEADER_FILE="\"$VERSION_HEADER_FILE\"" \
               /DVERSION_MACRO="$VERSION_MACRO" \
               /Fo"$(cygpath -w "$stage/version.obj")" \
               /Fe"$(cygpath -w "$stage/version.exe")" \
               "$(cygpath -w "$top/version.c")"
            "$stage/version.exe" > "$stage/VERSION.txt"
            rm "$stage"/version.{obj,exe}


            cmake . -DVERSION:STRING="${URIPARSER_VERSION}"


            build_sln "contrib/vstudio/vc10/uriparser.sln" "Debug|Win32" "uriparser"
            build_sln "contrib/vstudio/vc10/uriparser.sln" "Release|Win32" "uriparser"

            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp -a "contrib/vstudio/vc10/x86/UriParserStatDebug/uriparser.lib" \
                "$stage/lib/debug/uriparserd.lib"
            cp -a "contrib/vstudio/vc10/x86/UriParserStatRelease/uriparser.lib" \
                "$stage/lib/release/uriparser.lib"
            mkdir -p "$stage/include/uriparser"
            cp -a include/uriparser/*.h "$stage/include/uriparser"
        ;;

        "darwin")
            # populate version_file
            cc -DVERSION_HEADER_FILE="\"$VERSION_HEADER_FILE\"" \
               -DVERSION_MACRO="$VERSION_MACRO" \
               -o "$stage/version" "$top/version.c"
            "$stage/version" > "$stage/VERSION.txt"
            rm "$stage/version"

            cmake . -DCMAKE_INSTALL_PREFIX:STRING=../stage
            make
            make install
        ;;

        "linux")
            # populate version_file
            cc -DVERSION_HEADER_FILE="\"$VERSION_HEADER_FILE\"" \
               -DVERSION_MACRO="$VERSION_MACRO" \
               -o "$stage/version" "$top/version.c"
            "$stage/version" > "$stage/VERSION.txt"
            rm "$stage/version"

            # Linux build environment at Linden comes pre-polluted with stuff that can
            # seriously damage 3rd-party builds.  Environmental garbage you can expect
            # includes:
            #
            #    DISTCC_POTENTIAL_HOSTS     arch           root        CXXFLAGS
            #    DISTCC_LOCATION            top            branch      CC
            #    DISTCC_HOSTS               build_name     suffix      CXX
            #    LSDISTCC_ARGS              repo           prefix      CFLAGS
            #    cxx_version                AUTOBUILD      SIGN        CPPFLAGS
            #
            # So, clear out bits that shouldn't affect our configure-directed build
            # but which do nonetheless.
            #
            # unset DISTCC_HOSTS CC CXX CFLAGS CPPFLAGS CXXFLAGS

            # Prefer gcc-4.6 if available.
            if [[ -x /usr/bin/gcc-4.6 && -x /usr/bin/g++-4.6 ]]; then
                export CC=/usr/bin/gcc-4.6
                export CXX=/usr/bin/g++-4.6
            fi

            # Default target to 32-bit
            opts="${TARGET_OPTS:--m32}"

            # Handle any deliberate platform targeting
            if [ -z "$TARGET_CPPFLAGS" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS"
            fi

            # generate configue script
            ./autogen.sh

            # Debug first
            CFLAGS="$opts -O0 -g -fPIC -DPIC" CXXFLAGS="$opts -O0 -g -fPIC -DPIC" \
                ./configure --prefix="$stage" --includedir="$stage/include" --libdir="$stage/lib/debug" --disable-test
            make
            make install

            # clean the build artifacts
            make distclean

            # Release last
            CFLAGS="$opts -O3 -fPIC -DPIC" CXXFLAGS="$opts -O3 -fPIC -DPIC" \
                ./configure --prefix="$stage" --includedir="$stage/include" --libdir="$stage/lib/release" --disable-test
            make
            make install

            # clean the build artifacts
            make distclean
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    pwd
    cp -a COPYING "$stage/LICENSES/uriparser.txt"
popd

pass











