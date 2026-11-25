" Autoloaded functions for Abaqus message files (filetype abaqusmsg).

let s:save_cpo = &cpo
set cpo&vim

" Patterns shared by folding, motions and overviews
let s:pat = {
      \ 'step':      '^\s*STEP\s\+\d\+\s\+INCREMENT\s\+\d\+\s\+STEP TIME',
      \ 'increment': '^\s*\%(INCREMENT\s\+\d\+\s\+STARTS\.\|CYCLE\s\+\d\+\s\+STARTS:\)',
      \ 'retry':     '^\s*INCREMENT\s\+\d\+\s\+STARTS\. ATTEMPT NUMBER\s\+\%([2-9]\|[1-9]\d\+\)\>',
      \ 'iteration': '^\s*\%(CONVERGENCE CHECKS FOR \u.\{-}ITERATION\s\+\d\+\|SEVERE DISCONTINUITY ITER.*OPENINGS\|ITERATION\s\+\d\+\s\+SUMMARY\)',
      \ 'sdi':       '^\s*\%(CONVERGENCE CHECKS FOR SEVERE DISCONTINUITY ITERATION\|SEVERE DISCONTINUITY ITER\)',
      \ 'message':   '^\s\=\*\*\*\s\=\%(WARNING\|ERROR\|NOTE\):',
      \ 'warning':   '^\s\=\*\*\*\s\=WARNING:',
      \ 'error':     '^\s\=\*\*\*\s\=ERROR:\|^-\+\s*RUNTIME\s\+\w\+\s\+HAS\s\+OCCURR\=ED',
      \ 'failed':    '^\s\+.\{-}\%(NOT \%(YET \)\=ACHIEVED\|TOO LARGE COMPARED TO\|OUTSIDE OF CONVERGENCE\|IS ZERO EVERYWHERE BUT\|ERROR TOO LARGE\|IS DISTORTING EXCESSIVELY\)',
      \ 'diverging': 'THE SOLUTION APPEARS TO BE DIVERGING\|CONVERGENCE IS JUDGED UNLIKELY\|TOO MANY ATTEMPTS\|TIME INCREMENT REQUIRED IS LESS THAN THE MINIMUM\|TOO MANY INCREMENTS NEEDED\|HAS BEEN CUT BACK\|THE NEXT TIME INCREMENT WILL BE REDUCED',
      \ 'done':      '^\s*\%(STEP TIME COMPLETED\|TOTAL ARC LENGTH\)\s',
      \ 'end':       '^\s*THE ANALYSIS HAS \%(NOT \)\=BEEN COMPLETED',
      \ }
" cheap pre-filter: lines without any of these words cannot matter to s:AttemptInfo
let s:prefilter = 'CONVERGENCE CHECKS\|DISCONTINUITY ITER\|\*\*\*\|COMPLETED\|ARC LENGTH\|DIVERG\|UNLIKELY\|TOO MANY\|MINIMUM\|CUT BACK\|REDUCED\|RUNTIME\|SUMMARY'

function! abaqusmsg#Pattern(name) abort
  return s:pat[a:name]
endfunction

" ---------------------------------------------------------------- detect
function! abaqusmsg#Detect() abort
  let head = getline(1, 60)
  let ok = 0
  for l in head
    if l =~# '\<Abaqus\>\|\%(^\s*STEP\s\+\d\+\s\+INCREMENT\)\|S T E P\|A N A L Y S I S'
      let ok = 1
      break
    endif
  endfor
  if !ok
    return
  endif
  " Abaqus on Windows writes CRLF but the equation solver block is LF-only.
  " Vim then picks 'fileformat' unix and every other line ends in ^M.
  " Re-read such files as dos, which accepts both line endings.
  if get(g:, 'abaqusmsg_fix_fileformat', 1) && &fileformat ==# 'unix' && !&modified
        \ && !empty(filter(copy(head), 'v:val =~# "\r$"'))
    silent edit ++ff=dos
  endif
  setfiletype abaqusmsg
endfunction

" ---------------------------------------------------------------- folding
" Level 1: one fold per step (and one for the final summary)
" Level 2: one fold per increment attempt
function! abaqusmsg#FoldExpr(lnum) abort
  let l = getline(a:lnum)
  if l =~# s:pat.step || l =~# s:pat.end
    return '>1'
  elseif l =~# s:pat.increment
    return '>2'
  endif
  return '='
endfunction

" Summary of one increment attempt, used by the fold text and :AbaqusIncrements
function! s:AttemptInfo(start, stop) abort
  let l = getline(a:start)
  let info = {'inc': '', 'att': '', 'dt': '', 'iters': 0, 'sdi': 0, 'warn': 0, 'err': 0,
        \ 'status': '', 'time': '', 'reason': ''}
  let m = matchlist(l, 'INCREMENT\s\+\(\d\+\)\s\+STARTS\. ATTEMPT NUMBER\s\+\(\d\+\)\%(, TIME INCREMENT\s\+\(\S\+\)\)\=')
  if !empty(m)
    let [info.inc, info.att, info.dt] = [m[1], m[2], m[3]]
  else
    let m = matchlist(l, 'CYCLE\s\+\(\d\+\)')
    let info.inc = empty(m) ? '?' : m[1]
    let info.att = 'cycle'
  endif
  let stop = min([a:stop, a:start + get(g:, 'abaqusmsg_scan_lines', 20000)])
  let view = winsaveview()
  call cursor(a:start, col([a:start, '$']))
  while 1
    " search() skips uninteresting lines in C, much faster than a Vim script loop
    let lnum = search(s:prefilter, 'W', stop)
    if lnum == 0
      break
    endif
    let t = getline(lnum)
    call cursor(lnum, col([lnum, '$']))
    if t =~# s:pat.iteration
      let info.iters += 1
      if t =~# s:pat.sdi
        let info.sdi += 1
      endif
    elseif t =~# s:pat.warning
      let info.warn += 1
    elseif t =~# s:pat.error
      let info.err += 1
      if info.err == 1
        " an error is the most specific reason; it overrides an earlier note
        let info.reason = substitute(matchstr(t, '\%(\*\*\*\s\=ERROR:\s*\)\=\zs\S.*'), '\s\+$', '', '')
      endif
    elseif t =~# s:pat.done
      let info.status = 'ok'
      let info.time = matchstr(t, 'COMPLETED\s\+\zs[^ ,]\+')
    elseif t =~# s:pat.diverging && empty(info.reason)
      let info.reason = substitute(matchstr(t, '\%(\*\*\*\w\+:\s*\)\=\zs\S.*'), '\s\+$', '', '')
    endif
  endwhile
  call winrestview(view)
  if empty(info.status)
    let info.status = (a:stop >= line('$') && info.err == 0 && empty(info.reason)) ? 'running' : 'failed'
  endif
  return info
endfunction

function! s:Sym(ok) abort
  if &encoding ==# 'utf-8'
    return a:ok ==# 'ok' ? '✓' : a:ok ==# 'running' ? '…' : '✗'
  endif
  return a:ok ==# 'ok' ? 'OK' : a:ok ==# 'running' ? '..' : 'XX'
endfunction

function! s:AttemptText(info) abort
  let i = a:info
  let s = printf('INCREMENT %4s  attempt %-2s  dt %-10s %s ', i.inc, i.att, i.dt, s:Sym(i.status))
  if i.status ==# 'ok'
    let s .= printf('%-14s', 't=' . i.time)
  elseif i.status ==# 'running'
    let s .= printf('%-14s', 'in progress')
  else
    let s .= printf('%-14s', i.err ? 'FAILED' : 'cut back')
  endif
  let s .= printf(' %3d iter', i.iters)
  if i.sdi
    let s .= printf(' (%d SDI)', i.sdi)
  endif
  if i.err
    let s .= printf('  %d error%s', i.err, i.err == 1 ? '' : 's')
  endif
  if i.warn
    let s .= printf('  %d warning%s', i.warn, i.warn == 1 ? '' : 's')
  endif
  if !empty(i.reason) && i.status !=# 'ok'
    let s .= '  - ' . tolower(i.reason)
  endif
  return s
endfunction

function! abaqusmsg#FoldText() abort
  let l = getline(v:foldstart)
  let n = v:foldend - v:foldstart + 1
  if !exists('b:abaqusmsg_ftcache') || b:abaqusmsg_ftcache.tick != b:changedtick
    let b:abaqusmsg_ftcache = {'tick': b:changedtick}
  endif
  let key = v:foldstart . ':' . v:foldend
  if has_key(b:abaqusmsg_ftcache, key)
    return b:abaqusmsg_ftcache[key]
  endif
  if l =~# s:pat.increment
    let text = s:AttemptText(s:AttemptInfo(v:foldstart, v:foldend))
  elseif l =~# s:pat.step
    let proc = ''
    for lnum in range(v:foldstart + 1, min([v:foldend, v:foldstart + 15]))
      let b = matchstr(getline(lnum), 'S T E P\s\+\d\+\s\+\zs.*')
      if !empty(b)
        let proc = substitute(substitute(b, '\s\{2,}', '#', 'g'), ' ', '', 'g')
        let proc = substitute(substitute(proc, '#', ' ', 'g'), '\s\+$', '', '')
        break
      endif
    endfor
    let text = substitute(matchstr(l, 'STEP\s\+\d\+'), '\s\+', ' ', 'g') . (empty(proc) ? '' : '  ' . tolower(proc))
  else
    let text = substitute(l, '^\s\+\|\s\+$', '', 'g')
  endif
  let text = printf('%s%s  [%d lines]', repeat('  ', v:foldlevel - 1), text, n)
  let b:abaqusmsg_ftcache[key] = text
  return text
endfunction

" ---------------------------------------------------------------- motions
function! abaqusmsg#Jump(name, backward, visual) abort
  " read the count first: any :normal command below resets v:count1
  let n = v:count1
  if a:visual
    normal! gv
  endif
  let flags = (a:backward ? 'b' : '') . 'W'
  normal! m'
  for _ in range(n)
    if search(s:pat[a:name], flags) == 0
      break
    endif
  endfor
endfunction

" ---------------------------------------------------------------- overviews
function! abaqusmsg#Increments() abort
  let last = line('$')
  let view = winsaveview()
  " find attempt starts and step/summary boundaries with search() (fast)
  let starts = []
  call cursor(1, 1)
  let flags = 'cW'
  let any = s:pat.increment . '\|' . s:pat.step . '\|' . s:pat.end
  while 1
    let lnum = search(any, flags)
    if lnum == 0
      break
    endif
    let flags = 'W'
    if getline(lnum) =~# s:pat.increment
      call add(starts, lnum)
    elseif !empty(starts) && type(starts[-1]) == v:t_number
      call add(starts, [lnum])     " boundary marker
    endif
  endwhile
  call winrestview(view)
  let items = []
  for i in range(len(starts))
    if type(starts[i]) != v:t_number
      continue
    endif
    let nxt = i + 1 < len(starts) ? starts[i + 1] : [last + 1]
    let stop = (type(nxt) == v:t_number ? nxt : nxt[0]) - 1
    let info = s:AttemptInfo(starts[i], stop)
    call add(items, {'bufnr': bufnr('%'), 'lnum': starts[i], 'text': s:AttemptText(info),
          \ 'type': info.status ==# 'ok' ? '' : 'W'})
  endfor
  call setloclist(0, items, 'r')
  call setloclist(0, [], 'a', {'title': 'Abaqus increments: ' . expand('%:t')})
  lopen
endfunction

function! abaqusmsg#Problems(bang) abort
  let items = []
  let prev = ''
  let pre = '\*\*\*\|RUNTIME\|DIVERG\|UNLIKELY\|TOO MANY\|MINIMUM\|CUT BACK\|REDUCED\|ATTEMPT NUMBER'
  if a:bang
    let pre .= '\|ACHIEVED\|TOO LARGE\|OUTSIDE OF\|EVERYWHERE BUT\|DISTORTING'
  endif
  let view = winsaveview()
  call cursor(1, 1)
  let flags = 'cW'
  while 1
    let lnum = search(pre, flags)
    if lnum == 0
      break
    endif
    let flags = 'W'
    let t = getline(lnum)
    let kind = ''
    if t =~# s:pat.error
      let kind = 'E'
    elseif t =~# s:pat.warning
      let kind = 'W'
      " repeated identical warnings (e.g. negative eigenvalues every iteration) only once unless !
      let key = substitute(t, '\d\+', '#', 'g')
      if !a:bang && key ==# prev
        continue
      endif
      let prev = key
    elseif t =~# s:pat.diverging || t =~# s:pat.retry
      let kind = 'W'
    elseif a:bang && t =~# s:pat.failed
      let kind = 'I'
    endif
    if !empty(kind)
      call add(items, {'bufnr': bufnr('%'), 'lnum': lnum, 'type': kind,
            \ 'text': substitute(t, '^\s\+\|\s\+$', '', 'g')})
    endif
    call cursor(lnum, col([lnum, '$']))
  endwhile
  call winrestview(view)
  call setloclist(0, items, 'r')
  call setloclist(0, [], 'a', {'title': 'Abaqus problems: ' . expand('%:t')})
  if empty(items)
    lclose
    echomsg 'No warnings, errors or cutbacks found.'
  else
    lopen
  endif
endfunction

" ---------------------------------------------------------------- keep folds on reload
" Reloading the file (:e, :checktime, :AbaqusFollow) rebuilds the folds and
" the filetype plugin resets 'foldlevel', so every fold would close again.
" SaveFolds() runs from BufUnload (:e) and from b:undo_ftplugin (reloads that
" keep the folds until the filetype plugin runs again); RestoreFolds() runs at
" the end of the filetype plugin. Abaqus only appends to the file, so fold
" start lines stay valid; new folds follow 'foldlevel'.
function! s:FoldStarts() abort
  let starts = {}
  let view = winsaveview()
  " :global is much faster than a getline() loop on large files
  execute 'silent keepjumps keeppatterns global/' . escape(s:pat.step . '\|' . s:pat.end, '/')
        \ . '/let starts[line(".")] = 1'
  execute 'silent keepjumps keeppatterns global/' . escape(s:pat.increment, '/')
        \ . '/let starts[line(".")] = 2'
  call winrestview(view)
  return starts
endfunction

function! abaqusmsg#SaveFolds(...) abort
  let buf = a:0 ? a:1 : bufnr('%')
  " keep the first save of a reload: later calls see the folds already reset
  if buf != bufnr('%') || exists('b:abaqusmsg_folds') || &l:foldmethod !=# 'expr'
        \ || &filetype !=# 'abaqusmsg' || line('$') <= 1
    return
  endif
  let open = {}
  for [lnum, level] in items(s:FoldStarts())
    let open[lnum] = [level, foldclosed(lnum) == -1]
  endfor
  let b:abaqusmsg_folds = {'open': open, 'foldlevel': &l:foldlevel,
        \ 'foldenable': &l:foldenable, 'view': winsaveview()}
endfunction

function! abaqusmsg#RestoreFolds() abort
  if !exists('b:abaqusmsg_folds')
    return
  endif
  let s = b:abaqusmsg_folds
  unlet b:abaqusmsg_folds
  if &l:foldmethod !=# 'expr'
    return
  endif
  let &l:foldlevel = s.foldlevel
  let &l:foldenable = s.foldenable
  let last = line('$')
  let known = filter(copy(s.open), 'v:key <= last')
  let steps = sort(map(keys(filter(copy(known), 'v:val[0] == 1')), 'str2nr(v:val)'), 'n')
  let incs = sort(map(keys(filter(copy(known), 'v:val[0] == 2')), 'str2nr(v:val)'), 'n')
  " open the steps first so each attempt can be set, then close steps again
  for lnum in steps
    if foldclosed(lnum) == lnum
      execute lnum . 'foldopen'
    endif
  endfor
  for lnum in incs
    if known[lnum][1] && foldclosed(lnum) == lnum
      execute lnum . 'foldopen'
    elseif !known[lnum][1] && foldclosed(lnum) == -1 && foldlevel(lnum) == 2
      execute lnum . 'foldclose'
    endif
  endfor
  for lnum in steps
    if !known[lnum][1] && foldclosed(lnum) == -1
      execute lnum . 'foldclose'
    endif
  endfor
  call winrestview(s.view)
endfunction

" ---------------------------------------------------------------- follow a running job
function! abaqusmsg#Follow(stop) abort
  if exists('b:abaqusmsg_timer')
    call timer_stop(b:abaqusmsg_timer)
    unlet b:abaqusmsg_timer
    if a:stop
      echomsg 'Stopped following ' . expand('%:t')
      return
    endif
  elseif a:stop
    return
  endif
  setlocal autoread
  let bufnr = bufnr('%')
  let b:abaqusmsg_timer = timer_start(get(g:, 'abaqusmsg_follow_ms', 5000),
        \ {t -> s:FollowTick(bufnr, t)}, {'repeat': -1})
  normal! G
  echomsg 'Following ' . expand('%:t') . ' (:AbaqusFollow! to stop)'
endfunction

function! s:FollowTick(bufnr, timer) abort
  if !bufexists(a:bufnr)
    call timer_stop(a:timer)
    return
  endif
  if bufnr('%') != a:bufnr
    return
  endif
  let at_end = line('.') >= line('$') - 1
  silent! checktime
  if at_end
    normal! G
  endif
  if search(s:pat.end . '\|JOB TIME SUMMARY', 'nw')
    call timer_stop(a:timer)
    silent! unlet b:abaqusmsg_timer
    echomsg 'Analysis finished: ' . expand('%:t')
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
