return {
  {
    "webhooked/kanso.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.opt.termguicolors = true
      require("kanso").setup {
        theme = "ink",
      }
      vim.cmd.colorscheme "kanso-ink"
    end,
  },
}
