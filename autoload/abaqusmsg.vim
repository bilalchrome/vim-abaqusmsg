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
  " every iteration is either an equilibrium (EQI) or a severe discontinuity (SDI) iteration
  let s .= printf(' %3d iter (%d EQI, %d SDI)', i.iters, i.iters - i.sdi, i.sdi)
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
  let text = repeat('  ', v:foldlevel - 1) . text
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
" [start, stop] line ranges of every increment attempt, in file order
function! s:Attempts() abort
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
  let ranges = []
  for i in range(len(starts))
    if type(starts[i]) != v:t_number
      continue
    endif
    let nxt = i + 1 < len(starts) ? starts[i + 1] : [last + 1]
    call add(ranges, [starts[i], (type(nxt) == v:t_number ? nxt : nxt[0]) - 1])
  endfor
  return ranges
endfunction

function! abaqusmsg#Increments() abort
  let items = []
  for [start, stop] in s:Attempts()
    let info = s:AttemptInfo(start, stop)
    call add(items, {'bufnr': bufnr('%'), 'lnum': start, 'text': s:AttemptText(info),
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

" ---------------------------------------------------------------- hotspots
" Nodes that keep showing up in the convergence checks (largest residual,
" increment and correction, contact force and penetration errors) and in
" warnings, ranked by how often they appear in attempts that were cut back.
let s:node_re = '\<NODE\%(\s\+NUMBER\)\=\s\+\zs[[:alnum:]_]\%([[:alnum:]_.-]*[[:alnum:]_]\)\='
let s:pair_re = '([[:alnum:]_.\-]\+,\s*[[:alnum:]_.\-]\+)'

" What a line says about its node, e.g. 'residual force', 'contact force', 'warning'
function! s:HitLabel(lnum, t) abort
  let m = matchlist(a:t, '^\s*LARGEST\s\+\%(SCALED\s\+\)\=\(RESIDUAL\|INCREMENT OF\|CORRECTION TO\)\s\+\(.\{-}\)\s\+[-+]\=\%(\d\|\.\d\)')
  if !empty(m)
    let what = substitute(tolower(substitute(m[2], '\.\s*$', '', '')), '\s\+', ' ', 'g')
    return [tolower(matchstr(m[1], '^\S\+')) . ' ' . what, m[2] =~# 'CAV\.\s*VOL\|H\.PRESS']
  endif
  let m = matchlist(a:t, '^\s*MAX\.\s\+\(.\{-}\)\s\+ERROR\>')
  if !empty(m)
    return [tolower(substitute(m[1], 'CONTACT ', 'contact ', '')), 0]
  endif
  " node named in a ***WARNING / ***ERROR message, possibly on a continuation line
  for l in range(a:lnum, max([1, a:lnum - 4]), -1)
    let m = matchstr(getline(l), '^\s\=\*\*\*\s\=\zs\%(WARNING\|ERROR\)\ze:')
    if !empty(m)
      return [tolower(m), 0]
    endif
    if l < a:lnum && getline(l) !~# '^\s\{4,}\S'
      break
    endif
  endfor
  return ['', 0]
endfunction

function! s:CollectHotspots() abort
  let nodes = {}
  let internal = {}
  let pairs = {}
  " Same rule as the fold summaries: an attempt converged when it reports
  " STEP TIME COMPLETED; the last attempt may still be running. One search
  " pass for those lines is much faster than summarising every attempt.
  let atts = s:Attempts()
  let incs = map(copy(atts), 'matchstr(getline(v:val[0]), "\\%(INCREMENT\\|CYCLE\\)\\s\\+\\zs\\d\\+")')
  let done = {}
  let view = winsaveview()
  call cursor(1, 1)
  let flags = 'cW'
  while 1
    let lnum = search(s:pat.done, flags)
    if lnum == 0
      break
    endif
    let flags = 'W'
    let done[lnum] = 1
  endwhile
  let failed = []
  let dl = sort(map(keys(done), 'str2nr(v:val)'), 'n')
  let j = 0
  for i in range(len(atts))
    while j < len(dl) && dl[j] < atts[i][0]
      let j += 1
    endwhile
    let ok = j < len(dl) && dl[j] <= atts[i][1]
    if !ok && i == len(atts) - 1
      let ok = s:AttemptInfo(atts[i][0], atts[i][1]).status ==# 'running'
    endif
    call add(failed, !ok)
  endfor
  let a = -1
  let last = line('$')
  call cursor(empty(atts) ? last + 1 : atts[0][0], 1)
  while !empty(atts)
    let lnum = search('\<NODE\s', 'W')
    if lnum == 0
      break
    endif
    while a + 1 < len(atts) && atts[a + 1][0] <= lnum
      let a += 1
    endwhile
    if a < 0 || lnum > atts[a][1]
      continue
    endif
    let t = getline(lnum)
    let node = matchstr(t, s:node_re)
    if node !~# '\d'
      continue
    endif
    let [label, isint] = s:HitLabel(lnum, t)
    if empty(label)
      continue
    endif
    let next = ''
    if t =~# 'INSTANCE' || (lnum < last && getline(lnum + 1) =~# '^\s*INSTANCE')
      let next = lnum < last ? getline(lnum + 1) : ''
      let inst = matchstr(t . ' ' . next, '\<INSTANCE:\=\s*\zs[[:alnum:]_][[:alnum:]_.-]*')
      if !empty(inst) && node !~# '\.'
        let node = inst . '.' . node
      endif
    endif
    let d = isint || t =~# '\<INTERNAL\s\+NODE\>' ? internal : nodes
    if !has_key(d, node)
      let d[node] = {'node': node, 'hits': 0, 'failed': 0, 'what': {}, 'incs': {}, 'pairs': {}, 'lines': []}
    endif
    let h = d[node]
    let h.hits += 1
    let h.failed += failed[a]
    let h.what[label] = get(h.what, label, 0) + 1
    let h.incs[incs[a]] = 1
    if t =~# 'CONTACT PAIR'
      let pair = matchstr(t =~# 'CONTACT PAIR\s*\r\=$' && lnum < last ? getline(lnum + 1) : t, s:pair_re)
      if !empty(pair)
        let h.pairs[pair] = 1
        let pairs[pair] = 1
      endif
    endif
    call add(h.lines, lnum)
  endwhile
  call winrestview(view)
  return {'nodes': values(nodes), 'internal': values(internal), 'pairs': keys(pairs),
        \ 'attempts': len(atts), 'failed': eval(join(failed + [0], '+'))}
endfunction

function! s:ByFailed(a, b) abort
  return a:b.failed != a:a.failed ? a:b.failed - a:a.failed : a:b.hits - a:a.hits
endfunction

function! s:Pad(s, w) abort
  return a:s . repeat(' ', a:w - strdisplaywidth(a:s))
endfunction

" '1-3', '1, 4, 7-9'
function! s:Ranges(incs) abort
  let n = sort(map(filter(copy(a:incs), 'v:val =~# "^\\d\\+$"'), 'str2nr(v:val)'), 'n')
  let out = []
  let i = 0
  while i < len(n)
    let j = i
    while j + 1 < len(n) && n[j + 1] <= n[j] + 1
      let j += 1
    endwhile
    call add(out, i == j ? string(n[i]) : n[i] . '-' . n[j])
    let i = j + 1
  endwhile
  let s = join(out, ', ')
  return strchars(s) > 14 ? strcharpart(s, 0, 13) . '…' : s
endfunction

function! s:What(what) abort
  let items = sort(items(a:what), {a, b -> b[1] - a[1]})
  return join(map(items, 'v:val[0] . " " . v:val[1]'), ' · ')
endfunction

function! abaqusmsg#Hotspots(...) abort
  if &filetype !=# 'abaqusmsg'
    echohl WarningMsg | echo 'AbaqusHotspots: not an Abaqus .msg buffer' | echohl None
    return
  endif
  let src = win_getid()
  let srcbuf = bufnr('%')
  let name = expand('%:t')
  let r = s:CollectHotspots()
  let nodes = sort(r.nodes, function('s:ByFailed'))
  let limit = a:0 && a:1 > 0 ? a:1 : get(g:, 'abaqusmsg_hotspots', 25)
  let shown = nodes[: limit - 1]
  let utf = &encoding ==# 'utf-8'
  let [full, part] = utf ? ['█', '░'] : ['#', '.']
  let width = 16
  let top = empty(shown) ? 1 : max(map(copy(shown), 'v:val.hits'))
  let pairs = len(r.pairs) > 1

  let lines = [printf('Abaqus hotspots  %s  %s  %d attempt%s, %d cut back', name, utf ? '·' : '-',
        \ r.attempts, r.attempts == 1 ? '' : 's', r.failed)]
  if len(r.pairs) == 1
    call add(lines, 'contact pair ' . r.pairs[0])
  endif
  call add(lines, printf('%s in attempts that were cut back   %s in converged attempts   ' .
        \ '<CR> jump  n/N next hit  q close', full, part))
  call add(lines, '')
  let head = printf('  %s %s %8s %5s   %s %s', s:Pad('NODE', 18), s:Pad('', width), 'CUT BACK', 'ALL',
        \ s:Pad('INCREMENTS', 15), 'FLAGGED BY')
  call add(lines, head . (pairs ? '   CONTACT PAIR' : ''))
  let first = len(lines) + 1
  for h in shown
    let nf = float2nr(round(width * h.failed / top))
    let nt = max([1, float2nr(round(width * h.hits / top))])
    let nf = h.failed > 0 ? max([1, min([nf, nt])]) : 0
    let bar = repeat(full, nf) . repeat(part, nt - nf)
    let row = printf('  %s %s %8s %5d   %s %s', s:Pad(h.node, 18), s:Pad(bar, width),
          \ h.failed ? h.failed : '-', h.hits, s:Pad(s:Ranges(keys(h.incs)), 15), s:What(h.what))
    if pairs
      let row .= '   ' . join(keys(h.pairs), ' ')
    endif
    call add(lines, row)
  endfor
  if empty(shown)
    call add(lines, '  (no nodes in the convergence checks)')
  elseif len(nodes) > len(shown)
    call add(lines, printf('  … %d more (:AbaqusHotspots %d shows them all)', len(nodes) - len(shown), len(nodes)))
  endif
  if !empty(r.internal)
    let int = sort(r.internal, {a, b -> b.hits - a.hits})
    call add(lines, '')
    call add(lines, 'internal nodes (fluid cavity, hybrid pressure; rarely the cause): '
          \ . join(map(copy(int), 'v:val.node . " ×" . v:val.hits'), ', '))
  endif

  " reuse the report window if it is open
  let bufname = '[Abaqus hotspots]'
  let win = bufwinnr('^' . escape(bufname, '[]') . '$')
  if win > 0
    execute win . 'wincmd w'
  else
    execute 'botright ' . min([len(lines) + 1, 18]) . 'new'
    silent execute 'file ' . fnameescape(bufname)
    setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted nowrap nonumber norelativenumber
    setlocal nofoldenable nospell nolist cursorline winfixheight
  endif
  setlocal modifiable
  silent %delete _
  call setline(1, lines)
  setlocal nomodifiable
  let b:abaqusmsg_hot = {'src': src, 'srcbuf': srcbuf, 'first': first,
        \ 'rows': map(copy(shown), '{"node": v:val.node, "lines": v:val.lines}')}
  call s:HotspotSyntax(full, part)
  nnoremap <silent> <buffer> <CR> :call abaqusmsg#HotspotJump()<CR>:let v:hlsearch = &hlsearch<CR>
  nnoremap <silent> <buffer> q :close<CR>
  call cursor(first, 3)
endfunction

function! s:HotspotSyntax(full, part) abort
  syntax clear
  syntax match abaqushotTitle   /\%1l.*/
  syntax match abaqushotHead    /^  NODE .*/
  syntax match abaqushotHelp    /^\S\+ in attempts .*/ contains=abaqushotFull,abaqushotPart
  execute 'syntax match abaqushotFull /' . a:full . '\+/'
  execute 'syntax match abaqushotPart /' . escape(a:part, '.') . '\+/'
  syntax match abaqushotNode    /^  \zs\S\+/
  syntax match abaqushotPair    /([[:alnum:]_.\-]\+,\s*[[:alnum:]_.\-]\+)/
  syntax match abaqushotMuted   /^\%(internal nodes\|  …\|  (no\).*/
  hi def link abaqushotTitle  Title
  hi def link abaqushotHead   Comment
  hi def link abaqushotHelp   Comment
  hi def link abaqushotNode   abaqusmsgNode
  hi def link abaqushotPair   abaqusmsgContactPair
  hi def link abaqushotMuted  Comment
  " the .msg highlight groups may not be loaded with 'links' fallbacks yet
  hi def link abaqusmsgCutback ErrorMsg
  hi def link abaqusmsgGood    Type
  hi def link abaqusmsgNode    Identifier
  hi def link abaqusmsgContactPair Constant
  " Bars need a foreground colour only: many colorschemes draw ErrorMsg in
  " reverse video, which would turn the block characters into empty cells.
  call s:BarColour('abaqushotFull', 'abaqusmsgCutback')
  call s:BarColour('abaqushotPart', 'abaqusmsgGood')
endfunction

function! s:BarColour(group, from) abort
  let id = synIDtrans(hlID(a:from))
  let out = []
  for mode in ['gui', 'cterm']
    " the colour you see: fg for reverse video, a background badge, else fg
    let rev = synIDattr(id, 'reverse', mode) ==# '1' || synIDattr(id, 'inverse', mode) ==# '1'
    let fg = synIDattr(id, 'fg#', mode)
    let bg = synIDattr(id, 'bg#', mode)
    let normal_bg = synIDattr(synIDtrans(hlID('Normal')), 'bg#', mode)
    let c = !rev && bg !~# '^\%(-1\)\=$' && bg !=# normal_bg ? bg : fg
    if !empty(c) && c !=# '-1'
      call add(out, mode . 'fg=' . c)
    endif
  endfor
  execute 'hi clear ' . a:group
  execute empty(out) ? 'hi link ' . a:group . ' ' . a:from : 'hi ' . a:group . ' ' . join(out)
endfunction

" <CR> in the report: jump to the node's first hit after the cursor, fill the
" location list with every hit and search for the node so n/N step through them.
function! abaqusmsg#HotspotJump() abort
  let r = get(b:, 'abaqusmsg_hot', {})
  let i = line('.') - get(r, 'first', 0)
  if empty(r) || i < 0 || i >= len(r.rows)
    return
  endif
  let row = r.rows[i]
  if win_gotoid(r.src) == 0 || bufnr('%') != r.srcbuf
    echohl WarningMsg | echo 'AbaqusHotspots: the .msg window is gone' | echohl None
    return
  endif
  let num = matchstr(row.node, '[^.]*$')
  let @/ = '\<NODE\%(\s\+NUMBER\)\=\s\+\%(\S*\.\)\=\zs' . escape(num, '\.') . '\>'
  call setloclist(0, map(copy(row.lines), '{"bufnr": r.srcbuf, "lnum": v:val, ' .
        \ '"text": substitute(getline(v:val), "^\\s\\+\\|\\s\\+$", "", "g")}'), 'r')
  call setloclist(0, [], 'a', {'title': 'Abaqus hotspot: node ' . row.node})
  let nxt = filter(copy(row.lines), 'v:val > line(".")')
  call cursor(empty(nxt) ? row.lines[0] : nxt[0], 1)
  call search(@/, 'c', line('.'))
  normal! zvzz
  echo printf('node %s: %d hit%s (n/N next, :lopen lists them)', row.node, len(row.lines),
        \ len(row.lines) == 1 ? '' : 's')
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
