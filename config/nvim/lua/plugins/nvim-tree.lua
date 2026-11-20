return {
  "nvim-tree/nvim-tree.lua",
  version = "*",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("nvim-tree").setup({
      view = {
        side = 'right',
        width = 35,
        relativenumber = true,
      },
      renderer = {
        -- just the folder name, not the full ~/path/to/it
        root_folder_label = ":t",
        -- git state tints the file name instead of adding a glyph column
        highlight_git = "name",
        indent_markers = {
          enable = true,
        },
        icons = {
          show = {
            git = false,
          },
        },
      },
      -- disable window_picker for
      -- explorer to work well with
      -- window splits
      actions = {
        open_file = {
          window_picker = {
            enable = true,
          },
        },
      },
      filters = {
        dotfiles = false,
        git_ignored = false,
        custom = {},
      },
      git = {
        ignore = false,
      },
      update_focused_file = {
        enable = true,
        update_root = false,
      },
    })

    vim.keymap.set("n", "<leader>t", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file explorer" })
    vim.keymap.set("n", "<leader>ef", "<cmd>NvimTreeFindFileToggle<CR>", { desc = "Toggle file explorer on current file" })
    vim.keymap.set("n", "<leader>ec", "<cmd>NvimTreeCollapse<CR>", { desc = "Collapse file explorer" })
    vim.keymap.set("n", "<leader>er", "<cmd>NvimTreeRefresh<CR>", { desc = "Refresh file explorer" })
  end,
}
