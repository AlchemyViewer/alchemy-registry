vcpkg_download_distfile(ARCHIVE
    URLS "https://dl.suckless.org/libgrapheme/libgrapheme-${VERSION}.tar.gz"
    FILENAME "libgrapheme-${VERSION}.tar.gz"
    SHA512 92cb1ad5f86392bd7af24bcc75b7e8fec2a4ab1726879b6c4209b49703cd7c7fb64cfab78cb304a9ddf3538e5e03a7718060de457fecfa6236feebfaff5b73d6
)

vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

# Upstream ships a POSIX Makefile only. The release tarball carries the Unicode
# data the table generators read, so this builds offline; a git checkout would
# wget it.
file(COPY
        "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt"
        "${CMAKE_CURRENT_LIST_DIR}/run-generator.cmake"
    DESTINATION "${SOURCE_PATH}"
)

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH share/libgrapheme PACKAGE_NAME libgrapheme)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
