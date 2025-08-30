local M = {}

-- 为插件创建一个唯一的命名空间
local ns = vim.api.nvim_create_namespace("placeholder_highlighter")
local highlight_group = "Placeholder"

-- 默认配置
local defaults = {
  highlight = { fg = "#e06c75", bold = true }, -- 默认高亮
  filetypes = { "c", "cpp", "python", "lua", "go" }, -- 默认支持的文件类型
  debounce = 100, -- 防抖延迟, 单位毫秒
}

-- 用于存储合并后的用户配置
local config = {}

-- 防抖计时器
local debounce_timer = nil

-- 允许用户配置颜色
function M.set_highlight(hl_opts)
  local hl = hl_opts
  -- 如果用户没有提供自定义颜色，或者提供了一个空表，则使用默认颜色
  if hl == nil or vim.tbl_isempty(hl) then
    hl = defaults.highlight
  end
  vim.api.nvim_set_hl(0, highlight_group, hl)
end

-- 更精确的C-style占位符模式, 支持标志、宽度(*)、精度、长度修饰符(h, l, ll等)
local placeholder_pattern = "%%[%-+#0 ]*[0-9*]*%.?[0-9*]*[hlLjzt]?[hl]?[diuoxXfFeEgGaAcspn]"

-- 获取当前光标位置的函数
local function get_cursor_position()
  local row, _ = unpack(vim.api.nvim_win_get_cursor(0)) -- 获取当前窗口的光标行号（0-based）
  return row
end

local function is_comment_line(line, filetype)
  -- 判断注释规则
  if filetype == "python" then
    return line:match("^%s*#") ~= nil -- Python 注释：行首是 #（前面可以有空格）
  elseif filetype == "lua" then
    return line:match("^%s*--") ~= nil -- Lua 注释：行首是 --（前面可以有空格）
  elseif filetype == "cpp" or filetype == "c" then
    return line:match("^%s*//") ~= nil -- C/C++ 注释：行首是 //（前面可以有空格）
  elseif filetype == "sh" then
    return line:match("^%s*#") ~= nil -- Shell 脚本注释：行首是 #（前面可以有空格）
  else
    -- 对于其他文件类型，暂时不处理
    return false
  end
end

-- 使用 extmarks 高亮缓冲区中的占位符
function M.highlight_nearby()
  -- 使用配置中的文件类型列表
  local is_valid_filetype = false
  local filetype = vim.bo.filetype
  for _, ft in ipairs(config.filetypes) do
    if filetype == ft then
      is_valid_filetype = true
      break
    end
  end

  -- 如果文件类型不符合条件，直接返回
  if not is_valid_filetype then
    return
  end

  local cursor_line = get_cursor_position() -- 获取光标行号
  local bufnr = vim.api.nvim_get_current_buf() -- 获取当前缓冲区编号
  local total_line = vim.api.nvim_buf_line_count(bufnr) -- 获取缓冲区总行数

  -- 设置高亮范围（最多50行）
  local start_line = math.max(0, cursor_line - 50) -- 最小行号是0
  local end_line = math.min(total_line - 1, cursor_line + 50) -- 最大行号是 line_count - 1

  -- 清除范围内的旧高亮 (extmarks)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, start_line, end_line + 1)

  -- 遍历光标附近的行进行正则匹配
  for row = start_line, end_line do
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
    if is_comment_line(line, filetype) then
      goto continue
    end

    local start_pos = 1 -- 从行首开始搜索
    while true do
      local start, stop = string.find(line, placeholder_pattern, start_pos)
      if not start then
        break
      end

      -- 使用 extmark 添加高亮，它会自动跟随文本移动
      vim.api.nvim_buf_set_extmark(bufnr, ns, row, start - 1, {
        end_col = stop,
        hl_group = highlight_group,
      })

      -- 更新起始位置，避免无限循环
      start_pos = stop + 1
    end
    ::continue::
  end
end

-- 经过防抖处理的高亮函数
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
    callback = debounced_highlight, -- 使用防抖函数
  })
end

-- 初始化模块
function M.setup(opts)
  -- 合并用户配置和默认配置
  config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  M.set_highlight(config.highlight)
  M.setup_autocmd()
end

return M
