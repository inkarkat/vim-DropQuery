" dropquery.vim: asks the user how a :drop'ed file be opened
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" DEPENDENCIES:
"   - Requires VIM 7.0. 
"
" TODO:
" - Ask whether to discard changes when user selected option "Edit" on currently modified buffer. 
" - If a file is already open in another tab, this is not recognized, and the
"   desired action will be queried from the user. All tabs should be searched
"   for the file, and the first found tab and corresponding window inside should
"   be activated. 
"
" REVISION	DATE		REMARKS 
"	0.10	02-Nov-2006	Documented function arguments and the
"				-complete=file option. 
"				Better escaping of passed filespec. 
"				Now requiring VIM 7.0. 
"	0.09	26-Oct-2006	ENH: Learned from a VimTip that VIM does have a
"				built-in sleep comand; replaced clumsy function 
"				BideSomeTimeToLetActivationComplete(). 
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
if exists("loaded_dropquery") || (v:version < 700)
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

"-- functions -----------------------------------------------------------------
function! s:Drop( filespec )
"*******************************************************************************
"* PURPOSE:
"   Prompts the user for the action to be taken with the dropped file. 
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:filespec filespec of the dropped file. The syntax will be operating-system
"	specific due to the 'command -complete=file' option. 
"* RETURN VALUES: 
"   none
"*******************************************************************************
    let l:fileSpecInVimSyntax = escape( tr( a:filespec, '\', '/' ), ' \')
"****D echo '**** Dropped filespec is "' . a:filespec . '", in VIM syntax "' . l:fileSpecInVimSyntax . '". '

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
	let l:dropActionCommand = ":edit" . " " . l:fileSpecInVimSyntax
    elseif l:dropActionNr == 2
	let l:dropActionCommand = ":belowright split" . " " . l:fileSpecInVimSyntax
    elseif l:dropActionNr == 3
	let l:dropActionCommand = ":belowright vsplit" . " " . l:fileSpecInVimSyntax
    elseif l:dropActionNr == 4
	let l:dropActionCommand = ":pedit" . " " . l:fileSpecInVimSyntax
    elseif l:dropActionNr == 5
	let l:dropActionCommand = ":argedit" . " " . l:fileSpecInVimSyntax
    elseif l:dropActionNr == 6
	let l:dropActionCommand = ":argadd" . " " . l:fileSpecInVimSyntax
    elseif l:dropActionNr == 7
	" BF: Avoid :drop command as it adds the dropped file to the argument list. 
	"let l:dropActionCommand = ":drop" . " " . l:fileSpecInVimSyntax . "|only"
	let l:dropActionCommand = ":split" . " " . l:fileSpecInVimSyntax . "|only"
    elseif l:dropActionNr == 8
	let l:dropActionCommand = ":tabedit" . " ". l:fileSpecInVimSyntax
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
	"let l:dropActionCommand = ":drop" . " " . l:fileSpecInVimSyntax
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
	sleep 200m
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

"-- commands ------------------------------------------------------------------
" The filespec passed to :drop should conform to VIM syntax, just as the
" built-in :drop command would expect them:
" - spaces are escaped with '\'
" - path delimiters are forward slashes; backslashed are only used for
"   escaping. 
" - no enclosing of filespecs in double quotes
"
" Note to -complete=file:
" With this option, VIM (7.0) automatically converts the passed filespec to the
" typical syntax of the current operating-system (i.e. backslashes on Windows,
" no escaping of spaces on neither Unix nor Windows), and expands shell
" wildcards such as '?' and '*'. Without this option, the filespec would be
" passed as-is. 
"
" Note to -nargs=1: 
" :drop supports passing of multiple files, which are then added to the
" argument-list. This functionality cannot be supported, because the filespecs
" to :drop are not enclosed by double quotes, but have escaped spaces instead. 
" Fortunately, this functionality is seldomly used. 
:command! -nargs=1 -complete=file Drop call <SID>Drop(<f-args>)

if g:dropqueryRemapDrop
    cabbrev drop Drop
endif

let &cpo = s:save_cpo

