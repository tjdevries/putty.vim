let s:p_obj = {
      \ 'current_channel': v:null,
      \ 'active_channels': {},
      \ 'active_buffers': {},
      \ }


function! s:p_obj.new_channel(conn, id, set_current) abort dict
  let self.active_channels[a:conn] = a:id

  if a:set_current
    call s:p_obj.set_current_channel(a:conn)
  endfunction
endfunction

function! s:p_obj.close_channel(conn) abort dict
  if self.get_channel_id(a:conn) > 0
    call jobclose(self.get_channel_id(a:conn))
    unlet self.active_channels[a:conn]
  endif
endfunction

function! s:p_obj.get_channel_id(conn) abort dict
  return has_key(self.active_channels, a:conn) ?
        \ self.active_channels[a:conn]
        \ : -1
endfunction

function! s:p_obj.set_current_channel(conn) abort dict
  let self.current_channel = a:conn
endfunction

function! s:p_obj.get_current_channel_id() abort dict
  return self.get_channel_id(self.current_channel)
endfunction

function! s:p_obj.set_buffer(conn, buffer_id) abort dict
  if self.get_channel_id(a:conn) != -1
    let self.active_buffers[a:conn] = a:buffer_id
  endif
endfunction

function! s:p_obj.get_buffer(conn) abort dict
  return has_key(self.active_buffers, a:conn) ?
        \ self.active_buffers[a:conn]
        \ : -1
endfunction

function! s:p_obj.get_current_buffer() abort dict
  return self.get_buffer(self.current_channel)
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

  let connection_info = username . '@' . host

  let display_options = putty#configuration#get('defaults', 'window_options')
  if a:0 > 1
    let display_options = a:2
  endif

  call putty#close(connection_info)
  call putty#open_display(connection_info, display_options)

  let job_id = jobstart(
        \ [putty#configuration#get('defaults', 'plink_location'),
          \ '-batch',
          \ '-pw', inputsecret(printf('logging in pw for %s: ', connection_info)),
          \ connection_info
          \ ],
        \ {
          \ 'on_stdout': { id, data, event -> putty#display(id, data, event)},
          \ 'on_stderr': { id, data, event -> putty#display(id, data, event)},
          \ }
        \ )

  call s:p_obj.new_channel(connection_info, job_id, v:true)

  return connection_info
endfunction

""
" Close a putty window
function! putty#close(connection_info) abort
  call s:p_obj.close_channel(a:connection_info)
  call putty#clear()
endfunction

""
" Send info to my putty
" @param[optional] opts.connection_info (string): The user@host combination that we're connectioned to
" @param[optional] opts.clear_display (boolean): Clear the display before sending
" @param[optional] opts.clear_result (boolean): Clear the last result we've gotten
" @param[optional] opts.carriage_return (string): The string we want to send as a carraige return
function! putty#send(text, ...) abort
  let opts = a:0 > 0 ? a:1 : {}

  " Check to make sure we have valid keys.
  " This prevents us from making sad typos
  let allowed_items = ['connection_info', 'clear_display', 'clear_history', 'carriage_return']
  for key in keys(opts)
    if index(allowed_items, key) < 0
      throw '[PUTTY] Key "' . key . '" is not allowed'
    endif
  endfor

  let connection_info = get(opts, 'connection_info', v:null)
  let channel_id = connection_info != v:null ?
        \ p_obj.get_channel_id(connection_info)
        \ : p_obj.get_current_channel_id())
  let clear_display = get(opts, 'clear_display', v:false)
  let carriage_return = get(opts, 'carriage_return', "\<CR>")

  if clear_display || get(opts, 'clear_history', v:false)
    call putty#set_last_result([])
  endif


  if channel_id < 0
    echom "[PUTTY] Initializing connection. No previous connection for " . connection_info
    let connection_info = putty#open()
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
  let connection_info = a:0 > 0 ? a:1 : p_obj.current_channel

  let opts = get(g:, 'putty_default_window_options', {})
  if a:0 > 1
    let opts = a:2
  endif

  if s:p_obj.get_buffer(a:connection_info) == -1
    call std#window#temp(opts)

    call s:p_obj.set_buffer(a:connection_info, nvim_buf_get_number(0))
    call nvim_buf_set_name(g:putty_buffer_id, '[Putty Results] ' . connection_info)

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

" TODO: Need to change these to be able to be multiplexed
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
