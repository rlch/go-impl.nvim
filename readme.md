# go-impl.nvim

<!-- markdownlint-disable no-inline-html -->

> [!WARNING]
> THIS PROJECT IS STILL EXPERIMENTAL.

A Neovim plugin designed to simplify the implementation of Go interfaces.

## 🌟 Key Features

- **Fully Asynchronous**:
  Non-blocking operations for a seamless experience.
- **Smart Receiver Detection**:
  Automatically identifies the correct receiver based on cursor position.
- **Treesitter Validation**:
  Ensures the receiver is valid before executing `impl`.
- **Fast Interface Selection**:
  Uses [ibhagwan/fzf-lua](https://github.com/ibhagwan/fzf-lua) for quick and
  efficient interface selection.
- **Generic Parameters Support**:
  Allows specifying types for generic parameters with highlighting and interface
  declaration.

## 📋 Requirements

- Neovim >= 0.10.0
- Latest version of [josharian/impl](https://github.com/josharian/impl)

## 🚚 Installation

<details>
<summary>Install with <a href="https://github.com/folke/lazy.nvim">lazy.nvim</a></summary>

```lua
{
  "fang2hou/go-impl.nvim",
  ft = "go",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "ibhagwan/fzf-lua",
    "nvim-lua/plenary.nvim",
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

</details>

## 🚀 Usage

1. Open a Go file.
2. Place your cursor on the structure you want to implement.
3. Run `:lua require("go-impl").open()` or `:GoImplOpen` to start implementing.

## ⚙️ Configuration

The default configuration should work for most users.

Check out all available options in [config.lua](lua/go-impl/config.lua).

## 🔄 Alternatives and Related Projects

- [edolphin-ydf/goimpl.nvim](https://github.com/edolphin-ydf/goimpl.nvim) -
  Partial support for generic interfaces and telescope search.
  - This project is inspired by goimpl.nvim.
- [olexsmir/gopher.nvim](https://github.com/olexsmir/gopher.nvim) -
  Supports non-generic interfaces but requires manual input for arguments.
- [fatih/vim-go](https://github.com/fatih/vim-go) -
  A comprehensive Go development plugin for Vim.
- [rhysd/vim-go-impl](https://github.com/rhysd/vim-go-impl) -
  Wraps the `impl` command in Vim, and also needs manual input for arguments.

## 🪪 License

MIT
