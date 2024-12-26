# go-impl.nvim

This is a plugin for neovim that helps you to implement interfaces in go.

> [!WARNING]
> THIS PROJECT IS STILL IN DEVELOPMENT AND IT'S NOT READY FOR USE.

## Installation

I only tested this plugin with [lazy.nvim](https://github.com/folke/lazy.nvim), but it should work with any other plugin manager.

```lua
{
  "fang2hou/go-impl.nvim",
  ft = "go",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "ibhagwan/fzf-lua",
  },
  opts = {},
  keys = {
    {
      "<leader>Gi",
      function()
        require("go-impl").open()
      end,
      mode = { "n" },
      desc = "Go Impl",
    },
  },
}
```

## Configuration

See [config.lua](lua/go-impl/config.lua) for all available options.

## License

MIT
