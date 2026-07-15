return {
  {
    "vague2k/vague.nvim",
    config = function()
      require("vague").setup({})
      vim.cmd.colorscheme "vague"
    end
  },
  {
    "lunacookies/vim-substrata",
    lazy = false,
    priority = 1000,
    config = function()
      vim.opt.termguicolors = true

      local groups_to_clear = {
        "@variable",
        "@variable.builtin",
        "@variable.parameter",
        "@variable.member",
        "@property",
        "@field",
        "@constant",
        "@constant.builtin",
        "@module",
        "@label",
        "@punctuation",
        "@punctuation.delimiter",
        "@punctuation.bracket",
        "@punctuation.special",
      }
      for _, group in ipairs(groups_to_clear) do
        vim.api.nvim_set_hl(0, group, {})
      end
    end,
  },
}
