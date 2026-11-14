vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO secondlife/slua
    REF "v${VERSION}"
    SHA512 aed353909b0f1973dcb3c06e771678bd5a42ac382c678223cfe2fb5f83be67d376ab0b11bc8db09a0ac2210f58e1f61257ee4a3495d146ef21cd380102dbf4f8
    HEAD_REF main
    PATCHES
        cmake-config-export.patch
        builtins-add-to-table.patch
        parallel-checks.patch
)

# The offline half of the fork: the parser, the type checker, the linter and
# the compiler, and what they link. The VM is built as a static library
# because Analysis and Config link it privately, but nothing that runs a
# script -- CodeGen, the executor, the inliner, the REPL -- is built. Require
# is, for its navigator: Luau's rules for a require path, walked over the
# places a tool says there are (Luau/RequireNavigator.h).
#
# The compiler has its LSL front end, which compiles LSL for Luau's VM over
# Tailslide's tree. Tailslide is the fork's own, in its tree since 0.732.16,
# built here and installed in the package beside the compiler that links it
# publicly (cmake-config-export.patch): a host that uses Tailslide itself
# links this one, not another beside it. Its scanner and parser are the ones
# checked in, generation skipped so that the build needs neither flex nor
# bison. Its builtins are added to the table a load at a time, as before
# the fork took it in, where the fork has only the first load count: the
# ones embedded in the library are loaded only into an empty table, so a
# host's own, loaded first, are not defined twice, and a host adding what
# another grid's definitions have that the table lacks has them added
# (builtins-add-to-table.patch). Modules checked in parallel share nothing a
# check writes: each has its own internal error reporter, as upstream Luau
# now gives it, and free types' indices come from atomic counters
# (parallel-checks.patch). The LSL compiler's optional debug lines and its
# jump direction, once patched here, are upstream since 0.732.17.
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DLUAU_BUILD_CLI=OFF
        -DLUAU_BUILD_TESTS=OFF
        -DLUAU_BUILD_WEB=OFF
        -DLUAU_INSTALL_ANALYSIS=ON
        -DTAILSLIDE_SKIP_GEN=ON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME unofficial-slua)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST
    "${SOURCE_PATH}/LICENSE.txt"
    "${SOURCE_PATH}/lua_LICENSE.txt"
    "${SOURCE_PATH}/Tailslide/LICENSE"
    "${SOURCE_PATH}/Tailslide/NOTICE.txt"
)
