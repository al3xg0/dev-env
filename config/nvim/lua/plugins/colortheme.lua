-- Tinted-mono take on vague: the old greyscale ramp, but each step
-- blended ~35% back towards vague's original hue, so structure still
-- reads through lightness while a little colour comes through.
-- Diagnostics and git colours are left to vague so they still stand out.
local mono = {
  ghost = "#5c5c6b", -- comments: visible, ignorable
  faint = "#8c929f", -- punctuation-level: operators
  dim = "#808da1", -- structural chrome: keywords, icons, root paths
  muted = "#b5a399", -- strings
  soft = "#a99fb2", -- parameters, empty folders
  mid = "#a2abb7", -- types, builtins, symlinks
  strong = "#bfaa9a", -- numbers
  bold = "#afafc6", -- constants
  bright = "#bcbcca", -- properties, directories
  peak = "#c1aab1", -- functions, special/exec files
}

return {
  {
    "vague2k/vague.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.opt.termguicolors = true
      require("vague").setup {
        colors = {
          comment = mono.ghost,
          keyword = mono.dim,
          operator = mono.faint,
          string = mono.muted,
          parameter = mono.soft,
          builtin = mono.mid,
          type = mono.mid,
          number = mono.strong,
          constant = mono.bold,
          property = mono.bright,
          func = mono.peak,
        },
        -- Directory drives folder names in nvim-tree (vague paints it with
        -- its hint blue) — grey it out along with nvim-tree's own groups,
        -- without touching DiagnosticHint which shares the blue.
        on_highlights = function(highlights, _)
          highlights.Directory = { fg = mono.bright }
          highlights.NvimTreeFolderIcon = { fg = mono.dim }
          highlights.NvimTreeFolderName = { fg = mono.bright }
          highlights.NvimTreeOpenedFolderName = { fg = mono.peak }
          highlights.NvimTreeEmptyFolderName = { fg = mono.soft }
          highlights.NvimTreeRootFolder = { fg = mono.dim }
          highlights.NvimTreeSpecialFile = { fg = mono.peak }
          highlights.NvimTreeExecFile = { fg = mono.peak }
          highlights.NvimTreeSymlink = { fg = mono.mid }
        end,
      }
      vim.cmd.colorscheme "vague"
    end,
  },
  {
    -- Part of the monochrome look: strip the per-filetype brand colours
    -- from file icons (nvim-tree, telescope, etc.)
    "nvim-tree/nvim-web-devicons",
    opts = {
      color_icons = false,
      default = true,
      -- devicons defines its own highlight groups on load (after the theme),
      -- so the icon grey has to be set here rather than in on_highlights
      override = {
        default_icon = { icon = "󰈚", color = mono.dim, name = "Default" },
      },
    },
  },
}
