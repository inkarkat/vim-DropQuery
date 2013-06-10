" DropQuery.vim: Ask the user how a :drop'ped file be opened.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" DEPENDENCIES:
"   - ingo/buffer.vim autoload script
"   - ingo/cmdargs/file.vim autoload script
"   - ingo/cmdargs/glob.vim autoload script
"   - ingo/msg.vim autoload script
"   - ingo/external.vim autoload script
"   - ingo/window/quickfix.vim autoload script
"   - escapings.vim autoload script
"   - ingoactions.vim autoload script
"   - :MoveChangesHere command (optional)
"
" Copyright: (C) 2005-2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" REVISION	DATE		REMARKS
"	069	01-Jun-2013	Move ingofileargs.vim into ingo-library.
"	068	29-May-2013	Extract s:IsBlankBuffer() and
"				s:HasOtherBuffers() into ingo-library.
"	067	08-Apr-2013	Move ingowindow.vim functions into ingo-library.
"	066	18-Mar-2013	CHG: Move "show" accelerator from "w" to "h",
"				and "view" accelerator from "v" to "i";
"				reinstate "v" accelerator for "vsplit".
"				ENH: Allow to select the target window via new
"				"winnr" and "placement" actions.
"	065	15-Mar-2013	CHG: Stay in the preview window, as the user
"				probably wants to navigate in the opened file.
"				XXX: :pedit uses the CWD of the preview window.
"				If that already contains a file with another
"				CWD, the shortened command is wrong. Always use
"				the absolute filespec.
"				FIX: Expand all filespecs to full absolute
"				paths. (Though when :Drop'ping files " from
"				external tools like SendToGVIM, this is
"				typically already done to " deal with different
"				CWDs.) It's more precise to show the full path
"				for a " (single) file in the query, and prevents
"				problems with :set autochdir or " autocmds that
"				change the CWD, especially when :split'ing
"				multiple files or " commands that first move to
"				a different window.
"	064	06-Mar-2013	Change accelerator for multiple dropped files
"				from "new tab" to "open new tab and ask again",
"				as I mostly use that. Also remove "new tab"
"				action when re-querying; hardly makes sense to
"				have an empty tab page in between when appending
"				as tabs.
"				After "new tab", :redraw! to have the new blank
"				tab page visible before re-querying.
"				Rename "new GVIM" action to "external GVIM" and
"				use the "n" accelerator to also offer "new tab"
"				when there are already multiple tab pages.
"	063	28-Jan-2013	ENH: Re-introduce "new GVIM" action for dropped
"				buffers. Transfer the buffer contents via a temp
"				file to the new Vim instance, and remove the
"				buffer here.
"				FIX: Add missing "goto tab" action for dropped
"				buffers.
"				Unload existing unmodified buffers when dropping
"				file(s) to a "new GVIM" action to avoid a swap
"				file warning in the new instance, and print a
"				warning for modified buffers.
"				FIX: Pass the full absolute filespec to "new
"				GVIM" instance; the CWD may be different.
"				FIX: Handle file options or commands separated
"				by multiple whitespace.
"	062	27-Jan-2013	ENH: Allow forced query with [!]. Check for
"				current buffer already containing the dropped
"				target and omit senseless actions like "goto
"				window", "edit", "view", "diff", "move scratch
"				contents there", etc. then.
"				:BufDrop with neither [N] nor {bufname} brings
"				up a forced query with the current buffer as the
"				target: :BufDrop! %
"	061	26-Jan-2013	ENH: Implement :BufDrop command that takes
"				either an existing buffer number or name.
"				Delegate to s:DropSingleFile() for buffers
"				representing an existing file, and query from a
"				reduced set of actions for non-persisted
"				buffers.
"				FIX: "fresh" action first :bdeleted the dropped
"				file's buffer if it's already loaded. Since I
"				don't remember and can't find a good reason for
"				why the current buffer was spared in deletion,
"				then replaced with the dropped one and finally
"				deleted, let's drop first (with edit!), then
"				delete all other buffers.
"				FIX: Condition for "fresh" option still wrong.
"				Need to except the dropped buffer (number, or
"				file if it's already loaded), not the current
"				one.
"	060	25-Jan-2013	ENH: When the current window is the preview
"				window, move that action to the front, and
"				remove the superfluous equivalent edit action.
"				ENH: The quickfix list (but not a location list)
"				should remain at the bottom of Vim; do not use
"				'belowright' for horizontal splits then.
"				ENH: Move away from special windows (like the
"				sidebar panels from plugins like Project,
"				TagBar, NERD_tree, etc.) before querying the
"				user. It does not make sense to re-use that
"				special (small) window, and neither to do
"				(horizontal) splits.
"				The special windows are detected via predicate
"				expressions or functions configured in
"				g:DropQuery_MoveAwayPredicates.
"	059	25-Jan-2013	Split off autoload script.
"				Use ingo#msg#WarningMsg() and
"				ingo#msg#VimExceptionMsg().
"	058	11-Dec-2012	ENH: When the current buffer is a modified,
"				unpersisted scratch buffer, offer to "move
"				scratch contents there".
"	057	17-Sep-2012	Change 'show' split behavior to add custom
"				TopLeftHook() before :topleft. Without it, when
"				the topmost window has a winheight of 0 (in
"				Rolodex mode), Vim somehow makes all window
"				heights equal. I prefer to have the new window
"				open with a minimal height of 1, and keep the
"				other window heights as stable as possible. It's
"				much easier to change the height of the new
"				current window than recreating the previous
"				Rolodex-based layout with the original and the
"				new windows visible.
"				Move g:previewwindowsplitmode to the front of
"				the command to allow multiple commands joined
"				with cmd1 | winsplitcmd2.
"	056	27-Aug-2012	Factor out and use
"				ingofileargs#SplitAndUnescapeArguments().
"				Rename ingofileargs#ResolveExfilePatterns() to
"				ingofileargs#ResolveGlobs(), as it basically is
"				an extended version of
"				ingofileargs#ExpandGlobs().
"	055	02-Aug-2012	CHG: All new tabs open as the last tab, not the
"				next one. I think this is more useful and
"				consistent with what browsers to.
"	054	30-Jul-2012	Change from hard-coded :999argadd to the actual
"				max number. Same for :999tabedit.
"	053	29-Jul-2012	BUG: Canceling multi-file drop throws "Invalid
"				l:dropAction"; must abort function after
"				checking for empty value and printing warning.
"	052	01-Jun-2012	BUG: Drop of single file to existing different
"				tab is susceptible to changes of CWD; re-shorten
"				the filespec here, too. (Also for "fresh" option
"				out of precaution bordering paranoia.)
"	051	30-May-2012	ENH: Allow custom preview window placement via
"				g:previewwindowsplitmode.
"	050	22-May-2012	BUG: Must re-escape a:fileOptionsAndCommands
"				when :executing the command. Otherwise, stuff
"				like ":Drop +setf\ txt dropquery.vim" won't
"				work.
"	049	05-Apr-2012	ENH: Add "fresh" option for multiple files, too.
"				FIX: Correct condition for "fresh" option via
"				ingo#buffer#ExistOtherBuffers().
"				ENH: Change "new tab" button to "tab" button
"				with follow-up 1, 2, new query when more than
"				one tab is open.
"				Reintroduce single-file "readonly and ask again"
"				that was lightheartedly removed when "view" was
"				added. I still want to view a file in a new tab,
"				for example.
"	048	04-Apr-2012	CHG: For single files, remove accelerator from
"				"vsplit", add "view" instead.
"				ENH: Add "fresh" option for single files, which
"				clears all buffers and removes all arguments.
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
"				BF: In the :! Ex command, the character '!' must
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
let s:save_cpo = &cpo
set cpo&vim

function! s:IsVisibleWindow( filespec )
    let l:winNr = bufwinnr(escapings#bufnameescape(a:filespec))
    return l:winNr != -1
endfunction
function! s:IsEmptyTabPage()
    return (
    \	tabpagewinnr(tabpagenr(), '$') <= 1 &&
    \	ingo#buffer#IsBlank(bufnr(''))
    \)
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
	if ingo#buffer#IsBlank(winbufnr(l:winnr))
	    return l:winnr
	endif
    endfor
    return -1
endfunction
function! s:GetTabPageNr( targetBufNr )
"*******************************************************************************
"* PURPOSE:
"   If a:targetBufNr is visible on another tab page, return the tab page number.
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:targetBufNr Number of existing buffer.
"* RETURN VALUES:
"   Tab page number of the first tab page (other than the current one) where the
"   buffer is visible; else -1.
"*******************************************************************************
    if a:targetBufNr == -1
	return -1   " There's no such buffer.
    endif

    if tabpagenr('$') == 1
	return -1   " There's only one tab.
    endif

    for l:tabPage in range( 1, tabpagenr('$') )
	if l:tabPage == tabpagenr()
	    continue	" Skip current tab page.
	endif
	for l:bufNr in tabpagebuflist( l:tabPage )
	    if l:bufNr == a:targetBufNr
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
    if has('gui_running') && g:DropQuery_NoPopup
	let l:savedGuiOptions = &guioptions
	set guioptions+=c   " Temporarily avoid popup dialog.
    endif

    if ! g:DropQuery_NoPopup
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
    if has('gui_running') && g:DropQuery_NoPopup
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
"   Unmodified filespecs that are already open in this instance are unloaded to
"   avoid a swap file warning in the new instance. For modified buffers, a
"   warning is printed.
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:openCommand   Ex command used to open each file in a:exfilespecs.
"   a:filespecs	    List of absolute filespecs.
"* RETURN VALUES:
"   none
"*******************************************************************************
    for l:filespec in a:filespecs
	let l:existingBufNr = bufnr(escapings#bufnameescape(l:filespec))
	if l:existingBufNr != -1
	    try
		execute l:existingBufNr . 'bdelete'
	    catch /^Vim\%((\a\+)\)\=:E89/ " E89: No write since last change
		call ingo#msg#WarningMsg(printf('Buffer %d has unsaved changes here: %s', l:existingBufNr, bufname(l:existingBufNr)))
	    catch /^Vim\%((\a\+)\)\=:E/
		call ingo#msg#VimExceptionMsg()
	    endtry
	endif

	" Note: Must use full absolute filespecs; the new GVIM instance may have
	" a different CWD.
	let l:externalCommand = a:openCommand . ' ' . escapings#fnameescape(l:filespec)

	" Simply passing the file as an argument to GVIM would add the file to
	" the argument list. We're using an explicit a:openCommand instead.
	" Bonus: With this, special handling of the 'readonly' attribute (-R
	" argument) is avoided.
	call ingo#external#LaunchGvim([l:externalCommand])
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
"   a:excommand		    Ex command which will be invoked with each filespec.
"   a:specialFirstExcommand Ex command which will be invoked for the first filespec.
"			    If empty, the a:excommand will be invoked for the
"			    first filespec just like any other.
"   a:filespecs		    List of filespecs.
"   a:afterExcommand	    Optional Ex command which will be invoked after
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
"   a:excommand	    Ex command to be invoked
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
function! s:QueryWindow( querytext, dropAttributes )
    let l:actions = ['new &top', 'new &bottom', 'new &above', 'new &leftmost', 'new &rightmost'] +
    \   map(range(1, winnr('$')), '(v:val < 10 ? "&" . v:val : v:val) . (v:val ==' . winnr() . '? " (current)" : "")')
    let l:dropAction = s:Query(a:querytext, l:actions, 1)
    if l:dropAction =~# '(current)$'
	let l:dropAction = 'edit'
    elseif l:dropAction =~# '^\d\+$'
	let a:dropAttributes.winnr = l:dropAction
	let l:dropAction = 'winnr'
    elseif ! empty(l:dropAction)
	let a:dropAttributes.placement = {
	\   'new top': 'topleft',
	\   'new bottom': 'botright',
	\   'new above': 'aboveleft',
	\   'new leftmost': 'aboveleft vertical',
	\   'new rightmost': 'belowright vertical'
	\}[l:dropAction]
	let l:dropAction = 'placement'
    endif
    return l:dropAction
endfunction
function! s:QueryTab( querytext, dropAttributes )
    let l:actions = ['&new tab'] + map(range(1, tabpagenr('$')), 'v:val < 10 ? "&" . v:val : v:val')
    let l:dropAction = s:Query(a:querytext, l:actions, 1)
    if l:dropAction =~# '^\d\+$'
	let a:dropAttributes.tabnr = l:dropAction
	let l:dropAction = 'tabnr'
    endif
    return l:dropAction
endfunction
function! s:QueryActionForSingleFile( querytext, isNonexisting, hasOtherBuffers, hasOtherWindows, isVisibleWindow, isInBuffer, isOpenInAnotherTabPage, isBlankWindow )
    let l:dropAttributes = {'readonly': 0}

    " The :edit command can be used to both edit an existing file and create a
    " new file. We'd like to distinguish between the two in the query, however.
    " The changed action label "Create" offers a subtle hint that the dropped
    " file does not exist. This way, the user can cancel the dropping if he
    " doesn't want to create a new file (and mistakenly thought the dropped file
    " already existed).
    let l:editAction = (a:isNonexisting ? '&create' : '&edit')
    let l:actions = [l:editAction, '&split', '&vsplit', '&preview', '&argedit', '&only', 'e&xternal GVIM']
    if a:hasOtherWindows
	call insert(l:actions, '&window...', -1)
    endif
    if tabpagenr('$') == 1
	call insert(l:actions, 'new &tab', -1)
    else
	call insert(l:actions, '&new tab', -1)
	call insert(l:actions, '&tab...', -1)
    endif
    if &l:previewwindow
	" When the current window is the preview window, move that action to the
	" front, and remove the superfluous equivalent edit action.
	let l:actions = ['&preview'] + filter(l:actions[1:], 'v:val != "&preview"')
    endif
    if a:isInBuffer
	call remove(l:actions, 0)
    endif
    call s:QueryActionForArguments(l:actions)
    if ! a:isNonexisting
	if ! a:isInBuffer
	    call insert(l:actions, 'v&iew', 1)
	endif
	let l:previewIdx = index(l:actions, '&preview')
	if l:previewIdx != -1
	    call insert(l:actions, 's&how', l:previewIdx + 1)
	endif
	call add(l:actions, '&readonly and ask again')
    endif
    if a:hasOtherBuffers
	call insert(l:actions, '&fresh', index(l:actions, '&only') + 1)
    endif
    if ! a:isNonexisting && ! a:isBlankWindow && ! a:isInBuffer
	call insert(l:actions, '&diff', index(l:actions, '&split'))
    endif
    if a:isBlankWindow
	call insert(l:actions, 'use &blank window')
    endif
    if a:isOpenInAnotherTabPage
	call insert(l:actions, '&goto tab')
    endif
    if ! a:isInBuffer && a:isVisibleWindow
	call insert(l:actions, '&goto window')
    endif
    if ! a:isInBuffer && &l:modified && ! filereadable(expand('%')) && exists(':MoveChangesHere') == 2
	call insert(l:actions, '&move scratch contents there', 1)
    endif

    while 1
	let l:dropAction = s:Query(a:querytext, l:actions, 1)
	if l:dropAction ==# 'readonly and ask again'
	    let l:dropAttributes.readonly = 1
	    call filter(l:actions, 'v:val !~# "^.\\?readonly"')
	else
	    break
	endif
    endwhile
    if l:dropAction ==# 'window...'
	let l:dropAction = s:QueryWindow(a:querytext, l:dropAttributes)
    endif
    if l:dropAction ==# 'tab...'
	let l:dropAction = s:QueryTab(a:querytext, l:dropAttributes)
    endif

    return [l:dropAction, l:dropAttributes]
endfunction
function! s:QueryActionForMultipleFiles( querytext, fileNum )
    let l:dropAttributes = {'readonly': 0, 'fresh' : 0}
    let l:actions = ['&argedit', '&split', '&vsplit', 's&how', 'new tab', 'e&xternal GVIM', 'open new &tab and ask again', '&readonly and ask again']
    if ingo#buffer#ExistOtherBuffers(-1)
	call add(l:actions, '&fresh and ask again')
    endif
    call s:QueryActionForArguments(l:actions)
    if a:fileNum <= 4
	call insert(l:actions, '&diff', index(l:actions, '&split'))
    endif

    " Avoid "E36: Not enough room" when trying to open more splits than
    " possible.
    if a:fileNum > &lines   | call filter(l:actions, 'v:val !=# "&split" && v:val !=# "s&how"')  | endif
    if a:fileNum > &columns | call filter(l:actions, 'v:val !=# "&vsplit"') | endif

    while 1
	let l:dropAction = s:Query(a:querytext, l:actions, 1)
	if l:dropAction ==# 'open new tab and ask again'
	    execute tabpagenr('$') . 'tabnew'
	    redraw! " Without this, the new blank tab page isn't visible.
	    call filter(l:actions, 'v:val !~# "^.\\?open .\\?new .\\?tab\\|^.\\?new .\\?tab"')
	elseif l:dropAction ==# 'readonly and ask again'
	    let l:dropAttributes.readonly = 1
	    call filter(l:actions, 'v:val !~# "^.\\?readonly"')
	elseif l:dropAction ==# 'fresh and ask again'
	    let l:dropAttributes.fresh = 1
	    call filter(l:actions, 'v:val !~# "^.\\?fresh\\|^.\\?argadd"')
	else
	    break
	endif
    endwhile

    return [l:dropAction, l:dropAttributes]
endfunction
function! s:QueryActionForBuffer( querytext, hasOtherBuffers, hasOtherWindows, isVisibleWindow, isInBuffer, isOpenInAnotherTabPage, isBlankWindow )
    let l:dropAttributes = {'readonly': 0}

    let l:actions = ['&open', '&split', '&vsplit', '&preview', '&only', (tabpagenr('$') == 1 ? 'new &tab' : '&tab...'), 'e&xternal GVIM']
    if &l:previewwindow
	" When the current window is the preview window, move that action to the
	" front, and remove the superfluous equivalent edit action.
	let l:actions = ['&preview'] + filter(l:actions[1:], 'v:val != "&preview"')
    endif
    if a:isInBuffer
	call remove(l:actions, 0)
    endif
    let l:previewIdx = index(l:actions, '&preview')
    if l:previewIdx != -1
	call insert(l:actions, 's&how', l:previewIdx + 1)
    endif
    if a:hasOtherBuffers
	call insert(l:actions, '&fresh', index(l:actions, '&only') + 1)
    endif
    if a:isBlankWindow
	call insert(l:actions, 'use &blank window')
    elseif ! a:isInBuffer
	call insert(l:actions, '&diff', index(l:actions, '&split'))
    endif
    if a:isOpenInAnotherTabPage
	call insert(l:actions, '&goto tab')
    endif
    if ! a:isInBuffer && a:isVisibleWindow
	call insert(l:actions, '&goto window')
    endif
    if ! a:isInBuffer && &l:modified && ! filereadable(expand('%')) && exists(':MoveChangesHere') == 2
	call insert(l:actions, '&move scratch contents there', 1)
    endif

    let l:dropAction = s:Query(a:querytext, l:actions, 1)
    if l:dropAction ==# 'tab...'
	let l:dropAction = s:QueryTab(a:querytext, l:dropAttributes)
    endif

    return [l:dropAction, l:dropAttributes]
endfunction

function! s:IsMoveAway()
    for l:Predicate in g:DropQuery_MoveAwayPredicates
	if ingoactions#EvaluateOrFunc(l:Predicate)
	    return 1
	endif
	unlet l:Predicate   " The type might change, avoid E706.
    endfor
    return 0
endfunction
function! s:MoveAway()
    if winnr('$') == 1
	return 0 " Nowhere to turn to.
    endif

    if s:IsMoveAway()
	let l:originalWinNr = winnr()
	if winnr('#') != winnr()
	    " Try the previous window first.
	    wincmd p
	    if ! s:IsMoveAway()
		return 1    " Okay, we can stay there.
	    endif
	endif

	" Check all other available windows until we find one where we can stay.
	for l:winNr in filter(range(1, winnr('$')), 'v:val != l:originalWinNr')
	    execute l:winNr . 'wincmd w'
	    if ! s:IsMoveAway()
		return 1
	    endif
	endfor

	" No chance; remain at the original window.
	execute l:originalWinNr . 'wincmd w'
    endif

    return 0
endfunction
function! s:MoveAwayAndRefresh()
    let l:isMovedAway = s:MoveAway()
    if l:isMovedAway
	" Make the automatic switch of the current window visible before
	" querying the user.
	redraw
    endif
    return l:isMovedAway
endfunction
function! s:RestoreMove( isMovedAway, originalWinNr )
    if a:isMovedAway
	execute a:originalWinNr . 'wincmd w'
    endif
endfunction
function! s:HorizontalSplitModifier()
    if ingo#window#quickfix#IsQuickfixList(1) == 1
	" The quickfix list (but not a location list) should remain at the
	" bottom of Vim.
	return 'aboveleft'
    endif

    return 'belowright'
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
    for l:fileOptionOrCommand in split(a:fileOptionsAndCommands, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\s\+')
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

function! s:DropSingleFile( isForceQuery, filespec, querytext, fileOptionsAndCommands )
"*******************************************************************************
"* PURPOSE:
"   Prompts the user for the action to be taken with the dropped file.
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:isForceQuery  Flag whether to skip default actions and always query
"		    instead.
"   a:filespec	    Filespec of the dropped file. It is already expanded to an
"		    absolute path by DropQuery#Drop().
"   a:querytext	    Text to be presented to the user.
"   a:fileOptionsAndCommands	String containing all optional file options and
"				commands.
"* RETURN VALUES:
"   none
"*******************************************************************************
"****D echomsg '**** Dropped filespec' string(a:filespec) 'options' string(a:fileOptionsAndCommands)
    let l:exfilespec = escapings#fnameescape(s:ShortenFilespec(a:filespec))
    let l:exFileOptionsAndCommands = escape(a:fileOptionsAndCommands, ' \')
    let l:dropAttributes = {'readonly': 0}

    let l:originalBufNr = bufnr('')
    let l:originalWinNr = winnr()
    let l:isMovedAway = 0
    let l:isVisibleWindow = s:IsVisibleWindow(a:filespec)
    let l:tabPageNr = s:GetTabPageNr(bufnr(escapings#bufnameescape(a:filespec)))
    if ! a:isForceQuery && s:IsEmptyTabPage() && l:tabPageNr == -1
	let l:dropAction = 'edit'
    elseif ! a:isForceQuery && l:isVisibleWindow
	let l:dropAction = 'goto window'
    else
	let l:blankWindowNr = s:GetBlankWindowNr()
	let l:isNonexisting = empty(filereadable(a:filespec))
	let l:hasOtherBuffers = ingo#buffer#ExistOtherBuffers(bufnr(escapings#bufnameescape(a:filespec)))
	let l:hasOtherWindows = (winnr('$') > 1)
	let l:isInBuffer = (bufnr(escapings#bufnameescape(a:filespec)) == bufnr(''))
	let l:isMovedAway = s:MoveAwayAndRefresh()
	let [l:dropAction, l:dropAttributes] = s:QueryActionForSingleFile(
	\   (l:isInBuffer ? substitute(a:querytext, '^Action for ', '&this buffer ', '') : a:querytext),
	\   l:isNonexisting,
	\   l:hasOtherBuffers,
	\   l:hasOtherWindows,
	\   l:isVisibleWindow,
	\   l:isInBuffer,
	\   (l:tabPageNr != -1),
	\   (l:blankWindowNr != -1 && l:blankWindowNr != winnr())
	\)
    endif

    try
	if empty(l:dropAction)
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr)
	    call ingo#msg#WarningMsg('Canceled opening of file ' . a:filespec)
	elseif l:dropAction ==# 'edit' || l:dropAction ==# 'create'
	    execute 'confirm' (l:dropAttributes.readonly ? 'view' : 'edit') l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'view'
	    execute 'confirm view' l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'diff'
	    if ! s:HasDiffWindow()
		" Emulate :diffsplit because it doesn't allow to open the file
		" read-only.
		diffthis
	    endif
	    " Like :diffsplit, evaluate the 'diffopt' option to determine
	    " whether to split horizontally or vertically.
	    execute (&diffopt =~# 'vertical' ? 'belowright vertical' : s:HorizontalSplitModifier()) (l:dropAttributes.readonly ? 'sview' : 'split') l:exFileOptionsAndCommands l:exfilespec
	    diffthis
	elseif l:dropAction ==# 'split'
	    execute s:HorizontalSplitModifier() (l:dropAttributes.readonly ? 'sview' : 'split') l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'vsplit'
	    execute 'belowright' (l:dropAttributes.readonly ? 'vertical sview' : 'vsplit') l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'placement'
	    execute l:dropAttributes.placement (l:dropAttributes.readonly ? 'sview' : 'split') l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'show'
	    execute 'call TopLeftHook() | topleft sview' l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'preview'
	    " XXX: :pedit uses the CWD of the preview window. If that already
	    " contains a file with another CWD, the shortened command is wrong.
	    " Always use the absolute filespec.
	    execute (exists('g:previewwindowsplitmode') ? g:previewwindowsplitmode : '') 'confirm pedit' l:exFileOptionsAndCommands escapings#fnameescape(a:filespec)
	    " The :pedit command does not go to the preview window itself, but
	    " the user probably wants to navigate in there.
	    wincmd P
	    if l:dropAttributes.readonly
		setlocal readonly
	    endif
	elseif l:dropAction ==# 'argedit'
	    execute 'confirm argedit' l:exFileOptionsAndCommands l:exfilespec
	    if l:dropAttributes.readonly && bufnr('') != l:originalBufNr
		setlocal readonly
	    endif
	elseif l:dropAction ==# 'argadd'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr)

	    call s:ExecuteWithoutWildignore(argc() . 'argadd', [a:filespec])
	    " :argadd just modifies the argument list; l:dropAttributes.readonly
	    " doesn't apply here. l:exFileOptionsAndCommands isn't supported,
	    " neither.

	    " Since :argadd doesn't change the currently edited file, and there
	    " thus is no clash with an "edit file" message, show the new
	    " argument list as a courtesy.
	    args
	elseif l:dropAction ==# 'only'
	    " BF: Avoid :drop command as it adds the dropped file to the argument list.
	    "execute 'drop' l:exfilespec . '|only'
	    execute (l:dropAttributes.readonly ? 'sview' : 'split') l:exFileOptionsAndCommands l:exfilespec . '|only'
	elseif l:dropAction ==# 'fresh'
	    " Note: Taken from the implementation of :ZZ in ingocommands.vim.
	    if argc() > 0
		argdelete *
	    endif

	    execute (l:dropAttributes.readonly ? 'view!' : 'edit!') l:exFileOptionsAndCommands l:exfilespec
	    let l:newBufNr = bufnr('')
	    let l:maxBufNr = bufnr('$')
	    if l:newBufNr > 1
		execute printf('confirm silent! 1,%dbdelete', (l:newBufNr - 1))
	    endif
	    if l:newBufNr < l:maxBufNr
		execute printf('confirm silent! %d,%dbdelete', (l:newBufNr + 1), l:maxBufNr)
	    endif
	elseif l:dropAction ==# 'winnr'
	    execute l:dropAttributes.winnr . 'wincmd w'

	    " Note: Do not use the shortened l:exfilespec here, the window
	    " change may have changed the CWD and thus invalidated the filespec.
	    " Instead, re-shorten the absolute filespec.
	    let l:exfilespec = escapings#fnameescape(s:ShortenFilespec(a:filespec))

	    execute 'confirm' (l:dropAttributes.readonly ? 'view' : 'edit') l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'new tab'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr)

	    execute tabpagenr('$') . 'tabedit' l:exFileOptionsAndCommands l:exfilespec
	    if l:dropAttributes.readonly && bufnr('') != l:originalBufNr
		setlocal readonly
	    endif
	elseif l:dropAction ==# 'tabnr'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr)

	    execute 'tabnext' l:dropAttributes.tabnr

	    " Note: Do not use the shortened l:exfilespec here, the :tabnext may
	    " have changed the CWD and thus invalidated the filespec. Instead,
	    " re-shorten the absolute filespec.
	    let l:exfilespec = escapings#fnameescape(s:ShortenFilespec(a:filespec))

	    let l:blankWindowNr = s:GetBlankWindowNr()
	    if l:blankWindowNr == -1
		execute s:HorizontalSplitModifier() (l:dropAttributes.readonly ? 'sview' : 'split') l:exFileOptionsAndCommands l:exfilespec
	    else
		execute l:blankWindowNr . 'wincmd w'
		execute 'confirm' (l:dropAttributes.readonly ? 'view' : 'edit') l:exFileOptionsAndCommands l:exfilespec
	    endif
	elseif l:dropAction ==# 'goto tab'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr)

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
	elseif l:dropAction ==# 'goto window'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr)

	    " BF: Avoid :drop command as it adds the dropped file to the argument list.
	    " Do not use the :drop command to activate the window which contains the
	    " dropped file.
	    "execute 'drop' l:exFileOptionsAndCommands l:exfilespec
	    execute bufwinnr(escapings#bufnameescape(a:filespec)) . 'wincmd w'
	    if l:dropAttributes.readonly && bufnr('') != l:originalBufNr
		setlocal readonly
	    endif
	    call s:ExecuteFileOptionsAndCommands(a:fileOptionsAndCommands)
	elseif l:dropAction ==# 'use blank window'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr)

	    execute l:blankWindowNr . 'wincmd w'
	    " Note: Do not use the shortened l:exfilespec here, the :wincmd may
	    " have changed the CWD and thus invalidated the filespec. Instead,
	    " re-shorten the absolute filespec.
	    execute (l:dropAttributes.readonly ? 'view' : 'edit') l:exFileOptionsAndCommands escapings#fnameescape(s:ShortenFilespec(a:filespec))
	elseif l:dropAction ==# 'external GVIM'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr)

	    let l:fileOptionsAndCommands = (empty(l:exFileOptionsAndCommands) ? '' : ' ' . l:exFileOptionsAndCommands)
	    call s:ExternalGvimForEachFile( (l:dropAttributes.readonly ? 'view' : 'edit') . l:fileOptionsAndCommands, [ a:filespec ] )
	elseif l:dropAction ==# 'move scratch contents there'
	    execute 'belowright split' l:exFileOptionsAndCommands l:exfilespec
	    execute '$MoveChangesHere'
	else
	    throw 'Invalid dropAction: ' . l:dropAction
	endif
    catch /^Vim\%((\a\+)\)\=:E/
	call ingo#msg#VimExceptionMsg()
    endtry
endfunction
function! DropQuery#Drop( isForceQuery, filePatternsString )
"****D echomsg '**** Dropped pattern is "' . a:filePatternsString . '". '
    let l:filePatterns = ingo#cmdargs#file#SplitAndUnescape(a:filePatternsString)
    if empty(l:filePatterns)
	throw 'Must pass at least one filespec / pattern!'
    endif

    " Strip off the optional ++opt +cmd file options and commands.
    let [l:filePatterns, l:fileOptionsAndCommands] = ingo#cmdargs#file#FilterFileOptionsAndCommands(l:filePatterns)

    let [l:filespecs, l:statistics] = ingo#cmdargs#glob#Resolve(l:filePatterns)
"****D echomsg '****' string(l:statistics)
"****D echomsg '****' string(l:filespecs)

    " Expand all filespecs to full absolute paths. (Though when :Drop'ping files
    " from external tools like SendToGVIM, this is typically already done to
    " deal with different CWDs.) It's more precise to show the full path for a
    " (single) file in the query, and prevents problems with :set autochdir or
    " autocmds that change the CWD, especially when :split'ing multiple files or
    " commands that first move to a different window.
    call map(l:filespecs, 'fnamemodify(v:val, ":p")')

    if empty(l:filespecs)
	call ingo#msg#WarningMsg(printf("The file pattern '%s' resulted in no matches.", a:filePatternsString))
	return
    elseif l:statistics.files == 1
	call s:DropSingleFile(a:isForceQuery, l:filespecs[0], s:BuildQueryText(l:filespecs, l:statistics), l:fileOptionsAndCommands)
	return
    endif

    let l:originalWinNr = winnr()
    let l:isMovedAway = s:MoveAwayAndRefresh()
    let [l:dropAction, l:dropAttributes] = s:QueryActionForMultipleFiles(s:BuildQueryText(l:filespecs, l:statistics), l:statistics.files)

    let l:fileOptionsAndCommands = (empty(l:fileOptionsAndCommands) ? '' : ' ' . l:fileOptionsAndCommands)
    try
	if empty(l:dropAction)
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr)
	    call ingo#msg#WarningMsg('Canceled opening of ' . l:statistics.files . ' files. ')
	    return
	endif

	if l:dropAttributes.fresh
	    " Note: Taken from the implementation of :ZZ in ingocommands.vim.
	    if argc() > 0
		argdelete *
	    endif
	    " The current buffer may be included in the dropped files, so we
	    " should not simply :bdelete it after the drop action. Instead,
	    " clean out all buffers, and remove the newly created buffer
	    " afterwards. (But careful, that buffer number may have been
	    " re-used!)
	    execute printf('confirm silent! 1,%dbdelete', bufnr('$'))
	    let l:newBufNr = bufnr('')
	endif

	if l:dropAction ==# 'argadd'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr)

	    call s:ExecuteWithoutWildignore(argc() . 'argadd', l:filespecs)
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
	    \	'call TopLeftHook() | topleft sview' . l:fileOptionsAndCommands,
	    \	(s:IsEmptyTabPage() ? 'view' . l:fileOptionsAndCommands : ''),
	    \	reverse(l:filespecs)
	    \)
	elseif l:dropAction ==# 'new tab'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr)

	    " Note: Cannot use tabpagenr('$') here, as each file will increase
	    " it, but the expression isn't reevaluated. Just use a very large
	    " value to force adding as the last tab page for each one.
	    call s:ExecuteForEachFile(
	    \	'99999tabedit' . l:fileOptionsAndCommands . (l:dropAttributes.readonly ? ' +setlocal\ readonly' : ''),
	    \	(s:IsEmptyTabPage() ? (l:dropAttributes.readonly ? 'view' : 'edit') . l:fileOptionsAndCommands : ''),
	    \	l:filespecs
	    \)
	elseif l:dropAction ==# 'external GVIM'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr)

	    call s:ExternalGvimForEachFile( (l:dropAttributes.readonly ? 'view' : 'edit') . l:fileOptionsAndCommands, l:filespecs )
	else
	    throw 'Invalid dropAction: ' . l:dropAction
	endif

	if l:dropAttributes.fresh && empty(bufname(l:newBufNr))
	    execute printf('silent! %dbdelete', l:newBufNr)
	endif
    catch /^Vim\%((\a\+)\)\=:E/
	call ingo#msg#VimExceptionMsg()
    endtry
endfunction
function! DropQuery#DropBuffer( isForceQuery, bufNr, ... )
"*******************************************************************************
"* PURPOSE:
"   Prompts the user for the action to be taken with the dropped buffer number.
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:isForceQuery  Flag whether to skip default actions and always query
"   a:bufNr Number of existing buffer.
"   a:1     Buffer name argument alternative over a:bufNr. Takes precedence over
"	    it.
"* RETURN VALUES:
"   none
"*******************************************************************************
    let l:bufNr = (a:0 ? bufnr(a:1) : (a:bufNr == 0 ? bufnr('') : a:bufNr))
    if ! bufexists(l:bufNr)
	call ingo#msg#ErrorMsg('No such buffer: ' . (a:0 ? a:1 : a:bufNr))
	return
    endif
    let l:bufName = bufname(l:bufNr)

    let l:originalBufNr = bufnr('')
    let l:originalWinNr = winnr()
    let l:isMovedAway = 0
    let l:isForceQuery = (a:isForceQuery || l:bufNr == l:originalBufNr)
    let l:isVisibleWindow = (bufwinnr(l:bufNr) != -1)
    let l:tabPageNr = s:GetTabPageNr(l:bufNr)
    if ! l:isForceQuery && s:IsEmptyTabPage() && l:tabPageNr == -1
	let l:dropAction = 'edit'
    elseif ! l:isForceQuery && l:isVisibleWindow
	let l:dropAction = 'goto window'
    elseif ! empty(filereadable(l:bufName))
	return s:DropSingleFile(l:isForceQuery, l:bufName, printf('Action for %s?', l:bufName), '')
    else
	let l:blankWindowNr = s:GetBlankWindowNr()
	let l:isInBuffer = (l:bufNr == bufnr(''))
	let l:hasOtherWindows = (winnr('$') > 1)
	let l:isMovedAway = s:MoveAwayAndRefresh()
	let l:querytext = printf('Action for %s buffer #%d%s?',
	\   (l:isInBuffer ? 'this' : 'dropped'),
	\   l:bufNr,
	\   (empty(l:bufName) ? '' : ': ' . l:bufName)
	\)
	let [l:dropAction, l:dropAttributes] = s:QueryActionForBuffer(l:querytext,
	\   ingo#buffer#ExistOtherBuffers(l:bufNr),
	\   l:hasOtherWindows,
	\   l:isVisibleWindow,
	\   l:isInBuffer,
	\   (l:tabPageNr != -1),
	\   (l:blankWindowNr != -1 && l:blankWindowNr != winnr())
	\)
    endif

    try
	if empty(l:dropAction)
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr)
	    call ingo#msg#WarningMsg('Canceled opening of buffer #' . l:bufNr)
	elseif l:dropAction ==# 'edit'
	    execute 'confirm buffer' l:bufNr
	elseif l:dropAction ==# 'diff'
	    if ! s:HasDiffWindow()
		" Emulate :diffsplit because it doesn't allow to open the file
		" read-only.
		diffthis
	    endif
	    " Like :diffsplit, evaluate the 'diffopt' option to determine
	    " whether to split horizontally or vertically.
	    execute (&diffopt =~# 'vertical' ? 'belowright vertical' : s:HorizontalSplitModifier()) 'sbuffer' l:bufNr
	    diffthis
	elseif l:dropAction ==# 'split'
	    execute s:HorizontalSplitModifier() 'sbuffer' l:bufNr
	elseif l:dropAction ==# 'vsplit'
	    execute 'belowright vertical sbuffer' l:bufNr
	elseif l:dropAction ==# 'placement'
	    execute l:dropAttributes.placement 'sbuffer' l:bufNr
	elseif l:dropAction ==# 'show'
	    execute 'call TopLeftHook() | topleft sbuffer' l:bufNr
	elseif l:dropAction ==# 'preview'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr)

	    if &l:previewwindow
		execute 'confirm buffer' l:bufNr
	    else
		call ingo#window#preview#OpenPreview()
		execute 'confirm buffer' l:bufNr
		wincmd p
	    endif
	elseif l:dropAction ==# 'only'
	    " BF: Avoid :drop command as it adds the dropped file to the argument list.
	    "execute 'drop' l:exfilespec . '|only'
	    execute 'sbuffer' l:bufNr . '|only'
	elseif l:dropAction ==# 'fresh'
	    " Note: Taken from the implementation of :ZZ in ingocommands.vim.
	    if argc() > 0
		argdelete *
	    endif
	    execute 'confirm buffer' l:bufNr
	    let l:maxBufNr = bufnr('$')
	    if l:bufNr > 1
		execute printf('confirm silent! 1,%dbdelete', (l:bufNr - 1))
	    endif
	    if l:bufNr < l:maxBufNr
		execute printf('confirm silent! %d,%dbdelete', (l:bufNr + 1), l:maxBufNr)
	    endif
	elseif l:dropAction ==# 'winnr'
	    execute l:dropAttributes.winnr . 'wincmd w'
	    execute 'confirm buffer' l:bufNr
	elseif l:dropAction ==# 'new tab'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr)

	    execute tabpagenr('$') . 'tab sbuffer' l:bufNr
	elseif l:dropAction ==# 'tabnr'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr)

	    execute 'tabnext' l:dropAttributes.tabnr

	    let l:blankWindowNr = s:GetBlankWindowNr()
	    if l:blankWindowNr == -1
		execute s:HorizontalSplitModifier() 'sbuffer' l:bufNr
	    else
		execute l:blankWindowNr . 'wincmd w'
		execute 'confirm buffer' l:bufNr
	    endif
	elseif l:dropAction ==# 'goto tab'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr)

	    " The :drop command would do the trick and switch to the correct tab
	    " page, but it is to be avoided as it adds the dropped file to the
	    " argument list.
	    " Instead, first go to the tab page, then activate the correct window.
	    execute 'tabnext' l:tabPageNr
	    execute bufwinnr(l:bufNr) . 'wincmd w'
	elseif l:dropAction ==# 'goto window'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr)

	    execute bufwinnr(l:bufNr) . 'wincmd w'
	elseif l:dropAction ==# 'use blank window'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr)

	    execute l:blankWindowNr . 'wincmd w'
	    execute 'buffer' l:bufNr
	elseif l:dropAction ==# 'external GVIM'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr)

	    let l:bufContents = getbufline(l:bufNr, 1, '$')
	    if getbufvar(l:bufNr, '&fileformat') ==# 'dos'
		call map(l:bufContents, 'v:val . "\r"')
	    endif

	    let l:tempFilespec = tempname()
	    if writefile(l:bufContents, l:tempFilespec) == -1
		call ingo#msg#ErrorMsg('Write of transfer temp file failed: ' . l:tempFilespec)
		return
	    endif

	    " Forcibly unload the buffer from this Vim instance; it does not
	    " make sense to edit the same buffer in two different instances.
	    silent! execute l:bufNr . 'bdelete!'

	    call ingo#external#LaunchGvim([
	    \   'edit ' . escapings#fnameescape(l:tempFilespec),
	    \   'chdir ' . escapings#fnameescape(getcwd()),
	    \   (empty(l:bufName) ? '0file' : 'file ' . escapings#fnameescape(fnamemodify(l:bufName, ':p'))),
	    \   printf('if line2byte(line(''$'') + 1) > 0 | setl modified | call delete(%s) | endif',  string(l:tempFilespec))
	    \])
	elseif l:dropAction ==# 'move scratch contents there'
	    execute 'belowright sbuffer' l:bufNr
	    execute '$MoveChangesHere'
	else
	    throw 'Invalid dropAction: ' . l:dropAction
	endif
    catch /^Vim\%((\a\+)\)\=:E/
	call ingo#msg#VimExceptionMsg()
    endtry
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
