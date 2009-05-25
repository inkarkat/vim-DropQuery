" dropquery.vim: Ask the user how a :drop'ped file be opened. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" DEPENDENCIES:
"   - Requires Vim 7.0 or higher. 
"
" LIMITATIONS:
"
" TODO:
"   - Use new shellescape() function?
"
" REVISION	DATE		REMARKS 
"	035	26-May-2009	ENH: Handling ++enc=... and +cmd=...
"				Separated s:ExternalGvimForEachFile() from
"				s:ExecuteForEachFile(). 
"				BF: The original buffer was modified as
"				read-only if a read-only drop was canceled
"				through the :confirm command. Now checking
"				whether the buffer actually changed before
"				setting 'readonly'. 
"				BF: Removed :args after :argedit, it clashed
"				with the "edit file" message and caused the
"				hit-enter prompt. 
"	034	14-May-2009	Now using identifiers for l:dropAction via
"				s:Query() instead of an index into the choices
"				l:dropActionNr. 
"				Added choice "readonly and ask again". 
"				Choices "... and ask again" are removed from the
"				list of choices when asking again. 
"	033	05-Apr-2009	BF: Could not drop non-existing (i.e.
"				to-be-created) files any more. Fixed by not
"				categorically excluding non-existing files, only
"				if they represent a file pattern. 
"				ENH: Improved query text with a note about
"				the number of patterns that didn't yield file(s)
"				and the number of files that do not yet exist. 
"	032	11-Feb-2009	Factored out s:WarningMsg(). 
"				BF: Now catching VIM errors in s:Drop() and
"				s:DropSingleFile(); these may happened e.g. when
"				the :only fails due to a modified buffer. 
"	031	07-Jan-2009	Small BF: Using has('gui_running'). 
"	030	13-Sep-2008	BF: In ResolveExfilePatterns(), mixed up normal
"				filespec returned from glob() with exfilespecs. 
"				Renamed ...InExSyntax to ex... to shorten
"				identifiers names. 
"				Refactored special '!' escaping for :! ex
"				command. 
"				Reworked Escape...() functions. 
"				BF: Introduced s:ExecuteWithoutWildignore()
"				because :args and :argadd obey 'wildignore';
"				now, normally ignored files can be put on the
"				argument list if they are passed explicitly (not
"				via a file pattern). 
"				Now using <q-args> and -nargs=+ to allow
"				completion on all items. 
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
"				ENH: Correctly handling file patterns (e.g.
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

" Avoid installing twice or when in unsupported Vim version. 
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

"-- functions -----------------------------------------------------------------
function! s:WarningMsg( text )
    echohl WarningMsg
    let v:warningmsg = a:text
    echomsg v:warningmsg
    echohl None
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
function! s:EscapeExfilespecForExCommand( exfilespec, excommand)
"*******************************************************************************
"* PURPOSE:
"   Escaped a filespec in ex syntax so that it can also be safely used in the 
"   ':! command "filespec"' ex command. 
"   For ex commands, [%#] must be escaped; for the ':!' ex command, the [!]
"   character must be escaped, too, because it stands for the previously
"   executed :! command. 
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
"   Filespec in ex syntax that can be passed to any ex command. 
"*******************************************************************************
    let l:isBangCommand = (a:excommand =~# '^\s*\%(silent\s\+\)\?!')
    return (l:isBangCommand ? escape(a:exfilespec, '!') : a:exfilespec)
endfunction
function! s:EscapeNormalFilespecForExCommand( filespec )
"*******************************************************************************
"* PURPOSE:
"   Escape a normal filespec syntax so that it can be used in ex commands. 
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:filespec	    normal filespec
"* RETURN VALUES: 
"	? Explanation of the value returned.
"*******************************************************************************
    return escape( tr( a:filespec, '\', '/' ), ' \%#' )
endfunction
function! s:EscapeNormalFilespecForBufCommand( filespec )
"*******************************************************************************
"* PURPOSE:
"   Escape a normal filespec syntax so that it can be used for the bufname(),
"   bufnr(), bufwinnr(), ... commands. 
"   The filespec must be anchored to ^ and $, and special file pattern
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

function! s:IsVisibleWindow( filespec )
    let l:winNr = bufwinnr( s:EscapeNormalFilespecForBufCommand(a:filespec) )
    return l:winNr != -1
endfunction
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

function! s:SaveGuiOptions()
    let l:savedGuiOptions = ''
    if has('gui_running') && g:dropquery_NoPopup
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
    if has('gui_running') && g:dropquery_NoPopup
	let &guioptions = a:savedGuiOptions
    endif
endfunction
function! s:Query( msg, choices, default )
"*******************************************************************************
"* PURPOSE:
"   Ask the user for a choice. This is a wrapper around confirm() which allows
"   to specify and return choices by name, not by index. 
"* ASSUMPTIONS / PRECONDITIONS:
"   None. 
"* EFFECTS / POSTCONDITIONS:
"   None. 
"* INPUTS:
"   a:msg	Dialog text. 
"   a:choices	List of choices. Set the shortcut key by prepending '&'. 
"   a:default	Default choice text. Either number (0 for no default, (index +
"		1) for choice) or choice text; omit any shortcut key '&' there. 
"* RETURN VALUES: 
"   Choice text without the shortcut key '&'. Empty string if the dialog was
"   aborted. 
"*******************************************************************************
    let l:savedGuiOptions = s:SaveGuiOptions()

    let l:plainChoices = map(copy(a:choices), 'substitute(v:val, "&", "", "g")')
    let l:defaultIndex = (type(a:default) == type(0) ? a:default : max([index(l:plainChoices, a:default) + 1, 0]))
    let l:choice = ''
    let l:index = confirm(a:msg, join(a:choices, "\n"), l:defaultIndex, 'Question')
    if l:index > 0
	let l:choice = get(l:plainChoices, l:index - 1, '')
    endif

    call s:RestoreGuiOptions( l:savedGuiOptions )
    
    return l:choice
endfunction

function! s:ExternalGvimForEachFile( vimArguments, fileOptionsAndCommands, exfilespecs )
"*******************************************************************************
"* PURPOSE:
"   Opens each filespec in a:exfilespecs in an external GVIM. 
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:vimArguments	    Arguments passed to the GVIM instance. 
"   a:fileOptionsAndCommands	String containing all optional file options and
"				commands. 
"   a:exfilespecs	    List of filespecs in ex syntax. 
"* RETURN VALUES: 
"   none
"*******************************************************************************
    let l:exCommandForExternalGvim = (has('win32') || has('win64') ? 'silent !start gvim' : 'silent ! gvim')

    for l:exfilespec in a:exfilespecs
	let l:exfilespec = '"' . l:exfilespec . '"'
	execute l:exCommandForExternalGvim . ' ' . s:EscapeExfilespecForExCommand(l:exfilespec, l:excommand)
    endfor
	    " let l:exCommandForExternalGvim = s:exCommandForExternalGvim . (l:dropAttributes.readonly ? ' -R' : '')
	    " let l:fileOptionsAndCommandsForExCommand = (empty(a:fileOptionsAndCommands) ? '' : s:EscapeExfilespecForExCommand(a:fileOptionsAndCommands, l:exCommandForExternalGvim) . ' ')
	    " execute l:exCommandForExternalGvim . ' "'. l:fileOptionsAndCommandsForExCommand . s:EscapeExfilespecForExCommand(s:EscapeNormalFilespecForExCommand(l:filespec), l:exCommandForExternalGvim) . '"'
endfunction
function! s:ExecuteForEachFile( excommand, specialFirstExcommand, exfilespecs )
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
"   a:exfilespecs	    List of filespecs in ex syntax. 
"* RETURN VALUES: 
"   none
"*******************************************************************************
    let l:excommand = empty(a:specialFirstExcommand) ? a:excommand : a:specialFirstExcommand
    for l:exfilespec in a:exfilespecs
	execute l:excommand s:EscapeExfilespecForExCommand(l:exfilespec, l:excommand)
	let l:excommand = a:excommand
    endfor
endfunction
function! s:ExecuteWithoutWildignore( excommand, exfilespecs )
"*******************************************************************************
"* PURPOSE:
"   Executes a:excommand with all a:exfilespecs passed as arguments while
"   'wildignore' is temporarily  disabled. This allows to introduce filespecs to
"   the argument list (:args ..., :argadd ...) which would normally be filtered
"   by 'wildignore'. 
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:excommand		    ex command to be invoked
"   a:exfilespecs	    List of filespecs in ex syntax. 
"* RETURN VALUES: 
"   none
"*******************************************************************************
    let l:save_wildignore = &wildignore
    set wildignore=
    try
	execute a:excommand join(a:exfilespecs, ' ')
    finally
	let &wildignore = l:save_wildignore
    endtry
endfunction

function! s:BuildQueryText( exfilespecs, statistics )
    if a:statistics.files > 1
	let l:fileCharacterization = 'files'
    else
	let l:fileCharacterization = s:ConvertExfilespecToNormalFilespec(a:exfilespecs[0])
    endif
    if a:statistics.nonexisting == a:statistics.files
	let l:fileCharacterization = 'non-existing ' . l:fileCharacterization
    elseif a:statistics.nonexisting > 0
	let l:fileCharacterization .= printf(' (%d non-existing)', a:statistics.nonexisting)
    endif

    let l:fileNotes = (a:statistics.removed > 0 ? printf("%d file pattern%s resulted in no matches.\n", a:statistics.removed, (a:statistics.removed == 1 ? '' : 's')) : '')

    if a:statistics.files > 1
	return printf('%sAction for %d dropped %s?', l:fileNotes, a:statistics.files, l:fileCharacterization)
    else
	return printf('%sAction for %s?', l:fileNotes, l:fileCharacterization)
    endif
endfunction
function! s:QueryActionForSingleFile( querytext, isNonexisting, isOpenInAnotherTabPage )
    let l:dropAttributes = {'readonly': 0}

    " The :edit command can be used to both edit an existing file and create a
    " new file. We'd like to distinguish between the two in the query, however. 
    " The changed action label "Create" offers a subtle hint that the dropped
    " file does not exist. This way, the user can cancel the dropping if he
    " doesn't want to create a new file (and mistakenly thought the dropped file
    " already existed). 
    let l:editAction = (a:isNonexisting ? '&create' : '&edit')
    let l:actions = [l:editAction, '&split', '&vsplit', '&preview', '&argedit', 'arga&dd', '&only', 'new &tab', '&new GVIM', '&readonly and ask again']
    if a:isOpenInAnotherTabPage
	call insert(l:actions, '&goto tab')
    endif

    while 1
	let l:dropAction = s:Query(a:querytext, l:actions, 1)
	if l:dropAction ==# 'readonly and ask again'
	    let l:dropAttributes.readonly = 1
	    call filter(l:actions, 'v:val !~# "readonly"')
	else
	    break
	endif
    endwhile

    return [l:dropAction, l:dropAttributes]
endfunction
function! s:QueryActionForMultipleFiles( querytext )
    let l:dropAttributes = {'readonly': 0}
    let l:actions = ['arga&dd', '&argedit', '&split', '&vsplit', 'new &tab', '&new GVIM', '&open new tab and ask again', '&readonly and ask again']
    while 1
	let l:dropAction = s:Query(a:querytext, l:actions, 1)
	if l:dropAction ==# 'open new tab and ask again'
	    tabnew
	    call filter(l:actions, 'v:val !~# "open new tab"')
	elseif l:dropAction ==# 'readonly and ask again'
	    let l:dropAttributes.readonly = 1
	    call filter(l:actions, 'v:val !~# "readonly"')
	else
	    break
	endif
    endwhile

    return [l:dropAction, l:dropAttributes]
endfunction

function! s:FilterFileOptionsAndCommands( exfilePatterns )
"*******************************************************************************
"* PURPOSE:
"   Strip off the optional ++opt +cmd file options and commands. 
"
"   (In Vim 7.2,) options and commands can only appear at the beginning of the
"   file list; there can be multiple options, but only one command. They are
"   only applied to the first (opened) file, not to any other passed file. 
"
"* ASSUMPTIONS / PRECONDITIONS:
"   None. 
"* EFFECTS / POSTCONDITIONS:
"   None. 
"* INPUTS:
"   a:exfilePatterns	Raw list of exfile patterns. 
"* RETURN VALUES: 
"   [a:exfilePatterns, fileOptionsAndCommands]	First element is the passed
"   list, with any file options and commands removed. Second element is a string
"   containing all removed file options and commands. 
"*******************************************************************************
    let l:startIdx = 0
    while a:exfilePatterns[l:startIdx] =~# '^+\{1,2}'
	let l:startIdx += 1
    endwhile
    
    if l:startIdx == 0
	return [a:exfilePatterns, '']
    else
	return [a:exfilePatterns[l:startIdx : ], join(a:exfilePatterns[ : (l:startIdx - 1)], ' ')]
    endif
endfunction
function! s:PreviewBufNr()
    for l:winnr in range(1, winnr('$'))
	if getwinvar(l:winnr, '&previewwindow')
	    return winbufnr(l:winnr)
	endif
    endfor
    return -1
endfunction
function! s:DropSingleFile( exfilespec, querytext, fileOptionsAndCommands )
"*******************************************************************************
"* PURPOSE:
"   Prompts the user for the action to be taken with the dropped file. 
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:exfilespec    Filespec of the dropped file. 
"   a:querytext	    Text to be presented to the user. 
"   a:fileOptionsAndCommands	String containing all optional file options and
"				commands. 
"* RETURN VALUES: 
"   none
"*******************************************************************************
"****D echo '**** Dropped filespec is "' . a:exfilespec . '". '
    let l:filespec = s:ConvertExfilespecToNormalFilespec(a:exfilespec)
    let l:dropAttributes = {'readonly': 0}

    if s:IsEmptyTabPage()
	let l:dropAction = 'edit'
    elseif s:IsVisibleWindow(l:filespec)
	let l:dropAction = 'goto'
    else
	let l:tabPageNr = s:GetTabPageNr(l:filespec)
	let l:isNonexisting = empty(filereadable(l:filespec))
	let [l:dropAction, l:dropAttributes] = s:QueryActionForSingleFile(a:querytext, isNonexisting, (l:tabPageNr != -1))
    endif

    let l:originalBufNr = bufnr('')
    try
	if empty(l:dropAction)
	    call s:WarningMsg('Canceled opening of file ' . l:filespec)
	    return
	elseif l:dropAction ==# 'edit' || l:dropAction ==# 'create'
	    execute 'confirm' (l:dropAttributes.readonly ? 'view' : 'edit') a:fileOptionsAndCommands a:exfilespec
	elseif l:dropAction ==# 'split'
	    execute 'belowright' (l:dropAttributes.readonly ? 'sview' : 'split') a:fileOptionsAndCommands a:exfilespec
	elseif l:dropAction ==# 'vsplit'
	    execute 'belowright' (l:dropAttributes.readonly ? 'vertical sview' : 'vsplit') a:fileOptionsAndCommands a:exfilespec
	elseif l:dropAction ==# 'preview'
	    " The :pedit command does not go to the preview window, so the check
	    " for a change in the previewed buffer and the setting of the
	    " attributes has to be done differently. 
	    let l:originalPreviewBufNr = s:PreviewBufNr()
	    execute 'confirm pedit' a:fileOptionsAndCommands a:exfilespec
	    if l:dropAttributes.readonly
		let l:newPreviewBufNr = s:PreviewBufNr()
		if l:newPreviewBufNr != l:originalPreviewBufNr
		    call setbufvar(l:newPreviewBufNr, '&readonly', 1)
		endif
	    endif
	elseif l:dropAction ==# 'argedit'
	    execute 'confirm argedit' a:fileOptionsAndCommands a:exfilespec
	    if l:dropAttributes.readonly && bufnr('') != l:originalBufNr | setlocal readonly | endif
	elseif l:dropAction ==# 'argadd  '
	    call s:ExecuteWithoutWildignore('999argadd', [a:exfilespec])
	    " :argadd just modifies the argument list; l:dropAttributes.readonly
	    " doesn't apply here. a:fileOptionsAndCommands isn't supported,
	    " neither. 

	    " Since :argadd doesn't change the currently edited file, and there
	    " thus is no clash with an "edit file" message, show the new
	    " argument list as a courtesy. 
	    args
	elseif l:dropAction ==# 'only'
	    " BF: Avoid :drop command as it adds the dropped file to the argument list. 
	    "execute 'drop' a:exfilespec . '|only'
	    execute (l:dropAttributes.readonly ? 'sview' : 'split') a:fileOptionsAndCommands a:exfilespec . '|only'
	elseif l:dropAction ==# 'new tab'
	    execute '999tabedit' a:fileOptionsAndCommands a:exfilespec
	    if l:dropAttributes.readonly && bufnr('') != l:originalBufNr | setlocal readonly | endif
	elseif l:dropAction ==# 'new GVIM'
	    call s:ExternalGvimForEachFile( (l:dropAttributes.readonly ? ' -R' : ''), a:fileOptionsAndCommandsForExCommand, [ a:exfilespec ] )
	elseif l:dropAction ==# 'goto tab'
	    " The :drop command would do the trick and switch to the correct tab
	    " page, but it is to be avoided as it adds the dropped file to the
	    " argument list. 
	    " Instead, first go to the tab page, then activate the correct window. 
	    execute 'tabnext' l:tabPageNr
	    execute bufwinnr(s:EscapeNormalFilespecForBufCommand(l:filespec)) . 'wincmd w'
	    if l:dropAttributes.readonly && bufnr('') != l:originalBufNr | setlocal readonly | endif
	elseif l:dropAction ==# 'goto'
	    " BF: Avoid :drop command as it adds the dropped file to the argument list. 
	    " Do not use the :drop command to activate the window which contains the
	    " dropped file. 
	    "execute 'drop' a:fileOptionsAndCommands a:exfilespec
	    execute bufwinnr(s:EscapeNormalFilespecForBufCommand(l:filespec)) . 'wincmd w'
	    if l:dropAttributes.readonly && bufnr('') != l:originalBufNr | setlocal readonly | endif
	else
	    throw 'Invalid dropAction: ' . l:dropAction
	endif
    catch /^Vim\%((\a\+)\)\=:E/
	echohl ErrorMsg
	" v:exception contains what is normally in v:errmsg, but with extra
	" exception source info prepended, which we cut away. 
	let v:errmsg = substitute(v:exception, '^Vim\%((\a\+)\)\=:', '', '')
	echomsg v:errmsg
	echohl None
    endtry
endfunction
function! s:ContainsNoWildcards( filePattern )
    " Note: This is only an empirical approximation; it is not perfect. 
    if has('win32') || has('win64')
	return a:filePattern !~ '[*?]'
    else
	return a:filePattern !~ '\\\@<![*?{[]'
    endif
endfunction
function! s:ResolveExfilePatterns( exfilePatterns )
    let l:statistics = { 'files': 0, 'removed': 0, 'nonexisting': 0 }
    let l:exfilespecs = []
    for l:exfilePattern in a:exfilePatterns
	let l:filePattern = s:ConvertExfilespecToNormalFilespec(l:exfilePattern)
	let l:resolvedFilespecs = split( glob(l:filePattern), "\n" )
	if empty(l:resolvedFilespecs)
	    " The globbing yielded no files; however:
	    if filereadable(l:filePattern)
		" a) The file pattern itself represents an existing file. This
		"    happens if a file is passed that matches one of the
		"    'wildignore' patterns. In this case, as the file has been
		"    explicitly passed to us, we include it. 
		let l:exfilespecs += [l:exfilePattern]
	    elseif s:ContainsNoWildcards(l:filePattern)
		" b) The file pattern contains no wildcards and represents a
		"    to-be-created file. 
		let l:exfilespecs += [l:exfilePattern]
		let l:statistics.nonexisting += 1
	    else
		" Nothing matched this file pattern, or whatever matched is
		" covered by the 'wildignore' patterns and not a file itself. 
		let l:statistics.removed += 1
	    endif
	else
	    " We include whatever the globbing returned, converted to ex syntax.
	    " 'wildignore' patterns are filtered out. 
	    let l:exfilespecs += map(copy(l:resolvedFilespecs), 's:EscapeNormalFilespecForExCommand(v:val)')
	endif
    endfor

    let l:statistics.files = len(l:exfilespecs)
    return [l:exfilespecs, l:statistics]
endfunction
function! s:Drop( exfilePatternsString )
    let l:exfilePatterns = split( a:exfilePatternsString, '\\\@<! ')
    if empty( l:exfilePatterns )
	throw 'Must pass at least one filespec / pattern!'
    endif

    " Strip off the optional ++opt +cmd file options and commands. 
    let [l:exfilePatterns, l:fileOptionsAndCommands] = s:FilterFileOptionsAndCommands(l:exfilePatterns)

    let [l:exfilespecs, l:statistics] = s:ResolveExfilePatterns(l:exfilePatterns)
"****D echomsg '****' string(l:statistics)
"****D echomsg '****' string(l:exfilespecs)
    if empty(l:exfilespecs)
	call s:WarningMsg(printf("The file pattern '%s' resulted in no matches.", a:exfilePatternsString))
	return
    elseif l:statistics.files == 1
	call s:DropSingleFile(l:exfilespecs[0], s:BuildQueryText(l:exfilespecs, l:statistics), l:fileOptionsAndCommands)
	return
    endif

    let [l:dropAction, l:dropAttributes] = s:QueryActionForMultipleFiles(s:BuildQueryText(l:exfilespecs, l:statistics))

    let l:fileOptionsAndCommands = (empty(l:fileOptionsAndCommands) ? '' : ' ' . l:fileOptionsAndCommands)
    try
	if empty(l:dropAction)
	    call s:WarningMsg('Canceled opening of ' . l:statistics.files . ' files. ')
	    return
	elseif l:dropAction ==# 'argadd'
	    call s:ExecuteWithoutWildignore('999argadd', l:exfilespecs)
	    " :argadd just modifies the argument list; l:dropAttributes.readonly
	    " doesn't apply here. l:fileOptionsAndCommands isn't supported,
	    " neither. 

	    " Since :argadd doesn't change the currently edited file, and there
	    " thus is no clash with an "edit file" message, show the new
	    " argument list as a courtesy. 
	    args
	elseif l:dropAction ==# 'argedit'
	    call s:ExecuteWithoutWildignore('confirm args' . l:fileOptionsAndCommands, l:exfilespecs)
	    if l:dropAttributes.readonly | setlocal readonly | endif
	elseif l:dropAction ==# 'split'
	    call s:ExecuteForEachFile(
	    \	'belowright ' . (l:dropAttributes.readonly ? 'sview' : 'split') . l:fileOptionsAndCommands,
	    \	(s:IsEmptyTabPage() ? (l:dropAttributes.readonly ? 'view' : 'edit') . l:fileOptionsAndCommands : ''),
	    \	l:exfilespecs
	    \)
	elseif l:dropAction ==# 'vsplit'
	    call s:ExecuteForEachFile(
	    \	'belowright ' . (l:dropAttributes.readonly ? 'vertical sview' : 'vsplit') . l:fileOptionsAndCommands,
	    \	(s:IsEmptyTabPage() ? (l:dropAttributes.readonly ? 'view' : 'edit') . l:fileOptionsAndCommands : ''),
	    \	l:exfilespecs
	    \)
	elseif l:dropAction ==# 'new tab'
	    call s:ExecuteForEachFile(
	    \	'tabedit' . l:fileOptionsAndCommands . (l:dropAttributes.readonly ? ' +setlocal readonly' : ''),
	    \	(s:IsEmptyTabPage() ? (l:dropAttributes.readonly ? 'view' : 'edit') . l:fileOptionsAndCommands : ''),
	    \	l:exfilespecs
	    \)
	elseif l:dropAction ==# 'new GVIM'
	    call s:ExternalGvimForEachFile( (l:dropAttributes.readonly ? ' -R' : ''), l:fileOptionsAndCommands, l:exfilespecs )
	else
	    throw 'Invalid dropAction: ' . l:dropAction
	endif
    catch /^Vim\%((\a\+)\)\=:E/
	echohl ErrorMsg
	" v:exception contains what is normally in v:errmsg, but with extra
	" exception source info prepended, which we cut away. 
	let v:errmsg = substitute(v:exception, '^Vim\%((\a\+)\)\=:', '', '')
	echomsg v:errmsg
	echohl None
    endtry
endfunction

"-- commands ------------------------------------------------------------------
" The file pattern passed to :drop should conform to ex syntax, just as the
" built-in :drop command would expect them:
" - spaces, [%#] are escaped with '\'
" - path delimiters are forward slashes; backslashes are only used for
"   escaping. 
" - no enclosing of filespecs in double quotes
"
" A maximum of 20 arguments can be passed to a VIM function. The built-in :drop
" command supports more, though. To work around this limitation, everything is
" passed to the s:Drop() function as one string by using <q-args> instead of
" <f-args>; the function itself will split that into file patterns. Splitting is
" done on (unescaped) spaces, as the file patterns to :drop are not enclosed by
" double quotes, but contain escaped spaces. 
" We do specify multiple arguments, so that file completion works for all
" arguments. 
:command! -nargs=+ -complete=file Drop call <SID>Drop(<q-args>)

if g:dropquery_RemapDrop
    cabbrev drop Drop
endif

let &cpo = s:save_cpo

