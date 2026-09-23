# config.nu
#
# Installed by:
# version = "0.115.1"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# Nushell sets "sensible defaults" for most configuration settings, 
# so your `config.nu` only needs to override these defaults if desired.
#
# You can open this file in your default editor using:
#     config nu
#
# You can also pretty-print and page through the documentation for configuration
# options using:
#     config nu --doc | nu-highlight | less -R

# No startup banner.
$env.config.show_banner = false

# Named colors such as cyan already come from Ghostty's palette. Nushell's
# defaults pick the bright, bold ones. "default" is Ghostty's normal foreground.
# LS_COLORS is a second loud scheme, so leave it off.
$env.config.ls.use_ls_colors = false
$env.config.color_config = {
    separator: default
    leading_trailing_space_bg: {attr: n}
    header: default
    empty: default
    bool: default
    int: default
    filesize: default
    duration: default
    datetime: default
    range: default
    float: default
    string: default
    nothing: default
    binary: default
    "cell-path": default
    row_index: default
    record: default
    list: default
    block: default
    hints: default
    search_result: default
    shape_garbage: default
    shape_range: default
    shape_vardecl: default
    shape_string_interpolation: default
    shape_operator: default
    shape_raw_string: default
    shape_float: default
    shape_datetime: default
    shape_globpattern: default
    shape_externalarg: default
    shape_closure: default
    shape_pipe: default
    shape_flag: default
    shape_nothing: default
    shape_int: default
    shape_variable: default
    shape_keyword: default
    binary_whitespace: default
    shape_signature: default
    shape_filepath: default
    shape_custom: default
    shape_internalcall: default
    shape_literal: default
    shape_match_pattern: default
    glob: default
    shape_list: default
    closure: default
    semver: default
    shape_glob_interpolation: default
    shape_external: default
    binary_printable: default
    shape_binary: default
    shape_directory: default
    "semver-range": default
    shape_external_resolved: default
    binary_non_ascii: default
    shape_record: default
    binary_null_char: default
    shape_block: default
    shape_table: default
    shape_bool: default
    shape_matching_brackets: default
    shape_string: default
    binary_ascii_other: default
    shape_redirection: default
    selection_cursor: default
    selection: default
}

# Mitchell Hashimoto's Oh My Posh prompt.
source ~/.config/oh-my-posh/init.nu
