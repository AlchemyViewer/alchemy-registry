get_filename_component(_fonts_root "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# Data only, no library: the faces are staged into the viewer's fonts directory.
set(ALCHEMY_FONTS_DIR "${_fonts_root}/share/alchemy-fonts/fonts")

unset(_fonts_root)
