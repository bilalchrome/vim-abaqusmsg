" Detect Abaqus message files.  *.msg is also used by Outlook and others,
" so the first lines are checked for Abaqus output.
autocmd BufNewFile,BufRead *.msg,*.MSG call abaqusmsg#Detect()
