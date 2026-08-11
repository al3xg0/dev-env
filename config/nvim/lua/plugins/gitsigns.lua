return {
  "lewis6991/gitsigns.nvim",
  config = function()
    require('gitsigns').setup()
    vim.keymap.set("n", "<leader>gp", ":Gitsigns preview_hunk<CR>", {})
    vim.keymap.set("n", "<leader>gt", ":Gitsigns toggle_current_line_blame<CR>", {})
    vim.keymap.set("n", "<leader>gb", function()
      require('gitsigns').blame_line({ full = true })
    end, {})
  end
}
