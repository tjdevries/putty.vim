""
" Name of the plugin to be used in error messages
call conf#set_name(s:, 'Putty')

""
" Configuration options for PUTTY
call conf#add_area(s:, 'defaults')
call conf#add_setting(s:, 'defaults', 'plink_location', {
        \ 'type': v:t_string,
        \ 'default': 'C:\Program Files (x86)\PuTTY\plink.exe',
        \ 'description': 'Full path with executable name and extension',
        \ 'validator': {val -> executable(val) },
        \ })
call conf#add_setting(s:, 'defaults', 'window_options', {
        \ 'type': v:t_dict,
        \ 'default': {'filetype': 'lookitt', 'concealcursor': 'n'},
        \ 'description': 'The window options associated with the putty window',
        \ })
call conf#add_setting(s:, 'defaults', 'wait_time', {
        \ 'type': v:t_string,
        \ 'default': '10m',
        \ 'description': 'Wait time after sending a message through putty',
        \ })

function! putty#configuration#get(area, setting) abort
  call conf#get_setting(s:, a:area, a:setting)
endfunction

function! putty#configuration#set(area, setting, value) abort
  call conf#set_setting(s:, a:area, a:setting, a:value)
endfunction

function! putty#configuration#view() abort
  return conf#view(s:)
endfunction

function! putty#configuration#menu() abort
  return conf#menu(s:)
endfunction

function! putty#configuration#docs() abort
  return conf#docs#generate(s:)
endfunction
