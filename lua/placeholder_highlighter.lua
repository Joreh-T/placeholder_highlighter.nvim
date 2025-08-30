local M = {}

-- Create a unique namespace for the plugin
local ns = vim.api.nvim_create_namespace("placeholder_highlighter")
local highlight_group = "Placeholder"

-- Default configuration
local defaults = {
  highlight = { fg = "#e06c75", bold = true }, -- Default highlight
  filetypes = { "c", "cpp", "python", "lua", "go" }, -- Default supported file types
  debounce = 100, -- Debounce delay in milliseconds
}

-- Used to store merged user configuration
local config = {}

-- Debounce timer
local debounce_timer = nil

-- Allow users to configure colors
function M.set_highlight(hl_opts)
  local hl = hl_opts
  -- If user doesn't provide custom colors or provides an empty table, use default colors
  if hl == nil or vim.tbl_isempty(hl) then
    hl = defaults.highlight
  end
  vim.api.nvim_set_hl(0, highlight_group, hl)
end

-- More precise C-style placeholder pattern, supports flags, width(*), precision, length modifiers (h, l, ll, etc.)
local placeholder_pattern = "%%[%-+#0 ]*[0-9*]*%.?[0-9*]*[hlLjzt]?[hl]?[diuoxXfFeEgGaAcspn]"

-- Function to get current cursor position
local function get_cursor_position()
  local row, _ = unpack(vim.api.nvim_win_get_cursor(0)) -- Get current window cursor line number (0-based)
  return row
end

local function is_comment_line(line, filetype)
  -- Determine comment rules
  if filetype == "python" then
    return line:match("^%s*#") ~= nil -- Python comment: line starts with # (can have spaces before)
  elseif filetype == "lua" then
    return line:match("^%s*--") ~= nil -- Lua comment: line starts with -- (can have spaces before)
  elseif filetype == "cpp" or filetype == "c" then
    return line:match("^%s*//") ~= nil -- C/C++ comment: line starts with // (can have spaces before)
  elseif filetype == "sh" then
    return line:match("^%s*#") ~= nil -- Shell script comment: line starts with # (can have spaces before)
  else
    -- For other file types, don't process for now
    return false
  end
end

-- Use extmarks to highlight placeholders in buffer
function M.highlight_nearby()
  -- Use file type list from configuration
  local is_valid_filetype = false
  local filetype = vim.bo.filetype
  for _, ft in ipairs(config.filetypes) do
    if filetype == ft then
      is_valid_filetype = true
      break
    end
  end

  -- If file type doesn't meet criteria, return directly
  if not is_valid_filetype then
    return
  end

  local cursor_line = get_cursor_position() -- Get cursor line number
  local bufnr = vim.api.nvim_get_current_buf() -- Get current buffer number
  local total_line = vim.api.nvim_buf_line_count(bufnr) -- Get total buffer line count

  -- Set highlight range (cursor_line -50 lines, cursor_line +50 lines)
  local start_line = math.max(0, cursor_line - 50) -- Minimum line number is 0
  local end_line = math.min(total_line - 1, cursor_line + 50) -- Maximum line number is line_count - 1

  -- Clear old highlights (extmarks) in range
  vim.api.nvim_buf_clear_namespace(bufnr, ns, start_line, end_line + 1)

  -- Iterate through lines near cursor for regex matching
  for row = start_line, end_line do
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
    if is_comment_line(line, filetype) then
      goto continue
    end

    local start_pos = 1-- Start search from beginning of line
    while true do
      local start, stop = string.find(line, placeholder_pattern, start_pos)
      if not start then
        break
      end

      -- Use extmark to add highlight, it automatically follows text movement
      vim.api.nvim_buf_set_extmark(bufnr, ns, row, start - 1, {
        end_col = stop,
        hl_group = highlight_group,
      })

      -- Update start position to avoid infinite loop
      start_pos = stop + 1
    end
    ::continue::
  end
end

-- Debounced highlight function
local function debounced_highlight()
  if debounce_timer then
    debounce_timer:close()
  end

  debounce_timer = vim.loop.new_timer()
  debounce_timer:start(config.debounce, 0, vim.schedule_wrap(function()
    M.highlight_nearby()
  end))
end

function M.setup_autocmd()
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "CursorHold" }, {
    pattern = "*",
    callback = debounced_highlight,
  })
end

-- Initialize module
function M.setup(opts)
  -- Merge user configuration with default configuration
  config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  M.set_highlight(config.highlight)
  M.setup_autocmd()
end

return M
