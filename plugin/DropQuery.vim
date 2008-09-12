" dropquery.vim: Ask the user how a :drop'ed file be opened. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" DEPENDENCIES:
"   - Requires VIM 7.0 or higher. 
"
" LIMITATIONS:
"
" TODO:
"   - Handle ++enc=... and +cmd=... as part of the :drop command. 
"
" REVISION	DATE		REMARKS 
"	029	14-Jul-2008	BF: Including 'wildignore'd files if they are
"				explicitly passed, but not if they would match a
"				file pattern. 
"	028	09-Jul-2008	BF: Properly anchoring filespecs for bufnr() and
"				bufwinnr() commands via
"				s:EscapeNormalFilespecForBufCommand() to avoid
"				that dropping 'test.txt' jumps to
"				'test.txt.20080709a' because of the partial
"				match. 
"				Working around the fact that glob() hides
"				'wildignore'd files by using filereadable(). 
"				ENH: Correctly handling file-patterns (e.g.
"				*.txt) now. 
"	027	28-Jun-2008	Added Windows detection via has('win64'). 
"	026	23-Feb-2008	Replaced s:IsEmptyEditor() with
"				s:IsEmptyTabPage(), which is equivalent but more
"				straightforward. 
"				ENH: When multiple files are dropped on an empty
"				tab page, the empty window is re-used for
"				:[v]split and :tabedit actions (i.e. the first
"				file is :edited instead of :split). 
"				ENH: Offer to "open new tab and ask again" when
"				multiple files are dropped. This allows to
"				[v]split all dropped files in a separate tab. 
"	025	16-Nov-2007	ENH: Check for existence of a single dropped
"				file, and change first query action from "edit"
"				to "create" to provide a subtle hint to the
"				user. 
"				Renamed configuration variables to
"				g:dropquery_... for consistency with other
"				plugins. 
"				ENH: Asking whether to discard changes when the
"				action would abandon a currently modified
"				buffer (via :confirm). 
"				ENH: If a (single) file is already open in
"				another tab, an additional action "goto tab" is
"				prepended to the list of possible actions. 
"				Action "new tab" now adds the tab at the very
"				end, not after the current tab. This is more
"				intuitive, because you typically don't think
"				about tab pages when dropping a file. 
"	024	04-Jun-2007	BF: Single file action "new GVIM" didn't work on
"				Unix, because the filespec is passed in ex
"				syntax (i.e. spaces escaped by backslashes),
"				enclosed in double quotes. Thus, spaces were
"				quoted/escaped twice. On Windows, however,
"				filespecs must be double-quoted. Introduced
"				s:EscapeNormalFilespecForExCommand(); the
"				filespec for the external GVIM command is now
"				double-quoted and processed through
"				s:EscapeNormalFilespecForExCommand( s:ConvertExfilespecToNormalFilespec( filespec ) ). 
"				BF: In the :! ex command, the character '!' must
"				also be escaped. (It stands for the previously
"				executed :! command.) Now escaping [%#!] in
"				s:EscapeNormalFilespecForExCommand(). 
"	0.23	14-Dec-2006	Added foreground() call to :sleep to hopefully 
"				achieve dialog focus on activation. 
"	0.22	28-Nov-2006	Removed limitation to 20 dropped files: 
"				Switched main filespec format from normal to ex
"				syntax; VIM commands and user display use
"				s:ConvertExfilespecToNormalFilespec() to
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
"	0.09	26-Oct-2006	ENH: Learned from a vimtip that VIM does have a
"				built-in :sleep comand; replaced clumsy function 
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
if exists('g:loaded_dropquery') || (v:version < 700)
    finish
endif
let g:loaded_dropquery = 1

let s:save_cpo = &cpo
set cpo&vim

"-- global configuration ------------------------------------------------------
if !exists('g:dropquery_RemapDrop')
    " If set, remaps the built-in ':drop' command to use ':Drop' instead. 
    " With this option, other integrations (e.g. VisVim) need not be modified to
    " use the dropquery functionality. 
    let g:dropquery_RemapDrop = 1
endif

if !exists('g:dropquery_NoPopup')
    " If set, doesn't use a pop-up dialog in GVIM for the query. Instead, a
    " textual query (as is done in the console VIM) is used. This does not cover
    " the :confirm query "Save changes to...?" when abandoning modified buffers. 
    let g:dropquery_NoPopup = 0
endif

if has('win32') || has('win64')
    let s:exCommandForExternalGvim = 'silent !start gvim'
else
    let s:exCommandForExternalGvim = 'silent ! gvim'
endif

"-- functions -----------------------------------------------------------------
function! s:IsEmptyTabPage()
    let l:currentBufNr = bufnr('%')
    let l:isEmptyTabPage = ( 
		\ empty( bufname(l:currentBufNr) ) && 
		\ tabpagewinnr(tabpagenr(), '$') <= 1 && 
		\ getbufvar(l:currentBufNr, '&modified') == 0 && 
		\ empty( getbufvar(l:currentBufNr, '&buftype') )
		\)
    return l:isEmptyTabPage
endfunction

function! s:SaveGuiOptions()
    let l:savedGuiOptions = ''
    if has('gui') && g:dropquery_NoPopup
	let l:savedGuiOptions = &guioptions
	set guioptions+=c   " Temporarily avoid popup dialog. 
    endif

    if ! g:dropquery_NoPopup
	" Focus on the popup dialog requires that activation of VIM from the
	" external call has been completed, so better wait a few milliseconds to
	" avoid that VIM gets focus, but not VIM's popup dialog. This occurred
	" on Windows XP. 
	" The sleep workaround still doesn't work all the time on Windows XP.
	" I've empirically found out that I get better luck if foreground() is
	" called before the delay, or maybe I'm just fooled once more. 
	" This whole stuff reminds me of witchcraft, not engineering :-)
	call foreground()
	sleep 200m
    endif
    return l:savedGuiOptions
endfunction

function! s:RestoreGuiOptions( savedGuiOptions )
    if has('gui') && g:dropquery_NoPopup
	let &guioptions = a:savedGuiOptions
    endif
endfunction

function! s:QueryActionNrForSingleFile( filespec, isOpenInAnotherTabPage )
    let l:savedGuiOptions = s:SaveGuiOptions()

    " The :edit command can be used to both edit an existing file and create a
    " new file. We'd like to distinguish between the two in the query, however. 
    " The changed action label "Create" offers a subtle hint that the dropped
    " file does not exist. This way, the user can cancel the dropping if he
    " doesn't want to create a new file (and mistakenly thought the dropped file
    " already existed). 
    let l:editAction = empty( filereadable( a:filespec ) ) ? '&create' : '&edit'
    let l:actions = l:editAction . "\n&split\n&vsplit\n&preview\n&argedit\narga&dd\n&only\nnew &tab\n&new GVIM"
    if a:isOpenInAnotherTabPage
	let l:actions = "&goto tab\n" . l:actions
    endif

    let l:dropActionNr = confirm( 'Action for file ' . a:filespec . ' ?', l:actions, 1, 'Question' )

    call s:RestoreGuiOptions( l:savedGuiOptions )

    " Resort action numbers, considering that "goto tab" (#10) went to #1 in the
    " list. 
    if a:isOpenInAnotherTabPage
	if l:dropActionNr == 1
	    let l:dropActionNr = 10
	elseif l:dropActionNr > 1
	    let l:dropActionNr -= 1
	endif
    endif

    return l:dropActionNr
endfunction

function! s:QueryActionNrForMultipleFiles( fileNum )
    let l:savedGuiOptions = s:SaveGuiOptions()

    while 1
	let l:dropActionNr = confirm( 'Action for ' . a:fileNum . ' dropped files?', "arga&dd\n&argedit\n&split\n&vsplit\nnew &tab\n&new GVIM\n&open new tab and ask again", 1, 'Question' )
	if l:dropActionNr == 7
	    tabnew
	else
	    break
	endif
    endwhile

    call s:RestoreGuiOptions( l:savedGuiOptions )
    return l:dropActionNr
endfunction

function! s:IsVisibleWindow( filespec )
    let l:winNr = bufwinnr( s:EscapeNormalFilespecForBufCommand(a:filespec) )
    return l:winNr != -1
endfunction

function! s:GetTabPageNr( filespec )
"*******************************************************************************
"* PURPOSE:
"   If a:filespec has been loaded into a buffer that is visible on another tab
"   page, return the tab page number. 
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:filespec
"* RETURN VALUES: 
"   tab page number of the first tab page (other than the current one) where the
"   buffer is visible; else -1. 
"*******************************************************************************
    if tabpagenr('$') == 1
	return -1   " There's only one tab. 
    endif

    let l:targetBufNr = bufnr( s:EscapeNormalFilespecForBufCommand(a:filespec) )
    if l:targetBufNr == -1
	return -1   " There's no such buffer. 
    endif

    for l:tabPage in range( 1, tabpagenr('$') )
	if l:tabPage == tabpagenr()
	    continue	" Skip current tab page. 
	endif
	for l:bufNr in tabpagebuflist( l:tabPage )
	    if l:bufNr == l:targetBufNr
		return l:tabPage	" Found the buffer on this tab page. 
	    endif
	endfor
    endfor
    return -1
endfunction

function! s:ExecuteForEachFile( excommand, specialFirstExcommand, isQuoteFilespec, exfilespecs )
"*******************************************************************************
"* PURPOSE:
"   Executes a:excommand for each filespec in a:exfilespecs. 
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:excommand		    ex command which will be invoked with each filespec. 
"   a:specialFirstExcommand ex command which will be invoked for the first filespec. 
"			    If empty, the a:excommand will be invoked for the
"			    first filespec just like any other. 
"   a:isQuoteFilespec	    Flag whether the filespec should be double-quoted. 
"   a:exfilespecs	    List of filespecs in ex syntax. 
"* RETURN VALUES: 
"   none
"*******************************************************************************
    let l:excommand = empty(a:specialFirstExcommand) ? a:excommand : a:specialFirstExcommand
    for l:exfilespec in a:exfilespecs
	if a:isQuoteFilespec
	    let l:exfilespec = '"' . s:EscapeNormalFilespecForExCommand( s:ConvertExfilespecToNormalFilespec(l:exfilespec), l:excommand ) . '"'
	endif
	execute l:excommand . ' ' . l:exfilespec
	let l:excommand = a:excommand
    endfor
endfunction

function! s:ConvertExfilespecToNormalFilespec( exfilespec )
"*******************************************************************************
"* PURPOSE:
"   Converts the passed a:exfilespec to the normal filespec syntax (i.e. no
"   escaping of [%#], possibly backslashes as path separator). The normal syntax
"   is required by VIM functions such as bufwinnr(), because they do not
"   understand the escaping of [%#] for ex commands. 
"   Note: On Windows, fnamemodify() doesn't convert path separators to
"   backslashes. We don't do that neither, as forward slashes work just as well
"   and there is less potential for problems. 
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"	? Explanation of each argument that isn't obvious.
"* RETURN VALUES: 
"	? Explanation of the value returned.
"*******************************************************************************
    "return fnamemodify( substitute( a:exfilespec, '\\\([ \\%#]\)', '\1', 'g'), ':p' )
    return fnamemodify( a:exfilespec, ':gs+\\\([ \\%#]\)+\1+:p' )
endfunction

function! s:EscapeNormalFilespecForExCommand( filespec, excommand )
"*******************************************************************************
"* PURPOSE:
"   Escaped a normal filespec syntax so that it can be used in the ':! command
"   "filespec"' ex command. For ex commands, [%#] must be escaped; for the ':!'
"   ex command, the [!] character must be escaped, too, because it stands for
"   the previously execute :! command. 
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:filespec	    normal filespec
"   a:excommand	    ex command for which a:filespec should be escaped. Can be
"		    empty, which signifies any vanilla ex command. There's only
"		    a special case for the :! command. 
"* RETURN VALUES: 
"	? Explanation of the value returned.
"*******************************************************************************
    let l:isBangCommand = (a:excommand =~# '^\s*\%(silent\s\+\)\?!')
echomsg '****' a:excommand l:isBangCommand
    return substitute( a:filespec, '[\\%#' . (l:isBangCommand ? '!' : '') . ']', '\\\0', 'g' )
endfunction

function! s:EscapeNormalFilespecForBufCommand( filespec )
"*******************************************************************************
"* PURPOSE:
"   Escape a normal filespec syntax so that it can be used for the bufname(),
"   bufnr(), bufwinnr(), ... commands. 
"   The filespec must be anchored to ^ and $, and special file-pattern
"   characters must be escaped. The special filenames '#' and '%' need not be
"   escaped when they are anchored or occur within a longer filespec. 
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"	? Explanation of each argument that isn't obvious.
"* RETURN VALUES: 
"	? Explanation of the value returned.
"*******************************************************************************
    return '^' . escape(a:filespec, '*?,{}[]\') . '$'
endfunction

function! s:DropSingleFile( exfilespec )
"*******************************************************************************
"* PURPOSE:
"   Prompts the user for the action to be taken with the dropped file. 
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:exfilespec filespec of the dropped file. 
"* RETURN VALUES: 
"   none
"*******************************************************************************
"****D echo '**** Dropped filespec is "' . a:exfilespec . '". '
    let l:filespec = s:ConvertExfilespecToNormalFilespec(a:exfilespec)

    if s:IsEmptyTabPage()
	let l:dropActionNr = 1
    elseif s:IsVisibleWindow(l:filespec)
	let l:dropActionNr = 100
    else
	let l:tabPageNr = s:GetTabPageNr(l:filespec)
	let l:dropActionNr = s:QueryActionNrForSingleFile( l:filespec, (l:tabPageNr != -1) )
    endif

    " BF: HP-UX GVIM 6.3 confirm() returns -1 instead of 0 when dialog is aborted. 
    if l:dropActionNr <= 0
	echohl WarningMsg
	echo 'Canceled opening of file ' . l:filespec
	echohl None
	return
    elseif l:dropActionNr == 1
	execute 'confirm edit' . ' ' . a:exfilespec
    elseif l:dropActionNr == 2
	execute 'belowright split' . ' ' . a:exfilespec
    elseif l:dropActionNr == 3
	execute 'belowright vsplit' . ' ' . a:exfilespec
    elseif l:dropActionNr == 4
	execute 'confirm pedit' . ' ' . a:exfilespec
    elseif l:dropActionNr == 5
	execute 'confirm argedit' . ' ' . a:exfilespec
	args
    elseif l:dropActionNr == 6
	execute '999argadd' . ' ' . a:exfilespec
	args
    elseif l:dropActionNr == 7
	" BF: Avoid :drop command as it adds the dropped file to the argument list. 
	"execute 'drop' . ' ' . a:exfilespec . '|only'
	execute 'split' . ' ' . a:exfilespec . '|only'
    elseif l:dropActionNr == 8
	execute '999tabedit' . ' '. a:exfilespec
    elseif l:dropActionNr == 9
	execute s:exCommandForExternalGvim . ' "'. s:EscapeNormalFilespecForExCommand(l:filespec, s:exCommandForExternalGvim) . '"'
    elseif l:dropActionNr == 10
	" The :drop command would do the trick and switch to the correct tab
	" page, but it is to be avoided as it adds the dropped file to the
	" argument list. 
	" Instead, first go to the tab page, then activate the correct window. 
	execute 'tabnext' . ' '. l:tabPageNr
	execute bufwinnr(s:EscapeNormalFilespecForBufCommand(l:filespec)) . 'wincmd w'
    elseif l:dropActionNr == 100
	" BF: Avoid :drop command as it adds the dropped file to the argument list. 
	" Do not use the :drop command to activate the window which contains the
	" dropped file. 
	"execute "drop" . " " . a:exfilespec
	execute bufwinnr(s:EscapeNormalFilespecForBufCommand(l:filespec)) . 'wincmd w'
    else
	throw 'Invalid dropActionNr!'
    endif
endfunction

function! s:ResolveExfilePatterns( exfilePatterns )
    let l:exfilespecs = []
    for l:exfilePattern in a:exfilePatterns
	let l:filePattern = s:ConvertExfilespecToNormalFilespec(l:exfilePattern)
	" Note: glob() returns the native path separator, but we always want to
	" use forward slashes to avoid problems. 
	let l:resolvedFilespecs = split( substitute(glob(l:filePattern), '\', '/', 'g'), "\n" )
	if empty(l:resolvedFilespecs) && filereadable(l:filePattern)
	    " The globbing yielded no files; however, the file pattern itself
	    " represents an existing file. This happens if a file is passed that
	    " matches one of the 'wildignore' patterns. In this case, as the
	    " file has been explicitly passed to us, we include it. 
	    let l:exfilespecs += [l:exfilePattern]
	else
	    " We include whatever the globbing returned, converted to ex syntax.
	    " 'wildignore' patterns are filtered out. 
	    let l:exfilespecs += map(copy(l:resolvedFilespecs), 's:EscapeNormalFilespecForExCommand(v:val, "")')
	endif
    endfor
    return l:exfilespecs
endfunction

function! s:Drop( exfilePatternsString )
    let l:exfilePatterns = split( a:exfilePatternsString, '\\\@<! ')
    if empty( l:exfilePatterns )
	throw 'Must pass at least one filespec / pattern!'
    endif

    let l:exfilespecs = s:ResolveExfilePatterns( l:exfilePatterns )
echomsg '****' string(l:exfilespecs)
    if empty(l:exfilespecs)
	echohl WarningMsg
	echo 'The file-pattern ''' . a:exfilePatternsString . ''' resulted in no matches. '
	echohl None
	return
    elseif len(l:exfilespecs) == 1
	call s:DropSingleFile(l:exfilespecs[0])
	return
    endif

    let l:dropActionNr = s:QueryActionNrForMultipleFiles(len(l:exfilespecs))

    if l:dropActionNr <= 0
	echohl WarningMsg
	echo 'Canceled opening of ' . len(l:exfilespecs) . ' files. '
	echohl None
	return
    elseif l:dropActionNr == 1
	" Note: Instead of re-assembling the l:exfilespecs, we pass the
	" original file-patterns, as the :argadd / :args ex commands understand
	" them, too. 
	execute '999argadd' . ' ' . a:exfilePatternsString
	args
    elseif l:dropActionNr == 2
	execute 'confirm args' . ' ' . a:exfilePatternsString
	args
    elseif l:dropActionNr == 3
	call s:ExecuteForEachFile( 'belowright split', (s:IsEmptyTabPage() ? 'edit' : ''), 0, l:exfilespecs )
    elseif l:dropActionNr == 4
	call s:ExecuteForEachFile( 'belowright vsplit', (s:IsEmptyTabPage() ? 'edit' : ''), 0, l:exfilespecs )
    elseif l:dropActionNr == 5
	call s:ExecuteForEachFile( 'tabedit', (s:IsEmptyTabPage() ? 'edit' : ''), 0, l:exfilespecs )
    elseif l:dropActionNr == 6
	call s:ExecuteForEachFile( s:exCommandForExternalGvim, '', 1, l:exfilespecs )
    else
	throw 'Invalid dropActionNr!'
    endif
endfunction

"-- commands ------------------------------------------------------------------
" The file-pattern passed to :drop should conform to ex syntax, just as the
" built-in :drop command would expect them:
" - spaces, [%#] are escaped with '\'
" - path delimiters are forward slashes; backslashes are only used for
"   escaping. 
" - no enclosing of filespecs in double quotes
"
" Note to -nargs=1:
" A maximum of 20 arguments can be passed to a VIM function. The built-in :drop
" command supports more, though. To work around this limitation, everything is
" passed to the s:Drop() function as one string; the function itself will split
" that into file patterns. Splitting is done on (unescaped) spaces, as the
" file-patterns to :drop are not enclosed by double quotes, but contain escaped
" spaces. 
:command! -nargs=1 Drop call <SID>Drop(<f-args>)

if g:dropquery_RemapDrop
    cabbrev drop Drop
endif

let &cpo = s:save_cpo

