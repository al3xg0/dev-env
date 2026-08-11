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
      vim.lsp.config("pyright", {
        settings = {
          pyright = {
            disableOrganizeImports = true,
          },
          python = {
            analysis = {
              ignore = { "*" },
            },
          },
        },
      })
      vim.lsp.enable({ "ts_ls", "lua_ls", "gopls", "pyright", "ruff" })

      vim.keymap.set('n', 'K', vim.lsp.buf.hover, {})
      vim.keymap.set('n', '<leader>gd', vim.lsp.buf.definition, {})
      vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, {})
    end
  }
}
