
""
" open a putty window
function! putty#open() abort
  call putty#close()

  if !exists('g:_my_pw')
    let g:_my_pw = inputsecret('logging in: ')
  endif

  let g:putty_job_id = jobstart(['C:\Program Files (x86)\PuTTY\plink.exe', '-pw', g:_my_pw, 'tdevries@epic-cde'], {
        \ 'on_stdout': { id, data, event -> putty#display(id, data, event)},
        \ 'on_stderr': { id, data, event -> putty#display(id, data, event)},
        \ })
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
endfunction


function! putty#start() abort
  call putty#open()
  call putty#send("epicmenu")
  call putty#send("1")
  call putty#send("dev")
  call putty#send("dev")
  call putty#send("25832")
  call putty#send("epic")
  call putty#send("d ^%ZeW")
endfunction

function! putty#test() abort
  call putty#open()
  call putty#send("epicmenu")
  call putty#send("1")
  call putty#send("dev", "\r")
  call putty#send("dev", "\r")
  call putty#send("25832", "\r")
  call putty#send("epic", "\r")
  call putty#send("d ^%ZeW", "\r")
  call putty#send(";i LPL 325", "\r\n")
  call putty#send(';i LPL 325', "\r", v:true)
  call putty#send(';h LPL 325', "\r")
endfunction

""
" Open the display if it's not there
function! putty#open_display() abort
  if !exists('g:putty_buffer_id') || g:putty_buffer_id == -1
    call std#window#temp({'filetype': 'lookitt', 'concealcursor': 'n'})

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
