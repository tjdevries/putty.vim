
""
" open a putty window
" @param[optional] (dictionary) login_options: Options to login:
"   'username'
"   'host'
" @param[optional] (dictionary) display_options: The options to pass to putty#open_display
function! putty#open(...) abort
  let login_options = {}
  if a:0 > 0
    let login_options = a:1
  endif

  if has_key(login_options, 'username')
    let username = login_options.username
  else
    let username = input('Username: ')
  endif

  if has_key(login_options, 'host')
    let host = login_options.host
  else
    let host = input('Host: ')
  endif

  let display_options = g:putty_default_window_options
  if a:0 > 1
    let display_options = a:2
  endif

  call putty#close()
  call putty#open_display(display_options)

  let g:putty_job_id = jobstart(
        \ [g:putty_default_plink_location, '-pw', inputsecret('logging in pw: '), username . '@' . host],
        \ {
          \ 'on_stdout': { id, data, event -> putty#display(id, data, event)},
          \ 'on_stderr': { id, data, event -> putty#display(id, data, event)},
          \ }
        \ )

  return g:putty_job_id
endfunction

""
" Close a putty window
function! putty#close() abort
  if exists('g:putty_job_id')
    try
      call jobclose(g:putty_job_id)
    catch
    endtry
  endif

  let g:putty_job_id = -1

  call putty#clear()
endfunction

""
" Send info to my putty
" TODO: Change the carriage_return thing
function! putty#send(text, ...) abort
  let carriage_return = "\<CR>"
  if a:0 > 0
    let carriage_return = a:1
  endif

  let clear_display = v:false
  if a:0 > 1
    let clear_display = a:2
    if clear_display
      call putty#set_last_result([])
    endif
  endif

  if a:0 > 2
    call putty#set_last_result([])
  endif


  if !exists('g:putty_job_id') || g:putty_job_id == -1
    echom "[PUTTY] THIS SHOULD NOT BE HAPPENING"
    call putty#open()
  endif

  if clear_display
    call putty#clear()
  endif

  call std#window#view(g:putty_buffer_id)
  call jobsend(g:putty_job_id, a:text . carriage_return)

  " This just gives us a little time to get the response
  " before we go ahead and do anything else.
  " You might sometimes still have to put in "sleep ..." in your code.
  call putty#wait()
endfunction


""
" Open the display if it's not there
function! putty#open_display(...) abort
  let opts = get(g:, 'putty_default_window_options', {})
  if a:0 > 0
    let opts = a:1
  endif

  if !exists('g:putty_buffer_id') || g:putty_buffer_id == -1
    call std#window#temp(opts)

    let g:putty_buffer_id = nvim_buf_get_number(0)
    call nvim_buf_set_name(g:putty_buffer_id, '[Putty Results]' . g:putty_buffer_id)

    " If we can escape ansi items, do it
    if exists(':AnsiEsc')
      :AnsiEsc
    endif
  endif
endfunction

""
" Display function
function! putty#display(id, data, event) abort
  call putty#open_display()

  " Get rid of ugly line indexes
  for index in range(len(a:data))
    let a:data[index] = substitute(a:data[index], "", '', 'g')
  endfor

  " call nvim_buf_set_lines(g:putty_buffer_id,  0, -1, v:false, [])
  call nvim_buf_set_lines(g:putty_buffer_id,  -1, -1, v:false, a:data)

  call extend(putty#get_last_result(), a:data)
endfunction

""
" Clear the display
function! putty#clear() abort
  call putty#open_display()

  if g:putty_buffer_id > 0
    call nvim_buf_set_lines(g:putty_buffer_id, 0, -1, v:false, [])
  endif
endfunction

""
" Get last result
function! putty#get_last_result() abort
  return get(g:, '_putty_last_result', [])
endfunction

""
" Set last result
function! putty#set_last_result(result) abort
  let g:_putty_last_result = a:result
endfunction

""
" Wait the default amount of time
" set by g:putty_default_wait_timj
function! putty#wait() abort
  call execute('sleep ' . g:putty_default_wait_time)
endfunction
