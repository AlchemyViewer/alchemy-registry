# CMake modules only: nothing is compiled, and nothing here needs Rust. The
# project that imports a crate needs cargo and rustc when it configures.
set(VCPKG_BUILD_TYPE release)
set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO corrosion-rs/corrosion
    REF "v${VERSION}"
    SHA512 2b0d1ccafd5472f2938d084995662c586f19cb5cd4ead20fa25e9516d595eb5f756cb2d9abb12dccfa944b52a1f8002c69a1a4d955409c9d194c6d885a6d48ca
    HEAD_REF master
)

# Install only: the self-hosted include would look for Rust, and the tests
# would build crates.
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DCORROSION_BUILD_TESTS=OFF
        -DCORROSION_INSTALL_ONLY=ON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/Corrosion)

# The modules the config includes go beside it, rather than into a
# share/cmake every port would share.
file(GLOB modules "${CURRENT_PACKAGES_DIR}/share/cmake/*.cmake")
file(COPY ${modules} DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/share/cmake" "${CURRENT_PACKAGES_DIR}/lib")
vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/share/${PORT}/CorrosionConfig.cmake"
    [[list(APPEND CMAKE_MODULE_PATH "${PACKAGE_PREFIX_DIR}/share/cmake")]]
    [[list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}")]]
)

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
