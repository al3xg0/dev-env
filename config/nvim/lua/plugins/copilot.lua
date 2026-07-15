return {
  {
    "github/copilot.vim",
    lazy = false,
    config = function()
      vim.keymap.set("n", "<leader>cp", function()
        vim.cmd("Copilot toggle")
      end, { silent = true, noremap = true, desc = "Toggle Copilot" })
    end
  }
}
