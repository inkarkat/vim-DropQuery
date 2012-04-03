" dropquery.vim: Ask the user how a :drop'ped file be opened. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" DEPENDENCIES:
"   - Requires Vim 7.0 or higher. 
"   - escapings.vim autoload script. 
"   - ingofileargs.vim autoload script. 
"
" Copyright: (C) 2005-2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'. 
"
" REVISION	DATE		REMARKS 
"	048	04-Apr-2012	CHG: For single files, remove accelerator from
"				"vsplit", add "view" instead.
"	047	24-Mar-2012	BUG: s:Drop() must unescape filePatterns after
"				splitting, because the globbing done by
"				ingofileargs#ResolveExfilePatterns() does not
"				condense "\ " into " " when the file does not
"				exist, and then instead of creating "new file",
"				it would attempt to create "file" in the "new"
"				directory.
"	046	21-Feb-2012	FIX: Off-by-one error in getcmdline(). 
"	045	09-Feb-2012	Split off s:FilterFileOptionsAndCommands() and
"				s:ResolveExfilePatterns() to
"				autoload/ingofileargs.vim to allow reuse in
"				ingocommands.vim. 
"	044	01-Jul-2011	ENH: Implement handling of +cmd=... for the
"				single-file "goto" and "goto tab" actions by
"				emulating what the :edit commands do internally
"				(but therefore ++enc=... won't work). This is
"				useful because external applications may just
"				want to synchronize the current cursor position
"				to Vim via "SendToGVIM +42 foo.txt". 
"	043	24-May-2011	Change 'show' split behavior from :aboveleft to
"				:topleft, so that the full window width is used. 
"				Main use case is opening patch files while
"				writing the corresponding patch email (with the
"				email window padded so that its width is
"				limited). 
"	042	14-Aug-2010	BUG: s:ResolveExfilePatterns() didn't detect
"				filespecs (e.g. "C:\Program Files\ingo\tt
"				cache.cmd.20100814b") that match a 'wildignore'
"				pattern and contain spaces. The
"				backslash-escaping of spaces must be removed for
"				filereadable() to work. 
"	041	22-Jul-2010	Expanded "if l:dropAttributes.readonly && bufnr('') != l:originalBufNr | setlocal readonly | endif"
"				inside s:DropSingleFile() into multiple lines to
"				avoid the (well-known, but never before
"				analyzed) "Error while processing ...
"				DropSingleFile: E171: Missing :endif: catch
"				/^Vim\%((\a\+\)\=:E/". After my analysis, this
"				seems to be a bug in Vim 7.2 that can be
"				prevented by splitting the if statement to
"				multiple lines. 
"	040	15-Apr-2010	ENH: Added "diff" choice both for single file
"				(diff with existing diff or current window) and
"				multiple files (diff all those files). 
"	039	15-Apr-2010	ENH: Show only :argedit choice when there are no
"				arguments yet; add :argadd and make it the
"				preferred action otherwise. 
"	038	07-Jun-2009	Added "show" choice that splits files (above,
"				not below) read-only. 
"				Avoid "E36: Not enough room" when trying to open
"				more splits than possible. 
"	037	06-Jun-2009	BF: Typo in 'argadd' case in s:DropSingleFile(). 
"	036	27-May-2009	ENH: Implemented "use blank window" choice for
"				single file drop if such a window exists in the
"				current tab page (and is not the current window,
"				anyway). 
"				BF: Do not simply open single file in current
"				empty tab page if the file is already open in
"				another tab page. 
"				Now reducing the filespec to shortest possible
"				(:~:.) before opening file(s). This avoids ugly
"				long buffer names when :set noautochdir.  
"				ENH: Only mapping 'drop' if in and at the
"				beginning of a command line. 
"				Unescaping of passed filespecs is not necessary;
"				-complete=file automatically unescapes them. 
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
"				Replaced s:ConvertExfilespecToNormalFilespec(),
"				s:EscapeExfilespecForExCommand(),
"				s:EscapeNormalFilespecForExCommand(),
"				s:EscapeNormalFilespecForBufCommand() with
"				functions from escapings.vim library. 
"				Not simply passing the file as an argument to
"				GVIM any more, as it would add the file to the
"				argument list. We're using an explicit
"				a:openCommand instead. 
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
"				BF: Now catching Vim errors in s:Drop() and
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
"				syntax; Vim commands and user display use
"				s:ConvertExfilespecToNormalFilespec() to
"				unescape the ex syntax; that was formerly done
"				by -complete=file. 
"				Multiple files are passed as one string
"				(-nargs=1, and splitting is done inside the
"				s:Drop() function. 
"	0.21	16-Nov-2006	BF: '%' and '#' must also be escaped for Vim. 
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
"				Now requiring Vim 7.0. 
"	0.09	26-Oct-2006	ENH: Learned from a vimtip that Vim does have a
"				built-in :sleep comand; replaced clumsy function 
"				BideSomeTimeToLetActivationComplete(). 
"	0.08	25-Aug-2006	I18N: Endless loop in
"				BideSomeTimeToLetActivationComplete() on German 
"				locale; added ',' as a decimal separator. 
"	0.07	11-May-2006	Vim 7.0: Added action 'new tab'. 
"	0.06	10-May-2006	ENH: Added BideSomeTimeToLetActivationComplete()
"				to avoid that Vim gets the focus after
"				activation, but not Vim's popup dialog. 
"	0.05	17-Feb-2006	BF: Avoid :drop command as it adds the dropped
"				file to the argument list. 
"	0.04	15-Aug-2005	Added action 'new GVIM' to launch the file in a
"				new GVIM instance. Requires that 'gvim' is
"				accessible through $PATH. (Action 'new Vim'
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

"-- configuration -------------------------------------------------------------
if !exists('g:dropquery_RemapDrop')
    " If set, remaps the built-in ':drop' command to use ':Drop' instead. 
    " With this option, other integrations (e.g. VisVim) need not be modified to
    " use the dropquery functionality. 
    let g:dropquery_RemapDrop = 1
endif
if !exists('g:dropquery_NoPopup')
    " If set, doesn't use a pop-up dialog in GVIM for the query. Instead, a
    " textual query (as is done in the console Vim) is used. This does not cover
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

function! s:IsVisibleWindow( filespec )
    let l:winNr = bufwinnr(escapings#bufnameescape(a:filespec))
    return l:winNr != -1
endfunction
function! s:IsBlankBuffer( bufnr )
    return (empty(bufname(a:bufnr)) && 
    \ getbufvar(a:bufnr, '&modified') == 0 && 
    \ empty(getbufvar(a:bufnr, '&buftype'))
    \)
endfunction
function! s:IsEmptyTabPage()
    let l:isEmptyTabPage = ( 
    \	tabpagewinnr(tabpagenr(), '$') <= 1 && 
    \	s:IsBlankBuffer(bufnr(''))
    \)
    return l:isEmptyTabPage
endfunction
function! s:GetBlankWindowNr()
"*******************************************************************************
"* PURPOSE:
"   Find a blank, unused window (i.e. containing an unnamed, unmodified normal
"   buffer) in the current tab page and return its number. 
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   None. 
"* RETURN VALUES: 
"   Window number of the first blank window (preferring the current window), or
"   -1 if no such window exists. 
"*******************************************************************************
    " Check all windows in the current tab page, starting (and thus preferring)
    " the current window. 
    for l:winnr in insert(range(1, winnr('$')), winnr())
	if s:IsBlankBuffer(winbufnr(l:winnr))
	    return l:winnr
	endif
    endfor
    return -1
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
"   Tab page number of the first tab page (other than the current one) where the
"   buffer is visible; else -1. 
"*******************************************************************************
    if tabpagenr('$') == 1
	return -1   " There's only one tab. 
    endif

    let l:targetBufNr = bufnr(escapings#bufnameescape(a:filespec))
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
function! s:HasDiffWindow()
    let l:diffedWinNrs = filter( range(1, winnr('$')), 'getwinvar(v:val, "&diff")' )
    return ! empty(l:diffedWinNrs)
endfunction

function! s:SaveGuiOptions()
    let l:savedGuiOptions = ''
    if has('gui_running') && g:dropquery_NoPopup
	let l:savedGuiOptions = &guioptions
	set guioptions+=c   " Temporarily avoid popup dialog. 
    endif

    if ! g:dropquery_NoPopup
	" Focus on the popup dialog requires that activation of Vim from the
	" external call has been completed, so better wait a few milliseconds to
	" avoid that Vim gets focus, but not Vim's popup dialog. This occurred
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

function! s:ShortenFilespec( filespec )
    return fnamemodify(a:filespec, ':~:.')
endfunction
function! s:ExternalGvimForEachFile( openCommand, filespecs )
"*******************************************************************************
"* PURPOSE:
"   Opens each filespec in a:filespecs in an external GVIM. 
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:openCommand   Ex command used to open each file in a:exfilespecs. 
"   a:filespecs	    List of filespecs. 
"* RETURN VALUES: 
"   none
"*******************************************************************************
    let l:exCommandForExternalGvim = (has('win32') || has('win64') ? 'silent !start gvim' : 'silent ! gvim')

    for l:filespec in a:filespecs
	" Simply passing the file as an argument to GVIM would add the file to
	" the argument list. We're using an explicit a:openCommand instead. 
	" Bonus: With this, special handling of the 'readonly' attribute (-R
	" argument) is avoided. 
	execute l:exCommandForExternalGvim '-c' escapings#shellescape(a:openCommand . ' ' . escapings#fnameescape(s:ShortenFilespec(l:filespec)), 1)
    endfor
endfunction
function! s:ExecuteForEachFile( excommand, specialFirstExcommand, filespecs, ... )
"*******************************************************************************
"* PURPOSE:
"   Executes a:excommand for each filespec in a:filespecs. 
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:excommand		    ex command which will be invoked with each filespec. 
"   a:specialFirstExcommand ex command which will be invoked for the first filespec. 
"			    If empty, the a:excommand will be invoked for the
"			    first filespec just like any other. 
"   a:filespecs		    List of filespecs. 
"   a:afterExcommand	    Optional ex command which will be invoked after
"			    opening the file via a:excommand. 
"* RETURN VALUES: 
"   none
"*******************************************************************************
    let l:afterExcommand = (a:0 ? a:1 : '')
    let l:excommand = empty(a:specialFirstExcommand) ? a:excommand : a:specialFirstExcommand
    for l:filespec in a:filespecs
	execute l:excommand escapings#fnameescape(s:ShortenFilespec(l:filespec))
	let l:excommand = a:excommand
	if ! empty(l:afterExcommand)
	    execute l:afterExcommand
	endif
    endfor
endfunction
function! s:ExecuteWithoutWildignore( excommand, filespecs )
"*******************************************************************************
"* PURPOSE:
"   Executes a:excommand with all a:filespecs passed as arguments while
"   'wildignore' is temporarily  disabled. This allows to introduce filespecs to
"   the argument list (:args ..., :argadd ...) which would normally be filtered
"   by 'wildignore'. 
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:excommand	    ex command to be invoked
"   a:filespecs	    List of filespecs. 
"* RETURN VALUES: 
"   none
"*******************************************************************************
    let l:save_wildignore = &wildignore
    set wildignore=
    try
	execute a:excommand join(map(copy(a:filespecs), 'escapings#fnameescape(s:ShortenFilespec(v:val))'), ' ')
    finally
	let &wildignore = l:save_wildignore
    endtry
endfunction

function! s:BuildQueryText( filespecs, statistics )
    let l:fileCharacterization = (a:statistics.files > 1 ? 'files' : a:filespecs[0])
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
function! s:QueryActionForArguments( actions )
    if argc() > 0
	" There already are arguments; add :argadd choice and make it the
	" default by removing the accelerator from :argedit. 
	call insert(a:actions, '&argadd', index(a:actions, '&argedit'))
	let a:actions[index(a:actions, '&argedit')] = 'argedit'
    endif
endfunction
function! s:QueryActionForSingleFile( querytext, isNonexisting, isOpenInAnotherTabPage, isBlankWindow )
    let l:dropAttributes = {'readonly': 0}

    " The :edit command can be used to both edit an existing file and create a
    " new file. We'd like to distinguish between the two in the query, however. 
    " The changed action label "Create" offers a subtle hint that the dropped
    " file does not exist. This way, the user can cancel the dropping if he
    " doesn't want to create a new file (and mistakenly thought the dropped file
    " already existed). 
    let l:editAction = (a:isNonexisting ? '&create' : '&edit')
    let l:actions = [l:editAction, '&split', 'vsplit', '&preview', '&argedit', '&only', 'new &tab', '&new GVIM']
    call s:QueryActionForArguments(l:actions)
    if ! a:isNonexisting
	call insert(l:actions, '&view', 1)
	call insert(l:actions, 'sho&w', index(l:actions, '&preview') + 1)
    endif
    if ! a:isNonexisting && ! a:isBlankWindow
	call insert(l:actions, '&diff', index(l:actions, '&split'))
    endif
    if a:isBlankWindow
	call insert(l:actions, 'use &blank window')
    endif
    if a:isOpenInAnotherTabPage
	call insert(l:actions, '&goto tab')
    endif

    let l:dropAction = s:Query(a:querytext, l:actions, 1)
    return [l:dropAction, l:dropAttributes]
endfunction
function! s:QueryActionForMultipleFiles( querytext, fileNum )
    let l:dropAttributes = {'readonly': 0}
    let l:actions = ['&argedit', '&split', '&vsplit', 'sho&w', 'new &tab', '&new GVIM', '&open new tab and ask again', '&readonly and ask again']
    call s:QueryActionForArguments(l:actions)
    if a:fileNum <= 4
	call insert(l:actions, '&diff', index(l:actions, '&split'))
    endif

    " Avoid "E36: Not enough room" when trying to open more splits than
    " possible. 
    if a:fileNum > &lines   | call filter(l:actions, 'v:val !=# "&split" && v:val !=# "sho&w"')  | endif
    if a:fileNum > &columns | call filter(l:actions, 'v:val !=# "&vsplit"') | endif

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

function! s:PreviewBufNr()
    for l:winnr in range(1, winnr('$'))
	if getwinvar(l:winnr, '&previewwindow')
	    return winbufnr(l:winnr)
	endif
    endfor
    return -1
endfunction
function! s:ExecuteFileOptionsAndCommands( fileOptionsAndCommands )
"******************************************************************************
"* PURPOSE:
"   Execute the fileOptionsAndCommands for the current buffer. This emulates
"   what the :edit, :drop, ... commands handle themselves for the case where the
"   buffer is already loaded in a window. 
"
"* ASSUMPTIONS / PRECONDITIONS:
"   None. 
"* EFFECTS / POSTCONDITIONS:
"   None. 
"* INPUTS:
"   a:fileOptionsAndCommands	String containing all optional file options and
"				commands; can be empty. 
"* RETURN VALUES: 
"   None. 
"******************************************************************************
    " The individual file options / commands are space-delimited, but spaces can
    " be escaped via backslash. 
    for l:fileOptionOrCommand in split(a:fileOptionsAndCommands, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<! ')
	if l:fileOptionOrCommand =~# '^++\%(ff\|fileformat\)=' || l:fileOptionOrCommand =~# '^++\%(no\)\?\%(bin\|binary\)$'
	    execute 'setlocal' . l:fileOptionOrCommand[2:]
	elseif l:fileOptionOrCommand =~# '^++'
	    " Cannot execute ++enc and ++bad outside of :edit; ++edit only
	    " applies to :read. 
	elseif l:fileOptionOrCommand =~# '^+'
	    execute substitute(l:fileOptionOrCommand[1:], '\\\([ \\]\)', '\1', 'g')
	else
	    throw 'Invalid file option / command: ' . l:fileOptionOrCommand
	endif
    endfor
endfunction
function! s:DropSingleFile( filespec, querytext, fileOptionsAndCommands )
"*******************************************************************************
"* PURPOSE:
"   Prompts the user for the action to be taken with the dropped file. 
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:filespec	    Filespec of the dropped file. 
"   a:querytext	    Text to be presented to the user. 
"   a:fileOptionsAndCommands	String containing all optional file options and
"				commands. 
"* RETURN VALUES: 
"   none
"*******************************************************************************
"****D echomsg '**** Dropped filespec is "' . a:filespec . '". '
    let l:exfilespec = escapings#fnameescape(s:ShortenFilespec(a:filespec))
    let l:dropAttributes = {'readonly': 0}

    let l:tabPageNr = s:GetTabPageNr(a:filespec)
    if s:IsEmptyTabPage() && l:tabPageNr == -1
	let l:dropAction = 'edit'
    elseif s:IsVisibleWindow(a:filespec)
	let l:dropAction = 'goto'
    else
	let l:blankWindowNr = s:GetBlankWindowNr()
	let l:isNonexisting = empty(filereadable(a:filespec))
	let [l:dropAction, l:dropAttributes] = s:QueryActionForSingleFile(a:querytext, isNonexisting, (l:tabPageNr != -1), (l:blankWindowNr != -1 && l:blankWindowNr != winnr()))
    endif

    let l:originalBufNr = bufnr('')
    try
	if empty(l:dropAction)
	    call s:WarningMsg('Canceled opening of file ' . a:filespec)
	    return
	elseif l:dropAction ==# 'edit' || l:dropAction ==# 'create'
	    execute 'confirm' (l:dropAttributes.readonly ? 'view' : 'edit') a:fileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'view'
	    execute 'confirm view' a:fileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'diff'
	    if ! s:HasDiffWindow()
		" Emulate :diffsplit because it doesn't allow to open the file
		" read-only. 
		diffthis
	    endif
	    " Like :diffsplit, evaluate the 'diffopt' option to determine
	    " whether to split horizontally or vertically. 
	    execute 'belowright' (&diffopt =~# 'vertical' ? 'vertical' : '') (l:dropAttributes.readonly ? 'sview' : 'split') a:fileOptionsAndCommands l:exfilespec
	    diffthis
	elseif l:dropAction ==# 'split'
	    execute 'belowright' (l:dropAttributes.readonly ? 'sview' : 'split') a:fileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'vsplit'
	    execute 'belowright' (l:dropAttributes.readonly ? 'vertical sview' : 'vsplit') a:fileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'show'
	    execute 'topleft sview' a:fileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'preview'
	    " The :pedit command does not go to the preview window, so the check
	    " for a change in the previewed buffer and the setting of the
	    " attributes has to be done differently. 
	    let l:originalPreviewBufNr = s:PreviewBufNr()
	    execute 'confirm pedit' a:fileOptionsAndCommands l:exfilespec
	    if l:dropAttributes.readonly
		let l:newPreviewBufNr = s:PreviewBufNr()
		if l:newPreviewBufNr != l:originalPreviewBufNr
		    call setbufvar(l:newPreviewBufNr, '&readonly', 1)
		endif
	    endif
	elseif l:dropAction ==# 'argedit'
	    execute 'confirm argedit' a:fileOptionsAndCommands l:exfilespec
	    if l:dropAttributes.readonly && bufnr('') != l:originalBufNr
		setlocal readonly
	    endif
	elseif l:dropAction ==# 'argadd'
	    call s:ExecuteWithoutWildignore('999argadd', [a:filespec])
	    " :argadd just modifies the argument list; l:dropAttributes.readonly
	    " doesn't apply here. a:fileOptionsAndCommands isn't supported,
	    " neither. 

	    " Since :argadd doesn't change the currently edited file, and there
	    " thus is no clash with an "edit file" message, show the new
	    " argument list as a courtesy. 
	    args
	elseif l:dropAction ==# 'only'
	    " BF: Avoid :drop command as it adds the dropped file to the argument list. 
	    "execute 'drop' l:exfilespec . '|only'
	    execute (l:dropAttributes.readonly ? 'sview' : 'split') a:fileOptionsAndCommands l:exfilespec . '|only'
	elseif l:dropAction ==# 'new tab'
	    execute '999tabedit' a:fileOptionsAndCommands l:exfilespec
	    if l:dropAttributes.readonly && bufnr('') != l:originalBufNr
		setlocal readonly
	    endif
	elseif l:dropAction ==# 'new GVIM'
	    let l:fileOptionsAndCommands = (empty(a:fileOptionsAndCommands) ? '' : ' ' . a:fileOptionsAndCommands)
	    call s:ExternalGvimForEachFile( (l:dropAttributes.readonly ? 'view' : 'edit') . l:fileOptionsAndCommands, [ a:filespec ] )
	elseif l:dropAction ==# 'goto tab'
	    " The :drop command would do the trick and switch to the correct tab
	    " page, but it is to be avoided as it adds the dropped file to the
	    " argument list. 
	    " Instead, first go to the tab page, then activate the correct window. 
	    execute 'tabnext' l:tabPageNr
	    execute bufwinnr(escapings#bufnameescape(a:filespec)) . 'wincmd w'
	    if l:dropAttributes.readonly && bufnr('') != l:originalBufNr
		setlocal readonly
	    endif
	    call s:ExecuteFileOptionsAndCommands(a:fileOptionsAndCommands)
	elseif l:dropAction ==# 'goto'
	    " BF: Avoid :drop command as it adds the dropped file to the argument list. 
	    " Do not use the :drop command to activate the window which contains the
	    " dropped file. 
	    "execute 'drop' a:fileOptionsAndCommands l:exfilespec
	    execute bufwinnr(escapings#bufnameescape(a:filespec)) . 'wincmd w'
	    if l:dropAttributes.readonly && bufnr('') != l:originalBufNr
		setlocal readonly
	    endif
	    call s:ExecuteFileOptionsAndCommands(a:fileOptionsAndCommands)
	elseif l:dropAction ==# 'use blank window'
	    execute l:blankWindowNr . 'wincmd w'
	    " Note: Do not use the shortened l:exfilespec here, the :wincmd may
	    " have changed the CWD and thus invalidated the filespec. Instead,
	    " re-shorten the filespec. 
	    execute (l:dropAttributes.readonly ? 'view' : 'edit') a:fileOptionsAndCommands escapings#fnameescape(s:ShortenFilespec(a:filespec))
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
function! s:Drop( filePatternsString )
"****D echomsg '**** Dropped pattern is "' . a:filePatternsString . '". '
    let l:filePatterns = map(split( a:filePatternsString, '\\\@<! '), 'ingofileargs#unescape(v:val)')
    if empty( l:filePatterns )
	throw 'Must pass at least one filespec / pattern!'
    endif

    " Strip off the optional ++opt +cmd file options and commands. 
    let [l:filePatterns, l:fileOptionsAndCommands] = ingofileargs#FilterFileOptionsAndCommands(l:filePatterns)

    let [l:filespecs, l:statistics] = ingofileargs#ResolveExfilePatterns(l:filePatterns)
"****D echomsg '****' string(l:statistics)
"****D echomsg '****' string(l:filespecs)
    if empty(l:filespecs)
	call s:WarningMsg(printf("The file pattern '%s' resulted in no matches.", a:filePatternsString))
	return
    elseif l:statistics.files == 1
	call s:DropSingleFile(l:filespecs[0], s:BuildQueryText(l:filespecs, l:statistics), l:fileOptionsAndCommands)
	return
    endif

    let [l:dropAction, l:dropAttributes] = s:QueryActionForMultipleFiles(s:BuildQueryText(l:filespecs, l:statistics), l:statistics.files)

    let l:fileOptionsAndCommands = (empty(l:fileOptionsAndCommands) ? '' : ' ' . l:fileOptionsAndCommands)
    try
	if empty(l:dropAction)
	    call s:WarningMsg('Canceled opening of ' . l:statistics.files . ' files. ')
	    return
	elseif l:dropAction ==# 'argadd'
	    call s:ExecuteWithoutWildignore('999argadd', l:filespecs)
	    " :argadd just modifies the argument list; l:dropAttributes.readonly
	    " doesn't apply here. l:fileOptionsAndCommands isn't supported,
	    " neither. 

	    " Since :argadd doesn't change the currently edited file, and there
	    " thus is no clash with an "edit file" message, show the new
	    " argument list as a courtesy. 
	    args
	elseif l:dropAction ==# 'argedit'
	    call s:ExecuteWithoutWildignore('confirm args' . l:fileOptionsAndCommands, l:filespecs)
	    if l:dropAttributes.readonly | setlocal readonly | endif
	elseif l:dropAction ==# 'diff'
	    call s:ExecuteForEachFile(
	    \	(&diffopt =~# 'vertical' ? 'vertical' : '') . ' ' . 'belowright ' . (l:dropAttributes.readonly ? 'sview' : 'split') . l:fileOptionsAndCommands,
	    \	(s:IsEmptyTabPage() ? (l:dropAttributes.readonly ? 'view' : 'edit') . l:fileOptionsAndCommands : ''),
	    \	l:filespecs,
	    \	'diffthis'
	    \)
	elseif l:dropAction ==# 'split'
	    call s:ExecuteForEachFile(
	    \	'belowright ' . (l:dropAttributes.readonly ? 'sview' : 'split') . l:fileOptionsAndCommands,
	    \	(s:IsEmptyTabPage() ? (l:dropAttributes.readonly ? 'view' : 'edit') . l:fileOptionsAndCommands : ''),
	    \	l:filespecs
	    \)
	elseif l:dropAction ==# 'vsplit'
	    call s:ExecuteForEachFile(
	    \	'belowright ' . (l:dropAttributes.readonly ? 'vertical sview' : 'vsplit') . l:fileOptionsAndCommands,
	    \	(s:IsEmptyTabPage() ? (l:dropAttributes.readonly ? 'view' : 'edit') . l:fileOptionsAndCommands : ''),
	    \	l:filespecs
	    \)
	elseif l:dropAction ==# 'show'
	    call s:ExecuteForEachFile(
	    \	'topleft sview' . l:fileOptionsAndCommands,
	    \	(s:IsEmptyTabPage() ? 'view' . l:fileOptionsAndCommands : ''),
	    \	reverse(l:filespecs)
	    \)
	elseif l:dropAction ==# 'new tab'
	    call s:ExecuteForEachFile(
	    \	'tabedit' . l:fileOptionsAndCommands . (l:dropAttributes.readonly ? ' +setlocal\ readonly' : ''),
	    \	(s:IsEmptyTabPage() ? (l:dropAttributes.readonly ? 'view' : 'edit') . l:fileOptionsAndCommands : ''),
	    \	l:filespecs
	    \)
	elseif l:dropAction ==# 'new GVIM'
	    call s:ExternalGvimForEachFile( (l:dropAttributes.readonly ? 'view' : 'edit') . l:fileOptionsAndCommands, l:filespecs )
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
" double quotes, but contain escaped spaces. 
" We do specify multiple arguments, so that file completion works for all
" arguments. With -complete=file, the arguments are also automatically unescaped
" from exfilespec to normal filespecs. 
:command! -nargs=+ -complete=file Drop call <SID>Drop(<q-args>)

if g:dropquery_RemapDrop
    cabbrev <expr> drop (getcmdtype() == ':' && strpart(getcmdline(), 0, getcmdpos() - 1) =~# '^\s*drop$' ? 'Drop' : 'drop')
endif

let &cpo = s:save_cpo

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
