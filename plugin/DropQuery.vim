" DropQuery.vim: Ask the user how a :drop'ped file be opened.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" DEPENDENCIES:
"   - Requires Vim 7.0 or higher.
"   - ingo-library.vim plugin
"
" Copyright: (C) 2005-2021 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.

" Avoid installing twice or when in unsupported Vim version.
if exists('g:loaded_DropQuery') || (v:version < 700)
    finish
endif
let g:loaded_DropQuery = 1

"-- configuration -------------------------------------------------------------

if ! exists('g:DropQuery_RemapDrop')
    let g:DropQuery_RemapDrop = 1
endif
if ! exists('g:DropQuery_NoPopup')
    let g:DropQuery_NoPopup = 0
endif
if ! exists('g:DropQuery_MoveAwayPredicates')
    let g:DropQuery_MoveAwayPredicates = []
endif
if ! exists('g:DropQuery_ExemptPredicates')
    let g:DropQuery_ExemptPredicates = ['&buftype ==# "terminal"']
endif
if ! exists('g:DropQuery_PopupFocusCommand')
    " Focus on the popup dialog requires that activation of Vim from the
    " external call has been completed, so better wait a few milliseconds to
    " avoid that Vim gets focus, but not Vim's popup dialog. This occurred on
    " Windows XP.
    " The sleep workaround still doesn't work all the time on Windows XP. I've
    " empirically found out that I get better luck if foreground() is called
    " before the delay, or maybe I'm just fooled once more. This whole stuff
    " reminds me of witchcraft, not engineering :-)
    let g:DropQuery_PopupFocusCommand = 'call foreground() | sleep 300m'
endif
if ! exists('g:DropQuery_FilespecProcessor')
    let g:DropQuery_FilespecProcessor = ''
endif



"-- commands ------------------------------------------------------------------

" The file pattern passed to :drop should conform to Ex syntax, just as the
" built-in :drop command would expect them:
" - spaces, [%#] etc. are escaped with '\'
" - no enclosing of filespecs in double quotes
" - It is recommended that path delimiters are forward slashes; backslashes are
"   only used for escaping.
"
" A maximum of 20 arguments can be passed to a Vim function. The built-in :drop
" command supports more, though. To work around this limitation, everything is
" passed to the s:Drop() function as one string by using <q-args> instead of
" <f-args>; the function itself will split that into file patterns. Splitting is
" done on (unescaped) spaces, as the file patterns to :drop are not enclosed by
" double quotes, but contain escaped spaces. This also avoids the unescaping
" peculiarities of <f-args>, which make it fundamentally unsuitable for file
" arguments.
" We do specify multiple arguments, so that file completion works for all
" arguments.
command! -bang -range=-1 -nargs=* -complete=file Drop if ! DropQuery#Drop(<bang>0, <q-args>, (<count> == -1 ? [] : [<line1>, <line2>]))| echoerr ingo#err#Get() | endif

command! -bang -count=0 -nargs=? -complete=buffer BufDrop if ! DropQuery#DropBuffer(<bang>0, <count>, <f-args>) | echoerr ingo#err#Get() | endif

if g:DropQuery_RemapDrop
    cabbrev <expr> drop (getcmdtype() == ':' && strpart(getcmdline(), 0, getcmdpos() - 1) =~# '^\s*drop$' ? 'Drop' : 'drop')
endif

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
