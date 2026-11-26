return {
  {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.8',
    dependencies = { 
      'nvim-lua/plenary.nvim', 
      'nvim-telescope/telescope-ui-select.nvim',
      {'nvim-telescope/telescope-fzf-native.nvim', build = 'make' } 
    },
    config = function()
      require("telescope").setup({
        defaults = {
          layout_strategy = "vertical",
          mappings = {
            n = {
              ["d"] = require("telescope.actions").delete_buffer,
              ["<esc>"] = require("telescope.actions").close,
            },
            i = {
              ['<C-t>'] = require('telescope.actions.layout').toggle_preview
            },
          },
        },
        pickers = {
          find_files = {
            hidden = true,
            no_ignore = true,
            file_ignore_patterns = { "^%.git/", "node_modules/" },
          },
          live_grep = {
            additional_args = { "--hidden", "--no-ignore", "--glob", "!.git/", "--glob", "!node_modules/" },
          },
        },
        extensions = {
          ['ui-select'] = {
            require("telescope.themes").get_dropdown {
            }
          },
          fzf = {}
        }
      })

      require('telescope').load_extension('fzf')
      require("telescope").load_extension("ui-select")

      local builtin = require("telescope.builtin")
      vim.keymap.set('n', '<C-p>', builtin.find_files, {})
      vim.keymap.set('n', '<leader>lg', builtin.live_grep, {})
      vim.keymap.set('n', '<leader>gs', builtin.git_status, {})
      vim.keymap.set('n', '<leader>rs', builtin.resume, {})
      vim.keymap.set('n', '<leader>fr', builtin.lsp_references, { desc = 'Telescope LSP references' })
      vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
      vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
      vim.keymap.set('n', '<leader>en', function()
        builtin.find_files({ cwd = vim.fn.stdpath('config') })
      end, {})
    end
  },
}
