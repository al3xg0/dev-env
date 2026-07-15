return {
  {
    "github/copilot.vim",
    lazy = false,
    config = function()
      local copilot_enabled = true
      vim.keymap.set("n", "<leader>cp", function()
        if copilot_enabled then
          vim.cmd("Copilot disable")
          copilot_enabled = false
          vim.notify("Copilot disabled")
        else
          vim.cmd("Copilot enable")
          copilot_enabled = true
          vim.notify("Copilot enabled")
        end
      end, { silent = true, noremap = true, desc = "Toggle Copilot" })
    end
  }
}
