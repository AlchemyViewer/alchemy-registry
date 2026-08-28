if(TARGET unofficial::nvapi::nvapi)
    return()
endif()

get_filename_component(_nvapi_root "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

add_library(unofficial::nvapi::nvapi STATIC IMPORTED)
set_target_properties(unofficial::nvapi::nvapi PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${_nvapi_root}/include")

if(EXISTS "${_nvapi_root}/lib/nvapi64.lib")
    set_property(TARGET unofficial::nvapi::nvapi APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
    set_target_properties(unofficial::nvapi::nvapi PROPERTIES
        IMPORTED_LOCATION_RELEASE "${_nvapi_root}/lib/nvapi64.lib")
endif()

if(EXISTS "${_nvapi_root}/debug/lib/nvapi64.lib")
    set_property(TARGET unofficial::nvapi::nvapi APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
    set_target_properties(unofficial::nvapi::nvapi PROPERTIES
        IMPORTED_LOCATION_DEBUG "${_nvapi_root}/debug/lib/nvapi64.lib")
endif()

unset(_nvapi_root)
