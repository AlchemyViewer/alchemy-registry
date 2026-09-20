vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO secondlife/tailslide
    REF "v${VERSION}"
    SHA512 7d35101463afd25d5eb4057a0d476fdcb9689c43f0181e9b3aa5ff4a72e1a3f6c1adea8de30a190afd202bb8559597bd435e6580f9f9f1214839b9c0b151a278
    HEAD_REF main
    PATCHES
        build.patch
)

# The scanner and the parser are generated ahead of time, under generated/,
# so that the build needs neither flex nor bison: Apple's bison is too old for
# the grammar, and the Windows runner has neither. They were made from
# libtailslide/lslmini.l and lslmini.y at this version with GNU flex 2.6.4 (Homebrew; Apple's flex of the same name emits the older yy_size_t length) and
# bison 3.8.2, without #line directives so that they carry no path:
#
#     bison -l -o lslmini.tab.cc --defines=lslmini.tab.hh lslmini.y
#     flex -L -o lslmini.flex.cc lslmini.l
#
# Regenerate them whenever the version changes.
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DTAILSLIDE_BUILD_CLI=OFF
        -DTAILSLIDE_BUILD_TESTS=OFF
        "-DTAILSLIDE_PREGENERATED_DIR=${CMAKE_CURRENT_LIST_DIR}/generated"
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME unofficial-tailslide)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE" "${SOURCE_PATH}/NOTICE.txt")
