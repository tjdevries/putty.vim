let s:p_obj = get(s:, 'p_obj', {
      \ 'commands_sent': 0,
      \ 'current_channel': v:null,
      \ 'channels': {}
      \ })

function! s:p_obj.reset() abort dict
  let self.current_channel = v:null
  let self.channels = {}
endfunction

function! s:p_obj.set_current_channel(conn) abort dict
  let self.current_channel = a:conn
endfunction

function! s:p_obj.new_channel(conn, id, set_current) abort dict
  let self.channels[a:conn] = {
        \ 'job_id': a:id,
        \ 'buffer_id': -1,
        \ 'results': [],
        \ 'buffered_line': '',
        \ 'active': v:true,
        \ }

  if a:set_current
    call s:p_obj.set_current_channel(a:conn)
  endif
endfunction

function! s:p_obj.close_channel(conn) abort dict
  if self.get_job_id(a:conn) > 0
    call jobclose(self.get_job_id(a:conn))

    silent! unlet self.channels[a:conn]
  endif

  if self.current_channel == a:conn
    let self.current_channel = v:null
  endif
endfunction

function! s:p_obj.get_job_id(conn) abort dict
  return has_key(self.channels, a:conn) ?
        \ self.channels[a:conn].job_id
        \ : -1
endfunction

function! s:p_obj.set_buffer(conn, buffer_id) abort dict
  if has_key(self.channels, a:conn)
    let self.channels[a:conn].buffer_id = a:buffer_id
  else
    throw "[Putty.SetBuffer] No Channel: " . a:conn
  endif
endfunction

function! s:p_obj.get_buffer(conn) abort dict
  return has_key(self.channels, a:conn) ?
        \ self.channels[a:conn].buffer_id
        \ : -1
endfunction

function! s:p_obj.set_result(conn, res) abort dict
  if !has_key(self.channels, a:conn)
    return
  endif

  let result = a:res
  if type(result) != v:t_list
    let result = [result]
  endif

  let self.channels[a:conn].results = result
endfunction

function! s:p_obj.append_result(conn, res) abort dict
  if !has_key(self.results, a:conn)
    let self.channels[a:conn].results = []
  endif

  let result = a:res
  if type(result) != v:t_list
    let result = [result]
  endif

  call extend(self.channels[a:conn].results, result)
endfunction

function! s:p_obj.get_result(conn) abort dict
  if !has_key(self.channels, a:conn)
    return []
  endif

  return self.channels[a:conn].results
endfunction

function! s:p_obj.set_buffered_line(conn, buffered_line) abort
  let self.channels[a:conn].buffered_line = a:buffered_line
endfunction

function! s:p_obj.get_buffered_line(conn) abort
  return self.channels[a:conn].buffered_line
endfunction


""
" open a putty window
" @param[optional] (dictionary) login_options: Options to login:
"   'connection_info': user@host
" @param[optional] (dictionary) display_options: The options to pass to putty#open_display
function! putty#open(...) abort
  let login_options = {}
  if a:0 > 0
    let login_options = a:1
  endif

  if has_key(login_options, 'connection_info')
    let connection_info = login_options.connection_info
  else
    let username = input('Username: ')
    let host = input('Host: ')
    let connection_info = username . '@' . host
  endif

  let display_options = putty#configuration#get('defaults', 'window_options')
  if a:0 > 1
    let display_options = a:2
  endif

  call putty#close(connection_info)

  let job_id = jobstart(
        \ [putty#configuration#get('defaults', 'plink_location'),
          \ '-batch',
          \ '-pw', inputsecret(printf('logging in pw for %s: ', connection_info)),
          \ connection_info
          \ ],
        \ {
          \ 'on_stdout': { id, data, event -> putty#display(connection_info, data, event)},
          \ 'on_stderr': { id, data, event -> putty#display(connection_info, data, event)},
          \ }
        \ )

  call s:p_obj.new_channel(connection_info, job_id, v:true)
  call putty#open_display(connection_info, display_options)

  return connection_info
endfunction

""
" Close a putty window
function! putty#close(connection_info) abort
  call s:p_obj.close_channel(a:connection_info)
endfunction

""
" Send info to my putty
" @param[optional] opts.connection_info (string): The user@host combination that we're connectioned to
" @param[optional] opts.clear_display (boolean): Clear the display before sending
" @param[optional] opts.clear_history (boolean): Clear the last result we've gotten
" @param[optional] opts.carriage_return (string): The string we want to send as a carraige return
function! putty#send(text, ...) abort
  let s:p_obj.commands_sent = get(s:p_obj, 'commands_sent', 0) + 1
  let opts = a:0 > 0 ? a:1 : {}

  " Check to make sure we have valid keys.
  " This prevents us from making sad typos
  let allowed_items = [
        \ 'connection_info',
        \ 'clear_display',
        \ 'clear_history',
        \ 'carriage_return',
        \ ]

  for key in keys(opts)
    if index(allowed_items, key) < 0
      throw '[PUTTY] Key "' . key . '" is not allowed'
    endif
  endfor

  let connection_info = get(opts, 'connection_info', s:p_obj.current_channel)

  let channel_id = s:p_obj.get_job_id(connection_info)
  let clear_display = get(opts, 'clear_display', v:false)
  let carriage_return = get(opts, 'carriage_return', "\<CR>")

  if clear_display || get(opts, 'clear_history', v:false)
    call putty#set_last_result(connection_info, [])
  endif


  if channel_id < 0
    echom "[PUTTY] Initializing connection. No previous connection for " . connection_info
    let connection_info = putty#open({'connection_info': connection_info})
  endif

  if clear_display
    call putty#clear(connection_info)
  endif

  call std#window#view(s:p_obj.get_buffer(connection_info))
  call jobsend(s:p_obj.get_job_id(connection_info), a:text . carriage_return)

  " This just gives us a little time to get the response
  " before we go ahead and do anything else.
  " You might sometimes still have to put in "sleep ..." in your code.
  call putty#wait()
endfunction


""
" Open the display if it's not there
function! putty#open_display(...) abort
  let connection_info = a:0 > 0 ? a:1 : s:p_obj.current_channel

  let opts = putty#configuration#get('defaults', 'window_options')
  if a:0 > 1
    let opts = a:2
  endif

  if s:p_obj.get_buffer(connection_info) < 0
    let new_buffer = std#window#temp(opts)

    call s:p_obj.set_buffer(connection_info, new_buffer)
    call nvim_buf_set_name(
          \ new_buffer,
          \ printf('[Putty Results] %s (%s)', connection_info, new_buffer))

    " If we can escape ansi items, do it
    if exists(':AnsiEsc')
      :AnsiEsc
    endif
  endif
endfunction

""
" Display function
"
" @param id: Actually the connection information
function! putty#display(id, data, event) abort
  call putty#open_display(a:id)

  let new_line_marker = putty#configuration#get('terminal', 'new_line_marker')

  " Join all the lines together
  let all_lines = join(a:data)

  " See if we need to buffer the lines at all
  let buffer_output = v:false
  if all_lines[len(all_lines) - 1] != new_line_marker
    let buffer_output = v:true
  endif

  " Get the lines back, with the newline marker
  let lines = split(all_lines, new_line_marker, v:true)

  " Prepend any buffered output that we had before
  let lines[0] = s:p_obj.get_buffered_line(a:id) . lines[0]

  " If we need to buffer anything, go ahead and do it.
  " Remove the last line
  if buffer_output
    call s:p_obj.set_buffered_line(a:id, remove(lines, -1))
  else
    call s:p_obj.set_buffered_line(a:id, '')
  endif

  " Post process the lines
  for index in range(0, len(lines) - 1)
    " Clear the white space at the end of lines
    let lines[index] = substitute(lines[index], '\s*$', '', 'g')
  endfor

  call nvim_buf_set_lines(s:p_obj.get_buffer(a:id),  -1, -1, v:false, lines)

  call extend(putty#get_last_result(a:id), lines)
endfunction

""
" Clear the display
function! putty#clear(conn) abort
  call putty#open_display(a:conn)

  if s:p_obj.get_buffer(a:conn) > 0
    call nvim_buf_set_lines(s:p_obj.get_buffer(a:conn), 0, -1, v:false, [])
  endif
endfunction

" TODO: Need to change these to be able to be multiplexed
""
" Get last result
function! putty#get_last_result(conn) abort
  return s:p_obj.get_result(a:conn)
endfunction

""
" Set last result
function! putty#set_last_result(conn, result) abort
  call s:p_obj.set_result(a:conn, a:result)
endfunction

""
" Wait the default amount of time
function! putty#wait() abort
  call execute('sleep ' . putty#configuration#get('defaults', 'wait_time'))
endfunction

""
" Get session object
function! putty#get_session_object() abort
  return s:p_obj
endfunction

""
" Get the job_id for a connection
function! putty#get_job_id(conn) abort
  return s:p_obj.get_job_id(a:conn)
endfunction

""
" get the buffer_id for a connection
function! putty#get_buffer_id(conn) abort
  return s:p_obj.get_buffer(a:conn)
endfunction

function! putty#reset() abort
  for conn in keys(s:p_obj.channels)
    " Might already be closed
    silent! call putty#close(conn)
  endfor

  " Just in case, clear everything
  call s:p_obj.reset()
endfunction
