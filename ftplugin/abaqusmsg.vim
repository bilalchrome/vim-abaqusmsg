" Filetype plugin for Abaqus message files: folding, motions, overviews.

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = 'setlocal foldmethod< foldexpr< foldtext< foldlevel< foldenable< autoread<'
      \ . ' | silent! call abaqusmsg#Follow(1)'

" ----------------------------------------------------------------- folding
" One fold per step, one nested fold per increment attempt. The closed fold
" text summarises the attempt: increment, attempt, dt, converged or cut back,
" number of iterations, warnings, and the reason for failure.
if get(g:, 'abaqusmsg_folding', 1) && line('$') <= get(g:, 'abaqusmsg_fold_max_lines', 3000000)
  setlocal foldmethod=expr
  setlocal foldexpr=abaqusmsg#FoldExpr(v:lnum)
  setlocal foldtext=abaqusmsg#FoldText()
  let &l:foldlevel = get(g:, 'abaqusmsg_foldlevel', 1)
  setlocal foldenable
endif

" ----------------------------------------------------------------- motions
if !get(g:, 'abaqusmsg_no_mappings', 0)
  let s:maps = [
        \ [']]', '[[', 'increment'],
        \ [']a', '[a', 'retry'],
        \ [']S', '[S', 'step'],
        \ [']w', '[w', 'message'],
        \ [']e', '[e', 'error'],
        \ [']x', '[x', 'failed'],
        \ [']d', '[d', 'diverging'],
        \ ]
  for [s:fwd, s:bwd, s:name] in s:maps
    for s:mode in ['n', 'x', 'o']
      let s:vis = s:mode ==# 'x' ? 1 : 0
      execute printf('%snoremap <silent> <buffer> %s :<C-U>call abaqusmsg#Jump(%s, 0, %d)<CR>', s:mode, s:fwd, string(s:name), s:vis)
      execute printf('%snoremap <silent> <buffer> %s :<C-U>call abaqusmsg#Jump(%s, 1, %d)<CR>', s:mode, s:bwd, string(s:name), s:vis)
      " no space before '|': map commands would include it in the {lhs}
      let b:undo_ftplugin .= printf('|silent! %sunmap <buffer> %s|silent! %sunmap <buffer> %s', s:mode, s:fwd, s:mode, s:bwd)
    endfor
  endfor
  unlet s:maps s:fwd s:bwd s:name s:mode s:vis
endif

" ----------------------------------------------------------------- commands
command! -buffer AbaqusIncrements call abaqusmsg#Increments()
command! -buffer -bang AbaqusProblems call abaqusmsg#Problems(<bang>0)
command! -buffer -bang AbaqusFollow call abaqusmsg#Follow(<bang>0)
let b:undo_ftplugin .= '|delcommand AbaqusIncrements | delcommand AbaqusProblems'
      \ . ' | delcommand AbaqusFollow'

let &cpo = s:cpo_save
unlet s:cpo_save
