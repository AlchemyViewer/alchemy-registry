vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO secondlife/slua
    REF "v${VERSION}"
    SHA512 e5d0e78a8cf5462b754000eff8838c5f871459d358c86a3cb4be03ee2b12d9fa9c758b49dcc36aa8fd382fe8b0dc8ffd939d10c9fe6e12f177b3f45dd1603e30
    HEAD_REF main
    PATCHES
        cmake-config-export.patch
        builtins-add-to-table.patch
        lsl-debug-lines.patch
        lsl-jump-direction.patch
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
# (builtins-add-to-table.patch). It can record each instruction's LSL line,
# as Luau's own compiler does at debug level 1, where asked for: off by
# default, as the server compiles, so the bytecode is the server's unless a
# caller wants the lines -- a viewer weighing a script line by line
# (lsl-debug-lines.patch). A jump is forward or backward by where its label
# stands against it in the script, not by where the two nodes were allocated,
# which the compiler compared: the same script was JUMP one compile and
# JUMPBACK, two bytes larger and an interrupt check different, the next
# (lsl-jump-direction.patch).
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
