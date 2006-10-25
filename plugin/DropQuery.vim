" dropquery.vim: asks the user how a :drop'ed file be opened
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" TODO:
" - Ask whether to discard changes when user selected option "Edit" on currently modified buffer. 
" - If a file is already open in another tab, this is not recognized, and the
"   desired action will be queried from the user. All tabs should be searched
"   for the file, and the first found tab and corresponding window inside should
"   be activated. 
"
" REVISION	DATE		REMARKS 
"	0.08	25-Aug-2006	I18N: Endless loop in
"				BideSomeTimeToLetActivationComplete() on German 
"				locale; added ',' as a decimal separator. 
"	0.07	11-May-2006	VIM70: Added action 'new tab'. 
"	0.06	10-May-2006	ENH: Added BideSomeTimeToLetActivationComplete()
"				to avoid that VIM gets the focus after
"				activation, but not VIM's popup dialog. 
"	0.05	17-Feb-2006	BF: Avoid :drop command as it adds the dropped
"				file to the argument list. 
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
	" BF: Avoid :drop command as it adds the dropped file to the argument list. 
	"let l:dropActionCommand = ":drop" . " " . escape( a:filespec, ' ' ) . "|only"
	let l:dropActionCommand = ":split" . " " . escape( a:filespec, ' ' ) . "|only"
    elseif l:dropActionNr == 8
	let l:dropActionCommand = ":tabedit" . " ". a:filespec
    elseif l:dropActionNr == 9
	if has("win32")
	    let l:dropActionCommand = "silent !start gvim \"" . a:filespec . "\""
	else
	    let l:dropActionCommand = "silent ! gvim \"" . a:filespec . "\""
	endif
    elseif l:dropActionNr == 100
	" BF: Avoid :drop command as it adds the dropped file to the argument list. 
	" Do not use the :drop command to activate the window which contains the
	" dropped file. 
	"let l:dropActionCommand = ":drop" . " " . a:filespec
	let l:dropActionCommand = ":" . bufwinnr(a:filespec) . "wincmd w"
    else
	throw "Invalid dropActionNr!"
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

    if ! g:dropqueryNoDialog
	" Focus on the popup dialog requires that activation of VIM from the
	" external call has been completed, so better wait a few milliseconds to
	" avoid that VIM gets focus, but not VIM's popup dialog. This occurred
	" on Windows XP. 
	call s:BideSomeTimeToLetActivationComplete()
    endif

    let l:dropActionNr = confirm( "Action for file " . a:filespec . " ?", "&edit\n&split\n&vsplit\n&preview\n&argedit\narga&dd\n&only\nnew &tab\n&new GVIM", 1, "Question" )

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

function! s:BideSomeTimeToLetActivationComplete()
    if has("reltime")
	let l:starttime = reltime()
	while 1
	    let l:currenttime = reltimestr( reltime( l:starttime ) )
	    " Cannot compare numerically, need to do string comparison via
	    " pattern match.
	    " Desired delay is 0.2 sec. 
	    if l:currenttime =~ '^\s*\d\+[.,][23456789]'
		break
	    endif
	    " Since there is no built-in 'sleep' command, we're burning CPU
	    " cycles in this tight loop. 
	endwhile
    else
	if has("win32")
	    call system( 'hostname > NUL 2>&1' )
	else
	    call system( 'hostname > /dev/null 2>&1' )
	endif
    endif
endfunction

let &cpo = s:save_cpo

