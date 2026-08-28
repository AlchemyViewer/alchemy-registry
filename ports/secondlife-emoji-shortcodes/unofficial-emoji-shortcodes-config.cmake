get_filename_component(_emoji_root "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# Data only, no library: one emoji_characters.xml per language subdirectory,
# staged into the viewer's skin.
set(EMOJI_SHORTCODES_XUI_DIR "${_emoji_root}/share/secondlife-emoji-shortcodes/xui")

unset(_emoji_root)
