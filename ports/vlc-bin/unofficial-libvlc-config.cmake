if(TARGET unofficial::libvlc::libvlc)
    return()
endif()

get_filename_component(_vlc_root "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# Codec plugins, loaded at runtime from a directory VLC is pointed at.
set(VLC_PLUGINS_DIR "${_vlc_root}/plugins/vlc-bin")

# Headers are reached as <vlc/vlc.h>, so the interface is the include root.
foreach(name libvlc libvlccore)
    add_library(unofficial::libvlc::${name} SHARED IMPORTED)
    set_target_properties(unofficial::libvlc::${name} PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${_vlc_root}/include"
        IMPORTED_CONFIGURATIONS RELEASE)

    if(WIN32)
        set_target_properties(unofficial::libvlc::${name} PROPERTIES
            IMPORTED_LOCATION_RELEASE "${_vlc_root}/bin/${name}.dll"
            IMPORTED_IMPLIB_RELEASE "${_vlc_root}/lib/${name}.lib")
    else()
        set_target_properties(unofficial::libvlc::${name} PROPERTIES
            IMPORTED_LOCATION_RELEASE "${_vlc_root}/lib/${name}.dylib")
    endif()

    # The bundle is release-only, so every configuration takes the same binary.
    set_target_properties(unofficial::libvlc::${name} PROPERTIES
        MAP_IMPORTED_CONFIG_DEBUG Release
        MAP_IMPORTED_CONFIG_MINSIZEREL Release
        MAP_IMPORTED_CONFIG_RELWITHDEBINFO Release)
endforeach()

set_property(TARGET unofficial::libvlc::libvlc APPEND PROPERTY
    INTERFACE_LINK_LIBRARIES unofficial::libvlc::libvlccore)

unset(_vlc_root)
