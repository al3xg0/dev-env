return {
  "github/copilot.vim",
  config = function()
    vim.keymap.set("n", "<leader>ct", function()
      require("copilot.command").toggle()
    end)
  end
}
