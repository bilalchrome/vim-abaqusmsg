" Vim syntax file
" Language:     Abaqus/Standard message file (*.msg)
" Maintainer:   Bilal Abdul Halim
" Version:      2.0.0
" License:      MIT (see LICENSE)
"
" Design
"   * Data lines (LARGEST ..., MAX. ... ERROR, AVERAGE ...) highlight only
"     their label.  Numbers, node labels, DOFs and contact pairs are separate
"     matches, so each one stays visible.
"   * Status lines carry the meaning: converged, not converged, cutback or
"     divergence.  A failing increment can be spotted while scrolling.
"   * ***WARNING / ***ERROR / ***NOTE messages are regions that end at the
"     first line that is not an indented continuation, so a wrapped
"     multi-line message is coloured as one unit.
"   * Header boilerplate (PARALLEL ... ENABLED, connected-component tables)
"     is dimmed.
"
" Options (set them in your vimrc before the file is opened)
"   g:abaqusmsg_palette = 'links'   (default) colours come from your colorscheme
"                       = 'okabe'   colourblind-safe Okabe-Ito colours
"                                   (blue = good, orange = bad), for any
"                                   colorscheme; adapts to 'background'
"   g:abaqusmsg_dim_boilerplate = 0 do not dim the header boilerplate

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn case match
syn spell notoplevel

" ===================================================================
" Inline tokens (used everywhere, also inside other groups)
" ===================================================================

" Numbers: 12  -3.85839E-12  1.000E-02  3.467e+11  .5  0.00
" Not inside identifiers such as GENERAL_CONTACT_FACES_2, PART-1-1, S4R or 2026.HF3.
syn match abaqusmsgNumber
      \ /\%([[:alnum:]_.-]\)\@1<![-+]\=\%(\d\+\.\=\d*\|\.\d\+\)\%([eE][-+]\=\d\+\)\=\%([[:alnum:]_.]\)\@!/

" Node references: "AT NODE 17280", "AT INTERNAL NODE ..", "NODE 16814 OF CONTACT PAIR",
" "AT NODE  PART-1-1.123", "NODE NUMBER 5"
syn match abaqusmsgNode
      \ /\<\%(AT\s\+\%(INTERNAL\s\+\)\=\)\=NODE\%(\s\+NUMBER\)\=\s\+\zs[[:alnum:]_]\%([[:alnum:]_.-]*[[:alnum:]_]\)\=/
syn match abaqusmsgDof          /\<\%(DOF\|D\.O\.F\.\)\s\+\d\+\>/
syn match abaqusmsgElement      /\<ELEMENT\%(\s\+NUMBER\)\=\s\+\zs\%(\u\+[[:alnum:]_-]*\.\)\=\d\+\>/
syn match abaqusmsgInstance     /\<INSTANCE:\s*\zs.\{-}\ze\s*\r\=$/
" Contact pair names: (SURF1,SURF2)  (ASSEMBLY_PART-1-1.SURF,RIGID-1.SURF)
syn match abaqusmsgContactPair  /([[:alnum:]_.\-]\+,\s*[[:alnum:]_.\-]\+)/

syn cluster abaqusmsgInline contains=abaqusmsgNumber,abaqusmsgNode,abaqusmsgDof,abaqusmsgElement,abaqusmsgInstance,abaqusmsgContactPair

" ===================================================================
" File and step headers
" ===================================================================

" Spaced-letter banners: "A N A L Y S I S   D A T A   C H E C K",
" "P R O C E S S I N G   P A R T ...", "S T E P  1  S T A T I C ..."
syn match abaqusmsgBanner       /^\s*\u\%( \u\)\{2,}\%(\s\{2,}\u\%( \u\)*\)*.*$/ contains=abaqusmsgNumber
syn match abaqusmsgStepBanner   /^\s*S T E P\s\+\d\+.*$/
syn match abaqusmsgVersion      /^\s*Abaqus\%(\s\+3DEXPERIENCE\)\=\s\+\S\+.*$/
" " STEP    1     INCREMENT     1     STEP TIME    0.00"
syn match abaqusmsgStepLine     /^\s*STEP\s\+\d\+\s\+INCREMENT\s\+\d\+\s\+STEP TIME\s\+\S\+/ contains=abaqusmsgNumber

" Section headers inside the step header
syn match abaqusmsgSection      /^\s*\%(CONVERGENCE TOLERANCE PARAMETERS FOR\s.*\|TIME INCREMENTATION CONTROL PARAMETERS:\|CONTACT CONTROLS APPLIED TO.*\|AUTOMATIC \u\+ CONTROL WITH -\|FIXED TIME INCREMENTATION\|ANALYSIS SUMMARY:\|JOB TIME SUMMARY\|INITIAL ELEMENT LOAD BALANCE\|M E M O R Y\s.*\|E N D\s\+O F\s.*\)\s*\r\=$/

" Step options worth noticing (procedure settings that change behaviour)
syn match abaqusmsgStepOption   /^\s*\%(LARGE DISPLACEMENT THEORY WILL BE USED\|UNSYMMETRIC MATRIX STORAGE AND SOLUTION WILL BE USED\|LINEAR EXTRAPOLATION WILL BE USED\|PARABOLIC EXTRAPOLATION WILL BE USED\|MODIFIED RIKS METHOD IS USED\|THIS IS A LINEAR PERTURBATION STEP\|THE \u\+ EIGENSOLVER IS USED\|DYNAMIC APPLICATION.*\|\u.\{-}TIME INTEGRATOR IS USED\|DETAILED OUTPUT OF CONTACT CHANGES.*\|EQUILIBRIUM WILL BE CHECKED FOR SEVERE DISCONTINUITY ITERATIONS\|AGGRESSIVE\s\+TIME INCREMENTATION IS USED\|STABILIZATION .*\)\s*\r\=$/
syn match abaqusmsgStepOption   /^\s*THE MAXIMUM NUMBER OF INCREMENTS IN THIS STEP IS\s\+\d\+/ contains=abaqusmsgNumber

" ***-flagged non-default parameter lines (not ***WARNING/ERROR/NOTE)
syn match abaqusmsgNonDefault   /^\s\=\*\*\*\%(\s*\%(WARNING\|ERROR\|NOTE\)\>\)\@!.*$/ contains=abaqusmsgNumber

" Dimmed boilerplate
syn match abaqusmsgBoilerplate  /^\s*\%(PARALLEL .* ENABLED\|COLLECTING .*CONSTRAINT INFORMATION.*\|RESTART FILE WILL BE WRITTEN.*\|PRINT OF INCREMENT NUMBER.*\|DETAILS REGARDING ACTUAL SOLUTION WAVEFRONT REQUESTED\|DETAILED OUTPUT OF DIAGNOSTICS TO DATABASE REQUESTED\|ELEMENT OPERATIONS WILL BE CARRIED OUT .*\|WRITING ELEMENT AND NODE SETS .*\|REGIONS WITH NO ACTIVE USER NODES .*\|CONNECTED COMPONENT\s.*\|CHARACTERISTIC ELEMENT LENGTH .*\|-\{3,}[- \t]*\)\r\=$/
" connected-component table rows: "  17   2   2"
syn match abaqusmsgBoilerplate  /^\s*\d\+\s\+\d\+\s\+\d\+\s*\r\=$/

" ===================================================================
" Increments, attempts and iterations
" ===================================================================

" "INCREMENT     1 STARTS. ATTEMPT NUMBER  1, TIME INCREMENT  1.000E-02"
syn match abaqusmsgIncrement    /^\s*INCREMENT\s\+\d\+\s\+STARTS\..*$/ contains=abaqusmsgNumber,abaqusmsgRetry
" attempt 2 and above = cutback (the first attempt of this increment failed)
syn match abaqusmsgRetry        /ATTEMPT NUMBER\s\+\%([2-9]\|[1-9]\d\+\)\>/ contained
" direct cyclic
syn match abaqusmsgIncrement    /^\s*\%(CYCLE\|ITERATION\)\s\+\d\+\s\+STARTS:.*$/ contains=abaqusmsgNumber

" generic first, specific after it (when matches start at the same column the last one defined wins)
syn match abaqusmsgIterEquil    /^\s*CONVERGENCE CHECKS FOR \u.\{-}ITERATION\s\+\d\+/
syn match abaqusmsgIterSDI      /^\s*CONVERGENCE CHECKS FOR SEVERE DISCONTINUITY ITERATION\s\+\d\+/
" older releases: "SEVERE DISCONTINUITY ITERATION 2 ... 3 CLOSURES 1 OPENINGS"
syn match abaqusmsgIterSDI      /^\s*SEVERE DISCONTINUITY ITER.*OPENINGS.*$/ contains=abaqusmsgNumber

" Contact state changes
syn match abaqusmsgSDICount     /^\s*\d\+\s\+SEVERE DISCONTINUITIES OCCURRED DURING .*$/ contains=abaqusmsgNumber
syn match abaqusmsgContactChange /^\s*\d\+\s\+POINTS CHANGED FROM .*$/ contains=abaqusmsgNumber
syn match abaqusmsgContactChange /^\s*\d\+\s\+.\{-}CHANGED TO STICK AT\s\+\d\+.*$/ contains=abaqusmsgNumber
syn match abaqusmsgContactCount /^\s*THE NUMBER OF \%(CLOSE\|OPEN\) CONSTRAINT IS\ze\s/
" detailed contact output (*PRINT, CONTACT=YES)
syn match abaqusmsgContactDetail /^\s*CONTACT PAIR (.\{-})\s\+NODE\>/ contains=abaqusmsgContactPair

" Equation solver
syn match abaqusmsgSolver       /^\s*\%(\u\+\s\+\)*SOLVER RUNNING ON\s*\r\=$/
syn match abaqusmsgSolver       /^\s*\d\+\s\+HOSTS\=\s\+x\s\+\d\+\s\+MPI RANKS\=.*$/ contains=abaqusmsgNumber
syn match abaqusmsgSolver       /^\s*USING THE \S\+ SOLVER WITH .*$/ contains=abaqusmsgNumber
syn match abaqusmsgSolverStat   /^\s*\%(NUMBER OF \%(EQUATIONS\|RHS\|FLOPS\)\|SOLVER ELAPSED TIME\|ELAPSED WALL\%(CLOCK\)\= TIME\)\s*[:=]/

" Labels of the convergence check lines; the numbers stay separate tokens
"   LARGEST SCALED RESIDUAL FORCE   9.227E-03   AT NODE 17280   DOF  2
"   MAX. PENETRATION ERROR -3.85839E-12 AT NODE 16814 OF CONTACT PAIR
syn match abaqusmsgCheckLabel   /^\s*\zs\%(LARGEST\|CORRESPONDING\|ESTIMATE OF\|MAX\.\|MAXIMUM\)\>.\{-}\ze\s\+[-+]\=\%(\d\|\.\d\)/
syn match abaqusmsgAverage      /^\s*\zsAVERAGE\s.\{-}\ze\s\+[-+]\=\%(\d\|\.\d\)/
syn match abaqusmsgAverage      /\<TIME AVG\.\s.\{-}\ze\s\+[-+]\=\%(\d\|\.\d\)/
syn match abaqusmsgAverage      /\<USER-DEFINED\s.\{-}\ze\s\+[-+]\=\%(\d\|\.\d\)/
" hybrid / coupling compatibility check: "VOLUMETRIC  0  ..." (0 = ok)
syn match abaqusmsgGood         /^\s*\%(VOLUMETRIC\|COUPLING DISPLACEMENT\|COUPLING ROTATION\)\s\+0\s.*$/ contains=abaqusmsgNumber
syn match abaqusmsgBad          /^\s*\%(VOLUMETRIC\|COUPLING DISPLACEMENT\|COUPLING ROTATION\)\s\+[1-9*][0-9*]*\s.*$/ contains=abaqusmsgNumber

" ---- converged ------------------------------------------------------
syn match abaqusmsgGood
      \ /^\s\+.\{-}\%(HAVE CONVERGED\|ERRORS ARE WITHIN THE TOLERANCES\=\|ACCEPTED BASED ON\|CORRECTIONS ARE ZERO\|RESPONSE WAS LINEAR\|THERE IS ZERO .\{-}EVERYWHERE\|RESIDUALS ARE ZERO\).*$/
" second line of "... HAVE CONVERGED BASED ON ALTERNATIVE" / "RESIDUAL CRITERION"
syn match abaqusmsgGood         /^\s\+\%(RESIDUAL CRITERION\|ALTERNATIVE RESIDUAL CRITERION\)\s*\r\=$/
syn match abaqusmsgGood         /^\s*TIME INCREMENT MAY NOW INCREASE TO\s.*$/ contains=abaqusmsgNumber
syn match abaqusmsgDone         /^\s*\%(TIME INCREMENT COMPLETED\|STEP TIME COMPLETED\|TOTAL ARC LENGTH\)\s.*$/ contains=abaqusmsgNumber

" ---- not converged --------------------------------------------------
" (defined after Good: "IS ZERO EVERYWHERE BUT" must win)
syn match abaqusmsgBad
      \ /^\s\+.\{-}\%(NOT \%(YET \)\=ACHIEVED\|TOO LARGE COMPARED TO\|OUTSIDE OF CONVERGENCE\|IS ZERO EVERYWHERE BUT\|ERROR TOO LARGE\).*$/
syn match abaqusmsgBad          /^\s*ELEMENT\s\+\S\+.\{-}IS DISTORTING EXCESSIVELY\.\=/ contains=abaqusmsgElement

" ---- cutbacks and divergence -----------------------------------------
syn match abaqusmsgCutback
      \ /^\s*\%(BECAUSE .*\|THE NEXT TIME INCREMENT WILL BE REDUCED TO.*\|.\{-}HAS BEEN CUT BACK.*\|.\{-}TIME INCREMENT REQUIRED IS LESS THAN THE MINIMUM.*\|.\{-}TOO MANY ATTEMPTS.*\|.\{-}TOO MANY INCREMENTS NEEDED.*\)$/
      \ contains=abaqusmsgNumber
syn match abaqusmsgCutbackMsg   /THE SOLUTION APPEARS TO BE DIVERGING\.\=\%(\s*CONVERGENCE IS JUDGED UNLIKELY\.\=\)\=/ contained
syn match abaqusmsgCutbackMsg   /\%(CONVERGENCE IS JUDGED UNLIKELY\|TOO MANY ATTEMPTS MADE FOR THIS INCREMENT\|TIME INCREMENT REQUIRED IS LESS THAN THE MINIMUM SPECIFIED\|TOO MANY INCREMENTS NEEDED TO COMPLETE THE STEP\)\.\=/ contained

" Iteration summary
syn match abaqusmsgIterSummary  /^\s*ITERATION SUMMARY FOR THE INCREMENT:.*$/ contains=abaqusmsgNumber
syn match abaqusmsgIterSummary  /^\s*\d\+ ARE SEVERE DISCONTINUITY ITERATIONS AND\s\+\d\+ ARE EQUILIBRIUM ITERATIONS\.\=/ contains=abaqusmsgNumber

" ===================================================================
" Messages: ***WARNING / ***ERROR / ***NOTE (with wrapped continuation lines)
" ===================================================================
" A message continues on the following lines when they are indented by
" 4+ spaces; it ends at a blank line or a less-indented line.
syn region abaqusmsgWarningMsg  start=/^\s\=\*\*\*\s\=WARNING:/  end=/\%(\n\s\{4,}[[:alnum:](<]\)\@!$/ keepend contains=abaqusmsgMsgTag,abaqusmsgCutbackMsg,abaqusmsgNode,abaqusmsgElement,abaqusmsgDof,abaqusmsgContactPair
syn region abaqusmsgErrorMsg    start=/^\s\=\*\*\*\s\=ERROR:/    end=/\%(\n\s\{4,}[[:alnum:](<]\)\@!$/ keepend contains=abaqusmsgMsgTag,abaqusmsgCutbackMsg,abaqusmsgNode,abaqusmsgElement,abaqusmsgDof,abaqusmsgContactPair
syn region abaqusmsgNoteMsg     start=/^\s\=\*\*\*\s\=NOTE:/     end=/\%(\n\s\{4,}[[:alnum:](<]\)\@!$/ keepend contains=abaqusmsgMsgTag,abaqusmsgCutbackMsg,abaqusmsgNode,abaqusmsgElement,abaqusmsgDof,abaqusmsgContactPair
syn match  abaqusmsgMsgTag      /\*\*\*\s\=\%(WARNING\|ERROR\|NOTE\):/ contained
" Abaqus spells it OCCURED
syn region abaqusmsgRuntime     start=/^-\+\s*RUNTIME\s\+\w\+\s\+HAS\s\+OCCURR\=ED/ end=/^\s*\r\=$/ keepend

" ===================================================================
" Final summaries
" ===================================================================
syn match abaqusmsgCompleted    /^\s*THE ANALYSIS HAS BEEN COMPLETED\s*\r\=$/
syn match abaqusmsgNotCompleted /^\s*THE ANALYSIS HAS NOT BEEN COMPLETED\s*\r\=$/
syn match abaqusmsgRestart      /^\s*RESTART INFORMATION WRITTEN.*$/ contains=abaqusmsgNumber
syn match abaqusmsgRestart      /^\s*CHECK POINT.*$/ contains=abaqusmsgNumber
" ANALYSIS SUMMARY counts that are bad when they are not zero
syn match abaqusmsgSummaryBad   /^\s*[1-9]\d*\s\+\%(CUTBACKS IN AUTOMATIC INCREMENTATION\|ERROR MESSAGES\|WARNING MESSAGES DURING ANALYSIS\|ANALYSIS WARNINGS ARE NUMERICAL PROBLEM MESSAGES\|ANALYSIS WARNINGS ARE NEGATIVE EIGENVALUE MESSAGES\)\s*\r\=$/ contains=abaqusmsgNumber
syn match abaqusmsgJobTime      /^\s*\%(USER\|SYSTEM\|TOTAL CPU\|WALLCLOCK\) TIME (SEC)\s*=\|^\s*MEMORY PEAK (\u\+)\s*=/

" ===================================================================
" Synchronisation: messages are short, so a small look-back is enough
" even for very large .msg files.
" ===================================================================
syn sync minlines=40 maxlines=400

" ===================================================================
" Highlighting
" ===================================================================
function! s:AbaqusmsgLinks() abort
  hi def link abaqusmsgNumber        Number
  hi def link abaqusmsgNode          Identifier
  hi def link abaqusmsgDof           Number
  hi def link abaqusmsgElement       Identifier
  hi def link abaqusmsgInstance      Identifier
  hi def link abaqusmsgContactPair   Constant

  hi def link abaqusmsgBanner        Title
  hi def link abaqusmsgStepBanner    Title
  hi def link abaqusmsgVersion       Title
  hi def link abaqusmsgStepLine      Title
  hi def link abaqusmsgSection       Title
  hi def link abaqusmsgStepOption    Type
  hi def link abaqusmsgNonDefault    Special
  hi def link abaqusmsgBoilerplate   Comment

  hi def link abaqusmsgIncrement     Underlined
  hi def link abaqusmsgRetry         abaqusmsgCutback
  hi def link abaqusmsgIterEquil     Function
  hi def link abaqusmsgIterSDI       Special
  hi def link abaqusmsgSDICount      Special
  hi def link abaqusmsgContactChange PreProc
  hi def link abaqusmsgContactCount  PreProc
  hi def link abaqusmsgContactDetail PreProc
  hi def link abaqusmsgSolver        Comment
  hi def link abaqusmsgSolverStat    Comment
  hi def link abaqusmsgCheckLabel    Identifier
  hi def link abaqusmsgAverage       Comment
  hi def link abaqusmsgIterSummary   Label
  hi def link abaqusmsgDone          abaqusmsgGood

  hi def link abaqusmsgGood          Type
  hi def link abaqusmsgBad           WarningMsg
  hi def link abaqusmsgCutback       ErrorMsg
  hi def link abaqusmsgCutbackMsg    abaqusmsgCutback

  hi def link abaqusmsgWarningMsg    WarningMsg
  hi def link abaqusmsgErrorMsg      ErrorMsg
  hi def link abaqusmsgNoteMsg       Comment
  hi def link abaqusmsgMsgTag        Todo
  hi def link abaqusmsgRuntime       ErrorMsg

  hi def link abaqusmsgCompleted     abaqusmsgGood
  hi def link abaqusmsgNotCompleted  ErrorMsg
  hi def link abaqusmsgRestart       Comment
  hi def link abaqusmsgSummaryBad    WarningMsg
  hi def link abaqusmsgJobTime       Identifier
endfunction

function! s:hi(group, c, attr) abort
  exe printf('hi %s guifg=%s ctermfg=%d gui=%s cterm=%s', a:group, a:c[0], a:c[1], a:attr, a:attr)
endfunction

" Okabe-Ito colourblind-safe palette: blue = good, orange/vermillion = bad.
" Uses explicit colours, so the meaning does not depend on the colorscheme.
function! s:AbaqusmsgOkabe() abort
  let dark = &background ==# 'dark'
  let blue   = dark ? ['#56B4E9', 74]  : ['#0072B2', 25]
  let orange = dark ? ['#E69F00', 178] : ['#D55E00', 166]
  let verm   = dark ? ['#FF8C42', 209] : ['#B34700', 130]
  let yellow = dark ? ['#F0E442', 227] : ['#8A6D00', 94]
  let purple = dark ? ['#CC79A7', 175] : ['#A2457A', 132]
  let green  = dark ? ['#4FC3A1', 79]  : ['#007A5E', 29]
  let grey   = dark ? ['#8A8F98', 245] : ['#7A7F87', 243]
  let fg     = dark ? ['#E6E8EB', 254] : ['#1D1F23', 235]
  call s:hi('abaqusmsgGood',        blue,   'NONE')
  call s:hi('abaqusmsgBad',         orange, 'NONE')
  call s:hi('abaqusmsgCutback',     verm,   'bold,underline')
  call s:hi('abaqusmsgWarningMsg',  yellow, 'NONE')
  call s:hi('abaqusmsgErrorMsg',    verm,   'bold')
  call s:hi('abaqusmsgNotCompleted',verm,   'bold')
  call s:hi('abaqusmsgRuntime',     verm,   'bold')
  call s:hi('abaqusmsgNoteMsg',     grey,   'italic')
  call s:hi('abaqusmsgMsgTag',      fg,     'bold')
  call s:hi('abaqusmsgSummaryBad',  orange, 'bold')
  call s:hi('abaqusmsgIterSDI',     purple, 'bold')
  call s:hi('abaqusmsgSDICount',    purple, 'NONE')
  call s:hi('abaqusmsgIterEquil',   green,  'bold')
  call s:hi('abaqusmsgIncrement',   fg,     'bold,underline')
  call s:hi('abaqusmsgCompleted',   blue,   'bold')
  call s:hi('abaqusmsgDone',        blue,   'NONE')
  call s:hi('abaqusmsgBoilerplate', grey,   'NONE')
  call s:hi('abaqusmsgSolver',      grey,   'NONE')
  call s:hi('abaqusmsgSolverStat',  grey,   'NONE')
  call s:hi('abaqusmsgAverage',     grey,   'NONE')
  call s:hi('abaqusmsgCheckLabel',  fg,     'bold')
  call s:hi('abaqusmsgNumber',      fg,     'NONE')
  call s:hi('abaqusmsgNode',        purple, 'NONE')
  call s:hi('abaqusmsgDof',         purple, 'NONE')
  call s:hi('abaqusmsgContactPair', grey,   'italic')
endfunction

function! s:AbaqusmsgHighlight() abort
  if get(g:, 'abaqusmsg_palette', 'links') ==# 'okabe'
    call s:AbaqusmsgOkabe()
  endif
  call s:AbaqusmsgLinks()     " 'hi def' only fills groups not set above
  if !get(g:, 'abaqusmsg_dim_boilerplate', 1)
    hi link abaqusmsgBoilerplate NONE
  endif
endfunction

call s:AbaqusmsgHighlight()

" ':colorscheme' clears highlighting; re-apply it for open .msg buffers
augroup abaqusmsg_highlight
  autocmd!
  autocmd ColorScheme * call s:AbaqusmsgHighlight()
augroup END

let b:current_syntax = "abaqusmsg"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 sw=2 et
