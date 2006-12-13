" dropquery.vim: asks the user how a :drop'ed file be opened
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" DEPENDENCIES:
"   - Requires VIM 7.0. 
"
" LIMITATIONS:
"
" TODO:
" - Ask whether to discard changes when user selected option "Edit" on currently modified buffer. 
" - If a file is already open in another tab, this is not recognized, and the
"   desired action will be queried from the user. All tabs should be searched
"   for the file, and there should be an option "Goto tab" should be presented. 
"
" REVISION	DATE		REMARKS 
"	0.22	28-Nov-2006	Removed limitation to 20 dropped files: 
"				Switched main filespec format from normal to ex
"				syntax; VIM commands and user display use
"				s:ConvertFilespecInExSyntaxToNormalFilespec() to
"				unescape the ex syntax; that was formerly done
"				by -complete=file. 
"				Multiple files are passed as one string
"				(-nargs=1, and splitting is done inside the
"				s:Drop() function. 
"	0.21	16-Nov-2006	BF: '%' and '#' must also be escaped for VIM. 
"	0.20	15-Nov-2006	Added support for multiple files passed to
"				:Drop, making it fully compatible with the
"				built-in :drop command. 
"				Action 'argadd' now appends to the argument
"				list instead of inserting at the current
"				position. 
"				ENH: Printing current args after modifications
"				to the argument-list. 
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

if has("win32")
    let s:exCommandForExternalGvim = 'silent !start gvim'
else
    let s:exCommandForExternalGvim = 'silent ! gvim'
endif

"-- functions -----------------------------------------------------------------
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

function! s:SaveGuiOptions()
    let l:savedGuiOptions = ''
    if has("gui") && g:dropqueryNoDialog
	" Note: The dialog in the GUI version can be avoided by :set guioptions+=c
	let l:savedGuiOptions = &guioptions
	set guioptions+=c
    endif

    if ! g:dropqueryNoDialog
	" Focus on the popup dialog requires that activation of VIM from the
	" external call has been completed, so better wait a few milliseconds to
	" avoid that VIM gets focus, but not VIM's popup dialog. This occurred
	" on Windows XP. 
	sleep 200m
    endif
    return l:savedGuiOptions
endfunction

function! s:RestoreGuiOptions( savedGuiOptions )
    if has("gui") && g:dropqueryNoDialog
	let &guioptions = a:savedGuiOptions
    endif
endfunction

function! s:QueryActionNrForSingleFile( filespec )
    let l:savedGuiOptions = s:SaveGuiOptions()

    let l:dropActionNr = confirm( "Action for file " . a:filespec . " ?", "&edit\n&split\n&vsplit\n&preview\n&argedit\narga&dd\n&only\nnew &tab\n&new GVIM", 1, "Question" )

    call s:RestoreGuiOptions( l:savedGuiOptions )
    return l:dropActionNr
endfunction

function! s:QueryActionNrForMultipleFiles( fileNum )
    let l:savedGuiOptions = s:SaveGuiOptions()

    let l:dropActionNr = confirm( "Action for " . a:fileNum . " dropped files?", "arga&dd\n&argedit\n&split\n&vsplit\nnew &tab\n&new GVIM", 1, "Question" )

    call s:RestoreGuiOptions( l:savedGuiOptions )
    return l:dropActionNr
endfunction

function! s:IsVisibleWindow( filespec )
    let l:winNr = bufwinnr( a:filespec )
    return l:winNr != -1
endfunction

function! s:ExecuteForEachFile( excommand, isQuoteFilespec, filespecs )
"*******************************************************************************
"* PURPOSE:
"   Executes a:excommand for each filespec in a:filespecs. 
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:isQuoteFilespec	Flag whether the filespec should be double-quoted. This
"			is necessary if an external GVIM instance is started, as
"			the shell gets invoked. The filespec must still be in
"			ex syntax, though, as [%#] are interpreted inside the
"			ex command. 
"   a:filespecs		List of filespecs in ex syntax. 
"* RETURN VALUES: 
"   none
"*******************************************************************************
    for l:filespec in a:filespecs
	if a:isQuoteFilespec
	    let l:filespec = '"' . l:filespec . '"'
	endif
	execute a:excommand . ' ' . l:filespec
    endfor
endfunction

function! s:ConvertFilespecInExSyntaxToNormalFilespec( filespecInExSyntax )
"*******************************************************************************
"* PURPOSE:
"   Converts the passed a:filespecInExSyntax to the normal filespec syntax
"   (i.e. no escaping of [%#], possibly backslashes as path separator). The
"   normal syntax is required by VIM functions such as bufwinnr(), because they
"   do not understand the escaping of [%#] for ex commands. 
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"	? Explanation of each argument that isn't obvious.
"* RETURN VALUES: 
"	? Explanation of the value returned.
"*******************************************************************************
    "return fnamemodify( substitute( a:filespecInExSyntax, '\\\([ \\%#]\)', '\1', 'g'), ':p' )
    return fnamemodify( a:filespecInExSyntax, ':gs+\\\([ \\%#]\)+\1+:p' )
endfunction

function! s:DropSingleFile( filespecInExSyntax )
"*******************************************************************************
"* PURPOSE:
"   Prompts the user for the action to be taken with the dropped file. 
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:filespecInExSyntax filespec of the dropped file. 
"* RETURN VALUES: 
"   none
"*******************************************************************************
"****D echo '**** Dropped filespec is "' . a:filespecInExSyntax . '". '

    if s:IsEmptyEditor()
	let l:dropActionNr = 1
    elseif s:IsVisibleWindow( s:ConvertFilespecInExSyntaxToNormalFilespec(a:filespecInExSyntax) )
	let l:dropActionNr = 100
    else
	let l:dropActionNr = s:QueryActionNrForSingleFile( s:ConvertFilespecInExSyntaxToNormalFilespec(a:filespecInExSyntax) )
    endif

    " BF: HP-UX GVIM 6.3 confirm() returns -1 instead of 0 when dialog is aborted. 
    if l:dropActionNr <= 0
	echohl WarningMsg
	echo 'Canceled opening of file ' . s:ConvertFilespecInExSyntaxToNormalFilespec(a:filespecInExSyntax)
	echohl None
	return
    elseif l:dropActionNr == 1
	execute ':edit' . ' ' . a:filespecInExSyntax
    elseif l:dropActionNr == 2
	execute ':belowright split' . ' ' . a:filespecInExSyntax
    elseif l:dropActionNr == 3
	execute ':belowright vsplit' . ' ' . a:filespecInExSyntax
    elseif l:dropActionNr == 4
	execute ':pedit' . ' ' . a:filespecInExSyntax
    elseif l:dropActionNr == 5
	execute ':argedit' . ' ' . a:filespecInExSyntax
	args
    elseif l:dropActionNr == 6
	execute ':999argadd' . ' ' . a:filespecInExSyntax
	args
    elseif l:dropActionNr == 7
	" BF: Avoid :drop command as it adds the dropped file to the argument list. 
	"execute ':drop' . ' ' . a:filespecInExSyntax . '|only'
	execute ':split' . ' ' . a:filespecInExSyntax . '|only'
    elseif l:dropActionNr == 8
	execute ':tabedit' . ' '. a:filespecInExSyntax
    elseif l:dropActionNr == 9
	execute s:exCommandForExternalGvim . ' "' . a:filespecInExSyntax . '"'
    elseif l:dropActionNr == 100
	" BF: Avoid :drop command as it adds the dropped file to the argument list. 
	" Do not use the :drop command to activate the window which contains the
	" dropped file. 
	"execute ":drop" . " " . a:filespecInExSyntax
	execute ':' . bufwinnr(s:ConvertFilespecInExSyntaxToNormalFilespec(a:filespecInExSyntax)) . 'wincmd w'
    else
	throw 'Invalid dropActionNr!'
    endif
endfunction

function! s:Drop( filespecInExSyntaxString )
    let l:filespecs = split( a:filespecInExSyntaxString, '\\\@<! ')
    if empty( l:filespecs )
	throw 'Must pass at least one filespec!'
    elseif len( l:filespecs ) == 1
	call s:DropSingleFile( a:filespecInExSyntaxString )
	return
    endif

    let l:dropActionNr = s:QueryActionNrForMultipleFiles( len(l:filespecs) )

    if l:dropActionNr <= 0
	echohl WarningMsg
	echo 'Canceled opening of ' . len(l:filespecs) . ' files. '
	echohl None
	return
    elseif l:dropActionNr == 1
	execute '999argadd' . ' ' . a:filespecInExSyntaxString
	args
    elseif l:dropActionNr == 2
	execute 'args' . ' ' . a:filespecInExSyntaxString
	args
    elseif l:dropActionNr == 3
	call s:ExecuteForEachFile( 'belowright split', 0, l:filespecs )
    elseif l:dropActionNr == 4
	call s:ExecuteForEachFile( 'belowright vsplit', 0, l:filespecs )
    elseif l:dropActionNr == 5
	call s:ExecuteForEachFile( 'tabedit', 0, l:filespecs )
    elseif l:dropActionNr == 6
	call s:ExecuteForEachFile( s:exCommandForExternalGvim, 1, l:filespecs )
    else
	throw "Invalid dropActionNr!"
    endif
endfunction

"-- commands ------------------------------------------------------------------
" The filespec passed to :drop should conform to ex syntax, just as the
" built-in :drop command would expect them:
" - spaces, [%#] are escaped with '\'
" - path delimiters are forward slashes; backslashes are only used for
"   escaping. 
" - no enclosing of filespecs in double quotes
"
" Note to -nargs=1:
" A maximum of 20 arguments can be passed to a Vim function. The built-in :drop
" command supports more files, though. To work around this limitation, all
" files are passed to the s:Drop() function as one string; the function itself
" will split that into filespecs. Splitting is done on (unescaped) spaces, as
" the filespecs to :drop are not enclosed by double quotes, but contain escaped
" spaces. 
:command! -nargs=1 Drop call <SID>Drop(<f-args>)

if g:dropqueryRemapDrop
    cabbrev drop Drop
endif

let &cpo = s:save_cpo

