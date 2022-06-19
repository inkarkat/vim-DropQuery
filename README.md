DROPQUERY
===============================================================================
_by Ingo Karkat_

DESCRIPTION
------------------------------------------------------------------------------

This plugin ...

### SOURCE
(Original Vim tip, Stack Overflow answer, ...)

### SEE ALSO
(Plugins offering complementary functionality, or plugins using this library.)

### RELATED WORKS

- tcmdbar.vim ([vimscript #1779](http://www.vim.org/scripts/script.php?script_id=1779)) is a script for use with Total Commander's
  button bar by Andy Wokula

USAGE
------------------------------------------------------------------------------

    :Drop[!] [++opt] [+cmd] {file} ...
                            Automatically locate the visible {file}, use an empty
                            window for it, or ask where to open {file}. With [!],
                            always ask.
    :{range}Drop[!] [++opt] [+cmd] [{glob} ...]
                            Treat each line in {range} (stripped of leading and
                            trailing whitespace) as a filespec / glob and ask
                            where to open those. {glob} can be used to optionally
                            filter the list.
    :Drop[!] [++opt] [+cmd] {reg}
                            Treat each line in {reg} (stripped of leading and
                            trailing whitespace) as a filespec / glob and ask
                            where to open those.

    :[N]BufDrop[!] [N]      Automatically locate the visible buffer [N] / for
    :BufDrop[!] {bufname}   {bufname}, use an empty window for it, or ask where to
                            open it. With [!], or when the current buffer is
                            specified, always ask.

INSTALLATION
------------------------------------------------------------------------------

The code is hosted in a Git repo at
    https://github.com/inkarkat/vim-DropQuery
You can use your favorite plugin manager, or "git clone" into a directory used
for Vim packages. Releases are on the "stable" branch, the latest unstable
development snapshot on "master".

This script is also packaged as a vimball. If you have the "gunzip"
decompressor in your PATH, simply edit the \*.vmb.gz package in Vim; otherwise,
decompress the archive first, e.g. using WinZip. Inside Vim, install by
sourcing the vimball or via the :UseVimball command.

    vim DropQuery*.vmb.gz
    :so %

To uninstall, use the :RmVimball command.

### DEPENDENCIES

- Requires Vim 7.0 or higher.
- Requires the ingo-library.vim plugin ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)), version 1.045 or
  higher.

CONFIGURATION
------------------------------------------------------------------------------

For a permanent configuration, put the following commands into your vimrc:

By default, the plugins remaps the built-in :drop command to use :Drop
instead. With this option, other integrations (e.g. VisVim) need not be
modified to use the DropQuery functionality. To turn this off, use:

    let g:DropQuery_RemapDrop = 0

The plugin uses a pop-up dialog in GVIM for the query. To use a textual query
(as is done in the console Vim) instead, use:

    let g:DropQuery_NoPopup = 'default value'

This does not cover the :confirm query "Save changes to...?" when abandoning
modified buffers.

To exempt certain windows from being the base window for the offered drop
actions, and therefore move away from them before querying for a drop action,
you can define predicate expressions or Funcrefs to characterize such windows
in the following List:

    let g:DropQuery_MoveAwayPredicates = ["&filetype == 'scratch'"]

This is useful if you have any plugins that create vertical sidebars (e.g.
Tagbar), so you want to move to the (horizontally split) main window(s) first.

If no other window is available, a window that is covered by the predicate can
still be used as the base for dropping. The following configuration offers a
mandatory exemption instead. (This can be combined with the above, to try to
move away but if it fails still not offer the window.)

To exempt certain windows from being offered as targets for direct dropping
("Edit" / "View"), you can define predicate expressions or Funcrefs to
characterize such windows in the following List:

    let g:DropQuery_ExemptPredicates = ['&buftype ==# "terminal"']

By default, the plugin does not offer use of |terminal-window|s, assuming you
don't want to replace a running session with an opened file.

If you want to process individual filespecs passed to :Drop, you can hook in
a processor function that takes a single filespec (or file glob), and returns
this changed or unchanged:

    function! MyFilespecProcessor( filespec )
        " Create virtual X drive mapping to C:\Windows.
        return substitute(a:filespec, '^X:', 'C:\Windows', '')
    endfunction
    let g:DropQuery_FilespecProcessor = function('MyFilespecProcessor')

If you want to skip the querying for certain filespecs, you can define
automatic actions, either as Funcrefs that take a List of filespecs and return
[dropAction, dropAttributes] (or an empty List to do the querying, or throwing
an exception to abort), or [glob, dropAction, dropAttributes] Lists that
activate when all filespec(s) match the glob:

    function! MyAutoAction( files )
        return (len(a:files) == 1 && fnamemodify(a:files(0), ':e') ==# 'vim'
        \   ? ['split', {}]
        \   : ''
        \)
    endfunction
    let g:DropQuery_AutoActions = [
    \   ['*.vim', 'split', {}]
    \   function('MyAutoAction')
    \]

If you want to set the proposed default action for certain filespecs, you can
define automatic defaults, either as Funcrefs that take a List of filespecs
and return the default (or an empty String), or [glob, default] Lists that
activate when all filespec(s) match the glob:

    function! MyAutoDefault( files )
        return (len(a:files) == 1 && fnamemodify(a:files(0), ':e') ==# 'vim'
        \   ? 'split'
        \   : ''
        \)
    endfunction
    let g:DropQuery_AutoDefaults = [
    \   ['*.vim', 'split']
    \   function('MyAutoDefault')
    \]

CONTRIBUTING
------------------------------------------------------------------------------

Report any bugs, send patches, or suggest features via the issue tracker at
https://github.com/inkarkat/vim-DropQuery/issues or email (address below).

HISTORY
------------------------------------------------------------------------------

##### GOAL
First published version.

##### 0.01    23-May-2005
- Started development.

------------------------------------------------------------------------------
Copyright: (C) 2005-2022 Ingo Karkat -
The [VIM LICENSE](http://vimdoc.sourceforge.net/htmldoc/uganda.html#license) applies to this plugin.

Maintainer:     Ingo Karkat &lt;ingo@karkat.de&gt;
