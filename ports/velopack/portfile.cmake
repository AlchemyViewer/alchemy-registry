vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO velopack/velopack
    REF "${VERSION}"
    SHA512 5f782dcc2a172a90dd3e13130e00e6a2144cb679061cc6e7512029f5fb197a3278a9d5db00f3819ac5cbaa078211c18cee5cc2b0c24bbb8d77bda1825382c002
    HEAD_REF main
)

if(VCPKG_TARGET_IS_WINDOWS)
    set(USER_HOME "$ENV{USERPROFILE}")
else()
    set(USER_HOME "$ENV{HOME}")
endif()

if(DEFINED ENV{CARGO_HOME})
    set(CARGO_HOME "$ENV{CARGO_HOME}")
else()
    set(CARGO_HOME "${USER_HOME}/.cargo")
endif()

find_program(CARGO_EXECUTABLE cargo
    HINTS "${CARGO_HOME}"
    PATH_SUFFIXES "bin"
    REQUIRED)

find_program(RUSTUP_EXECUTABLE rustup
    HINTS "${CARGO_HOME}"
    PATH_SUFFIXES "bin"
    REQUIRED)

if(VCPKG_TARGET_IS_WINDOWS)
    set(RUST_TARGET "x86_64-pc-windows-msvc")
elseif(VCPKG_TARGET_IS_OSX)
    if(VCPKG_OSX_ARCHITECTURES MATCHES "arm64")
        set(RUST_TARGET "aarch64-apple-darwin")
    else()
        set(RUST_TARGET "x86_64-apple-darwin")
    endif()
elseif(VCPKG_TARGET_IS_LINUX)
    set(RUST_TARGET "x86_64-unknown-linux-gnu")
else()
    message(FATAL_ERROR "velopack has no rust target mapping for ${TARGET_TRIPLET}.")
endif()

vcpkg_execute_required_process(
    COMMAND ${RUSTUP_EXECUTABLE} target add ${RUST_TARGET}
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME rustup-${TARGET_TRIPLET}-rel
)

# velopack_libc is a rust crate with no debug distribution; the release build
# serves every configuration.
vcpkg_execute_build_process(
    COMMAND ${CARGO_EXECUTABLE} build --target ${RUST_TARGET} --release -p velopack_libc
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME cargo-${TARGET_TRIPLET}-rel
)

set(CARGO_OUT_DIR "${SOURCE_PATH}/target/${RUST_TARGET}/release")

if(VCPKG_TARGET_IS_WINDOWS)
    file(INSTALL "${CARGO_OUT_DIR}/velopack_libc.dll" DESTINATION "${CURRENT_PACKAGES_DIR}/bin")
    file(INSTALL "${CARGO_OUT_DIR}/velopack_libc.dll.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
else()
    file(INSTALL "${CARGO_OUT_DIR}/libvelopack_libc.a" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
endif()

file(INSTALL
    "${SOURCE_PATH}/src/lib-cpp/include/Velopack.h"
    "${SOURCE_PATH}/src/lib-cpp/include/Velopack.hpp"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include/velopack")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/unofficial-velopack-config.cmake"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/unofficial-velopack")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
