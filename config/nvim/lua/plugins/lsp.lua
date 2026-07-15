return {
  {
    "williamboman/mason.nvim",
    lazy = false,
    config = function()
      require("mason").setup()
    end
  },
  {
    "williamboman/mason-lspconfig.nvim",
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "buf_ls",
          "lua_ls",
          "ts_ls",
          "awk_ls",
          "bashls",
          "clangd",
          "cssls",
          "dockerls",
          "eslint",
          "gopls",
          "jsonls",
          "mdx_analyzer",
          "pyright",
          "ruff",
          "sqlls",
          "tailwindcss",
          "rust_analyzer",
        }
      })
    end
  },
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    config = function()
      local lspconfig = require("lspconfig")
      lspconfig.ts_ls.setup({})
      lspconfig.lua_ls.setup({})
      lspconfig.gopls.setup({})
      lspconfig.pyright.setup({
        pyright = {
          disableOrganizeImports = true,
        },
        python = {
          analysis = {
            ignore = { "*" },
          },
        },
      })
      lspconfig.ruff.setup({})

      vim.keymap.set('n', 'K', vim.lsp.buf.hover, {})
      vim.keymap.set('n', '<leader>gd', vim.lsp.buf.definition, {})
      vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, {})
    end
  }
}
