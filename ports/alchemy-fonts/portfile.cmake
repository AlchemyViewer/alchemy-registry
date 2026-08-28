set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO AlchemyViewer/alchemy-fonts
    REF "${VERSION}"
    SHA512 fb0451cce8da446088bc4038b4470686b7e38ca21fdf777b63e36efd15212809dd10c5db15ee5a018bd4a9efbc95f922a9a8c2f1295683bd5570c13d63837ad2
    HEAD_REF main
)

# Named rather than globbed so a new upstream family has to be adopted knowingly,
# together with its licence below.
set(FONT_FAMILIES
    0xproto
    cascadia-code
    dejavu-sans
    ibm-plex
    inter
    lexica-ultralegible
    noto-emoji
    opendyslexic
    source-code
    source-han-sans
    source-sans
    twemoji
)

# The families are flattened into one directory; the .txt/.md are the per-family
# licence texts, which ship beside the faces they cover.
foreach(family IN LISTS FONT_FAMILIES)
    file(INSTALL
        DIRECTORY "${SOURCE_PATH}/${family}/"
        DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/fonts"
        FILES_MATCHING
        PATTERN "*.ttc"
        PATTERN "*.ttf"
        PATTERN "*.otf"
        PATTERN "*.woff2"
        PATTERN "*.txt"
        PATTERN "*.md"
    )
endforeach()

vcpkg_install_copyright(
    FILE_LIST
        "${SOURCE_PATH}/0xproto/0xProto-license.txt"
        "${SOURCE_PATH}/cascadia-code/CascadiaCode-LICENSE.txt"
        "${SOURCE_PATH}/dejavu-sans/DejaVu-License.txt"
        "${SOURCE_PATH}/ibm-plex/IBMPlex-LICENSE.txt"
        "${SOURCE_PATH}/inter/Inter-LICENSE.txt"
        "${SOURCE_PATH}/lexica-ultralegible/LexicaUltralegible-license.txt"
        "${SOURCE_PATH}/noto-emoji/NotoEmoji-LICENSE.txt"
        "${SOURCE_PATH}/opendyslexic/OpenDyslexic-LICENSE.txt"
        "${SOURCE_PATH}/source-code/SourceCode.LICENSE.md"
        "${SOURCE_PATH}/source-han-sans/SourceHanSans.txt"
        "${SOURCE_PATH}/source-sans/SourceSans.LICENSE.md"
        "${SOURCE_PATH}/twemoji/Twemoji-MIT-license.txt"
        "${SOURCE_PATH}/twemoji/Twemoji-Artwork-CC-BY-license.txt"
    COMMENT "Fonts contained within this package are licensed as follows"
    )

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/unofficial-alchemy-fonts-config.cmake"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/unofficial-alchemy-fonts")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
