if(TARGET unofficial::cef::cef)
    return()
endif()

get_filename_component(_cef_root "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# CEF headers are reached both as "cef_app.h" and as "include/cef_app.h", so both
# roots go on the interface.
set(CEF_INCLUDE_DIR "${_cef_root}/include/cef/include")

# Runtime payload the consumer stages beside its executable. On Apple the
# framework bundle carries all of it, so only CEF_FRAMEWORK_DIR is set there.
set(CEF_RESOURCE_DIR "")
set(CEF_BINARY_DIR_RELEASE "")
set(CEF_BINARY_DIR_DEBUG "")
set(CEF_FRAMEWORK_DIR "")

if(EXISTS "${_cef_root}/share/cef-bin/Resources")
    set(CEF_RESOURCE_DIR "${_cef_root}/share/cef-bin/Resources")
endif()
if(EXISTS "${_cef_root}/share/cef-bin/Release")
    set(CEF_BINARY_DIR_RELEASE "${_cef_root}/share/cef-bin/Release")
endif()
if(EXISTS "${_cef_root}/share/cef-bin/Debug")
    set(CEF_BINARY_DIR_DEBUG "${_cef_root}/share/cef-bin/Debug")
else()
    set(CEF_BINARY_DIR_DEBUG "${CEF_BINARY_DIR_RELEASE}")
endif()
if(EXISTS "${_cef_root}/lib/Chromium Embedded Framework.framework")
    set(CEF_FRAMEWORK_DIR "${_cef_root}/lib/Chromium Embedded Framework.framework")
endif()

if(WIN32)
    set(_cef_wrapper "lib/libcef_dll_wrapper.lib")
else()
    set(_cef_wrapper "lib/libcef_dll_wrapper.a")
endif()

add_library(unofficial::cef::libcef_dll_wrapper STATIC IMPORTED)
set_target_properties(unofficial::cef::libcef_dll_wrapper PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${_cef_root}/include/cef;${CEF_INCLUDE_DIR}"
    IMPORTED_CONFIGURATIONS RELEASE
    IMPORTED_LOCATION_RELEASE "${_cef_root}/${_cef_wrapper}")
if(EXISTS "${_cef_root}/debug/${_cef_wrapper}")
    set_property(TARGET unofficial::cef::libcef_dll_wrapper APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
    set_target_properties(unofficial::cef::libcef_dll_wrapper PROPERTIES
        IMPORTED_LOCATION_DEBUG "${_cef_root}/debug/${_cef_wrapper}")
endif()

# Only Debug takes the debug artifact; every other configuration is built against
# the release one, matching which payload the consumer stages.
set_target_properties(unofficial::cef::libcef_dll_wrapper PROPERTIES
    MAP_IMPORTED_CONFIG_MINSIZEREL Release
    MAP_IMPORTED_CONFIG_RELWITHDEBINFO Release)

add_library(unofficial::cef::cef INTERFACE IMPORTED)
set_property(TARGET unofficial::cef::cef APPEND PROPERTY
    INTERFACE_LINK_LIBRARIES unofficial::cef::libcef_dll_wrapper)

# On Apple the loader resolves through the embedded framework, so there is no
# separate library to link against.
if(NOT APPLE)
    add_library(unofficial::cef::libcef SHARED IMPORTED)
    set_target_properties(unofficial::cef::libcef PROPERTIES
        IMPORTED_CONFIGURATIONS RELEASE
        MAP_IMPORTED_CONFIG_MINSIZEREL Release
        MAP_IMPORTED_CONFIG_RELWITHDEBINFO Release)

    if(WIN32)
        set_target_properties(unofficial::cef::libcef PROPERTIES
            IMPORTED_LOCATION_RELEASE "${_cef_root}/bin/libcef.dll"
            IMPORTED_IMPLIB_RELEASE "${_cef_root}/lib/libcef.lib")
        if(EXISTS "${_cef_root}/debug/lib/libcef.lib")
            set_property(TARGET unofficial::cef::libcef APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
            set_target_properties(unofficial::cef::libcef PROPERTIES
                IMPORTED_LOCATION_DEBUG "${_cef_root}/debug/bin/libcef.dll"
                IMPORTED_IMPLIB_DEBUG "${_cef_root}/debug/lib/libcef.lib")
        endif()
    else()
        set_target_properties(unofficial::cef::libcef PROPERTIES
            IMPORTED_LOCATION_RELEASE "${_cef_root}/lib/libcef.so")
        if(EXISTS "${_cef_root}/debug/lib/libcef.so")
            set_property(TARGET unofficial::cef::libcef APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
            set_target_properties(unofficial::cef::libcef PROPERTIES
                IMPORTED_LOCATION_DEBUG "${_cef_root}/debug/lib/libcef.so")
        endif()
    endif()

    set_property(TARGET unofficial::cef::cef APPEND PROPERTY
        INTERFACE_LINK_LIBRARIES unofficial::cef::libcef)
endif()

unset(_cef_wrapper)
unset(_cef_root)
