# Placeholder Highlighter for Neovim

A simple but powerful Neovim plugin that highlights C-style format specifiers (like `%d`, `%f`, `%s`) inside strings.

This is especially useful for languages like C, C++, Go, Python, Lua, etc., where the built-in syntax highlighting might not distinguish these placeholders from the rest of the string. This plugin makes them stand out, improving code readability.

## Features

-   **Accurate Highlighting**: Uses a precise regex to correctly identify complex format specifiers, including flags, width, precision, and length modifiers (e.g., `%-10.2f`, `%lld`).
-   **Optimized**: Highlighting updates are debounced to ensure smooth performance even in large files.
-   **Configurable**: Easily customize the highlight color, supported filetypes, and performance settings.

## Installation & Configuration

This plugin is designed to be configured using the standard `setup(opts)` pattern.

Here is an example for the [`lazy.nvim`](https://github.com/folke/lazy.nvim) plugin manager.

```lua
return {
  "Joreh-T/placeholder_highlighter.nvim",

  -- Load the plugin
  event = "VeryLazy",

  opts = {
    -- Example: Link the highlight to your theme's 'SpecialChar' group
    highlight = { link = "SpecialChar" },

    -- Example: Add 'rust' and 'typescript' to the list of supported filetypes
    filetypes = {
      "c",
      "cpp",
      "python",
      "lua",
      "go",
      "rust",
      "typescript",
    },

    -- Example: Change the debounce delay to 200ms
    debounce = 200,
  },
}
```

## Configuration Options

You can pass any of the following options to the `setup` function.

| Option      | Description                                                                                             | Default Value                               |
| :---------- | :------------------------------------------------------------------------------------------------------ | :------------------------------------------ |
| `highlight` | A highlight table to customize the placeholder color. You can link to an existing group or define a new one. | `{ fg = "#e06c75", bold = true }` (Red, Bold) |
| `filetypes` | A list of filetypes where the plugin should be active.                                                  | `{ "c", "cpp", "python", "lua", "go" }`     |
| `debounce`  | The delay in milliseconds for debouncing the highlight update on text change.                           | `100`                                       |
