set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)
set(VCPKG_FIXUP_MACHO_RPATH OFF)

# The prebuilt xcframework from the upstream release. The archive carries no
# licence text, so that comes from the repository at the same tag.
vcpkg_download_distfile(
    SENTRY_ARCHIVE
    URLS "https://github.com/getsentry/sentry-cocoa/releases/download/${VERSION}/SentryObjC-Dynamic.xcframework.zip"
    FILENAME "sentry-cocoa.${VERSION}.SentryObjC-Dynamic.xcframework.zip"
    SHA512 bba107efc0b18b0c6fa5ef6b3a7de9d848c1b46ed892d73c265bb97d530e41b932435f03b7f621c75fa139f1379be7eeaad74b9bf7b2fa98d3bffdd1a8f38cb1
)

vcpkg_download_distfile(
    SENTRY_LICENSE
    URLS "https://raw.githubusercontent.com/getsentry/sentry-cocoa/${VERSION}/LICENSE.md"
    FILENAME "sentry-cocoa.${VERSION}.LICENSE.md"
    SHA512 1d717ad4fa2eef387a57b7044fd5753f4bd5020bdf15e3d7920ccc6c522dcda337b47a527aa43dd6325ce4f1866dd1828e23bfe2abfd4f61905c37a4e1c52a0f
)

vcpkg_extract_source_archive(
    SENTRY_DIR
    ARCHIVE "${SENTRY_ARCHIVE}"
    NO_REMOVE_ONE_LEVEL
)

set(SENTRY_SLICE "${SENTRY_DIR}/SentryObjC-Dynamic.xcframework/macos-arm64_x86_64")

file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/lib")

# cp -a rather than file(COPY): a macOS framework is a versioned bundle whose
# top-level entries are symlinks into Versions/Current, and CMake would follow
# them and flatten the bundle.
vcpkg_execute_required_process(
    COMMAND cp -a "${SENTRY_SLICE}/SentryObjC.framework" "${CURRENT_PACKAGES_DIR}/lib/SentryObjC.framework"
    WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
    LOGNAME "copy-framework-${TARGET_TRIPLET}"
)

vcpkg_execute_required_process(
    COMMAND cp -a "${SENTRY_SLICE}/dSYMs/SentryObjC.framework.dSYM" "${CURRENT_PACKAGES_DIR}/lib/SentryObjC.framework.dSYM"
    WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
    LOGNAME "copy-dsym-${TARGET_TRIPLET}"
)

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/unofficial-sentry-cocoa-config.cmake"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/unofficial-sentry-cocoa")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

vcpkg_install_copyright(FILE_LIST "${SENTRY_LICENSE}")
