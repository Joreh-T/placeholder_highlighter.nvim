local M = {}

-- 设置默认颜色
local default_highlight = { fg = "#ff79c6", bold = true }  -- 默认颜色是粉色和加粗
local highlight_group = "Placeholder"

-- 允许用户配置颜色
function M.set_highlight(custom_highlight)
  -- 如果用户没有提供自定义颜色，使用默认颜色
  local hl = custom_highlight or default_highlight
  vim.api.nvim_set_hl(0, highlight_group, hl)
end

-- 正则表达式匹配支持多种占位符
local placeholder_pattern = "%%[-+]?%d*[%.]*[a-zA-Z]" -- 支持 % 后面跟字母,数字,+,-,的占位符

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

-- 高亮缓冲区中的指定范围内的所有占位符
function M.highlight_nearby()
  local valid_filetypes = { "c", "cpp", "python", "lua", "go" } -- 定义支持高亮的文件类型

  local is_valid_filetype = false
  local filetype = vim.bo.filetype

  for _, ft in ipairs(valid_filetypes) do
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

  -- 清除已有高亮，防止重复叠加
  -- vim.api.nvim_buf_clear_namespace(bufnr, -1, start_line, end_line + 1)

  -- 遍历光标附近的行进行正则匹配
  for row = start_line, end_line do
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
    if is_comment_line(line, filetype) then
      goto continue
    end

    local start_pos = 0

    while true do
      local start, stop = string.find(line, placeholder_pattern, start_pos)
      if not start then
        break
      end

      if start and stop then
        -- 添加高亮（`stop` 是匹配结束位置）
        vim.api.nvim_buf_add_highlight(bufnr, -1, highlight_group, row, start - 1, stop)
      end
      -- 更新起始位置，避免无限循环
      start_pos = stop + 1
    end
    ::continue::
  end
end

function M.setup_autocmd()
  vim.api.nvim_create_autocmd(
    { "TextChanged", "TextChangedI", "CursorHold" },  -- 事件
    {
      pattern = "*",  -- 可以根据需要调整文件类型限制
      callback = M.highlight_nearby,  -- 直接调用函数
    }
  )
end

-- 初始化模块
function M.setup(custom_highlight)
  M.set_highlight(custom_highlight)  -- 设置自定义高亮（如果有）
  M.setup_autocmd()  -- 设置自动命令
end

return M

