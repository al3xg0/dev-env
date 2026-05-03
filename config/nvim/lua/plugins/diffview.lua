return {
  "sindrets/diffview.nvim",
  event = "VeryLazy",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles" },
  config = function()
    require("diffview").setup()

    vim.keymap.set("n", "<leader>dv", ":DiffviewOpen<CR>", { desc = "Open Diffview" })
    vim.keymap.set("n", "<leader>gq", ":DiffviewClose<CR>", { desc = "Close Diffview" })
  end,
}
