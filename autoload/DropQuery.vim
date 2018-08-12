" DropQuery.vim: Ask the user how a :drop'ped file be opened.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" DEPENDENCIES:
"   - ingo/actions.vim autoload script
"   - ingo/buffer.vim autoload script
"   - ingo/cmdargs/file.vim autoload script
"   - ingo/cmdargs/glob.vim autoload script
"   - ingo/compat.vim autoload script
"   - ingo/err.vim autoload script
"   - ingo/escape.vim autoload script
"   - ingo/escape/file.vim autoload script
"   - ingo/external.vim autoload script
"   - ingo/fs/path.vim autoload script
"   - ingo/msg.vim autoload script
"   - ingo/query.vim autoload script
"   - ingo/window/preview.vim autoload script
"   - ingo/window/quickfix.vim autoload script
"   - ingo/window/special.vim autoload script
"   - :MoveChangesHere command (optional)
"
" Copyright: (C) 2005-2018 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" REVISION	DATE		REMARKS
"	098	13-Jul-2018	Use b:appendAfterLnum (if set) for
"                               :MoveChangesHere. This allows filetypes (like
"                               changelog, fortunes) to set the insert point.
"	097	08-Dec-2017	Replace :doautocmd with ingo#event#Trigger().
"	096	07-Dec-2017	ENH: DWIM: Introduce s:isLastDropToArgList and
"				put "argadd" choice in front if the last (single
"				or multiple) argument(s) was added, too.
"	095	28-Nov-2017	Remove &argadd for multiple files if in blank
"				window and there are no arguments yet.
"	094	05-Feb-2016	Re-apply filespec expansion to absolute one in
"				DWIM case.
"				Actions like |Split| don't work with explicit
"				:cd and :set autochdir. Workaround this by
"				skipping filespec shortening in
"				s:ShortenFilespec() (not needed with :set
"				autochdir, anyway). My autolcd.vim plugin
"				instead temporarily turns off 'autochdir'.
"	093	04-Feb-2016	DWIM: Better handling when passed a
"				backslash-delimited Windows-style path on Unix.
"	092	29-May-2015	ENH: Add "add to quickfix" option for multi-file
"				drop.
"				Re-introduce :argadd unconditionally (to avoid
"				switching files), as I found it useful. Assign
"				fixed accelerators &argadd and ar&gedit.
"	091	28-May-2015	With Vim 7.4.565, :99999tabedit causes "E16:
"				Invalid range"; use tabpagenr('$') instead.
"				FIX: Missing accelerator on multi-file "new
"				tab".
"				ENH: Add "badd" option that just does :badd.
"	090	03-Mar-2015	ENH: Add "arg+add" option that adds the current
"				buffer (if it's the single one) to the argument
"				list _and_ the dropped file(s). Useful when
"				collecting individual files to the argument
"				list.
"	089	13-Feb-2015	BUG: Inconsistent use of ingo#msg vs. ingo#err
"				and return status of functions. Straighten out
"				and document.
"				Return success status also from
"				DropQuery#DropBuffer().
"	088	07-Feb-2015	ENH: Keep previous (last accessed) window after
"				having moved away. Add a:previousWinNr argument
"				to s:RestoreMove(), and use that also in
"				s:MoveAway().
"	087	30-Jan-2015	Switch to
"				ingo#regexp#fromwildcard#AnchoredToPathBoundaries()
"				to correctly enforce path boundaries in :Drop
"				{reg} and :{range}Drop {glob}.
"	086	22-Oct-2014	Add g:DropQuery_FilespecProcessor to allow hook
"				functions to tweak the opened filespecs.
"	085	30-Sep-2014	ENH: :Drop also takes a register name, whose
"				lines are treated as filespecs, similar to the
"				passed range.
"	084	29-Sep-2014	ENH: :Drop takes an optional range to treat
"				lines in the buffer as filespecs.
"				Add a:rangeList argument to DropQuery#Drop(),
"				and return state now, as we now need explicit
"				error handling.
"	083	06-Jul-2014	Use ingo#window#preview#OpenFilespec().
"	082	06-Jun-2014	When in the preview window and there's a normal
"				window below, offer "edit below" as first
"				choice.
"				Add "ask individually" action for multiple
"				dropped files.
"	081	23-May-2014	Use ingo#fs#path#Exists() instead of
"				filereadable().
"	080	20-May-2014	Add "above" split choice.
"	079	30-Apr-2014	Factor out s:Query() functionality to
"				ingo#query#ConfirmAsText().
"				Bump sleep length to focus the popup from 200 ms
"				to 300 ms as the old value didn't properly focus
"				it at least on sake.
"				Factor out the entire voodoo to a more amenable
"				g:DropQuery_PopupFocusCommand configuration
"				variable.
"	078	03-Apr-2014	FIX: Avoid "E516: No buffers deleted" when
"				opening in external GVIM and the dropped file
"				has been unloaded already here. Need to check
"				for the buffer being loaded, not just for its
"				existence.
"	077	26-Feb-2014	Allow both "&new tab" and "new &tab"
"				accelerators when there's only a single tab
"				page.
"	076	19-Feb-2014	FIX: Correct empty argument type to
"				s:DropSingleFile() when dropping a buffer.
"	075	11-Feb-2014	Correctly handle :Drop ++ff=dos +1 file command
"				with multiple fileOptionsAndCommands. Requires
"				changed
"				ingo#cmdargs#file#FilterFileOptionsAndCommands()
"				API that now returns a List.
"				FIX: Also pass fileOptionsAndCommands to
"				external GVIM; forgot to append the variable to
"				the externalCommand.
"				FIX: Missing whitespace when executing :setlocal
"				command in s:ExecuteFileOptionsAndCommands().
"				Use ingo#escape#Unescape() there.
"	074	18-Nov-2013	ingo#buffer#IsBlank() now supports optional
"				argument.
"	073	02-Oct-2013	ENH: Add another query to "external GVIM" when
"				there are other GVIM instances, and offer to
"				open the file(s) in an existing instance.
"				ENH: When dropping multiple files to "external
"				GVIM", offer to :Drop all files in one new GVIM
"				instance in addition to the existing opening
"				each in a new instance. This probably makes more
"				sense in most situations (though there may be
"				use cases for the separate instances, too).
"	072	08-Aug-2013	Move escapings.vim into ingo-library.
"	071	03-Jul-2013	BUG: Invalid buffer drop action "open"; the
"				correct name is "edit".
"			    	Move ingoactions.vim into ingo-library.
"   	070	14-Jun-2013	Minor: Make substitute() robust against
"				'ignorecase'.
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
"				Refactored special '!' escaping for :! Ex
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
"				Unix, because the filespec is passed in Ex
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
"				Switched main filespec format from normal to Ex
"				syntax; Vim commands and user display use
"				s:ConvertExfilespecToNormalFilespec() to
"				unescape the Ex syntax; that was formerly done
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

let s:isLastDropToArgList = 0
function! s:IsVisibleWindow( filespec )
    let l:winNr = bufwinnr(ingo#escape#file#bufnameescape(a:filespec))
    return l:winNr != -1
endfunction
function! s:IsEmptyTabPage()
    return (
    \	tabpagewinnr(tabpagenr(), '$') <= 1 &&
    \	ingo#buffer#IsBlank()
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
function! s:GetOtherVims()
    return filter(
    \   split(serverlist(), '\n'),
    \   'v:val !=# v:servername'
    \)
endfunction

function! s:SaveGuiOptions()
    let l:savedGuiOptions = ''
    if has('gui_running') && g:DropQuery_NoPopup
	let l:savedGuiOptions = &guioptions
	set guioptions+=c   " Temporarily avoid popup dialog.
    endif

    if ! g:DropQuery_NoPopup
	execute g:DropQuery_PopupFocusCommand
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
	let l:choice = ingo#query#ConfirmAsText(a:msg, a:choices, a:default, 'Question')
    call s:RestoreGuiOptions( l:savedGuiOptions )
    return l:choice
endfunction

function! s:ShortenFilespec( filespec )
    if &autochdir " && expand('%:p:h') !=# getcwd()
	" Unfortunately, the built-in :split commands do not work with
	" 'autochdir' when the CWD has been changed, as the implementation does
	" not take the directory change into account and doesn't translate the
	" filespec after switching windows. To work around this, don't shorten
	" the absolute filespec when 'autochdir' is set; it's not needed in that
	" case, anyway (as the CWD will continuously change and buffer paths
	" adapted).
	return a:filespec
    endif

    return fnamemodify(a:filespec, ':~:.')
endfunction
function! s:BufDeleteExisting( filespec )
    let l:existingBufNr = bufnr(ingo#escape#file#bufnameescape(a:filespec))
    if l:existingBufNr != -1 && bufloaded(l:existingBufNr)
	try
	    execute l:existingBufNr . 'bdelete'
	catch /^Vim\%((\a\+)\)\=:E89:/ " E89: No write since last change
	    call ingo#msg#WarningMsg(printf('Buffer %d has unsaved changes here: %s', l:existingBufNr, bufname(l:existingBufNr)))
	catch /^Vim\%((\a\+)\)\=:/
	    call ingo#msg#VimExceptionMsg() " Need to print this here as we want to avoid interrupting the outer flow.
	endtry
    endif
endfunction
function! s:ExternalGvimForEachFile( openCommand, filespecs )
"*******************************************************************************
"* PURPOSE:
"   Opens each filespec in a:filespecs in an external GVIM.
"   Unmodified filespecs that are already open in this instance are unloaded to
"   avoid a swap file warning in the new instance. For modified buffers, a
"   warning is printed.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Launches one new GVIM instance per passed filespec.
"* INPUTS:
"   a:openCommand   Ex command used to open each file in a:exfilespecs.
"   a:filespecs	    List of absolute filespecs.
"* RETURN VALUES:
"   none
"*******************************************************************************
    for l:filespec in a:filespecs
	call s:BufDeleteExisting(l:filespec)

	" Note: Must use full absolute filespecs; the new GVIM instance may have
	" a different CWD.
	let l:externalCommand = a:openCommand . ' ' . ingo#compat#fnameescape(l:filespec)

	" Simply passing the file as an argument to GVIM would add the file to
	" the argument list. We're using an explicit a:openCommand instead.
	" Bonus: With this, special handling of the 'readonly' attribute (-R
	" argument) is avoided.
	call ingo#external#LaunchGvim([l:externalCommand])
    endfor
endfunction
function! s:ExternalGvimForAllFiles( fileOptionsAndCommands, filespecs )
"*******************************************************************************
"* PURPOSE:
"   Drops all a:filespecs in an external GVIM.
"   Unmodified filespecs that are already open in this instance are unloaded to
"   avoid a swap file warning in the new instance. For modified buffers, a
"   warning is printed.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Launches one new GVIM instance.
"* INPUTS:
"   a:fileOptionsAndCommands	String containing all optional file options and
"				commands; can be empty.
"   a:filespecs	    List of absolute filespecs.
"* RETURN VALUES:
"   none
"*******************************************************************************
    let l:externalCommand = 'Drop' . a:fileOptionsAndCommands
    for l:filespec in a:filespecs
	call s:BufDeleteExisting(l:filespec)

	" Note: Must use full absolute filespecs; the new GVIM instance may have
	" a different CWD.
	let l:externalCommand .= ' ' . ingo#compat#fnameescape(l:filespec)
    endfor

    call ingo#external#LaunchGvim([l:externalCommand])
endfunction
function! s:OtherGvimForEachFile( servername, fileOptionsAndCommands, filespecs )
"*******************************************************************************
"* PURPOSE:
"   Drops all a:filespecs in the remote GVIM that has a:servername.
"   Unmodified filespecs that are already open in this instance are unloaded to
"   avoid a swap file warning in the new instance. For modified buffers, a
"   warning is printed.
"* ASSUMPTIONS / PRECONDITIONS:
"   A GVIM instance with a:servername exists.
"* EFFECTS / POSTCONDITIONS:
"   Sends :Drop command to external GVIM instance.
"* INPUTS:
"   a:servername    Name of the remote GVIM instance.
"   a:fileOptionsAndCommands	String containing all optional file options and
"				commands; can be empty.
"   a:filespecs	    List of absolute filespecs.
"* RETURN VALUES:
"   none
"*******************************************************************************
    let l:externalCommand = "\<C-\>\<C-n>:Drop" . a:fileOptionsAndCommands
    for l:filespec in a:filespecs
	call s:BufDeleteExisting(l:filespec)

	" Note: Must use full absolute filespecs; the other GVIM instance may
	" have a different CWD.
	let l:externalCommand .= ' ' . ingo#compat#fnameescape(l:filespec)
    endfor

    call remote_send(a:servername, l:externalCommand . "\<CR>")
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
	execute l:excommand ingo#compat#fnameescape(s:ShortenFilespec(l:filespec))
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
	execute a:excommand join(map(copy(a:filespecs), 'ingo#compat#fnameescape(s:ShortenFilespec(v:val))'), ' ')
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
function! s:QueryActionForArguments( actions, isMultipleFiles )
    let l:idx = index(a:actions, 'ar&gedit')
    if argc() == 0 && ! empty(bufname('')) && ! ingo#buffer#ExistOtherBuffers(bufnr(''))
	" There is only the current buffer (which might have been :Drop'ed
	" before). As the plugin doesn't ask for the first buffer (and just
	" :edit's it), but we might want to collect all dropped files into the
	" argument list, offer an option to :argadd the current one plus the
	" :Drop'ed one(s).
	call insert(a:actions, 'arg&+add', l:idx + 1)
    endif
endfunction
function! s:QueryOther( querytext, dropAttributes, otherVims, isMultipleFiles )
    let l:actions = (a:isMultipleFiles ? ['Drop in &new GVIM', '&Each in new GVIM']: ['&new GVIM']) +
    \   map(copy(a:otherVims), 'substitute(v:val, "^\\%(.*\\d\\)\\@!\\|\\d", "\\&&", "")')
    let l:dropAction = s:Query(a:querytext, l:actions, 1)
    if l:dropAction ==# 'new GVIM' || l:dropAction ==# 'Each in new GVIM'
	let l:dropAction = 'external GVIM'
    elseif l:dropAction ==# 'Drop in new GVIM'
	let l:dropAction = 'external single GVIM'
    else
	let a:dropAttributes.servername = l:dropAction
	let l:dropAction = 'other GVIM'
    endif
    return l:dropAction
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
function! s:QueryActionForSingleFile( querytext, isNonexisting, hasOtherBuffers, hasOtherWindows, isVisibleWindow, isLoaded, isInBuffer, isOpenInAnotherTabPage, isBlankWindow )
    let l:dropAttributes = {'readonly': 0}

    " The :edit command can be used to both edit an existing file and create a
    " new file. We'd like to distinguish between the two in the query, however.
    " The changed action label "Create" offers a subtle hint that the dropped
    " file does not exist. This way, the user can cancel the dropping if he
    " doesn't want to create a new file (and mistakenly thought the dropped file
    " already existed).
    let l:editAction = (a:isNonexisting ? '&create' : '&edit')
    let l:otherVims = s:GetOtherVims()
    let l:actions = [l:editAction, '&split', 'a&bove', '&vsplit', '&preview', '&argadd', 'ar&gedit', '&only', 'e&xternal GVIM'.(empty(l:otherVims) ? '' : '...')]
    if a:hasOtherWindows
	call insert(l:actions, '&window...', -1)
    endif
    if tabpagenr('$') == 1
	call insert(l:actions, '&new tab', -1)
	call insert(l:actions, 'new &tab', -1)
    else
	call insert(l:actions, '&new tab', -1)
	call insert(l:actions, '&tab...', -1)
    endif
    if s:isLastDropToArgList
	" Move to the front; it's likely that the next file is meant to be added, too.
	let l:actions = ['&argadd'] + filter(l:actions, 'v:val != "&argadd"')
    endif
    if &l:previewwindow
	if winnr('$') > winnr() && ! ingo#window#special#IsSpecialWindow(winnr() + 1)
	    " When the current window is the preview window, replace the edit
	    " action with a special "edit below" action that corresponds to the
	    " default edit (assuming the preview window is located above a
	    " normal window).
	    let l:actions[0] = l:editAction . ' below'
	else
	    " Move the preview action to the front, and remove the superfluous
	    " equivalent edit action.
	    let l:actions = ['&preview'] + filter(l:actions[1:], 'v:val != "&preview"')
	endif
    endif
    if a:isInBuffer
	call remove(l:actions, 0)
    endif
    if ! a:isNonexisting
	if ! a:isInBuffer
	    call insert(l:actions, 'v&iew', 1)
	endif
	let l:previewIdx = index(l:actions, '&preview')
	if l:previewIdx != -1
	    call insert(l:actions, 's&how', l:previewIdx + 1)
	endif
	call add(l:actions, '&readonly and ask again')
	if ! a:isLoaded
	    call insert(l:actions, 'badd', index(l:actions, 'ar&gedit') + 1)
	endif
    endif
    call s:QueryActionForArguments(l:actions, 0)
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
    if ! a:isInBuffer && &l:modified && ! ingo#fs#path#Exists(expand('%')) && exists(':MoveChangesHere') == 2
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
    if l:dropAction ==# 'external GVIM...'
	let l:dropAction = s:QueryOther(a:querytext, l:dropAttributes, l:otherVims)
    endif
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
    let l:actions = ['&argadd', 'ar&gedit', '&split', '&vsplit', 's&how', 'badd', 'add to &quickfix', '&new tab', 'e&xternal GVIM...', 'open new &tab and ask again', '&readonly and ask again', 'ask &individually']
    if ingo#buffer#ExistOtherBuffers(-1)
	call add(l:actions, '&fresh and ask again')
    endif

    let l:blankWindowNr = s:GetBlankWindowNr()
    if l:blankWindowNr != -1 && l:blankWindowNr == winnr() && argc() == 0
	call filter(l:actions, 'v:val != "&argadd"')
    endif

    call s:QueryActionForArguments(l:actions, 1)
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
    if l:dropAction ==# 'external GVIM...'
	let l:dropAction = s:QueryOther(a:querytext, l:dropAttributes, s:GetOtherVims(), 1)
    endif

    return [l:dropAction, l:dropAttributes]
endfunction
function! s:QueryActionForBuffer( querytext, hasOtherBuffers, hasOtherWindows, isVisibleWindow, isInBuffer, isOpenInAnotherTabPage, isBlankWindow )
    let l:dropAttributes = {'readonly': 0}

    let l:otherVims = s:GetOtherVims()
    let l:actions = ['&edit', '&split', '&vsplit', '&preview', '&only', (tabpagenr('$') == 1 ? 'new &tab' : '&tab...'), 'e&xternal GVIM'.(empty(l:otherVims) ? '' : '...')]
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
    if ! a:isInBuffer && &l:modified && ! ingo#fs#path#Exists(expand('%')) && exists(':MoveChangesHere') == 2
	call insert(l:actions, '&move scratch contents there', 1)
    endif

    let l:dropAction = s:Query(a:querytext, l:actions, 1)
    if l:dropAction ==# 'external GVIM...'
	let l:dropAction = s:QueryOther(a:querytext, l:dropAttributes, l:otherVims)
    endif
    if l:dropAction ==# 'tab...'
	let l:dropAction = s:QueryTab(a:querytext, l:dropAttributes)
    endif

    return [l:dropAction, l:dropAttributes]
endfunction

function! s:IsMoveAway()
    for l:Predicate in g:DropQuery_MoveAwayPredicates
	if ingo#actions#EvaluateOrFunc(l:Predicate)
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
	let l:previousWinNr = winnr('#') ? winnr('#') : 1
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
	call s:RestoreMove(1, l:originalWinNr, l:previousWinNr)
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
function! s:RestoreMove( isMovedAway, originalWinNr, previousWinNr )
    if a:isMovedAway
	if winnr('#') != a:previousWinNr
	    execute a:previousWinNr . 'wincmd w'
	endif
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
"   a:fileOptionsAndCommands	List containing all optional file options and
"				commands; can be empty.
"* RETURN VALUES:
"   None.
"******************************************************************************
    for l:fileOptionOrCommand in a:fileOptionsAndCommands
	if l:fileOptionOrCommand =~# '^++\%(ff\|fileformat\)=' || l:fileOptionOrCommand =~# '^++\%(no\)\?\%(bin\|binary\)$'
	    execute 'setlocal' l:fileOptionOrCommand[2:]
	elseif l:fileOptionOrCommand =~# '^++'
	    " Cannot execute ++enc and ++bad outside of :edit; ++edit only
	    " applies to :read.
	elseif l:fileOptionOrCommand =~# '^+'
	    execute ingo#escape#Unescape(l:fileOptionOrCommand[1:], '\ ')
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
"   a:fileOptionsAndCommands	List containing all optional file options and
"				commands.
"* RETURN VALUES:
"   0 if unsuccessful
"   1 if a file was opened
"   -1 if the opening has been canceled by the user
"*******************************************************************************
"****D echomsg '**** Dropped filespec' string(a:filespec) 'options' string(a:fileOptionsAndCommands)
    let l:exfilespec = ingo#compat#fnameescape(s:ShortenFilespec(a:filespec))
    let l:exFileOptionsAndCommands = join(map(a:fileOptionsAndCommands, "escape(v:val, '\\ ')"))
    let l:exFileOptionsAndCommands = (empty(l:exFileOptionsAndCommands) ? '' : ' ' . l:exFileOptionsAndCommands)
    let l:dropAttributes = {'readonly': 0}
"****D echomsg '****' string(l:exFileOptionsAndCommands) string(l:exfilespec)
    let l:originalBufNr = bufnr('')
    let l:originalWinNr = winnr()
    let l:previousWinNr = winnr('#') ? winnr('#') : 1
    let l:isMovedAway = 0
    let l:isVisibleWindow = s:IsVisibleWindow(a:filespec)
    let l:tabPageNr = s:GetTabPageNr(bufnr(ingo#escape#file#bufnameescape(a:filespec)))
    if ! a:isForceQuery && s:IsEmptyTabPage() && l:tabPageNr == -1
	let l:dropAction = 'edit'
    elseif ! a:isForceQuery && l:isVisibleWindow
	let l:dropAction = 'goto window'
    else
	let l:blankWindowNr = s:GetBlankWindowNr()
	let l:isNonexisting = ! ingo#fs#path#Exists(a:filespec)
	let l:hasOtherBuffers = ingo#buffer#ExistOtherBuffers(bufnr(ingo#escape#file#bufnameescape(a:filespec)))
	let l:hasOtherWindows = (winnr('$') > 1)
	let l:bufNr = bufnr(ingo#escape#file#bufnameescape(a:filespec))
	let l:isLoaded = (l:bufNr != -1)
	let l:isInBuffer = (l:bufNr == bufnr(''))
	let l:isMovedAway = s:MoveAwayAndRefresh()
	let [l:dropAction, l:dropAttributes] = s:QueryActionForSingleFile(
	\   (l:isInBuffer ? substitute(a:querytext, '^\CAction for ', '&this buffer ', '') : a:querytext),
	\   l:isNonexisting,
	\   l:hasOtherBuffers,
	\   l:hasOtherWindows,
	\   l:isVisibleWindow,
	\   l:isLoaded,
	\   l:isInBuffer,
	\   (l:tabPageNr != -1),
	\   (l:blankWindowNr != -1 && l:blankWindowNr != winnr())
	\)
    endif

    let s:isLastDropToArgList = (l:dropAction =~# '^arg')
    try
	if empty(l:dropAction)
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)
	    call ingo#msg#WarningMsg('Canceled opening of file ' . a:filespec)
	    return -1
	elseif l:dropAction ==# 'edit' || l:dropAction ==# 'create'
	    execute 'confirm' (l:dropAttributes.readonly ? 'view' : 'edit') . l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'edit below' || l:dropAction ==# 'create below'
	    execute (winnr() + 1) . 'wincmd w'
	    execute 'confirm' (l:dropAttributes.readonly ? 'view' : 'edit') . l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'view'
	    execute 'confirm view' . l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'diff'
	    if ! s:HasDiffWindow()
		" Emulate :diffsplit because it doesn't allow to open the file
		" read-only.
		diffthis
	    endif
	    " Like :diffsplit, evaluate the 'diffopt' option to determine
	    " whether to split horizontally or vertically.
	    execute (&diffopt =~# 'vertical' ? 'belowright vertical' : s:HorizontalSplitModifier()) (l:dropAttributes.readonly ? 'sview' : 'split') . l:exFileOptionsAndCommands l:exfilespec
	    diffthis
	elseif l:dropAction ==# 'split'
	    execute s:HorizontalSplitModifier() (l:dropAttributes.readonly ? 'sview' : 'split') . l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'above'
	    execute 'aboveleft' (l:dropAttributes.readonly ? 'sview' : 'split') . l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'vsplit'
	    execute 'belowright' (l:dropAttributes.readonly ? 'vertical sview' : 'vsplit') . l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'placement'
	    execute l:dropAttributes.placement (l:dropAttributes.readonly ? 'sview' : 'split') . l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'show'
	    execute 'call TopLeftHook() | topleft sview' . l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'preview'
	    call ingo#window#preview#OpenFilespec(a:filespec, {'isSilent': 0, 'isBang': 0, 'prefixCommand': 'confirm', 'exFileOptionsAndCommands': l:exFileOptionsAndCommands})
	    " The :pedit command does not go to the preview window itself, but
	    " the user probably wants to navigate in there.
	    wincmd P
	    if l:dropAttributes.readonly
		setlocal readonly
	    endif
	elseif l:dropAction ==# 'argedit'
	    execute 'confirm argedit' . l:exFileOptionsAndCommands l:exfilespec
	    if l:dropAttributes.readonly && bufnr('') != l:originalBufNr
		setlocal readonly
	    endif
	elseif l:dropAction ==# 'argadd'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    call s:ExecuteWithoutWildignore(argc() . 'argadd', [a:filespec])
	    " :argadd just modifies the argument list; l:dropAttributes.readonly
	    " doesn't apply here. l:exFileOptionsAndCommands isn't supported,
	    " neither.

	    " Since :argadd doesn't change the currently edited file, and there
	    " thus is no clash with an "edit file" message, show the new
	    " argument list as a courtesy.
	    args
	elseif l:dropAction ==# 'arg+add'
	    call s:ExecuteWithoutWildignore(argc() . 'argadd', [expand('%')])
	    " Try to make the current buffer the current argument; this fails
	    " when changes have been made; ignore this then, and keep the
	    " argument index unset: "((3) of 2)".
	    silent! execute argc() . 'argument'

	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    call s:ExecuteWithoutWildignore(argc() . 'argadd', [a:filespec])
	    " :argadd just modifies the argument list; l:dropAttributes.readonly
	    " doesn't apply here. l:exFileOptionsAndCommands isn't supported,
	    " neither.

	    " Since :argadd doesn't change the currently edited file, and there
	    " thus is no clash with an "edit file" message, show the new
	    " argument list as a courtesy.
	    args
	elseif l:dropAction ==# 'badd'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    execute 'badd' l:exfilespec
	    " :badd just modifies the buffer list; l:dropAttributes.readonly
	    " doesn't apply here. l:exFileOptionsAndCommands isn't supported,
	    " neither.
	    " Since :badd doesn't change the currently edited file, and there
	    " thus is no clash with an "edit file" message, show the new buffer
	    " number as a courtesy.
	    let l:addedBufferFilespec = ingo#escape#file#bufnameescape(a:filespec)
	    let l:addedBufNr = bufnr(l:addedBufferFilespec)
	    if l:addedBufNr != -1
		echo printf("%d\t\"%s\"", l:addedBufNr, bufname(l:addedBufferFilespec))
	    endif
	elseif l:dropAction ==# 'only'
	    " BF: Avoid :drop command as it adds the dropped file to the argument list.
	    "execute 'drop' l:exfilespec . '|only'
	    execute (l:dropAttributes.readonly ? 'sview' : 'split') . l:exFileOptionsAndCommands l:exfilespec . '|only'
	elseif l:dropAction ==# 'fresh'
	    " Note: Taken from the implementation of :ZZ in ingocommands.vim.
	    if argc() > 0
		argdelete *
	    endif

	    execute (l:dropAttributes.readonly ? 'view!' : 'edit!') . l:exFileOptionsAndCommands l:exfilespec
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
	    let l:exfilespec = ingo#compat#fnameescape(s:ShortenFilespec(a:filespec))

	    execute 'confirm' (l:dropAttributes.readonly ? 'view' : 'edit') . l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'new tab'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    execute tabpagenr('$') . 'tabedit' . l:exFileOptionsAndCommands l:exfilespec
	    if l:dropAttributes.readonly && bufnr('') != l:originalBufNr
		setlocal readonly
	    endif
	elseif l:dropAction ==# 'tabnr'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    execute 'tabnext' l:dropAttributes.tabnr

	    " Note: Do not use the shortened l:exfilespec here, the :tabnext may
	    " have changed the CWD and thus invalidated the filespec. Instead,
	    " re-shorten the absolute filespec.
	    let l:exfilespec = ingo#compat#fnameescape(s:ShortenFilespec(a:filespec))

	    let l:blankWindowNr = s:GetBlankWindowNr()
	    if l:blankWindowNr == -1
		execute s:HorizontalSplitModifier() (l:dropAttributes.readonly ? 'sview' : 'split') . l:exFileOptionsAndCommands l:exfilespec
	    else
		execute l:blankWindowNr . 'wincmd w'
		execute 'confirm' (l:dropAttributes.readonly ? 'view' : 'edit') . l:exFileOptionsAndCommands l:exfilespec
	    endif
	elseif l:dropAction ==# 'goto tab'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    " The :drop command would do the trick and switch to the correct tab
	    " page, but it is to be avoided as it adds the dropped file to the
	    " argument list.
	    " Instead, first go to the tab page, then activate the correct window.
	    execute 'tabnext' l:tabPageNr
	    execute bufwinnr(ingo#escape#file#bufnameescape(a:filespec)) . 'wincmd w'
	    if l:dropAttributes.readonly && bufnr('') != l:originalBufNr
		setlocal readonly
	    endif
	    call s:ExecuteFileOptionsAndCommands(a:fileOptionsAndCommands)
	elseif l:dropAction ==# 'goto window'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    " BF: Avoid :drop command as it adds the dropped file to the argument list.
	    " Do not use the :drop command to activate the window which contains the
	    " dropped file.
	    "execute 'drop' . l:exFileOptionsAndCommands l:exfilespec
	    execute bufwinnr(ingo#escape#file#bufnameescape(a:filespec)) . 'wincmd w'
	    if l:dropAttributes.readonly && bufnr('') != l:originalBufNr
		setlocal readonly
	    endif
	    call s:ExecuteFileOptionsAndCommands(a:fileOptionsAndCommands)
	elseif l:dropAction ==# 'use blank window'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    execute l:blankWindowNr . 'wincmd w'
	    " Note: Do not use the shortened l:exfilespec here, the :wincmd may
	    " have changed the CWD and thus invalidated the filespec. Instead,
	    " re-shorten the absolute filespec.
	    execute (l:dropAttributes.readonly ? 'view' : 'edit') . l:exFileOptionsAndCommands ingo#compat#fnameescape(s:ShortenFilespec(a:filespec))
	elseif l:dropAction ==# 'external GVIM'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)
	    call s:ExternalGvimForEachFile((l:dropAttributes.readonly ? 'view' : 'edit') . l:exFileOptionsAndCommands, [ a:filespec ])
	elseif l:dropAction ==# 'other GVIM'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)
	    call s:OtherGvimForEachFile(l:dropAttributes.servername, l:exFileOptionsAndCommands, [ a:filespec ])
	elseif l:dropAction ==# 'move scratch contents there'
	    execute 'belowright split' . l:exFileOptionsAndCommands l:exfilespec
	    execute (exists('b:appendAfterLnum') ? b:appendAfterLnum : '$') . 'MoveChangesHere'
	else
	    throw 'Invalid dropAction: ' . l:dropAction
	endif

	return 1
    catch /^Vim\%((\a\+)\)\=:/
	call ingo#err#SetVimException()
	return 0
    endtry
endfunction
function! DropQuery#Drop( isForceQuery, filePatternsString, rangeList )
"******************************************************************************
"* PURPOSE:
"	? What the procedure does (not how).
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"	? Explanation of each argument that isn't obvious.
"* RETURN VALUES:
"   0 if unsuccessful
"   1 if file(s) were opened
"   -1 if the opening has been canceled by the user
"******************************************************************************
"****D echomsg '**** Dropped pattern is "' . a:filePatternsString . '". '
    let l:filePatterns = ingo#cmdargs#file#SplitAndUnescape(a:filePatternsString)
    if empty(l:filePatterns) && empty(a:rangeList)
	call ingo#err#Set('filespec, glob, or range required')
	return 0
    endif

    " Strip off the optional ++opt +cmd file options and commands.
    let [l:filePatterns, l:fileOptionsAndCommands] = ingo#cmdargs#file#FilterFileOptionsAndCommands(l:filePatterns)

    if ! empty(a:rangeList) || len(l:filePatterns) == 1 && l:filePatterns[0] =~# '^[-a-zA-Z0-9"*+_/]$'
	if empty(a:rangeList)
	    " :Drop {reg}
	    let l:lines = split(getreg(l:filePatterns[0]), '\n')
	    let l:filePatterns = []
	else
	    " :{range}Drop [{glob}]
	    let l:lines = getline(a:rangeList[0], a:rangeList[1])
	endif

	" Take all non-empty lines.
	let l:nonEmptyLines =
	\   filter(
	\       map(
	\           l:lines,
	\           'ingo#str#Trim(v:val)'
	\       ),
	\       'v:val =~# "\\S"'
	\   )

	if ! empty(l:nonEmptyLines)
	    " Further filter the lines by the passed glob(s).
	    let l:rangeGlobExpr =
	    \   join(
	    \       map(
	    \           l:filePatterns,
	    \           'ingo#regexp#fromwildcard#AnchoredToPathBoundaries(v:val)'
	    \       ),
	    \       '\|'
	    \   )
	    let l:filePatterns = filter(l:nonEmptyLines, 'v:val =~ l:rangeGlobExpr')
	endif
    endif

    if ! empty(g:DropQuery_FilespecProcessor)
	call map(l:filePatterns, 'call(g:DropQuery_FilespecProcessor, [v:val])')
    endif

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

    if l:statistics.files == 1 && l:statistics.nonexisting == 1 && ingo#fs#path#Separator() ==# '/' && l:filePatterns[0] =~# '\\' && l:filePatterns[0] !~# '/'
	" DWIM: A backslash-separated filespec has been passed on Unix. Instead
	" of offering to create a monster of a long filename, normalize and try
	" again.
	let [l:filespecs, l:statistics] = ingo#cmdargs#glob#Resolve(map(l:filePatterns, 'ingo#fs#path#Normalize(v:val)'))
	call map(l:filespecs, 'fnamemodify(v:val, ":p")')
    endif

    if empty(l:filespecs)
	call ingo#msg#WarningMsg(printf("The file pattern '%s' resulted in no matches.", a:filePatternsString))
	return -1
    elseif l:statistics.files == 1
	return s:DropSingleFile(a:isForceQuery, l:filespecs[0], s:BuildQueryText(l:filespecs, l:statistics), l:fileOptionsAndCommands)
    endif

    let l:originalWinNr = winnr()
    let l:previousWinNr = winnr('#') ? winnr('#') : 1
    let l:isMovedAway = s:MoveAwayAndRefresh()
    let [l:dropAction, l:dropAttributes] = s:QueryActionForMultipleFiles(s:BuildQueryText(l:filespecs, l:statistics), l:statistics.files)

    let l:exFileOptionsAndCommands = join(map(l:fileOptionsAndCommands, "escape(v:val, '\\ ')"))
    let l:exFileOptionsAndCommands = (empty(l:exFileOptionsAndCommands) ? '' : ' ' . l:exFileOptionsAndCommands)

    let s:isLastDropToArgList = (l:dropAction =~# '^arg')
    try
	if empty(l:dropAction)
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)
	    call ingo#msg#WarningMsg('Canceled opening of ' . l:statistics.files . ' files. ')
	    return -1
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

	if l:dropAction ==# 'ask individually'
	    let l:success = 0
	    for l:filespec in l:filespecs
		if l:success == 1
		    redraw  " Otherwise, the individual drop result (e.g. a split window) wouldn't be visible yet.
		endif
		let l:success = (s:DropSingleFile(1, l:filespec, s:BuildQueryText([l:filespec], {'files': 1, 'removed': 0, 'nonexisting': 0}), l:fileOptionsAndCommands) == 1)
		if ! l:success
		    " Need to print this here to fit into the interactive flow.
		    call ingo#msg#ErrorMsg(ingo#err#Get())
		endif
	    endfor
	elseif l:dropAction ==# 'argedit'
	    call s:ExecuteWithoutWildignore('confirm args' . l:exFileOptionsAndCommands, l:filespecs)
	    if l:dropAttributes.readonly | setlocal readonly | endif
	elseif l:dropAction ==# 'argadd'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    call s:ExecuteWithoutWildignore(argc() . 'argadd', l:filespecs)
	    " :argadd just modifies the argument list; l:dropAttributes.readonly
	    " doesn't apply here. l:fileOptionsAndCommands isn't supported,
	    " neither.

	    " Since :argadd doesn't change the currently edited file, and there
	    " thus is no clash with an "edit file" message, show the new
	    " argument list as a courtesy.
	    args
	elseif l:dropAction ==# 'arg+add'
	    call s:ExecuteWithoutWildignore(argc() . 'argadd', [expand('%')])
	    " Try to make the current buffer the current argument; this fails
	    " when changes have been made; ignore this then, and keep the
	    " argument index unset: "((3) of 2)".
	    silent! execute argc() . 'argument'

	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    call s:ExecuteWithoutWildignore(argc() . 'argadd', l:filespecs)
	    " :argadd just modifies the argument list; l:dropAttributes.readonly
	    " doesn't apply here. l:fileOptionsAndCommands isn't supported,
	    " neither.

	    " Since :argadd doesn't change the currently edited file, and there
	    " thus is no clash with an "edit file" message, show the new
	    " argument list as a courtesy.
	    args
	elseif l:dropAction ==# 'badd'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    let l:bufNum = bufnr('$')
	    call s:ExecuteForEachFile('badd', '', l:filespecs)
	    " :badd just modifies the buffer list; l:dropAttributes.readonly
	    " doesn't apply here. l:exFileOptionsAndCommands isn't supported,
	    " neither.
	    " Since :badd doesn't change the currently edited file, and there
	    " thus is no clash with an "edit file" message, notify about the
	    " number of added buffers as a courtesy.
	    let l:addedBufNum = bufnr('$') - l:bufNum
	    if l:addedBufNum == 0
		call ingo#msg#WarningMsg('No new buffers were added')
	    else
		echo printf('Added %d buffers', l:addedBufNum)
	    endif
	elseif l:dropAction ==# 'add to quickfix'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    silent call ingo#event#Trigger('QuickFixCmdPre DropQuery') | " Allow hooking into the quickfix update.
		call setqflist(map(
		\   l:filespecs,
		\   "{'filename': v:val, 'lnum': 1}"
		\), 'a')
	    silent call ingo#event#Trigger('QuickFixCmdPost DropQuery') | " Allow hooking into the quickfix update.
	    " This just modifies the quickfix list; l:dropAttributes.readonly
	    " doesn't apply here. l:exFileOptionsAndCommands isn't supported,
	    " neither.
	    " Since this doesn't change the currently edited file, and there
	    " thus is no clash with an "edit file" message, notify about the
	    " total and number of added entries as a courtesy.
	    echo printf('Add %d entries; total now is %d', len(l:filespecs), len(getqflist()))
	elseif l:dropAction ==# 'diff'
	    call s:ExecuteForEachFile(
	    \	(&diffopt =~# 'vertical' ? 'vertical' : '') . ' ' . 'belowright ' . (l:dropAttributes.readonly ? 'sview' : 'split') . l:exFileOptionsAndCommands,
	    \	(s:IsEmptyTabPage() ? (l:dropAttributes.readonly ? 'view' : 'edit') . l:exFileOptionsAndCommands : ''),
	    \	l:filespecs,
	    \	'diffthis'
	    \)
	elseif l:dropAction ==# 'split'
	    call s:ExecuteForEachFile(
	    \	'belowright ' . (l:dropAttributes.readonly ? 'sview' : 'split') . l:exFileOptionsAndCommands,
	    \	(s:IsEmptyTabPage() ? (l:dropAttributes.readonly ? 'view' : 'edit') . l:exFileOptionsAndCommands : ''),
	    \	l:filespecs
	    \)
	elseif l:dropAction ==# 'vsplit'
	    call s:ExecuteForEachFile(
	    \	'belowright ' . (l:dropAttributes.readonly ? 'vertical sview' : 'vsplit') . l:exFileOptionsAndCommands,
	    \	(s:IsEmptyTabPage() ? (l:dropAttributes.readonly ? 'view' : 'edit') . l:exFileOptionsAndCommands : ''),
	    \	l:filespecs
	    \)
	elseif l:dropAction ==# 'show'
	    call s:ExecuteForEachFile(
	    \	'call TopLeftHook() | topleft sview' . l:exFileOptionsAndCommands,
	    \	(s:IsEmptyTabPage() ? 'view' . l:exFileOptionsAndCommands : ''),
	    \	reverse(l:filespecs)
	    \)
	elseif l:dropAction ==# 'new tab'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    " Note: Cannot use tabpagenr('$') here, as each file will increase
	    " it, but the expression isn't reevaluated. Just use a very large
	    " value to force adding as the last tab page for each one.
	    call s:ExecuteForEachFile(
	    \	tabpagenr('$') . 'tabedit' . l:exFileOptionsAndCommands . (l:dropAttributes.readonly ? ' +setlocal\ readonly' : ''),
	    \	(s:IsEmptyTabPage() ? (l:dropAttributes.readonly ? 'view' : 'edit') . l:exFileOptionsAndCommands : ''),
	    \	l:filespecs
	    \)
	elseif l:dropAction ==# 'external GVIM'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)
	    call s:ExternalGvimForEachFile((l:dropAttributes.readonly ? 'view' : 'edit') . l:exFileOptionsAndCommands, l:filespecs)
	elseif l:dropAction ==# 'external single GVIM'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)
	    call s:ExternalGvimForAllFiles(l:exFileOptionsAndCommands, l:filespecs)
	elseif l:dropAction ==# 'other GVIM'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)
	    call s:OtherGvimForEachFile(l:dropAttributes.servername, l:exFileOptionsAndCommands, l:filespecs)
	else
	    throw 'Invalid dropAction: ' . l:dropAction
	endif

	if l:dropAttributes.fresh && empty(bufname(l:newBufNr))
	    execute printf('silent! %dbdelete', l:newBufNr)
	endif

	return 1
    catch /^Vim\%((\a\+)\)\=:/
	call ingo#err#SetVimException()
	return 0
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
"   0 if unsuccessful
"   1 if a buffer was opened
"   -1 if the opening has been canceled by the user
"*******************************************************************************
    let l:bufNr = (a:0 ? bufnr(a:1) : (a:bufNr == 0 ? bufnr('') : a:bufNr))
    if ! bufexists(l:bufNr)
	call ingo#err#Set('No such buffer: ' . (a:0 ? a:1 : a:bufNr))
	return 0
    endif
    let l:bufName = bufname(l:bufNr)

    let l:originalBufNr = bufnr('')
    let l:originalWinNr = winnr()
    let l:previousWinNr = winnr('#') ? winnr('#') : 1
    let l:isMovedAway = 0
    let l:isForceQuery = (a:isForceQuery || l:bufNr == l:originalBufNr)
    let l:isVisibleWindow = (bufwinnr(l:bufNr) != -1)
    let l:tabPageNr = s:GetTabPageNr(l:bufNr)
    if ! l:isForceQuery && s:IsEmptyTabPage() && l:tabPageNr == -1
	let l:dropAction = 'edit'
    elseif ! l:isForceQuery && l:isVisibleWindow
	let l:dropAction = 'goto window'
    elseif ingo#fs#path#Exists(l:bufName)
	return s:DropSingleFile(l:isForceQuery, l:bufName, printf('Action for %s?', l:bufName), [])
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
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)
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
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

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
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    execute tabpagenr('$') . 'tab sbuffer' l:bufNr
	elseif l:dropAction ==# 'tabnr'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    execute 'tabnext' l:dropAttributes.tabnr

	    let l:blankWindowNr = s:GetBlankWindowNr()
	    if l:blankWindowNr == -1
		execute s:HorizontalSplitModifier() 'sbuffer' l:bufNr
	    else
		execute l:blankWindowNr . 'wincmd w'
		execute 'confirm buffer' l:bufNr
	    endif
	elseif l:dropAction ==# 'goto tab'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    " The :drop command would do the trick and switch to the correct tab
	    " page, but it is to be avoided as it adds the dropped file to the
	    " argument list.
	    " Instead, first go to the tab page, then activate the correct window.
	    execute 'tabnext' l:tabPageNr
	    execute bufwinnr(l:bufNr) . 'wincmd w'
	elseif l:dropAction ==# 'goto window'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    execute bufwinnr(l:bufNr) . 'wincmd w'
	elseif l:dropAction ==# 'use blank window'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    execute l:blankWindowNr . 'wincmd w'
	    execute 'buffer' l:bufNr
	elseif l:dropAction ==# 'external GVIM' || l:dropAction ==# 'other GVIM'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    let l:bufContents = getbufline(l:bufNr, 1, '$')
	    if getbufvar(l:bufNr, '&fileformat') ==# 'dos'
		call map(l:bufContents, 'v:val . "\r"')
	    endif

	    let l:tempFilespec = tempname()
	    if writefile(l:bufContents, l:tempFilespec) == -1
		call ingo#err#Set('Write of transfer temp file failed: ' . l:tempFilespec)
		return 0
	    endif

	    " Forcibly unload the buffer from this Vim instance; it does not
	    " make sense to edit the same buffer in two different instances.
	    silent! execute l:bufNr . 'bdelete!'

	    let l:externalCommands = [
	    \   'edit ' . ingo#compat#fnameescape(l:tempFilespec),
	    \   'chdir ' . ingo#compat#fnameescape(getcwd()),
	    \   (empty(l:bufName) ? '0file' : 'file ' . ingo#compat#fnameescape(fnamemodify(l:bufName, ':p'))),
	    \   printf('if line2byte(line(''$'') + 1) > 0 | setl modified | call delete(%s) | endif',  string(l:tempFilespec))
	    \]

	    if l:dropAction ==# 'external GVIM'
		call ingo#external#LaunchGvim(l:externalCommands)
	    elseif l:dropAction ==# 'other GVIM'
		call remote_send(l:dropAttributes.servername, "\<C-\>\<C-n>:" . join(l:externalCommands, '|') . "\<CR>")
	    else
		throw 'ASSERT: Invalid dropAction: ' . string(l:dropAction)
	    endif
	elseif l:dropAction ==# 'move scratch contents there'
	    execute 'belowright sbuffer' l:bufNr
	    execute '$MoveChangesHere'
	else
	    throw 'Invalid dropAction: ' . l:dropAction
	endif
	return 1
    catch /^Vim\%((\a\+)\)\=:/
	call ingo#err#SetVimException()
	return 0
    endtry
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
