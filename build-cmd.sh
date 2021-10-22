#!/usr/bin/env bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e
# bleat on references to undefined shell variables
set -u

URIPARSER_SOURCE_DIR="uriparser"
VERSION_HEADER_FILE="${URIPARSER_SOURCE_DIR}/include/uriparser/UriBase.h"
VERSION_MACRO="URI_VER_ANSI"


if [ -z "$AUTOBUILD" ] ; then 
    exit 1
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

top="$(pwd)"
stage="$top"/stage

# load autobuild provided shell functions and variables
source_environment_tempfile="$stage/source_environment.sh"
"$AUTOBUILD" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

pushd "$URIPARSER_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        windows*)
            load_vsvars

            # populate version_file
            cl /DVERSION_HEADER_FILE="\"$VERSION_HEADER_FILE\"" \
               /DVERSION_MACRO="$VERSION_MACRO" \
               /Fo"$(cygpath -w "$stage/version.obj")" \
               /Fe"$(cygpath -w "$stage/version.exe")" \
               "$(cygpath -w "$top/version.c")"
            "$stage/version.exe" > "$stage/VERSION.txt"
            rm "$stage"/version.{obj,exe}

            cmake . -G "$AUTOBUILD_WIN_CMAKE_GEN" \
                  -DCMAKE_INSTALL_PREFIX:STRING="$(cygpath -w ${stage})" \
                  -DCMAKE_CXX_FLAGS="$LL_BUILD_RELEASE" \
                  -DCMAKE_C_FLAGS="$LL_BUILD_RELEASE" \
                  -DURIPARSER_BUILD_TESTS=OFF \
                  -DURIPARSER_BUILD_DOCS=OFF

            build_sln "uriparser.sln" "Release|$AUTOBUILD_WIN_VSPLATFORM" "uriparser"

            mkdir -p "$stage/lib/release"
            cp -a "Release/uriparser.lib" \
                "$stage/lib/release/uriparser.lib"
            cp -a "Release/uriparser.dll" \
                "$stage/lib/release/uriparser.dll"
            mkdir -p "$stage/include/uriparser"
            cp -a include/uriparser/*.h "$stage/include/uriparser"
        ;;

        darwin*)
            # populate version_file
            cc -DVERSION_HEADER_FILE="\"$VERSION_HEADER_FILE\"" \
               -DVERSION_MACRO="$VERSION_MACRO" \
               -o "$stage/version" "$top/version.c"
            "$stage/version" > "$stage/VERSION.txt"
            rm "$stage/version"

            cmake . -DCMAKE_INSTALL_PREFIX:STRING="${stage}" \
                  -DCMAKE_CXX_FLAGS="$LL_BUILD_RELEASE" \
                  -DCMAKE_C_FLAGS="$LL_BUILD_RELEASE" \
                  -DURIPARSER_BUILD_TESTS=OFF \
                  -DURIPARSER_BUILD_DOCS=OFF
            make
            make install

            stage_lib="${stage}"/lib
            stage_release="${stage_lib}"/release

            # Move the libs to release folder
            mv "${stage}"/lib "${stage}"/release
            mkdir "${stage_lib}"
            mv "${stage}"/release "${stage_release}"


            # Make sure libs are stamped with the -id
            # fix_dylib_id doesn't really handle symlinks
            pushd "$stage_release"
            fix_dylib_id "liburiparser.1.0.27.dylib" || \
                echo "fix_dylib_id liburiparser.dylib failed, proceeding"
            fix_dylib_id "liburiparser.1.dylib" || \
                echo "fix_dylib_id liburiparser.dylib failed, proceeding"

            CONFIG_FILE="$build_secrets_checkout/code-signing-osx/config.sh"
            if [ -f "$CONFIG_FILE" ]; then
                source $CONFIG_FILE
                for dylib in lib*.dylib;
                do
                    if [ -f "$dylib" ]; then
                        codesign --force --timestamp --sign "$APPLE_SIGNATURE" "$dylib"
                    fi
                done
            else 
                echo "No config file found; skipping codesign."
            fi
            popd
        ;;

        linux*)
            # populate version_file
            cc -DVERSION_HEADER_FILE="\"$VERSION_HEADER_FILE\"" \
               -DVERSION_MACRO="$VERSION_MACRO" \
               -o "$stage/version" "$top/version.c"
            "$stage/version" > "$stage/VERSION.txt"
            rm "$stage/version"


            opts="${TARGET_OPTS:--m$AUTOBUILD_ADDRSIZE $LL_BUILD_RELEASE}"

            # Handle any deliberate platform targeting
            if [ -z "${TARGET_CPPFLAGS:-}" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS"
            fi

            rm -rf build && mkdir build && pushd build

            cmake .. -DCMAKE_INSTALL_PREFIX:STRING="${stage}" \
                  -DCMAKE_CXX_FLAGS="$LL_BUILD_RELEASE" \
                  -DCMAKE_C_FLAGS="$LL_BUILD_RELEASE" \
                  -DURIPARSER_BUILD_TESTS=OFF \
                  -DURIPARSER_BUILD_DOCS=OFF -DBUILD_SHARED_LIBS=OFF

            make -j $AUTOBUILD_CPU_COUNT
            make install

            popd
            mkdir -p "${stage}/lib/release"
            mv ${stage}/lib/*.a "${stage}/lib/release"

			;;
    esac
    mkdir -p "$stage/LICENSES"
    pwd
    cp -a COPYING "$stage/LICENSES/uriparser.txt"
popd
