local file = arg[1]

local SocketStream = require 'nvim.socket_stream'
local socket_stream = SocketStream.open(file)
local Session = require 'nvim.session'
local session = Session.new(socket_stream)

vim = {
  eval = function (expression)
    local ok, res = session:request('nvim_eval', expression)
    print('.............evaluation: ' .. expression)
    print(ok)
    if type(res) == "number" then
      res = math.floor(res)
    end
    print(res)
    print ('............evaluated.')
    return res
  end,
  command = function (expression)
    print(':' .. expression)
    local ok = session:request('nvim_command', expression)
    print(ok)
    print ('............command Done.')
  end,
  buffer = function ()
    print('   buffer: ')

    local ok, current_buffer = session:request('nvim_get_current_buf')
    local ok, fname = session:request('nvim_buf_get_name', current_buffer)
    local ok, line_count = session:request('nvim_buf_line_count', current_buffer)
    local ok, lines = session:request('nvim_buf_get_lines', current_buffer, 0, line_count, 0)
    local ok, number = session:request('nvim_eval', 'bufnr(\'%\')')

    local result = lines
    result.fname = fname
    result.number = number
    return result;
  end
}

local ok, res = session:request('vim_get_api_info')
local channel_id, _ = unpack(res)

-- set channel on nvim buffer
print( "let g:lua_channel = " .. math.floor(channel_id))
vim.command( "let g:lua_channel = " .. math.floor(channel_id))

function setup()
  package.cpath = vim.eval("$VIMHOME") .. "/color_coded.so"
  local loaded = pcall(require, "color_coded")
  if not loaded then
    vim.command('echohl WarningMsg | ' ..
    'echomsg "color_coded unavailable: you need to compile it ' ..
    '(see README.md)" | ' ..
    'echohl None')
    vim.command("let s:color_coded_valid = 0")
    return
  else
    local version = color_coded_api_version()
    print(version)
    local val = vim.eval("g:color_coded_api_version")
    print(val)
    if version ~= math.floor(val) then
      vim.command( 'echohl WarningMsg | ' ..
      'echomsg "color_coded has been updated: you need to recompile it ' ..
      '(see README.md)" | ' ..
      'echohl None')
      vim.command("let s:color_coded_valid = 0")
    end
  end
end

setup()

function color_coded_buffer_name()
  local name = vim.buffer().fname
  if (name == nil or name == '') then
    name = tostring(vim.buffer().number)
  end
  return name
end

function color_coded_buffer_details()
  local line_count = #vim.buffer()
  local buffer = vim.buffer()
  local data = {}
  for i = 1,#buffer do
    -- NOTE: buffer is a userdata; must be copied into array
    data[i] = buffer[i]
  end
  return color_coded_buffer_name(), table.concat(data, '\n')
end


function push()
  local name, data = color_coded_buffer_details()
  color_coded_push(name, vim.eval('&ft'), data)
end

function pull()
  local name = color_coded_buffer_name()
  color_coded_pull(name)
end

function moved()
  local name = color_coded_buffer_name()
  color_coded_moved(name, vim.eval("line(\"w0\")"), vim.eval("line(\"w$\")"))
end

function enter()
  local name, data = color_coded_buffer_details()
  color_coded_enter(name, vim.eval('&ft'), data)
end

function destroy()
  color_coded_destroy(color_coded_buffer_name())
end

function exit()
  color_coded_exit()
end

function last_error()
  vim.command(
    "echo \"" .. string.gsub(color_coded_last_error(), "\"", "'") ..  "\""
  )
end

function test()
  session:request('nvim_command', "call color_coded#add_match('NamespaceRef', 11, 22, 3)")
end

function get_buffer_name()
  local name = color_coded_buffer_name()
  vim.command("let g:file = '" .. name .. "'")
  return name
end

session:run(
function (command, args)
  print('>>>>>>>>>>>>   ', command)
  call = loadstring(command)
  call()
  return 0
end,
_, _)
