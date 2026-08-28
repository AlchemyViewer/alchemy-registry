set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO AlchemyViewer/alchemy-branding
    REF "v${VERSION}"
    SHA512 a5f8ad703659f2057a87700c1da369d8bd7024c48e82c2c15c4bd81ac25075f474978df16bcb8038f5895ea22b063ea7d0ff847c86ab8e5ec80eb155675cb13a
    HEAD_REF main
)

# installer/ is consumed by the packaging step, viewer/ by the running client.
file(INSTALL "${SOURCE_PATH}/assets/installer" "${SOURCE_PATH}/assets/viewer"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/unofficial-alchemy-branding-config.cmake"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/unofficial-alchemy-branding")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
