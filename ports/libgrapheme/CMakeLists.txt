cmake_minimum_required(VERSION 3.20)
project(libgrapheme VERSION 3.0.0 LANGUAGES C)

include(GNUInstallDirs)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Each generator parses data/*.txt and prints a lookup table on stdout. The
# paths it reads are relative, so it has to run from the source root, and
# src/*.c include the result as "../gen/<name>.h" -- so the header has to land
# back in the source tree rather than the build directory.
#
# These are host tools. Building them with the target compiler is only correct
# because every triplet this port is used on builds natively.
set(LIBGRAPHEME_TABLES bidirectional case character line sentence word)

set(generated_headers "")
foreach(table IN LISTS LIBGRAPHEME_TABLES)
    add_executable(gen-${table} "gen/${table}.c" gen/util.c)
    target_include_directories(gen-${table} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
    if(MSVC)
        target_compile_definitions(gen-${table} PRIVATE _CRT_SECURE_NO_WARNINGS)
    endif()

    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_SOURCE_DIR}/gen/${table}.h"
        COMMAND "${CMAKE_COMMAND}"
                "-DGENERATOR=$<TARGET_FILE:gen-${table}>"
                "-DOUTPUT=${CMAKE_CURRENT_SOURCE_DIR}/gen/${table}.h"
                "-DWORKDIR=${CMAKE_CURRENT_SOURCE_DIR}"
                -P "${CMAKE_CURRENT_SOURCE_DIR}/run-generator.cmake"
        DEPENDS gen-${table}
        COMMENT "Generating gen/${table}.h"
        VERBATIM
    )
    list(APPEND generated_headers "${CMAKE_CURRENT_SOURCE_DIR}/gen/${table}.h")
endforeach()

add_custom_target(libgrapheme-tables DEPENDS ${generated_headers})

add_library(grapheme
    src/bidirectional.c
    src/case.c
    src/character.c
    src/line.c
    src/sentence.c
    src/utf8.c
    src/util.c
    src/word.c
)
add_dependencies(grapheme libgrapheme-tables)

target_include_directories(grapheme
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
if(MSVC)
    target_compile_definitions(grapheme PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()

install(TARGETS grapheme
    EXPORT libgrapheme-targets
    ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
)
install(FILES grapheme.h DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")
install(EXPORT libgrapheme-targets
    NAMESPACE libgrapheme::
    DESTINATION share/libgrapheme
)

file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/libgrapheme-config.cmake"
     "include(\"\${CMAKE_CURRENT_LIST_DIR}/libgrapheme-targets.cmake\")\n")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/libgrapheme-config.cmake"
    DESTINATION share/libgrapheme
)
