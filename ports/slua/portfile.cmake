vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

# Pinned to a commit of main rather than a tag: the tags lag main, and the
# build layout that keeps LSLBuiltins a leaf library is only on main.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO secondlife/slua
    REF 50d97c000e12fceafc2232dee39d7a0562d5a7c3
    SHA512 0d6d2246df570628c29a4027f7523db3c419b7c437bad2b85d3df2547eae8c7f08c7e79afeb99dbb3e910b35207a1657defb33b3e6814a1fbc27341baea928d9
    HEAD_REF main
    PATCHES
        cmake-config-export.patch
        tailslide-package.patch
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
# Tailslide's tree: found as the tailslide port's package rather than the
# fork's staging folder, linked by the compiler publicly, and the builtins a
# host has loaded into Tailslide's table left as they are
# (tailslide-package.patch). It can record each instruction's LSL line, as
# Luau's own compiler does at debug level 1, where asked for: off by default,
# as the server compiles, so the bytecode is the server's unless a caller
# wants the lines -- a viewer weighing a script line by line
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
        -DLUAU_USE_TAILSLIDE=ON
        -DLUAU_INSTALL_ANALYSIS=ON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME unofficial-slua)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt" "${SOURCE_PATH}/lua_LICENSE.txt")
