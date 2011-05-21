" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}



" TODO: Use v:servername instead of pid?
if !exists('g:scratch_saver#lock_file')
    let g:scratch_saver#lock_file = '~/.vim/info/scratch_saver.${pid}.lock'
endif
if !exists('g:scratch_saver#open_command')
    let g:scratch_saver#open_command = 'vnew'
endif


let s:V = vital#of('scratch_saver').load('String')


function! scratch_saver#load()
    " dummy function to load this script.
endfunction


function! scratch_saver#prompt_if_force_quit()
    let pids = s:get_crashed_pids()
    " Delete empty lock files.
    " (certainly it's crash but it's not harmful
    " because there were no unsaved buffer)
    let empty_pids = copy(pids)    " Copy to not skip element when :unlet pids[i] occured.
    for i in range(len(empty_pids))
        let pid = empty_pids[i]
        let empty_lock_file = s:get_lock_file_by_pid(pid)
        if s:is_empty_file(empty_lock_file)
            try
                call delete(empty_lock_file)
            catch
                call s:echomsg('WarningMsg',
                \   "Can't delete an empty lock file '"
                \   . empty_lock_file . "'.")
            endtry
        else
            " Remove from original list to
            " not skip an element incorrectly.
            unlet pids[i]
        endif
    endfor
    if empty(pids)
        return
    endif

    " Found unsaved buffer(s)!
    try
        call s:open_buffer()
        call s:write_list_to_buffer(pids)
    catch
        call s:echomsg('WarningMsg',
        \   'fatal: Detected crash but'
        \   . ' Could not create a buffer to restore...'
        \   . ' v:throwpoint = '.v:throwpoint
        \   . ', v:exception = '.v:exception)
    endtry
endfunction

function! s:is_empty_file(file)
    try   | let lines = readfile(a:file)
    catch | let lines = [] | endtry
    return empty(lines)
endfunction

" Return empty list for ERROR.
function! s:get_crashed_pids()
    " Return true when discovered lock file whose process is dead.
    let pids = []
    let ERROR = -1
    for lock_file in s:get_all_lock_files()
        let pid = s:get_pid_by_lock_file(lock_file, ERROR)
        if pid ># 0 && !s:process_is_running(pid)
            call add(pids, pid)
        endif
    endfor
    return pids
endfunction

let s:openbuf = {}
function! s:open_buffer()
    if empty(s:openbuf)
        let s:openbuf = openbuf#new('scratch_saver')
    endif
    " s:openbuf.open() throws an exception
    " if something is wrong.
    call s:openbuf.open({
    \   'bufname': '__scratch_saver__',
    \   'opener': g:scratch_saver#open_command,
    \   'silent': 1,
    \})
endfunction

function! s:write_list_to_buffer(pids)
    let messages = [
    \   "scratch_saver.vim detected crash!",
    \   "(PID: ".join(a:pids, ',').")",
    \   "want to restore unsaved buffer?",
    \   "",
    \]
    for pid in a:pids
        let lock_file = s:get_lock_file_by_pid(pid)
        call setline(1,
        \   messages
        \   + ["Unsaved buffer:"]
        \   + readfile(lock_file))
    endfor
endfunction

function! scratch_saver#create_lock_file()
    " Create lock file.
    " Lock file should not exist here.
    let lock_file = s:get_lock_file()
    if getftype(lock_file) !=# ''
        call s:echomsg('WarningMsg',
        \   "the path '" . lock_file . "'exists.")
        return
    endif

    " Okay, the path does not exist and is not a file.
    let dir = s:get_lock_dir()
    try | call mkdir(dir, 'p') | catch | endtry
    if !isdirectory(dir)
        call s:echomsg('WarningMsg',
        \   "scratch_saver: Could not create"
        \   . " lock file directory.")
        return
    endif

    try
        call writefile([], lock_file)
    catch
        call s:echomsg('WarningMsg',
        \   "scratch_saver: Could not create lock file: "
        \   . v:exception)
    endtry
endfunction

function! scratch_saver#quit_gracefully()
    " Delete lock file.
    let lock_file = s:get_lock_file()
    if filereadable(lock_file)
        try
            call delete(lock_file)
        catch
            call s:echomsg('WarningMsg',
            \   "scratch_saver: Could not delete lock file: "
            \   . v:exception)
        endtry
    endif
endfunction

function! scratch_saver#save_modified_buffers()
    let lock_file = s:get_lock_file()
    call writefile(s:get_modified_buffers(), lock_file)
endfunction

function! s:get_modified_buffers()
    let is_modified =
    \     'getbufvar(v:val, "&buftype") ==# ""'
    \   . ' && '
    \   . 'getbufvar(v:val, "&modified")'
    return filter(s:get_all_buffers(), is_modified)
endfunction

function! s:get_all_buffers()
    " Use tabpagebuflist() to get all buffers to avoid :redir
    let buffers = []
    for nr in range(tabpagenr('$'))
        let buffers += tabpagebuflist(nr + 1)
    endfor
    return buffers
endfunction


function! s:echomsg(hl, msg)
    try
        execute 'echohl' a:hl
        echomsg a:msg
    finally
        echohl None
    endtry
endfunction

function! s:get_lock_file()
    return s:V.String.replace(
    \   expand(g:scratch_saver#lock_file),
    \   '${pid}',
    \   getpid())
endfunction

function! s:get_lock_dir()
    return fnamemodify(s:get_lock_file(), ':p:h')
endfunction

function! s:get_all_lock_files()
    return split(glob(s:get_lock_dir() . '/*'), '\n')
endfunction

function! s:get_pid_by_lock_file(lock_file, error)
    let [left, right] = s:V.String.divide_leftright(
    \   expand(g:scratch_saver#lock_file),
    \   '${pid}'
    \)
    if stridx(a:lock_file, left) !=# 0
        return a:error
    endif
    let pid = a:lock_file
    let pid = empty(left)  ? pid : pid[strlen(left) :]
    let pid = empty(right) ? pid : pid[: strlen(pid) - strlen(right) - 1]
    let positive_number = '^[1-9][0-9]*$'
    return pid =~# positive_number ? pid + 0 : a:error
endfunction

function! s:get_lock_file_by_pid(pid)
    let [left, right] = s:V.String.divide_leftright(
    \   expand(g:scratch_saver#lock_file),
    \   '${pid}'
    \)
    return left . a:pid . right
endfunction

function! s:process_is_running(pid)
    try   | return vimproc#kill(a:pid, 0) ==# 0
    catch | return 0 | endtry
endfunction


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
