" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Load Once {{{
if (exists('g:loaded_scratch_saver') && g:loaded_scratch_saver) || &cp
    finish
endif
let g:loaded_scratch_saver = 1
" }}}
" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}


augroup scratch-saver
    autocmd!
    autocmd VimEnter * call scratch_saver#prompt_if_force_quit()
    autocmd VimEnter * call scratch_saver#create_lock_file()
    autocmd VimLeave * call scratch_saver#quit_gracefully()
augroup END


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
