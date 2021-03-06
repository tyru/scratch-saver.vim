let s:base_dir = expand('<sfile>:r')
let s:self_version = expand('<sfile>:t:r')

let s:loaded = {}

function! s:import(name, ...)
  let module = s:_import(a:name, s:_scripts())
  if a:0 && type(a:1) == type({})
    call extend(a:1, module, 'keep')
  endif
  return module
endfunction

function! s:load(...) dict
  let scripts = s:_scripts()
  for name in a:000
    let target = split(name, '\W\+')
    let dict = self
    while 2 <= len(target)
      let ns = remove(target, 0)
      if !has_key(dict, ns)
        let dict[ns] = {}
      endif
      if type(dict[ns]) == type({})
        let dict = dict[ns]
      else
        let target = []
      endif
    endwhile

    if !empty(target) && !has_key(dict, target[0])
      let dict[target[0]] = s:_import(name, scripts)
    endif
  endfor
  return self
endfunction

function! s:_import(name, scripts)
  if type(a:name) == type(0)
    return s:_build_module(a:name)
  endif
  if a:name =~# '^[^A-Z]' || a:name =~# '\W[^A-Z]'
    throw 'vital: module name must start with capital letter: ' . a:name
  endif
  let target = a:name == '' ? '' : '/' . substitute(a:name, '\W\+', '/', 'g')
  let target = substitute(target, '\l\zs\ze\u', '_', 'g') " OrderedSet -> Ordered_Set
  let target = substitute(target, '[/_]\zs\u', '\l\0', 'g') " Ordered_Set -> ordered_set
  let pat = substitute(s:base_dir . target, '[/\\]', '[/\\\\]', 'g') . '\.vim$'
  let sid = 0
  for script in a:scripts
    if script =~? pat
      let sid = matchstr(script, '^\s*\zs\d\+') - 0
      break
    endif
  endfor
  if !sid
    try
      source `=s:base_dir . target . '.vim'`
    catch /^Vim\%((\a\+)\)\?:E484/
      throw 'vital: module not found: ' . a:name
    endtry
    let sid = len(a:scripts) + 1  " We expect that the file newly read is +1.
  endif
  return s:_build_module(sid)
endfunction

function! s:_scripts()
  return split(s:_redir('scriptnames'), "\n")
endfunction

function! s:_build_module(sid)
  if has_key(s:loaded, a:sid)
    return copy(s:loaded[a:sid])
  endif
  let prefix = '<SNR>' . a:sid . '_'
  let funcs = s:_redir('function')
  let filter_pat = '^\s*function ' . prefix
  let map_pat = prefix . '\zs\w\+'
  let functions = map(filter(split(funcs, "\n"), 'v:val =~# filter_pat'),
  \          'matchstr(v:val, map_pat)')

  let module = {}
  for func in functions
    let module[func] = function(prefix . func)
  endfor
  if has_key(module, '_vital_loaded')
    try
      call module._vital_loaded(vital#{s:self_version}#new())
    catch
      " FIXME: Show the error message for debug.
    endtry
  endif
  call filter(module, 'v:key =~# "^\\a"')
  let s:loaded[a:sid] = module
  return copy(module)
endfunction

function! s:_redir(...)
  let temp = tempname()
  let save_vfile = &verbosefile
  let &verbosefile = temp

  let res = ''
  try
    for c in a:000
      silent execute c
    endfor
    if &verbosefile ==# temp
      let &verbosefile = save_vfile
      let res = join(readfile(temp, 'b'), "\n")
    endif
  finally
    call delete(temp)
  endtry
  return res
endfunction

function! vital#{s:self_version}#new()
  let V = s:import('')
  call V.import('Prelude', V)
  return V
endfunction
