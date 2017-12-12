" pim global plugin for semantic highlighting using libclang
" Maintainer:	Jeaye <contact@jeaye.com>

" Setup
" ------------------------------------------------------------------------------

let s:color_coded_api_version = 0xba89eb5
let g:color_coded_api_version = s:color_coded_api_version
let s:color_coded_valid = 1
let s:color_coded_unique_counter = 1
let g:color_coded_matches = {}

function! s:color_coded_create_defaults()
  if !exists("g:color_coded_filetypes")
    let g:color_coded_filetypes = ['c', 'cc', 'cpp', 'objc']
  endif
endfunction!


function! color_coded#setup()
  " Lua is prepared, finish setup
  call s:color_coded_create_defaults()

  return s:color_coded_valid
endfunction!

" Events
" ------------------------------------------------------------------------------

function! color_coded#push()
  if index(g:color_coded_filetypes, &ft) < 0 || g:color_coded_enabled == 0
    return
  endif
  call rpcrequest(g:lua_channel, "push()")
endfunction!

function! color_coded#pull()
  if index(g:color_coded_filetypes, &ft) < 0 || g:color_coded_enabled == 0
    return
  endif
  call rpcrequest(g:lua_channel, "pull()")
endfunction!

function! color_coded#moved()
  if index(g:color_coded_filetypes, &ft) < 0 || g:color_coded_enabled == 0
    return
  endif
  call rpcrequest(g:lua_channel, "moved()")
endfunction!

function! color_coded#enter()
  if index(g:color_coded_filetypes, &ft) < 0 || g:color_coded_enabled == 0
    return
  endif

  " Each new window controls highlighting separate from the buffer
  if !exists("w:color_coded_own_syntax") || w:color_coded_name != color_coded#get_buffer_name()
    " Preserve spell after ownsyntax clears it
    let s:keepspell = &spell
      if has('b:current_syntax')
        execute 'ownsyntax ' . b:current_syntax
      else
        execute 'ownsyntax ' . &ft
      endif
      let &spell = s:keepspell
    unlet s:keepspell

    let w:color_coded_own_syntax = 1

    " Each window has a unique ID
    let w:color_coded_unique_counter = s:color_coded_unique_counter
    let s:color_coded_unique_counter += 1

    " Windows can be reused; clear it out if needed
    if exists("w:color_coded_name")
      call color_coded#clear_matches(w:color_coded_name)
    endif
    let w:color_coded_name = color_coded#get_buffer_name()
    call color_coded#clear_matches(w:color_coded_name)
  endif

  call rpcrequest(g:lua_channel, "enter()")
endfunction!

function! color_coded#destroy()
  if index(g:color_coded_filetypes, &ft) < 0 || g:color_coded_enabled == 0
    return
  endif
  call rpcrequest(g:lua_channel, "destroy()")

  call color_coded#clear_matches(color_coded#get_buffer_name())
endfunction!

function! color_coded#exit()
  if g:color_coded_enabled == 0
    return
  endif
  call rpcrequest(g:lua_channel, "exit()")
endfunction!

" Commands
" ------------------------------------------------------------------------------

function! color_coded#last_error()
  call rpcrequest(g:lua_channel, "last_error()")
endfunction!

function! color_coded#toggle()
  let g:color_coded_enabled = g:color_coded_enabled ? 0 : 1
  if g:color_coded_enabled == 0
    call color_coded#clear_all_matches()
    echo "color_coded: disabled"
  else
    call color_coded#enter()
    echo "color_coded: enabled"
  endif
endfunction!

" Utilities
" ------------------------------------------------------------------------------

" We keep two sets of buffer names right now
" 1) Lua's color_coded_buffer_name
"   - Just the filename or buffer number
"   - Used for interfacing with C++
" 2) VimL's color_coded#get_buffer_name
"   - A combination of 1) and a unique window counter
"   - Used for storing per-window syntax matches
function! color_coded#get_buffer_name()
  call rpcrequest(g:lua_channel, "get_buffer_name()")
  if exists("w:color_coded_unique_counter")
    return g:file . w:color_coded_unique_counter
  else
    return g:file
  endif
endfunction!

function! color_coded#add_match(type, line, col, len)
  let g:file = color_coded#get_buffer_name()
  call add(g:color_coded_matches[g:file],
          \matchaddpos(a:type, [[ a:line, a:col, a:len ]], -1))
  unlet g:file
  return
endfunction!

" Clears color_coded matches only in the current buffer
function! color_coded#clear_matches(file)
  try
    if has_key(g:color_coded_matches, a:file) == 1
      for id in g:color_coded_matches[a:file]
        call matchdelete(id)
      endfor
    endif
  catch
    echomsg "color_coded caught: " . v:exception
  finally
    let g:color_coded_matches[a:file] = []
  endtry
endfunction!

" Clears color_coded matches in all open buffers
function! color_coded#clear_all_matches()
  let g:color_coded_matches = {}
endfunction!
