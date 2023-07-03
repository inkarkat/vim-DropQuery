" DropQuery.vim: Ask the user how a :drop'ped file be opened.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" DEPENDENCIES:
"   - ingo-library.vim plugin
"   - :MoveChangesHere command (optional)
"
" Copyright: (C) 2005-2023 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
let s:save_cpo = &cpo
set cpo&vim

let s:defaultDropAttributes = {'readonly': 0, 'fresh' : 0}
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
function! s:ExternalGvimForEachFile( openCommand, exFileOptionsAndCommands, filespecs )
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
"   a:exFileOptionsAndCommands	String containing all optional file options and
"				commands; can be empty.
"   a:filespecs	    List of absolute filespecs.
"* RETURN VALUES:
"   none
"*******************************************************************************
    for l:filespec in a:filespecs
	call s:BufDeleteExisting(l:filespec)

	" Note: Must use full absolute filespecs; the new GVIM instance may have
	" a different CWD.
	let l:externalCommand = a:openCommand .
	\   ' ' . (empty(a:exFileOptionsAndCommands) ? '' : ' ' . a:exFileOptionsAndCommands) .
	\   ingo#compat#fnameescape(l:filespec)

	" Simply passing the file as an argument to GVIM would add the file to
	" the argument list. We're using an explicit a:openCommand instead.
	" Bonus: With this, special handling of the 'readonly' attribute (-R
	" argument) is avoided.
	call ingo#external#LaunchGvim([l:externalCommand])
    endfor
endfunction
function! s:ExternalGvimForAllFiles( exFileOptionsAndCommands, filespecs )
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
"   a:exFileOptionsAndCommands	String containing all optional file options and
"				commands; can be empty.
"   a:filespecs	    List of absolute filespecs.
"* RETURN VALUES:
"   none
"*******************************************************************************
    let l:externalCommand = 'Drop' . a:exFileOptionsAndCommands
    for l:filespec in a:filespecs
	call s:BufDeleteExisting(l:filespec)

	" Note: Must use full absolute filespecs; the new GVIM instance may have
	" a different CWD.
	let l:externalCommand .= ' ' . ingo#compat#fnameescape(l:filespec)
    endfor

    call ingo#external#LaunchGvim([l:externalCommand])
endfunction
function! s:OtherGvimForEachFile( servername, exFileOptionsAndCommands, filespecs )
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
"   a:exFileOptionsAndCommands	String containing all optional file options and
"				commands; can be empty.
"   a:filespecs	    List of absolute filespecs.
"* RETURN VALUES:
"   none
"*******************************************************************************
    let l:externalCommand = "\<C-\>\<C-n>:Drop" . a:exFileOptionsAndCommands
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

    if l:excommand[0] ==# '$' && v:version < 800 || v:version == 800 && ! has('patch259')
	" Compatibility: Prior to Vim 8.0.259, :$tabedit did not work; up to Vim
	" 7.4.565 a large count could simply be used, but need to use the last
	" tab page number after that.
	let l:excommand = tabpagenr('$') . l:excommand[1:]
    endif

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
    let l:idx = max([index(a:actions, 'ar&gedit'), index(a:actions, '&argadd')])
    if argc() == 0 && ! empty(bufname('')) && winnr('$') == 1
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
function! s:QueryActionForSingleFile( querytext, isExisting, hasOtherBuffers, hasOtherWindows, hasOtherDiffWindow, isVisibleWindow, isLoaded, isInBuffer, isOpenInAnotherTabPage, isBlankWindow, isCurrentWindowAvailable, default )
    let l:dropAttributes = copy(s:defaultDropAttributes)

    " The :edit command can be used to both edit an existing file and create a
    " new file. We'd like to distinguish between the two in the query, however.
    " The changed action label "Create" offers a subtle hint that the dropped
    " file does not exist. This way, the user can cancel the dropping if he
    " doesn't want to create a new file (and mistakenly thought the dropped file
    " already existed).
    let l:editAction = (a:isCurrentWindowAvailable ? (a:isExisting ? '&edit' : '&create') : '')
    let l:otherVims = s:GetOtherVims()
    let l:actions = []
    if ! empty(l:editAction)
	call add(l:actions, l:editAction)
    endif
    call extend(l:actions, ['&split', 'a&bove', '&vsplit', '&preview', '&argadd'])
    if empty(l:editAction)
	call add(l:actions, 'ar&gedit in split')
    else
	call add(l:actions, 'ar&gedit')
	if a:hasOtherWindows
	    call add(l:actions, '&only')
	endif
    endif
    call add(l:actions, 'e&xternal GVIM'.(empty(l:otherVims) ? '' : '...'))
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
	let l:actions = ['&argadd'] + filter(l:actions, 'v:val !=# "&argadd"')
    endif
    if &l:previewwindow && ! empty(l:editAction)
	if winnr('$') > winnr() && ! ingo#window#special#IsSpecialWindow(winnr() + 1)
	    " When the current window is the preview window, replace the edit
	    " action with a special "edit below" action that corresponds to the
	    " default edit (assuming the preview window is located above a
	    " normal window).
	    let l:actions[0] = l:editAction . ' below'
	else
	    " Move the preview action to the front, and remove the superfluous
	    " equivalent edit action.
	    let l:actions = ['&preview'] + filter(l:actions[1:], 'v:val !=# "&preview"')
	endif
    endif
    if a:isInBuffer && ! empty(l:editAction)
	call remove(l:actions, 0)
    endif
    if a:isExisting
	if ! a:isInBuffer
	    if ! empty(l:editAction)
		call insert(l:actions, 'v&iew', 1)
	    endif
	    if a:hasOtherDiffWindow
		if &l:diff
		    " Keep the current window participating in the diff. This
		    " means that we cannot use DropQuery to unjoin a window from
		    " a diff, but there are several other options to do such
		    " (e.g. splitting and closing the previous window).
		    let l:actions[0] = 'diffthis'
		else
		    " Offer to replace the current buffer and join in the diff.
		    call insert(l:actions, 'diffthis', 1)
		endif
	    endif
	endif
	let l:previewIdx = index(l:actions, '&preview')
	if l:previewIdx != -1
	    call insert(l:actions, 's&how', l:previewIdx + 1)
	endif
	call add(l:actions, '&readonly and ask again')
	if ! a:isLoaded
	    call insert(l:actions, 'badd', max([index(l:actions, 'ar&gedit'), index(l:actions, '&argadd')]) + 1)
	endif
    endif
    call s:QueryActionForArguments(l:actions, 0)
    if a:hasOtherBuffers
	call insert(l:actions, '&fresh', max([index(l:actions, '&only'), index(l:actions, 'ar&gedit'), index(l:actions, '&argadd')]) + 1)
    endif
    if a:isExisting && ! a:isBlankWindow && ! a:isInBuffer
	call insert(l:actions, '&diffsplit', index(l:actions, '&preview'))
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
    if ! a:isInBuffer && ingo#buffer#IsScratch() && exists(':MoveChangesHere') == 2
	call insert(l:actions, '&move scratch contents there', 1)
    endif
    if a:isExisting && &l:modifiable && ! &l:readonly
	call add(l:actions, 'read here')
    endif

    while 1
	let l:dropAction = s:Query(a:querytext, l:actions, a:default)
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
function! s:QueryActionForMultipleFiles( querytext, fileNum, isCurrentWindowAvailable, default )
    let l:dropAttributes = copy(s:defaultDropAttributes)
    let l:actions = ['&argadd']
    if a:isCurrentWindowAvailable
	call add(l:actions, 'ar&gedit')
    else
	call add(l:actions, 'ar&gedit in split')
    endif
    if argc() > 0
	call add(l:actions, 'replace existing args')
    endif
    call extend(l:actions, ['&split', '&vsplit', 's&how', 'badd', 'add to &quickfix', '&new tab', 'e&xternal GVIM...', 'open new &tab and ask again', '&readonly and ask again', 'ask &individually'])
    if ingo#buffer#ExistOtherBuffers(-1)
	call add(l:actions, '&fresh and ask again')
    endif

    let l:blankWindowNr = s:GetBlankWindowNr()
    if l:blankWindowNr != -1 && l:blankWindowNr == winnr() && argc() == 0
	call filter(l:actions, 'v:val !=# "&argadd"')
    endif

    call s:QueryActionForArguments(l:actions, 1)
    if a:fileNum <= 4
	call insert(l:actions, '&diffsplit', index(l:actions, '&split'))
    endif

    if &l:modifiable && ! &l:readonly
	call add(l:actions, 'read here')
    endif

    " Avoid "E36: Not enough room" when trying to open more splits than
    " possible.
    if a:fileNum > &lines   | call filter(l:actions, 'v:val !=# "&split" && v:val !=# "s&how"')  | endif
    if a:fileNum > &columns | call filter(l:actions, 'v:val !=# "&vsplit"') | endif

    while 1
	let l:dropAction = s:Query(a:querytext, l:actions, a:default)
	if l:dropAction ==# 'open new tab and ask again'
	    execute tabpagenr('$') . 'tabnew'
	    redraw! " Without this, the new blank tab page isn't visible.
	    call filter(l:actions, 'v:val !~# "^.\\?open .\\?new .\\?tab\\|^.\\?new .\\?tab" . (argc() == 0 ? "\\|^.\\?argadd" : "")')
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
function! s:QueryActionForBuffer( querytext, hasOtherBuffers, hasOtherWindows, isVisibleWindow, isInBuffer, isOpenInAnotherTabPage, isBlankWindow, isCurrentWindowAvailable, isEmpty )
    let l:dropAttributes = copy(s:defaultDropAttributes)

    let l:editAction = (a:isCurrentWindowAvailable ? '&edit' : '')
    let l:otherVims = s:GetOtherVims()
    let l:actions = []
    if ! empty(l:editAction)
	call add(l:actions, l:editAction)
    endif
    call extend(l:actions, ['&split', '&vsplit', '&preview'])
    if a:hasOtherWindows && ! empty(l:editAction)
	call add(l:actions, '&only')
    endif
    call add(l:actions, (tabpagenr('$') == 1 ? 'new &tab' : '&tab...'))
    call add(l:actions, 'e&xternal GVIM'.(empty(l:otherVims) ? '' : '...'))
    if &l:previewwindow
	" When the current window is the preview window, move that action to the
	" front, and remove the superfluous equivalent edit action.
	let l:actions = ['&preview'] + filter(l:actions[1:], 'v:val !=# "&preview"')
    endif
    if a:isInBuffer && ! empty(l:editAction)
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
	call insert(l:actions, '&diffsplit', index(l:actions, '&preview'))
    endif
    if a:isOpenInAnotherTabPage
	call insert(l:actions, '&goto tab')
    endif
    if ! a:isInBuffer && a:isVisibleWindow
	call insert(l:actions, '&goto window')
    endif
    if ! a:isInBuffer && ingo#buffer#IsScratch() && exists(':MoveChangesHere') == 2
	call insert(l:actions, '&move scratch contents there', 1)
    endif
    if ! a:isEmpty && &l:modifiable && ! &l:readonly
	call add(l:actions, 'read here')
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
function! s:IsExempt()
    for l:Predicate in g:DropQuery_ExemptPredicates
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
	    execute l:fileOptionOrCommand[1:]
	else
	    throw 'Invalid file option / command: ' . l:fileOptionOrCommand
	endif
    endfor
endfunction
function! s:EchoArgsSummary( whatAdded ) abort
    echomsg printf('Now %d argument%s, added %s', argc(), (argc() == 1 ? '' : 's'), a:whatAdded)
endfunction

function! s:GetAutoAction( filespecs ) abort
    for l:AutoAction in g:DropQuery_AutoActions
	if type(l:AutoAction) == type(function('tr'))
	    let l:result = call(l:AutoAction, [a:filespecs])
	    if ! empty(l:result)
		return l:result
	    endif
	elseif type(l:AutoAction) == type([])
	    let [l:glob, l:result] = [l:AutoAction[0], l:AutoAction[1:2]]
	    let l:globPattern = ingo#regexp#fromwildcard#FileOrPath(l:glob)
	    for l:filespec in a:filespecs
		if l:filespec !~# l:globPattern
		    let l:result = []
		    break
		endif
	    endfor
	    if ! empty(l:result)
		return l:result
	    endif
	else
	    throw 'Wrong type in g:DropQuery_AutoActions; not a Funcref or List: ' . string(l:AutoAction)
	endif
    endfor
    return ['', {}]
endfunction
function! s:GetAutoDefault( filespecs ) abort
    for l:AutoDefault in g:DropQuery_AutoDefaults
	if type(l:AutoDefault) == type(function('tr'))
	    let l:default = call(l:AutoDefault, [a:filespecs])
	    if ! empty(l:default)
		return l:default
	    endif
	elseif type(l:AutoDefault) == type([])
	    let [l:glob, l:default] = l:AutoDefault
	    let l:globPattern = ingo#regexp#fromwildcard#FileOrPath(l:glob)
	    for l:filespec in a:filespecs
		if l:filespec !~# l:globPattern
		    let l:default = ''
		    break
		endif
	    endfor
	    if ! empty(l:default)
		return l:default
	    endif
	else
	    throw 'Wrong type in g:DropQuery_AutoDefaults; not a Funcref or List: ' . string(l:AutoDefault)
	endif
    endfor
    return ''
endfunction

function! s:DropSingleFile( isForceQuery, filespec, isExisting, querytext, fileOptionsAndCommands )
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
"   a:isExisting    Flag whether the passed a:filespec exists in the file
"                   system.
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
    let l:exFileOptionsAndCommands = ingo#cmdargs#file#FileOptionsAndCommandsToEscapedExCommandLine(a:fileOptionsAndCommands)
"****D echomsg '****' string(l:exFileOptionsAndCommands) string(l:exfilespec)
    let l:originalBufNr = bufnr('')
    let l:originalWinNr = winnr()
    let l:previousWinNr = winnr('#') ? winnr('#') : 1
    let l:isMovedAway = 0
    let l:isVisibleWindow = s:IsVisibleWindow(a:filespec)
    let l:tabPageNr = s:GetTabPageNr(bufnr(ingo#escape#file#bufnameescape(a:filespec)))

    try
	let [l:dropAction, l:dropAttributes] = s:GetAutoAction([a:filespec])
	let l:dropAttributes = extend(copy(l:dropAttributes), s:defaultDropAttributes)
    catch /^Vim\%((\a\+)\)\=:/
	throw ingo#msg#MsgFromVimException()   " Don't swallow Vimscript errors.
    catch
	call ingo#msg#ErrorMsg(v:exception)    " A custom exception indicates abort.
	return -1
    endtry

    if ! empty(l:dropAction)
	" Action is provided by the auto action.
    elseif ! a:isForceQuery && s:IsEmptyTabPage() && l:tabPageNr == -1
	let l:dropAction = 'edit'
    elseif ! a:isForceQuery && l:isVisibleWindow
	let l:dropAction = 'goto window'
    else
	let l:blankWindowNr = s:GetBlankWindowNr()
	let l:hasOtherBuffers = ingo#buffer#ExistOtherBuffers(bufnr(ingo#escape#file#bufnameescape(a:filespec)))
	let l:hasOtherWindows = (winnr('$') > 1)
	let l:bufNr = bufnr(ingo#escape#file#bufnameescape(a:filespec))
	let l:isLoaded = (l:bufNr != -1)
	let l:isInBuffer = (l:bufNr == bufnr(''))
	let l:isMovedAway = s:MoveAwayAndRefresh()
	let l:default = s:GetAutoDefault([a:filespec])
	let [l:dropAction, l:dropAttributes] = s:QueryActionForSingleFile(
	\   (l:isInBuffer ? substitute(a:querytext, '^\CAction for ', '&this buffer ', '') : a:querytext),
	\   a:isExisting,
	\   l:hasOtherBuffers,
	\   l:hasOtherWindows,
	\   ingo#window#special#HasOtherDiffWindow(),
	\   l:isVisibleWindow,
	\   l:isLoaded,
	\   l:isInBuffer,
	\   (l:tabPageNr != -1),
	\   (l:blankWindowNr != -1 && l:blankWindowNr != winnr()),
	\   ! s:IsExempt(),
	\   (empty(l:default) ? 1 : l:default)
	\)
    endif

    let s:isLastDropToArgList = (l:dropAction =~# '^arg')
    try
	if empty(l:dropAction)
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)
	    call ingo#msg#WarningMsg('Canceled opening of file ' . a:filespec)
	    return -1
	elseif l:dropAction ==# 'edit' || l:dropAction ==# 'create'
	    execute 'confirm' (l:dropAttributes.readonly ? 'view' : 'edit') l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'edit below' || l:dropAction ==# 'create below'
	    execute (winnr() + 1) . 'wincmd w'
	    execute 'confirm' (l:dropAttributes.readonly ? 'view' : 'edit') l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'view'
	    execute 'confirm view' l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'diffthis'
	    execute 'confirm' (l:dropAttributes.readonly ? 'view' : 'edit') l:exFileOptionsAndCommands l:exfilespec
	    diffthis
	elseif l:dropAction ==# 'diffsplit'
	    if ! ingo#window#special#HasDiffWindow()
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
	elseif l:dropAction ==# 'above'
	    execute 'aboveleft' (l:dropAttributes.readonly ? 'sview' : 'split') l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'vsplit'
	    execute 'belowright' (l:dropAttributes.readonly ? 'vertical sview' : 'vsplit') l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'placement'
	    execute l:dropAttributes.placement (l:dropAttributes.readonly ? 'sview' : 'split') l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'show'
	    execute (exists(':TopLeft') ==2 ? 'TopLeft' : 'topleft') 'sview' l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'preview'
	    call ingo#window#preview#OpenFilespec(a:filespec, {'isSilent': 0, 'isBang': 0, 'prefixCommand': 'confirm', 'exFileOptionsAndCommands': l:exFileOptionsAndCommands})
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
	elseif l:dropAction ==# 'argedit in split'
	    let l:argNum = argc()
	    call s:ExecuteWithoutWildignore(l:argNum . 'argadd', [a:filespec])

	    execute s:HorizontalSplitModifier() (l:argNum + 1) . 'sargument' l:exFileOptionsAndCommands
	    if l:dropAttributes.readonly && bufnr('') != l:originalBufNr
		setlocal readonly
	    endif
	elseif l:dropAction ==# 'argadd'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    call s:ExecuteWithoutWildignore(argc() . 'argadd', [a:filespec])
	    " :argadd just modifies the argument list; l:dropAttributes.readonly
	    " doesn't apply here. l:exFileOptionsAndCommands isn't supported,
	    " neither.
	    call s:EchoArgsSummary(a:filespec)
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
	    call s:EchoArgsSummary(a:filespec)
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
	    let l:exfilespec = ingo#compat#fnameescape(s:ShortenFilespec(a:filespec))

	    execute 'confirm' (l:dropAttributes.readonly ? 'view' : 'edit') l:exFileOptionsAndCommands l:exfilespec
	elseif l:dropAction ==# 'new tab'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    execute tabpagenr('$') . 'tabedit' l:exFileOptionsAndCommands l:exfilespec
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
		execute s:HorizontalSplitModifier() (l:dropAttributes.readonly ? 'sview' : 'split') l:exFileOptionsAndCommands l:exfilespec
	    else
		execute l:blankWindowNr . 'wincmd w'
		execute 'confirm' (l:dropAttributes.readonly ? 'view' : 'edit') l:exFileOptionsAndCommands l:exfilespec
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
	    "execute 'drop' l:exFileOptionsAndCommands l:exfilespec
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
	    execute (l:dropAttributes.readonly ? 'view' : 'edit') l:exFileOptionsAndCommands ingo#compat#fnameescape(s:ShortenFilespec(a:filespec))
	elseif l:dropAction ==# 'external GVIM'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)
	    call s:ExternalGvimForEachFile((l:dropAttributes.readonly ? 'view' : 'edit'), l:exFileOptionsAndCommands, [a:filespec])
	elseif l:dropAction ==# 'other GVIM'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)
	    call s:OtherGvimForEachFile(l:dropAttributes.servername, l:exFileOptionsAndCommands, [a:filespec])
	elseif l:dropAction ==# 'move scratch contents there'
	    execute 'belowright split' l:exFileOptionsAndCommands l:exfilespec
	    execute (exists('b:appendAfterLnum') ? b:appendAfterLnum : '$') . 'MoveChangesHere'
	elseif l:dropAction ==# 'read here'
	    execute 'keepalt read' l:exFileOptionsAndCommands l:exfilespec
	    normal! ']
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
	return s:DropSingleFile(a:isForceQuery, l:filespecs[0], l:statistics.nonexisting == 0, s:BuildQueryText(l:filespecs, l:statistics), l:fileOptionsAndCommands)
    endif

    let l:originalWinNr = winnr()
    let l:previousWinNr = winnr('#') ? winnr('#') : 1
    let l:isMovedAway = s:MoveAwayAndRefresh()

    try
	let [l:dropAction, l:dropAttributes] = s:GetAutoAction(l:filespecs)
	let l:dropAttributes = extend(copy(l:dropAttributes), s:defaultDropAttributes)
    catch /^Vim\%((\a\+)\)\=:/
	throw ingo#msg#MsgFromVimException()   " Don't swallow Vimscript errors.
    catch
	call ingo#msg#ErrorMsg(v:exception)    " A custom exception indicates abort.
	return -1
    endtry
    if empty(l:dropAction)
	let l:default = s:GetAutoDefault(l:filespecs)
	let [l:dropAction, l:dropAttributes] = s:QueryActionForMultipleFiles(
	\   s:BuildQueryText(l:filespecs, l:statistics),
	\   l:statistics.files,
	\   ! s:IsExempt(),
	\   (empty(l:default) ? 1 : l:default)
	\)
    endif

    let l:exFileOptionsAndCommands = ingo#cmdargs#file#FileOptionsAndCommandsToEscapedExCommandLine(l:fileOptionsAndCommands)
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
		let l:isExisting = (ingo#fs#path#Exists(l:filespec) || ingo#cmdargs#glob#IsSpecialFile(l:filespec))
		let l:success = (s:DropSingleFile(1, l:filespec, l:isExisting, s:BuildQueryText([l:filespec], {'files': 1, 'removed': 0, 'nonexisting': (l:isExisting ? 0 : 1)}), l:fileOptionsAndCommands) == 1)
		if ! l:success
		    " Need to print this here to fit into the interactive flow.
		    call ingo#msg#ErrorMsg(ingo#err#Get())
		endif
	    endfor
	elseif l:dropAction ==# 'argedit'
	    call s:ExecuteWithoutWildignore('confirm args' . l:exFileOptionsAndCommands, l:filespecs)
	    if l:dropAttributes.readonly | setlocal readonly | endif
	elseif l:dropAction ==# 'argedit in split'
	    let l:argNum = argc()
	    call s:ExecuteWithoutWildignore(l:argNum . 'argadd', l:filespecs)

	    execute s:HorizontalSplitModifier() (l:argNum + 1) . 'sargument' l:exFileOptionsAndCommands
	elseif l:dropAction ==# 'replace existing args'
	    argdelete *
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    call s:ExecuteWithoutWildignore('0argadd', l:filespecs)
	    " :argadd just modifies the argument list; l:dropAttributes.readonly
	    " doesn't apply here. l:fileOptionsAndCommands isn't supported,
	    " neither.
	    call s:EchoArgsSummary(len(l:filespecs) . ' files')
	elseif l:dropAction ==# 'argadd'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    call s:ExecuteWithoutWildignore(argc() . 'argadd', l:filespecs)
	    " :argadd just modifies the argument list; l:dropAttributes.readonly
	    " doesn't apply here. l:fileOptionsAndCommands isn't supported,
	    " neither.
	    call s:EchoArgsSummary(len(l:filespecs) . ' files')
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
	    call s:EchoArgsSummary(len(l:filespecs) . ' files')
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

	    call ingo#window#quickfix#CmdPre(1, 'DropQuery')
		call setqflist(map(
		\   l:filespecs,
		\   "{'filename': v:val, 'lnum': 1}"
		\), 'a')
	    call ingo#window#quickfix#CmdPost(1, 'DropQuery')
	    " This just modifies the quickfix list; l:dropAttributes.readonly
	    " doesn't apply here. l:exFileOptionsAndCommands isn't supported,
	    " neither.
	    " Since this doesn't change the currently edited file, and there
	    " thus is no clash with an "edit file" message, notify about the
	    " total and number of added entries as a courtesy.
	    echo printf('Add %d entries; total now is %d', len(l:filespecs), len(getqflist()))
	elseif l:dropAction ==# 'diffsplit'
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
	    \	(exists(':TopLeft') ==2 ? 'TopLeft' : 'topleft') . ' sview' . l:exFileOptionsAndCommands,
	    \	(s:IsEmptyTabPage() ? 'view' . l:exFileOptionsAndCommands : ''),
	    \	reverse(l:filespecs)
	    \)
	elseif l:dropAction ==# 'new tab'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)

	    call s:ExecuteForEachFile(
	    \	'$tabedit' . l:exFileOptionsAndCommands . (l:dropAttributes.readonly ? ' +setlocal\ readonly' : ''),
	    \	(s:IsEmptyTabPage() ? (l:dropAttributes.readonly ? 'view' : 'edit') . l:exFileOptionsAndCommands : ''),
	    \	l:filespecs
	    \)
	elseif l:dropAction ==# 'external GVIM'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)
	    call s:ExternalGvimForEachFile((l:dropAttributes.readonly ? 'view' : 'edit'), l:exFileOptionsAndCommands, l:filespecs)
	elseif l:dropAction ==# 'external single GVIM'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)
	    call s:ExternalGvimForAllFiles(l:exFileOptionsAndCommands, l:filespecs)
	elseif l:dropAction ==# 'other GVIM'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)
	    call s:OtherGvimForEachFile(l:dropAttributes.servername, l:exFileOptionsAndCommands, l:filespecs)
	elseif l:dropAction ==# 'read here'
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)
	    call s:ExecuteForEachFile('keepalt read ' . l:exFileOptionsAndCommands, '', l:filespecs, "normal! ']")
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
	return s:DropSingleFile(l:isForceQuery, l:bufName, 1, printf('Action for %s?', l:bufName), [])
    else
	let l:blankWindowNr = s:GetBlankWindowNr()
	let l:isInBuffer = (l:bufNr == bufnr(''))
	let l:hasOtherWindows = (winnr('$') > 1)
	let l:isMovedAway = s:MoveAwayAndRefresh()
	let l:isEmpty = ingo#buffer#IsEmpty(l:bufNr)
	let l:querytext = printf('Action for %s buffer #%d%s?',
	\   (l:isInBuffer ? 'this' : 'dropped') . (l:isEmpty ? ' empty' : ''),
	\   l:bufNr,
	\   (empty(l:bufName) ? '' : ': ' . l:bufName)
	\)
	let [l:dropAction, l:dropAttributes] = s:QueryActionForBuffer(l:querytext,
	\   ingo#buffer#ExistOtherBuffers(l:bufNr),
	\   l:hasOtherWindows,
	\   l:isVisibleWindow,
	\   l:isInBuffer,
	\   (l:tabPageNr != -1),
	\   (l:blankWindowNr != -1 && l:blankWindowNr != winnr()),
	\   ! s:IsExempt(),
	\   l:isEmpty
	\)
    endif

    try
	if empty(l:dropAction)
	    call s:RestoreMove(l:isMovedAway, l:originalWinNr, l:previousWinNr)
	    call ingo#msg#WarningMsg('Canceled opening of buffer #' . l:bufNr)
	elseif l:dropAction ==# 'edit'
	    execute 'confirm buffer' l:bufNr
	elseif l:dropAction ==# 'diffsplit'
	    if ! ingo#window#special#HasDiffWindow()
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
	    execute (exists(':TopLeft') ==2 ? 'TopLeft' : 'topleft') 'sbuffer' l:bufNr
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
	elseif l:dropAction ==# 'read here'
	    execute 'keepalt read' l:exFileOptionsAndCommands l:exfilespec
	    normal! ']
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
