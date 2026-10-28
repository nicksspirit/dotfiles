local M = {}
local popup_win

local function guide_path()
  local source = debug.getinfo(1, "S").source:sub(2)
  local module_path = vim.fn.resolve(vim.fn.fnamemodify(source, ":p"))
  local repo_root = vim.fn.fnamemodify(module_path, ":h:h:h:h:h:h")
  return repo_root .. "/docs/treemux.md"
end

function M.open()
  local path = guide_path()
  if vim.fn.filereadable(path) ~= 1 then
    vim.notify("Treemux shortcuts guide not found: " .. path, vim.log.levels.ERROR)
    return
  end

  if popup_win and vim.api.nvim_win_is_valid(popup_win) then
    vim.api.nvim_win_close(popup_win, true)
  end

  local lines = vim.fn.readfile(path)
  local max_line_length = 0
  for _, line in ipairs(lines) do
    max_line_length = math.max(max_line_length, #line)
  end

  local width = math.min(math.max(60, math.min(max_line_length, 100)), vim.o.columns - 4)
  local height = math.min(
    math.max(1, vim.o.lines - 4),
    math.max(10, math.floor(vim.o.lines * 0.8)),
    #lines
  )
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_name(buf, "Treemux shortcuts")
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false

  popup_win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height - 2) / 2)),
    col = math.max(0, math.floor((vim.o.columns - width - 2) / 2)),
    style = "minimal",
    border = "rounded",
    title = " Treemux shortcuts ",
    title_pos = "center",
  })

  vim.wo[popup_win].wrap = true
  vim.wo[popup_win].linebreak = true
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(popup_win) then
      vim.api.nvim_win_close(popup_win, true)
    end
  end, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(popup_win) then
      vim.api.nvim_win_close(popup_win, true)
    end
  end, { buffer = buf, silent = true, nowait = true })
end

return M
