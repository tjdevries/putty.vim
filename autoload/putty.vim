let s:p_obj = {
      \ 'channel_id': v:null,
      \ }


function! s:p_obj.set_channel(id) abort dict
  let self.channel_id = a:id
endfunction

function! s:p_obj.get_channel() abort dict
  return self.channel_id
endfunction

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

  let display_options = putty#configuration#get('defaults', 'window_options')
  if a:0 > 1
    let display_options = a:2
  endif

  call putty#close()
  call putty#open_display(display_options)

  let g:putty_job_id = jobstart(
        \ [putty#configuration#get('defaults', 'plink_location'),
          \ '-batch',
          \ '-pw', inputsecret(printf('logging in pw for %s@%s: ', username, host)),
          \ username . '@' . host
          \ ],
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
" @param[optional] clear_display (boolean): Clear the display before sending
" @param[optional] clear_result (boolean): Clear the last result we've gotten
" @param[optional] carriage_return (string): The string we want to send as a
"       carraige return
function! putty#send(text, ...) abort
  let opts = a:0 > 0 ? a:1 : {}

  " Check to make sure we have valid keys.
  " This prevents us from making sad typos
  let allowed_items = ['channel_id', 'clear_display', 'clear_history', 'carriage_return']
  for key in keys(opts)
    if index(allowed_items, key) < 0
      throw '[PUTTY] Key "' . key . '" is not allowed'
    endif
  endfor

  let channel_id = get(opts, 'channel_id', p_obj.get_channel())
  let clear_display = get(opts, 'clear_display', v:false)
  let carriage_return = get(opts, 'carriage_return', "\<CR>")

  if clear_display || get(opts, 'clear_history', v:false)
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
    " let a:data[index] = index . ':  ' . a:data[index]
  endfor

  " TODO: Buffer lines that aren't really finished

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
function! putty#wait() abort
  call execute('sleep ' . putty#configuration#get('defaults', 'wait_time'))
endfunction
