-- Half-mono take on Substrata, same treatment as the earlier vague-mono
-- but gentler: a greyscale lightness ramp per role, tinted towards the
-- original Substrata hue at 50% strength — mono structure, but the colours
-- still breathe. Diagnostics and git colours are left to substrata so they
-- still stand out. Pairs with ghostty's substrata-mono.txt.
local mono = {
  ghost = "#5c5e6e", -- comments: visible, ignorable
  faint = "#6e7283", -- punctuation-level: operators, delimiters
  dim = "#8494ab", -- structural chrome: keywords, icons, root paths
  muted = "#76a0a3", -- strings
  soft = "#b4b3c7", -- parameters, empty folders
  mid = "#a292ae", -- types, builtins, symlinks
  strong = "#a18daf", -- numbers (substrata's own magenta)
  bold = "#a493b0", -- constants, booleans
  bright = "#b6b6c7", -- properties, directories
  peak = "#a4b6cc", -- functions, special/exec files
}
local fg = "#b5b4c9"

return {
  {
    "kvrohit/substrata.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.opt.termguicolors = true
      vim.g.substrata_italic_comments = true
      vim.g.substrata_italic_functions = true
      vim.g.substrata_variant = "default"

      -- port bug: the default palette defines `magenta` but the theme reads
      -- `c.pink`; without this, those groups fall back to the near-white fg
      require("substrata.colors").default.pink = "#a18daf"

      vim.cmd.colorscheme "substrata"

      -- Mono overrides on top of substrata's base. Treesitter @-captures
      -- mostly link to the standard groups; set the stragglers explicitly.
      local groups = {
        Comment = { fg = mono.ghost, italic = true },
        Operator = { fg = mono.faint },
        Delimiter = { fg = mono.faint },
        Keyword = { fg = mono.dim },
        Statement = { fg = mono.dim },
        Conditional = { fg = mono.dim },
        Repeat = { fg = mono.dim },
        Include = { fg = mono.dim },
        Exception = { fg = mono.dim },
        PreProc = { fg = mono.dim },
        StorageClass = { fg = mono.dim },
        String = { fg = mono.muted },
        Character = { fg = mono.bold },
        Type = { fg = mono.mid },
        Typedef = { fg = mono.mid },
        Structure = { link = "Type" },
        Number = { fg = mono.strong },
        Float = { fg = mono.strong },
        Boolean = { fg = mono.bold },
        Constant = { fg = mono.bold },
        Function = { fg = mono.peak, italic = true },
        Identifier = { fg = fg },
        Special = { fg = mono.mid },
        MatchParen = { fg = "#f0ecfe", bg = "#2e313d", bold = true },
        ["@variable"] = { fg = fg },
        ["@variable.parameter"] = { fg = mono.soft },
        ["@variable.builtin"] = { fg = mono.mid },
        ["@property"] = { fg = mono.bright },
        ["@variable.member"] = { fg = mono.bright },
        ["@type.builtin"] = { link = "Type" },
        ["@function.call"] = { link = "Function" },
        ["@constructor"] = { fg = mono.faint },
        ["@keyword.operator"] = { fg = mono.faint },
        ["@punctuation.special"] = { fg = mono.strong },
        -- grey out nvim-tree the same way the vague-mono setup did
        Directory = { fg = mono.bright },
        NvimTreeFolderIcon = { fg = mono.dim },
        NvimTreeFolderName = { fg = mono.bright },
        NvimTreeOpenedFolderName = { fg = mono.peak },
        NvimTreeEmptyFolderName = { fg = mono.soft },
        NvimTreeRootFolder = { fg = mono.dim },
        NvimTreeSpecialFile = { fg = mono.peak },
        NvimTreeExecFile = { fg = mono.peak },
        NvimTreeSymlink = { fg = mono.mid },
      }
      for group, opts in pairs(groups) do
        vim.api.nvim_set_hl(0, group, opts)
      end
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
      -- so the icon grey has to be set here rather than with the overrides
      override = {
        default_icon = { icon = "󰈚", color = "#8593a6", name = "Default" },
      },
    },
  },
}
