vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO secondlife/tailslide
    REF "v${VERSION}"
    SHA512 7d75510ae165792831cf955b63f8ebe3b249499cde52086f94602546c436d6cbd250a18116ec202fe1045e248b9215acf3b8bd16f2a9cadc6b21c28f7d9bb03d
    HEAD_REF main
    PATCHES
        # The library installed with a CMake package of its own.
        build.patch
)

# The scanner and parser upstream checks in are used as they are, generation
# skipped so that the build needs neither flex nor bison (Apple's bison is too
# old for the grammar, and the Windows runner has neither).
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DTAILSLIDE_BUILD_CLI=OFF
        -DTAILSLIDE_BUILD_TESTS=OFF
        -DTAILSLIDE_SKIP_GEN=ON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME unofficial-tailslide)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE" "${SOURCE_PATH}/NOTICE.txt")
