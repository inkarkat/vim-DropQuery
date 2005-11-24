" dropquery.vim: asks the user how a :drop'ed file be opened
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" TODO:
" - Ask whether to discard changes when user selected option "Edit" on currently modified buffer. 
"
" REVISION	DATE		REMARKS 
"	0.04	15-Aug-2005	Added action 'new GVIM' to launch the file in a
"				new GVIM instance. Requires that 'gvim' is
"				accessible through $PATH. (Action 'new VIM'
"				doesn't make much sense, because a new terminal
"				window would be required, too.)
"				BF: HP-UX GVIM 6.3 confirm() returns -1 instead
"				of 0 when dialog is aborted. 
"       0.03    18-Jul-2005     Added preference ':belowright' for both splits. 
"                               In general, I'd like to keep the default
"                               ':set nosplitbelow', though. 
"	0.02	01-Jun-2005	ENH: if dropped file is already visible; simply
"				activate the corresponding window. 
"	0.01	23-May-2005	file creation

" Avoid installing twice or when in compatible mode
if exists("loaded_dropquery")
    finish
endif
let loaded_dropquery = 1

let s:save_cpo = &cpo
set cpo&vim

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
    if s:IsEmptyEditor()
	let l:dropActionNr = 1
    elseif s:IsVisibleWindow( a:filespec )
	let l:dropActionNr = 100
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
	let l:dropActionCommand = ":belowright split" . " " . a:filespec
    elseif l:dropActionNr == 3
	let l:dropActionCommand = ":belowright vsplit" . " " . a:filespec
    elseif l:dropActionNr == 4
	let l:dropActionCommand = ":pedit" . " " . a:filespec
    elseif l:dropActionNr == 5
	let l:dropActionCommand = ":argedit" . " " . escape( a:filespec, ' ' )
    elseif l:dropActionNr == 6
	let l:dropActionCommand = ":argadd" . " " . escape( a:filespec, ' ' )
    elseif l:dropActionNr == 7
	let l:dropActionCommand = ":drop" . " " . escape( a:filespec, ' ' ) . "|only"
    elseif l:dropActionNr == 8
	if has("win32")
	    let l:dropActionCommand = "silent !start gvim \"" . a:filespec . "\""
	else
	    let l:dropActionCommand = "silent ! gvim \"" . a:filespec . "\""
	endif
    elseif l:dropActionNr == 100
	" Use the :drop command to activate the window which contains the
	" dropped file. 
	let l:dropActionCommand = ":drop" . " " . a:filespec
	"let l:dropActionCommand = ":" . bufwinnr(a:filespec) . "wincmd w"
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

function! s:IsEmptyEditor()
    let l:currentBufNr = bufnr("%")
    let l:isEmptyEditor = ( 
		\ bufname(l:currentBufNr) == "" && 
		\ s:IsBufTheOnlyWin(l:currentBufNr) && 
		\ getbufvar(l:currentBufNr, "&modified") == 0 && 
		\ getbufvar(l:currentBufNr, "&buftype") == "" 
		\)
    return l:isEmptyEditor
endfunction

function! s:QueryActionNr( filespec )
    if has("gui") && g:dropqueryNoDialog
	" Note: The dialog in the GUI version can be avoided by :set guioptions+=c
	let l:savedGuioptions = &guioptions
	set guioptions+=c
    endif

    let l:dropActionNr = confirm( "Action for file " . a:filespec . " ?", "&edit\n&split\n&vsplit\n&preview\n&argedit\narga&dd\n&only\n&new GVIM", 1, "Question" )

    " BF: HP-UX GVIM 6.3 confirm() returns -1 instead of 0 when dialog is aborted. 
    if l:dropActionNr < 0
	let l:dropActionNr = 0
    endif

    if has("gui") && g:dropqueryNoDialog
	let &guioptions = l:savedGuioptions
    endif

    return l:dropActionNr
endfunction

function! s:IsVisibleWindow( filespec )
    let l:winNr = bufwinnr( a:filespec )
    return l:winNr != -1
endfunction

let &cpo = s:save_cpo

