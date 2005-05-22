" dropquery.vim: asks the user how a :drop'ed file be opened
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
" REVISION	DATE		REMARKS 
"	0.01	23-May-2005	file creation

" Avoid installing twice or when in compatible mode
if exists("loaded_dropquery")
    finish
endif
let loaded_dropquery = 1

"-- global configuration ------------------------------------------------------
if !exists("g:dropqueryRemapDrop")
    " If set, remaps the built-in ':drop' command to use ':Drop' instead. 
    " With this option, other integrations (e.g. VisVim) need not be modified to
    " use the dropquery functionality. 
    let g:dropqueryRemapDrop = 1
endif

if !exists("g:dropqueryNoDialog")
    " If set, never uses a pop-up dialog in the GUI VIM. Instead, a textual
    " query (as is done in the console VIM) is used. 
    let g:dropqueryNoDialog = 0
endif

"-- commands ------------------------------------------------------------------
" Note to -nargs=1: 
" :drop supports passing of multiple files, which are then added to the
" argument-list. This functionality cannot be supported, because the filespecs
" to :drop are not enclosed by double quotes, but have escaped spaces instead. 
" Fortunately, this functionality is seldomly used. 
:command! -nargs=1 -complete=file Drop call <SID>Drop(<f-args>)

if g:dropqueryRemapDrop
    cabbrev drop Drop
endif


"-- functions -----------------------------------------------------------------
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
    elseif l:dropActionNr == 5
	let l:dropActionCommand = ":argedit" . " " . escape( a:filespec, ' ' )
    elseif l:dropActionNr == 6
	let l:dropActionCommand = ":argadd" . " " . escape( a:filespec, ' ' )
    elseif l:dropActionNr == 7
	let l:dropActionCommand = ":drop" . " " . escape( a:filespec, ' ' ) . "|only"
    else
	assert 0
	return
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
    if has("gui") && g:dropqueryNoDialog
	" Note: The dialog in the GUI version can be avoided by :set guioptions+=c
	let l:savedGuioptions = &guioptions
	set guioptions+=c
    endif

    let l:dropActionNr = confirm( "Action for file " . a:filespec . " ?", "&edit\n&split\n&vsplit\n&preview\n&argedit\narga&dd\n&only", 1, "Question" )

    if has("gui") && g:dropqueryNoDialog
	let &guioptions = l:savedGuioptions
    endif

    return l:dropActionNr
endfunction

