" Self-test: loads the plugin from this repository and checks it on
" sample/example.msg.  Run from the repository folder:
"
"     vim -Nu NONE -i NONE -es -S test/smoke.vim
"
" Prints PASS/FAIL lines and exits with status 1 if anything failed.

let s:root = fnamemodify(expand('<sfile>:p'), ':h:h')
let &runtimepath = s:root . ',' . &runtimepath
filetype plugin on
syntax on
set encoding=utf-8

let s:out = []
let s:failed = 0
function! s:Check(name, ok, ...) abort
  call add(s:out, (a:ok ? 'PASS  ' : 'FAIL  ') . a:name . (a:0 ? '  (' . a:1 . ')' : ''))
  if !a:ok | let s:failed += 1 | endif
endfunction

execute 'edit ' . fnameescape(s:root . '/sample/example.msg')

call s:Check('filetype detected', &filetype ==# 'abaqusmsg', &filetype)
call s:Check('mixed CRLF/LF re-read as dos', &fileformat ==# 'dos' && !search("\r$", 'nw'), &fileformat)
call s:Check('buffer not modified', !&modified)
call s:Check('syntax loaded', get(b:, 'current_syntax', '') ==# 'abaqusmsg')

let s:l = search('ATTEMPT NUMBER  2', 'nw')
call s:Check('retried attempt highlighted',
      \ s:l > 0 && synIDattr(synID(s:l, match(getline(s:l), 'ATTEMPT') + 1, 1), 'name') ==# 'abaqusmsgRetry')
let s:l = search('EQUILIBRIUM NOT ACHIEVED', 'nw')
call s:Check('failed check highlighted',
      \ s:l > 0 && synIDattr(synID(s:l, match(getline(s:l), 'EQUIL') + 1, 1), 'name') ==# 'abaqusmsgBad')
let s:l = search('LARGEST SCALED RESIDUAL FORCE', 'nw')
call s:Check('node number is a separate token',
      \ s:l > 0 && synIDattr(synID(s:l, match(getline(s:l), 'NODE\s\+\zs\d') + 1, 1), 'name') ==# 'abaqusmsgNode')

call s:Check('folding enabled', &foldmethod ==# 'expr')
let s:inc = search('INCREMENT\s\+1 STARTS', 'nw')
call s:Check('fold text summarises attempt', foldtextresult(s:inc) =~# 'INCREMENT\s\+1\s\+attempt 1 .* cut back',
      \ foldtextresult(s:inc))

let s:inc2 = search('INCREMENT\s\+2 STARTS', 'nw')
execute s:inc2 . 'foldopen'
edit
call s:Check('open fold survives :e', foldclosed(s:inc2) == -1 && foldclosed(s:inc) == s:inc,
      \ foldclosed(s:inc2))

AbaqusIncrements
call s:Check(':AbaqusIncrements lists 4 attempts', len(getloclist(0)) == 4, len(getloclist(0)))
lclose
AbaqusProblems
call s:Check(':AbaqusProblems finds problems', len(getloclist(0)) > 0, len(getloclist(0)))
lclose

call cursor(1, 1)
normal 2]]
call s:Check(']] jumps to increment starts', getline('.') =~# 'ATTEMPT NUMBER  2', line('.'))

setlocal filetype=text
call s:Check('undo_ftplugin removes mappings', empty(maparg(']]', 'n')))

call add(s:out, s:failed ? printf('%d check(s) FAILED', s:failed) : 'All checks passed.')
for s:line in s:out
  verbose echo s:line
endfor
execute (s:failed ? 'cquit' : 'qall!')
