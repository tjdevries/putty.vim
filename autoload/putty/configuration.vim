""
" Name of the plugin to be used in error messages
let s:plugin_name = 'Putty'

""
" Configuration options for PUTTY
let s:plugin_configuration = {
      \ 'defaults': {
        \ 'plink_location': {
          \ 'type': v:t_string,
          \ 'default': 'C:\Program Files (x86)\PuTTY\plink.exe',
          \ 'description': 'Full path with executable name and extension',
          \ 'validator': {val -> executable(val) },
          \ },
        \ 'window_options': {
          \ 'type': v:t_dict,
          \ 'default': {'filetype': 'lookitt', 'concealcursor': 'n'},
          \ 'description': 'The window options associated with the putty window',
          \ },
        \ 'wait_time': {
          \ 'type': v:t_string,
          \ 'default': '10m',
          \ 'prompt': 'Wait time after sending a message through putty',
          \ },
        \ },
      \ }

" TODO: Change to something like
" call conf#add_area(s:, 'area')
" call conf#add_setting(s:, 'area', 'setting', {})
"
" func p...#get(area, setting) abort
"   return conf#get(s:, a:area, a:setting)
" endfunc
"
" ...

function! putty#configuration#get(area, setting) abort
  let config_area = has_key(s:plugin_configuration, a:area) ?
    \ s:plugin_configuration[a:area] :
    \ execute(printf(
      \ 'throw "[%s]. No key ''%s''"', toupper(s:plugin_name), a:area
      \ ))

  return has_key(config_area, a:setting) ?
    \ config_area[a:setting] :
    \ execute(printf(
      \ 'throw "[%s]. No setting ''%s'' for area ''%s''"', toupper(s:plugin_name), a:setting, a:area
      \ ))
endfunction

function! putty#configuration#set(area, setting, value) abort
  let config_area = has_key(s:plugin_configuration, a:area) ?
    \ s:plugin_configuration[a:area] :
    \ execute(printf(
      \ 'throw "[%s]. No key ''%s''"', toupper(s:plugin_name), a:area
      \ ))

  return has_key(config_area, a:setting) ?
    \ execute('let s:plugin_configuration[a:area][a:setting] = a:value') :
    \ execute(printf(
      \ 'throw "[%s]. No setting ''%s'' for area ''%s''"', toupper(s:plugin_name), a:setting, a:area
      \ ))
endfunction

function! putty#configuration#view() abort
  return copy(s:plugin_configuration)
endfunction

function! putty#configuration#menu() abort
  let s:has_quickmenu = get(s:, 'has_quickmenu', stridx(&runtimepath, 'quickmenu.vim') >= 0)
  if !s:has_quickmenu
    throw '[PUTTY]. Quickmenu.vim required to have menus'
  endif

  call quickmenu#reset()

  call quickmenu#header('[Putty] Configuration Menu')

  for area in keys(s:plugin_configuration)
    " Make a smaller header area for each area
    call quickmenu#append('# ' . area, '')

    for setting in keys(s:plugin_configuration[area])
      " Give the option of a setting for each item:
      call quickmenu#append(
            \ printf('Set: %s.%s', area, setting),
            \ printf('call putty#configuration#set("%s", "%s", input("New Setting: "))', area, setting),
            \ )

    endfor
  endfor

  call quickmenu#toggle(0)
endfunction
