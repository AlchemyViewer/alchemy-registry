get_filename_component(_dicts_root "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# Data only, no library: the .aff/.dic pairs are staged for hunspell at runtime.
set(ALCHEMY_DICTIONARIES_DIR "${_dicts_root}/share/alchemy-dictionaries/dictionaries")

unset(_dicts_root)
