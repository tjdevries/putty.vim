""
" Configuration options for PUTTY
let s:plugin_configuration = {
      \ 'defaults': {
        \ 'plink_location': 'C:\Program Files (x86)\PuTTY\plink.exe',
        \ 'window_options': {'filetype': 'lookitt', 'concealcursor': 'n'},
        \ 'wait_time': '10m',
        \ },
      \ }

function! putty#configuration#get(area, setting) abort
  let config_area = has_key(s:plugin_configuration, a:area) ?
    \ s:plugin_configuration[a:area] :
    \ execute(printf(
      \ 'throw "[PUTTY]. No key ''%s''"', a:area
      \ ))

  return has_key(config_area, a:setting) ?
    \ config_area[a:setting] :
    \ execute(printf('throw "[PUTTY]. No setting ''%s'' for area ''%s''"', a:setting, a:area))
endfunction

function! putty#configuration#set(area, setting, value) abort
  let config_area = has_key(s:plugin_configuration, a:area) ?
    \ s:plugin_configuration[a:area] :
    \ execute(printf(
      \ 'throw "[PUTTY]. No key ''%s''"', a:area
      \ ))

  return has_key(config_area, a:setting) ?
    \ execute('let s:plugin_configuration[a:area][a:setting] = a:value') :
    \ execute(printf('throw "[PUTTY]. No setting ''%s'' for area ''%s''"', a:setting, a:area))
endfunction

function! putty#configuration#view() abort
  return copy(s:plugin_configuration)
endfunction
