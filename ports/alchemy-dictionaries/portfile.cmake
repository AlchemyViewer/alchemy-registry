set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO AlchemyViewer/3p-dictionaries
    REF "v${VERSION}"
    SHA512 6ad31ce111cd672258cfe0b47b6513785daf4c7c2d7cd975125aec0ae2825b51fe3454c1c539d63ab47cc619d7e982c68eaf311004224852909db8e86061dae9
    HEAD_REF main
)

# dictionaries.xml is the index the spell checker reads; sl.dic is the
# Second Life word list that supplements whichever language is selected.
file(INSTALL
    "${SOURCE_PATH}/src/dictionaries.xml"
    "${SOURCE_PATH}/src/sl.dic"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/dictionaries"
)

# Named rather than globbed so a new upstream language has to be adopted
# knowingly, together with its licence below.
set(DICTIONARY_LANGUAGES de en es fr pt_br ru uk)

# Hunspell wants the .aff and .dic of every language in one flat directory.
foreach(language IN LISTS DICTIONARY_LANGUAGES)
    file(INSTALL
        DIRECTORY "${SOURCE_PATH}/src/${language}/"
        DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/dictionaries"
        FILES_MATCHING
        PATTERN "*.aff"
        PATTERN "*.dic"
    )
endforeach()

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/unofficial-alchemy-dictionaries-config.cmake"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/unofficial-alchemy-dictionaries")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

vcpkg_install_copyright(
    FILE_LIST
        "${SOURCE_PATH}/src/de/de_de-dictionary-license.txt"
        "${SOURCE_PATH}/src/en/en_au-dictionary-license.txt"
        "${SOURCE_PATH}/src/en/en_ca-dictionary-license.txt"
        "${SOURCE_PATH}/src/en/en_gb-dictionary-license.txt"
        "${SOURCE_PATH}/src/en/en_us-dictionary-license.txt"
        "${SOURCE_PATH}/src/en/en_za-dictionary-license.txt"
        "${SOURCE_PATH}/src/es/es-dictionary-license.txt"
        "${SOURCE_PATH}/src/fr/fr-dictionary-license.txt"
        "${SOURCE_PATH}/src/pt_br/pt_br-dictionary-license.txt"
        "${SOURCE_PATH}/src/ru/ru_ru-dictionary-license.txt"
        "${SOURCE_PATH}/src/uk/uk_ua-dictionary-license.txt"
    COMMENT "Dictionaries contained within this package are licensed as follows"
    )
