vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO NVIDIA/nvapi
    REF 70d337db9186e968eab622f7e786de7e437faf3d
    SHA512 20c5e46510f9b5a8ca387d97af9f78424e4a549e78632e356808f3c203b1ac1ecd3ce7f113abf7aa2877284e7c678be739ac56be246158e22519296eeda1b655
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
