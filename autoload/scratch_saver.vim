" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}



if !exists('g:scratch_saver#lock_file')
    let g:scratch_saver#lock_file = '~/.vim/info/scratch_saver.lock'
endif
if !exists('g:scratch_saver#open_command')
    let g:scratch_saver#open_command = 'vnew'
endif


function! scratch_saver#load()
    " dummy function to load this script.
endfunction


function! scratch_saver#prompt_if_force_quit()
    " Show buffer when lock file exists.
    let lock_file = expand(g:scratch_saver#lock_file)
    if !filereadable(lock_file)
        return
    endif

    try
        call s:open_buffer()
        call s:write_list_to_buffer()
    catch
        call s:echomsg('WarningMsg',
        \   'fatal: Detected crash but'
        \   . ' Could not create a buffer to restore...')
    endtry
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

function! s:write_list_to_buffer()
    let messages = [
    \   "scratch_saver.vim detected crash!",
    \   "want to restore unsaved buffer?",
    \   "",
    \]
    let lock_file = expand(g:scratch_saver#lock_file)
    let unsaved_buffer_list = readfile(lock_file)
    call setline(1, messages + unsaved_buffer_list)
endfunction

function! scratch_saver#create_lock_file()
    " Create lock file.
    " Lock file should not exist here.
    let lock_file = expand(g:scratch_saver#lock_file)
    if getftype(lock_file) !=# ''
        call s:echomsg('WarningMsg',
        \   "the path '" . lock_file . "'exists.")
        return
    endif

    " Okay, the path does not exist and is not a file.
    let dir = fnamemodify(lock_file, ':p:h')
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
    let lock_file = expand(g:scratch_saver#lock_file)
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
    let lock_file = expand(g:scratch_saver#lock_file)
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


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
