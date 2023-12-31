local api = vim.api

local M = {}

local options = {
  show_warnings = true, -- Show warning if any required option is missing
  highlights = {
    defaults = {
      bold = false,
      italic = false,
    },
  },
  integration = {
    lualine = {
      enabled = true,
    },
  },
}

--- Gets the highlight `group`.
--- @param hl_name string
--- @return table<string, any>
function M.get_highlight(hl_name)
  return api.nvim_get_hl(0, { name = hl_name, link = false })
end

local function fallback_hl_from_mode(mode)
  local hls = {
    Normal = 'CursorLineNr',
    Insert = 'Question',
    Visual = 'Type',
    Select = 'Keyword',
    Replace = 'Title',
    Command = 'Constant',
    Terminal = 'Question',
    TerminalNormal = 'CursorLineNr',
  }
  return hls[mode] or hls.normal
end

-- Link any missing mode highlight to its fallback highlight
local function set_fallback_highlight_groups()
  local modes = {
    'Normal',
    'Insert',
    'Visual',
    'Command',
    'Replace',
    'Select',
    'Terminal',
    'TerminalNormal',
  }

  for _, mode in pairs(modes) do
    local hl_name = mode .. 'Mode'
    if vim.tbl_isempty(M.get_highlight(hl_name)) then
      local fallback_hl = fallback_hl_from_mode(mode)

      if mode == 'Normal' or mode == 'TerminalNormal' then
        -- We can't directly link the `(Terminal)NormalMode` highlight to
        -- `CursorLineNr` since it will mutate, so we copy it instead
        local cursor_line_nr = M.get_highlight('CursorLineNr')
        api.nvim_set_hl(0, hl_name, cursor_line_nr)
      else
        api.nvim_set_hl(0, hl_name, { link = fallback_hl })
      end
    end
  end
end

--- Get mode name from mode.
---@param mode string
---@return string
local function mode_name_from_mode(mode)
  local mode_names = {
    ['n']  = 'Normal',
    ['i']  = 'Insert',
    ['v']  = 'Visual',
    ['V']  = 'Visual',
    ['']  = 'Visual',
    ['s']  = 'Select',
    ['S']  = 'Select',
    ['R']  = 'Replace',
    ['c']  = 'Command',
    ['t']  = 'Terminal',
    ['nt'] = 'TerminalNormal',
  }
  return mode_names[mode] or 'Normal'
end

--- Set the foreground and background color of 'CursorLineNr'. Accepts any
--- highlight definition map that `vim.api.nvim_set_hl()` does.
--- @param hl_name string
function M.set_cursor_line_highlight(hl_name)
  local hl_group = M.get_highlight(hl_name)
  local hl = vim.tbl_extend('force', options.highlights.defaults, hl_group)
  api.nvim_set_hl(0, 'CursorLineNr', hl)
end

local function create_autocmds()
  local augroup = api.nvim_create_augroup('Modicator', {})
  api.nvim_create_autocmd('ModeChanged', {
    callback = function()
      local mode = api.nvim_get_mode().mode
      local mode_name = mode_name_from_mode(mode)

      M.set_cursor_line_highlight(mode_name .. 'Mode')
    end,
    group = augroup,
  })
  api.nvim_create_autocmd('Colorscheme', {
    callback = set_fallback_highlight_groups,
    group = augroup,
  })
end

local function check_option(option)
  if not vim.o[option] then
    local message = string.format(
      'cursorlinenr.nvim requires `%s` to be set. Run `:set %s` or add `vim.o.%s '
      .. '= true` to your init.lua',
      option,
      option,
      option
    )
    vim.notify(message, vim.log.levels.WARN)
  end
end

local function check_deprecated_config(opts)
  if opts.highlights and opts.highlights.modes then
    local message = 'cursorlinenr.nvim: configuration of highlights has changed '
        .. 'to highlight groups rather than using `highlights.modes`. Check '
        .. '`:help modicator-configuration` to see the new configuration API.'
    vim.notify(message, vim.log.levels.WARN)
  end
end

local function lualine_is_loaded()
  local ok, _ = pcall(require, 'lualine')
  return ok
end

--- @param opts table<string, any>
function M.setup(opts)
  options = vim.tbl_deep_extend('force', options, opts or {})

  if options.show_warnings then
    for _, opt in pairs({ 'cursorline', 'number', 'termguicolors' }) do
      check_option(opt)
    end
    check_deprecated_config(options)
  end

  if lualine_is_loaded() and options.integration.lualine.enabled then
    require('integration.lualine').use_lualine_mode_highlights()
  else
    set_fallback_highlight_groups()
  end

  api.nvim_set_hl(0, 'CursorLineNr', { link = 'NormalMode' })

  create_autocmds()
end

return M