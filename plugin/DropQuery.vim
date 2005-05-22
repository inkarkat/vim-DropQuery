" dropquery.vim: asks the user how a :drop'ed file be opened
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
" REVISION	DATE		REMARKS 
"	0.01	23-May-2005	file creation

" Avoid installing twice or when in compatible mode
if exists("loaded_dropquery")
    "TODO finish
endif
let loaded_dropquery = 1

if !exists("g:dropqueryRemapDrop")
    let g:dropqueryRemapDrop = 1
endif

"------------------------------------------------------------------------------
:command! -nargs=1 -complete=file Drop call <SID>Drop(<f-args>)

if g:dropqueryRemapDrop
    cabbrev drop Drop
endif


"------------------------------------------------------------------------------
function! s:Drop( filespec )
    let l:currentBufNr = bufnr("%")
    let l:isEmptyEditor = ( 
		\ bufname(l:currentBufNr) == "" && 
		\ s:IsBufTheOnlyWin(l:currentBufNr) && 
		\ getbufvar(l:currentBufNr, "&modified") == 0 && 
		\ getbufvar(l:currentBufNr, "&buftype") == "" 
		\)
    if l:isEmptyEditor
	let l:dropActionNr = 1
    else
	let l:dropActionNr = s:QueryActionNr( a:filespec )
    endif

    if l:dropActionNr == 0
	echohl WarningMsg
	echo "Canceled opening of file " . a:filespec
	echohl None
	return
    elseif l:dropActionNr == 1
	let l:dropActionCommand = ":edit" . " " . a:filespec
    elseif l:dropActionNr == 2
	let l:dropActionCommand = ":split" . " " . a:filespec
    elseif l:dropActionNr == 3
	let l:dropActionCommand = ":vsplit" . " " . a:filespec
    elseif l:dropActionNr == 4
	let l:dropActionCommand = ":pedit" . " " . a:filespec
    endif

    execute l:dropActionCommand 
endfunction


function! s:IsBufTheOnlyWin( bufnr )
    let l:bufIdx = bufnr("$")
    while l:bufIdx > 0
	if l:bufIdx != a:bufnr
	    if bufwinnr(l:bufIdx) != -1
		return 0
	    endif
	endif
	let l:bufIdx = l:bufIdx - 1
    endwhile
    return 1
endfunction

function! s:QueryActionNr( filespec )
    let l:dropActionNr = confirm( "Action for file " . a:filespec . " ?", "&edit\n&split\n&vsplit\n&preview", 1, "Question" )
    return l:dropActionNr

    " Note: The dialog in the GUI version can be avoided by :set guioptions-=c
    "
    "echohl Question
    "let l:dropActionResponse = input( "[e]dit, (s)plit, (v)split, (p)review " . a:filespec . "? " )
    "echohl None
endfunction

