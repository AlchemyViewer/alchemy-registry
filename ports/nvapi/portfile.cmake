vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO NVIDIA/nvapi
    REF 51e5aae4bc40c3ccd3fb7d4dfd94256e7bfc496e
    SHA512 001a52098d1f65dbd079582ea3b76b8715a9abcba258f0f92717b48fd1f0b38f1cb6c381e9445601259e33e6230dd0c116d7ad25b65c83e00d398fa94558930f
    HEAD_REF main
)

file(INSTALL
    DIRECTORY "${SOURCE_PATH}/"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include/nvapi"
    FILES_MATCHING
    PATTERN "*.c"
    PATTERN "*.h"
    PATTERN "amd64" EXCLUDE
    PATTERN "docs" EXCLUDE
    PATTERN "Sample_Code" EXCLUDE
    PATTERN "x86" EXCLUDE
)

if(VCPKG_TARGET_ARCHITECTURE MATCHES "arm64")
    file(INSTALL "${SOURCE_PATH}/aarch64/nvapia64.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
    if(NOT VCPKG_BUILD_TYPE)
        file(INSTALL "${SOURCE_PATH}/aarch64/nvapia64.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")
    endif()
else()
    file(INSTALL "${SOURCE_PATH}/amd64/nvapi64.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
    if(NOT VCPKG_BUILD_TYPE)
        file(INSTALL "${SOURCE_PATH}/amd64/nvapi64.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")
    endif()
endif()

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/unofficial-nvapi-config.cmake"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/unofficial-nvapi")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/License.txt")
