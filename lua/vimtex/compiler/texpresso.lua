local M = {}

local path_cache = {}
local path_cache_from_wsl = {}

function M.path(path, distro)
  if not distro or distro == "" then
    return path
  end

  local key = distro .. "\0" .. path

  if path_cache[key] then
    return path_cache[key]
  end

  local name = "VIMTEX_TEXPRESSO_PATH"
  local wslenv = name .. "/p"

  if vim.env.WSLENV and vim.env.WSLENV ~= "" then
    wslenv = vim.env.WSLENV .. ":" .. wslenv
  end

  local result = vim.system({
    "wsl.exe",
    "-d",
    distro,
    "--",
    "printenv",
    name,
  }, {
    text = true,
    env = {
      [name] = path,
      WSLENV = wslenv,
    },
  }):wait()

  if result.code ~= 0 then
    return path
  end

  local translated = vim.trim(result.stdout)

  if translated == "" then
    return path
  end

  path_cache[key] = translated
  path_cache_from_wsl[distro .. "\0" .. translated] = path

  return translated
end

function M.path_from_wsl(path, distro)
  if not distro or distro == "" then
    return path
  end

  local key = distro .. "\0" .. path

  if path_cache_from_wsl[key] then
    return path_cache_from_wsl[key]
  end

  local result = vim.system({
    "wsl.exe",
    "-d",
    distro,
    "--",
    "wslpath",
    "-w",
    path,
  }, {
    text = true,
  }):wait()

  if result.code ~= 0 then
    return path
  end

  local translated = vim.trim(result.stdout)

  if translated == "" then
    return path
  end

  path_cache_from_wsl[key] = translated
  path_cache[distro .. "\0" .. translated] = path

  return translated
end

function M.attach()
  local stopped = false

  vim.api.nvim_buf_attach(0, false, {
    on_lines = function(_, buf, _tick, first, oldlast, newlast)
      if stopped then
        return true
      end

      local compiler = vim.b[buf].vimtex and vim.b[buf].vimtex.compiler

      if not compiler or not compiler.job then
        return
      end

      local path = M.path(
        vim.api.nvim_buf_get_name(buf),
        compiler.wsl
      )

      local count = oldlast - first
      local lines = ""

      if first < newlast then
        lines = table.concat(
          vim.api.nvim_buf_get_lines(buf, first, newlast, false),
          "\n"
        ) .. "\n"
      end

      local msg = vim.json.encode({
        "change-lines",
        path,
        first,
        count,
        lines,
      })

      vim.api.nvim_chan_send(compiler.job, msg .. "\n")
    end,
  })

  return function()
    stopped = true
  end
end

return M
