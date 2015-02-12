" DropQuery.vim: Ask the user how a :drop'ped file be opened.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" DEPENDENCIES:
"   - Requires Vim 7.0 or higher.
"   - DropQuery.vim autoload script
"   - ingo/err.vim autoload script
"
" Copyright: (C) 2005-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" REVISION	DATE		REMARKS
"	065	22-Oct-2014	Add g:DropQuery_FilespecProcessor to allow hook
"				functions to tweak the opened filespecs.
"	064	29-Sep-2014	ENH: :Drop takes an optional range to treat
"				lines in the buffer as filespecs.
"				Check for returned state of DropQuery#Drop(), as
"				we now need explicit error handling.
"	063	30-Apr-2014	Introduce g:DropQuery_PopupFocusCommand
"				configuration to enable easier fiddling.
"	062	27-Jan-2013	ENH: Allow forced query with [!].
"	061	26-Jan-2013	ENH: Implement :BufDrop command that takes
"				either an existing buffer number or name.
"	060	25-Jan-2013	ENH: Move away from special windows (like the
"				sidebar panels from plugins like Project,
"				TagBar, NERD_tree, etc.) before querying the
"				user. It does not make sense to re-use that
"				special (small) window, and neither to do
"				(horizontal) splits.
"				The special windows are detected via predicate
"				expressions or functions configured in
"				g:DropQuery_MoveAwayPredicates.
"	059	25-Jan-2013	Split off autoload script.
"				Rename to DropQuery.vim.
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
"				s:HasOtherBuffers().
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

" Avoid installing twice or when in unsupported Vim version.
if exists('g:loaded_DropQuery') || (v:version < 700)
    finish
endif
let g:loaded_DropQuery = 1

"-- configuration -------------------------------------------------------------

if ! exists('g:DropQuery_RemapDrop')
    let g:DropQuery_RemapDrop = 1
endif
if ! exists('g:DropQuery_NoPopup')
    let g:DropQuery_NoPopup = 0
endif
if ! exists('g:DropQuery_MoveAwayPredicates')
    let g:DropQuery_MoveAwayPredicates = []
endif
if ! exists('g:DropQuery_PopupFocusCommand')
    " Focus on the popup dialog requires that activation of Vim from the
    " external call has been completed, so better wait a few milliseconds to
    " avoid that Vim gets focus, but not Vim's popup dialog. This occurred on
    " Windows XP.
    " The sleep workaround still doesn't work all the time on Windows XP. I've
    " empirically found out that I get better luck if foreground() is called
    " before the delay, or maybe I'm just fooled once more. This whole stuff
    " reminds me of witchcraft, not engineering :-)
    let g:DropQuery_PopupFocusCommand = 'call foreground() | sleep 300m'
endif
if ! exists('g:DropQuery_FilespecProcessor')
    let g:DropQuery_FilespecProcessor = ''
endif



"-- commands ------------------------------------------------------------------

" The file pattern passed to :drop should conform to Ex syntax, just as the
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
" double quotes, but contain escaped spaces. This also avoids the unescaping
" peculiarities of <f-args>, which make it fundamentally unsuitable for file
" arguments.
" We do specify multiple arguments, so that file completion works for all
" arguments.
command! -bang -range=-1 -nargs=* -complete=file Drop if ! DropQuery#Drop(<bang>0, <q-args>, (<count> == -1 ? [] : [<line1>, <line2>]))| echoerr ingo#err#Get() | endif

command! -bang -count=0 -nargs=? -complete=buffer BufDrop call DropQuery#DropBuffer(<bang>0, <count>, <f-args>)

if g:DropQuery_RemapDrop
    cabbrev <expr> drop (getcmdtype() == ':' && strpart(getcmdline(), 0, getcmdpos() - 1) =~# '^\s*drop$' ? 'Drop' : 'drop')
endif

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
