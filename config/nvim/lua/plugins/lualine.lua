return {
  "nvim-lualine/lualine.nvim",
  config = function()
    require("lualine").setup({
      options = {
        theme = 'auto', -- automatically uses the current colorscheme
        globalstatus = true,
      },
      extensions = { 'nvim-tree' },
    })
  end
}