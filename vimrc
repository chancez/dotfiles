set nocompatible               " be iMproved
set shell=/usr/local/bin/zsh

call plug#begin('~/.vim/plugged')

Plug 'AndrewRadev/splitjoin.vim'
Plug 'MarcWeber/vim-addon-mw-utils'
Plug 'Matt-Deacalion/vim-systemd-syntax'
Plug 'SirVer/ultisnips'
Plug 'honza/vim-snippets'
Plug 'altercation/vim-colors-solarized'
Plug 'avakhov/vim-yaml', { 'for': [ 'yaml', 'yaml.ansible' ] }
Plug 'git@github.com:chancez/neomake.git', { 'branch': 'custom_tempfile_dir2' }
Plug 'burnettk/vim-angular', { 'for': 'javascript' }
Plug 'chancez/groovy.vim', { 'for': 'groovy' }
Plug 'ekalinin/Dockerfile.vim', { 'for': 'Dockerfile' }
Plug 'elzr/vim-json', { 'for': 'json' }
Plug 'exu/pgsql.vim'
Plug 'geoffharcourt/one-dark.vim'
Plug 'joshdick/onedark.vim'
" Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug '/usr/local/opt/fzf'
Plug 'junegunn/fzf.vim'
Plug 'junegunn/vim-easy-align'
Plug 'justinmk/vim-sneak'
Plug 'ludovicchabant/vim-gutentags'
Plug 'majutsushi/tagbar', { 'on': ['TagbarToggle'] }
Plug 'mattn/gist-vim'
Plug 'mattn/webapi-vim'
Plug 'mtth/scratch.vim'
Plug 'mustache/vim-mustache-handlebars'
Plug 'othree/html5.vim', { 'for': 'html' }
Plug 'pangloss/vim-javascript', { 'for': 'javascript' }
Plug 'othree/yajs.vim', { 'for': 'javascript' }
Plug 'rizzatti/dash.vim'
Plug 'rust-lang/rust.vim', { 'for': 'rust' }
Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }
Plug 'jistr/vim-nerdtree-tabs', { 'on': 'NERDTreeToggle' }
Plug 'simeji/winresizer'
Plug 'terryma/vim-multiple-cursors'
Plug 'timonv/vim-cargo', { 'for': 'rust' }
Plug 'tomtom/tlib_vim'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-eunuch'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-git'
Plug 'machakann/vim-sandwich'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
if has('nvim')
  Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
else
  Plug 'Shougo/deoplete.nvim'
  Plug 'roxma/nvim-yarp'
  Plug 'roxma/vim-hug-neovim-rpc'
endif
Plug 'zchee/deoplete-go', { 'for': 'go', 'do': 'make'}
Plug 'ervandew/supertab'
Plug 'hashivim/vim-terraform', { 'for': 'terraform' }
Plug 'chr4/nginx.vim'
Plug 'wesQ3/vim-windowswap'
Plug 'google/vim-jsonnet', { 'for': 'jsonnet' }
Plug 'pearofducks/ansible-vim'
Plug 'wincent/terminus'
Plug 'kassio/neoterm'

function! InstallGoBins(info)
  if a:info.status != 'unchanged' || a:info.force
      if a:info.status == 'installed'
          GoInstallBinaries
      endif
      if a:info.status == 'updated'
          GoUpdateBinaries
      endif
    UpdateRemotePlugins
  endif
endfunction

Plug 'fatih/vim-go', { 'do': function('InstallGoBins') }

call plug#end()


" Theme
let g:onedark_termcolors=16

"Use 24-bit (true-color) mode in Vim/Neovim when outside tmux.
"If you're using tmux version 2.2 or later, you can remove the outermost $TMUX check and use tmux's 24-bit color support
"(see < http://sunaku.github.io/tmux-24bit-color.html#usage > for more information.)
if (empty($TMUX))
  if (has("nvim"))
    "For Neovim 0.1.3 and 0.1.4 < https://github.com/neovim/neovim/pull/2198 >
    let $NVIM_TUI_ENABLE_TRUE_COLOR=1
  endif
  "For Neovim > 0.1.5 and Vim > patch 7.4.1799 < https://github.com/vim/vim/commit/61be73bb0f965a895bfb064ea3e55476ac175162 >
  "Based on Vim patch 7.4.1770 (`guicolors` option) < https://github.com/vim/vim/commit/8a633e3427b47286869aa4b96f2bfc1fe65b25cd >
  " < https://github.com/neovim/neovim/wiki/Following-HEAD#20160511 >
  if (has("termguicolors"))
    set termguicolors
  endif
endif

" use the system clipboard
set clipboard=unnamed

if (has("nvim"))
    set clipboard+=unnamedplus
    set inccommand=nosplit
endif

syntax on
colorscheme onedark

" Comment below to turn off the mouse
set mouse=a
" Keybinds

" Remap leader to comma
let mapleader=","
" Fast saving
nmap <leader>w :w!<cr>
" Making paste work with indenting
set pastetoggle=<F2>

" paste and discard overwritten contents, keeping existing paste buffer
vnoremap <leader>p "_dP

" Nerdtree keys
map <leader>n <plug>NERDTreeTabsToggle<CR>
map <C-e> :NERDTreeToggle<CR>:NERDTreeMirror<CR>
map <leader>e :NERDTreeFind<CR>
nmap <leader>nt :NERDTreeFind<CR>

set grepprg=rg\ --vimgrep\ --no-heading\ --smart-case

" Write the current file with sudo w!!
cmap w!! %!sudo tee > /dev/null %

" Get rid of annoying mistakes
cmap WQ wq
cmap wQ wq
"cmap Q q

nnoremap ; :
vnoremap ; :

nnoremap ;; ;
vnoremap ;; ;

nnoremap ,, ,
vnoremap ,, ,
nnoremap ; :

" Escape insert by hitting jj
inoremap jj <ESC>
" Clear the current search highlights
nmap <silent> <leader>/ :nohlsearch<CR>

" edit vimrc/zshrc and load vimrc bindings
nnoremap <leader>ev :e $MYVIMRC<CR>
nnoremap <leader>ez :e ~/.zshrc<CR>
nnoremap <leader>sv :source $MYVIMRC<CR>

nnoremap <leader>: @:<CR>

if has('nvim')
    " this maps leader + esc to exit terminal mode
    tnoremap <leader><Esc> <C-\><C-n>
    " This makes navigating windows the same no matter if they are displaying
    " a normal buffer or a terminal buffer
    tnoremap <A-h> <C-\><C-n><C-w>h
    tnoremap <A-j> <C-\><C-n><C-w>j
    tnoremap <A-k> <C-\><C-n><C-w>k
    tnoremap <A-l> <C-\><C-n><C-w>l
endif
let g:Guifont="Inconsolata For Powerline:12"

" Wrapped lines goes down/up to next row, rather than next line in file.
nnoremap j gj    
nnoremap k gk

" Make Y behave like other capitals
nnoremap Y y$

" Reselect visual block after indent:
vnoremap < <gv
vnoremap > >gv

" Move around windows
map <A-j> <C-W>j
map <A-k> <C-W>k
map <A-h> <C-W>h
map <A-l> <C-W>l

" UI
set hidden
set visualbell
set t_vb=
set title		        " Adjust title bar accordingly
set scrolloff=5	        " Begin scrolling when cursor is at 5 from the edge
set colorcolumn=79	    " Highlight the 80th char column
set autoread    " Read a file if detect to have been changed outside of vim
set browsedir=current           " which directory to use for the file browser

" Searching options
set incsearch		" Searches as you type.
set ignorecase		" Ignore case when searching.
set smartcase		" If case seems to matter, use it
set hlsearch		" Highlight as you search.
set showmatch		" highlight matching [{()}]
set magic		    " :help magic

" Folding
set foldenable      " Enable folding
set foldlevelstart=10   " open most folds by default
set foldnestmax=10      " 10 nested fold max
" space open/closes folds
nnoremap <space> za
set foldmethod=indent   " fold based on indent level

" Other Stuff
set number		    " Show Line numbers
set list            " Show tabs/spaces/eol/etc
set ttyfast		    " Speed option
set spell		    " Spell checking on.
set showmode		" Shows what mode your on at the bottom left
set backspace=eol,start,indent		" Allow backspace in insertmode
set whichwrap+=<,>,h,l	" Allows you to wrap to a previous line with h  and l
set linespace=0	" Number of pixels between chars

" Project specific .vimrcs
set exrc
set secure " Disable unsafe commands in project specific .vimrc

" Allow undos and history to be persistant
set undofile
set undolevels=1000
set history=1000

" These are the directories
set undodir=~/.vim/tmp/undo/
set backupdir=~/.vim/tmp/backup/
set directory=~/.vim/tmp/swap/
set backup

" Auto complete settings
set wildmenu
set wildmode=list:longest,full
set wildignore+=*.pyc
set completeopt=menuone,longest " completion window
set completeopt+=noinsert
set completeopt+=noselect
set pumheight=6                 " Keep a small completion window

" Indentation and wrapping
set autoindent		" Auto indentation stuff
set smartindent	    " Indent based on file type.
set tabstop=4
set shiftwidth=4
set expandtab
set linebreak		" Wraps lines instead of inserting an EOL
set textwidth=79	" How many char to allow before inserting a newline
set wrap		    " Allows wrapping on display.

" Status Line Options
set showcmd         " show partial commands in status line and
set laststatus=2    " Always show status line
let g:bufferline_echo = 0

" My own commands
command! -nargs=* -complete=file TermBelow call TermFunc('below', 'new', '15', <f-args>)
command! -nargs=* -complete=file TermBottom call TermFunc('bo', 'new', '15', <f-args>)
command! -nargs=* -complete=file TermSizedBottom call TermFunc('bo', 'new', <f-args>)

function! TermFunc(pos, direction, size, ...)
    execute a:pos " " . a:size . a:direction . " "
    execute 'terminal ' . join(a:000)
    setlocal winfixheight
endfunction

" airline
if !exists('g:airline_symbols')
  let g:airline_symbols = {}
endif
let g:airline_theme='onedark'
let g:airline_symbols.space = "\ua0"
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#buffer_nr_show = 1
let g:airline#extensions#branch#enabled = 0
let g:airline#extensions#fugitiveline#enabled = 0
let g:airline#extensions#syntastic#enabled = 0
let g:airline#extensions#tagbar#enabled = 0

" Neomake
" When writing a buffer.
call neomake#configure#automake('w')
let g:neomake_tempfile_base_directory = '/Users/chance/.vim/tmp/neomake'

" multicursor
" let g:multi_cursor_next_key='<C-n>'
" let g:multi_cursor_prev_key='<C-p>'
" let g:multi_cursor_skip_key='<C-x>'
let g:multi_cursor_exit_from_visual_mode = 0
let g:multi_cursor_exit_from_insert_mode = 0

function! Multiple_cursors_before()
  let g:deoplete#disable_auto_complete = 1
endfunction
function! Multiple_cursors_after()
  let g:deoplete#disable_auto_complete = 0
endfunction

" vim-go
let g:go_highlight_functions = 1
let g:go_highlight_methods = 1
let g:go_highlight_structs = 1
let g:go_highlight_interfaces = 1
let g:go_highlight_operators = 0
let g:go_highlight_build_constraints = 1
let g:go_fmt_command = "goimports"
let g:go_fmt_options = {
    \ 'gofmt': '-s',
    \ }

" let g:go_auto_sameids = 1

" Might fix folds being UN collapsed on fmt
let g:go_fmt_experimental = 1
" Shows type info in status bar for function under cursor
" Disabled as it slows things down and hides errors.
" let g:go_auto_type_info = 1
" By default the testing commands run asynchronously in the background and
" display results with go#jobcontrol#Statusline(). To make them run in a new
" terminal
let g:go_term_enabled = 1

" By default new terminals are opened in a vertical split. To change it:
let g:go_term_mode = "split"

" don't run vet/lint with vim-go, it's done with Neomake
let g:go_metalinter_autosave = 0
" disable auto fmt on save:
" let g:go_fmt_autosave = 0

" vim-go keybindings
au FileType go nmap <leader>gob <Plug>(go-build)
au FileType go nmap <leader>got <Plug>(go-test)
au FileType go nmap <leader>gotf <Plug>(go-test-func)
au FileType go nmap <leader>gol <Plug>(go-lint)
au FileType go nmap <leader>gov <Plug>(go-vet)
au FileType go nmap <Leader>i <Plug>(go-info)

" rust.vim
let g:rustfmt_autosave = 1

" vim-terraform
let g:terraform_fmt_on_save = 1

" Plugin key-mappings.
nmap <silent> <C-h> <Plug>DashSearch

let g:AutoPairsShortcutToggle = '<M-y>'

" fzf
let g:fzf_layout = { 'down': '~23%' }
let g:fzf_buffers_jump = 1

let g:find_home = 'find $HOME -path "*/\.*" -prune -o -path "*/Applications*" -prune -o -path "*/Library*" -prune -o -type d -print 2> /dev/null'
command! FZFcd call fzf#run({
\   'source':   g:find_home,
\   'sink':     'cd',
\   'down':     '20%',
\   'options': '--prompt "cd> "'
\ })

command! FZFGoImport call fzf#run({
\   'source':   'gopkgs -short | sort | uniq',
\   'sink':     'GoImport',
\   'down':     '20%',
\   'options': '--prompt "GoImport> "'
\ })

command! FZFGoDoc call fzf#run({
\   'source':   'gopkgs -short | sort | uniq',
\   'sink':     'GoDoc',
\   'down':     '20%',
\   'options': '--prompt "GoDoc> "'
\ })

" Command for git grep
" - fzf#vim#grep(command, with_column, [options], [fullscreen])
command! -bang -nargs=* GGrep
  \ call fzf#vim#grep(
  \   'git grep --line-number '.shellescape(<q-args>), 0,
  \   { 'dir': systemlist('git rev-parse --show-toplevel')[0] }, <bang>0)

" Override Colors command. You can safely do this in your .vimrc as fzf.vim
" will not override existing commands.
command! -bang Colors
  \ call fzf#vim#colors({'left': '15%', 'options': '--reverse --margin 30%,0'}, <bang>0)

" Augmenting Ag command using fzf#vim#with_preview function
"   * fzf#vim#with_preview([[options], preview window, [toggle keys...]])
"     * For syntax-highlighting, Ruby and any of the following tools are required:
"       - Highlight: http://www.andre-simon.de/doku/highlight/en/highlight.php
"       - CodeRay: http://coderay.rubychan.de/
"       - Rouge: https://github.com/jneen/rouge
"
"   :Ag  - Start fzf with hidden preview window that can be enabled with "?" key
"   :Ag! - Start fzf in fullscreen and display the preview window above
command! -bang -nargs=* Ag
  \ call fzf#vim#ag(<q-args>,
  \                 <bang>0 ? fzf#vim#with_preview('up:60%')
  \                         : fzf#vim#with_preview('right:50%:hidden', '?'),
  \                 <bang>0)

" Similarly, we can apply it to fzf#vim#grep. To use ripgrep instead of ag:
command! -bang -nargs=* Rg
  \ call fzf#vim#grep(
  \   'rg --column --line-number --no-heading --color=always --smart-case '.shellescape(<q-args>), 1,
  \   <bang>0 ? fzf#vim#with_preview('up:60%')
  \           : fzf#vim#with_preview('right:50%:hidden', '?'),
  \   <bang>0)

" Likewise, Files command with preview window
command! -bang -nargs=? -complete=dir Files
  \ call fzf#vim#files(<q-args>, fzf#vim#with_preview(), <bang>0)

nnoremap <silent> <M-o> :Buffers<cr>
nnoremap <silent> <C-p> :FZF<CR>
nnoremap <silent> <M-p> :Tags<CR>
nnoremap <silent> <M-P> :BTags<CR>

nnoremap <silent> <M-c> :FZFcd<CR>
nnoremap <silent> <M-i> :FZFGoImport<CR>

fun! JQFun(...)
    execute '%!jq .'
endfunction

command! -nargs=* -complete=file JQ call JQFun( '<f-args>' )

" Easy align

" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)

" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)

" vim-sandwich options
" add some of the vim-surround bindings
runtime macros/sandwich/keymap/surround.vim
" https://github.com/machakann/vim-sandwich/wiki/Introduce-vim-surround-keymappings

" Textobjects to select a text surrounded by braket or same characters user input.
xmap is <Plug>(textobj-sandwich-query-i)
xmap as <Plug>(textobj-sandwich-query-a)
omap is <Plug>(textobj-sandwich-query-i)
omap as <Plug>(textobj-sandwich-query-a)

" Deoplete options
let g:deoplete#enable_at_startup = 1
" <TAB>: completion.
" inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"
" default to going down the list instead of up
let g:SuperTabDefaultCompletionType = "<c-n>"

" ultisnips options
" Don't use tab, because it's already used for going through autocompletes
let g:UltiSnipsExpandTrigger = "<c-l>"
let g:UltiSnipsJumpForwardTrigger = "<c-j>"
let g:UltiSnipsJumpBackwardTrigger = "<c-k>"
let g:UltiSnipsListSnippets = "<c-,>"

" Fugitive options
nnoremap <silent> <leader>gs :Gstatus<CR>
nnoremap <silent> <leader>gd :Gdiff<CR>
nnoremap <silent> <leader>gc :Gcommit<CR>
nnoremap <silent> <leader>gb :Gblame<CR>
nnoremap <silent> <leader>gl :Glog<CR>
nnoremap <silent> <leader>gp :Git push<CR>

" Gist options
let g:gist_show_privates = 1
let g:gist_get_multiplefile = 1

" Scratch buffer options
let g:scratch_insert_autohide = 0
let g:scratch_persistence_file = "~/.vim/tmp/scratch-buffer.txt"

" Commentary options
map <silent> <M-/> :Commentary<CR>

" Nerd Tree Options
let NERDTreeIgnore=['\.pyc', '\~$', '\.swo$', '\.swp$', '\.git', '\.hg', '\.svn', '\.bzr', 'Godeps', 'vendor']
let NERDTreeShowBookmarks=1
"let NERDTreeChDirMode=0
"let NERDTreeShowHidden=1
let g:nerdtree_tabs_open_on_console_startup=2
" On startup, focus NERDTree if opening a directory, focus file if opening a file. (When set to 2, always focus file window after startup).
let g:nerdtree_tabs_smart_startup_focus=2

" winresizer
unmap <leader>w
let g:winresizer_start_key = '<leader>w '

" tagbar
" Toggle tagbar
nmap <silent> <leader>tb :TagbarToggle<CR>

" tagbar options for go
let g:tagbar_type_go = {
    \ 'ctagstype' : 'go',
    \ 'kinds'     : [
        \ 'p:package',
        \ 'i:imports:1',
        \ 'c:constants',
        \ 'v:variables',
        \ 't:types',
        \ 'n:interfaces',
        \ 'w:fields',
        \ 'e:embedded',
        \ 'm:methods',
        \ 'r:constructor',
        \ 'f:functions'
    \ ],
    \ 'sro' : '.',
    \ 'kind2scope' : {
        \ 't' : 'ctype',
        \ 'n' : 'ntype'
    \ },
    \ 'scope2kind' : {
        \ 'ctype' : 't',
        \ 'ntype' : 'n'
    \ },
    \ 'ctagsbin'  : 'gotags',
    \ 'ctagsargs' : '-sort -silent'
\ }

" Set easytags options
let g:easytags_opts = ['--options=$HOME/.ctags']
let g:easytags_dynamic_files = 2
let g:easytags_events = ['BufWritePost']
let g:easytags_async = 1
let g:easytags_auto_highlight = 0

" When you set g:easytags_dynamic_files to 2 new tags files are created in the same directory as the file you're editing. If you want the tags files to be created in your working directory instead then change Vim's 'cpoptions' option to include the lowercase letter 'd'.
set tags=./tags;,tags;
set cpoptions=aAceFsBd

" guten tags options
" let g:gutentags_file_list_command = 'ag -l | ctags -L -'

" vim-sneak
let g:sneak#s_next = 1
"let g:sneak#streak = 1

nmap ;; <Plug>SneakNext
nmap ,, <Plug>SneakPrevious

function! ToggleVerbose()
    if !&verbose
        set verbosefile=~/.log/vim/verbose.log
        set verbose=15
    else
        set verbose=0
        set verbosefile=
    endif
endfunction

" Autocmd Section

" If you prefer the Omni-Completion tip window to close when a selection is
" made, these lines close it on movement in insert mode or when leaving
" insert mode
autocmd CursorMovedI * if pumvisible() == 0|pclose|endif
autocmd InsertLeave * if pumvisible() == 0|pclose|endif

" Python
autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
au FileType python setlocal expandtab textwidth=79 shiftwidth=4 tabstop=8 softtabstop=4 smartindent cinwords=if,elif,else,for,while,try,except,finally,def,class,with

" HTML Specifics
au BufRead,BufNewFile *.html setlocal shiftwidth=2 tabstop=2 textwidth=0 wrapmargin=0
au BufRead,BufNewFile *.mkd setlocal shiftwidth=2 tabstop=2 textwidth=0 wrapmargin=79
au BufRead,BufNewFile *.jade setlocal shiftwidth=2 tabstop=2 textwidth=0 wrapmargin=0
" au FileType html,markdown set omnifunc=htmlcomplete#Complete

" CSS
au BufRead,BufNewFile *.css setlocal shiftwidth=2 tabstop=2 textwidth=0 wrapmargin=0
au BufRead,BufNewFile *.styl setlocal shiftwidth=2 tabstop=2 textwidth=0 wrapmargin=0
au FileType css set omnifunc=csscomplete#Complete

" JavaScript
autocmd FileType javascript setlocal tabstop=2 shiftwidth=2

" CoffeeScript
au BufNewFile,BufReadPost *.coffee setlocal shiftwidth=2 tabstop=2 expandtab
au BufNewFile,BufReadPost *.coffee setlocal foldmethod=indent nofoldenable

" Text files
au BufRead,BufNewFile *.txt setlocal textwidth=0 wrap

" Golang
au FileType go setl tabstop=4
au FileType go setl shiftwidth=4
au FileType go setl noexpandtab

" Groovy
au BufRead,BufNewFile Jenkinsfile set filetype=groovy
au FileType groovy setlocal expandtab shiftwidth=4 tabstop=8 softtabstop=4 smartindent cursorcolumn


" do not wrap generate go protobuf files
autocmd BufNewFile,BufRead *.pb.go setlocal textwidth=0 nowrap

" Protobuf
au FileType proto setlocal tabstop=2 shiftwidth=2

" Show trailing whitespace and spaces.
highlight ExtraWhitespace ctermbg=red guibg=red
match ExtraWhitespace /\s\+$/
autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
autocmd InsertLeave * match ExtraWhitespace /\s\+$/
autocmd BufWinLeave * call clearmatches()

fun! StripTrailingWhitespace()
    " Only strip if the b:noStripeWhitespace variable isn't set
    if exists('b:noStripWhitespace')
        return
    endif
    %s/\s\+$//e
endfun
autocmd BufWritePre * call StripTrailingWhitespace()
autocmd FileType markdown setlocal shiftwidth=2 tabstop=2 textwidth=0 wrapmargin=0
autocmd FileType markdown let b:noStripWhitespace=1

" set .envrc to sh
au BufRead,BufNewFile .envrc set filetype=sh

" Removes trailing white spaces
autocmd FileType asm,c,cpp,java,php,javascript,python,sql,twig,xml,yml autocmd BufWritePre <buffer> :call setline(1,map(getline(1,"$"),'substitute(v:val,"\\s\\+$","","")'))

au BufRead,BufNewFile user-data set filetype=yaml
au BufRead,BufNewFile *.yml set filetype=yaml
au FileType yaml setlocal expandtab shiftwidth=2 tabstop=2 cursorcolumn
au FileType sh setlocal tabstop=4 shiftwidth=4

" fix gutentags erroring on git commit/rebase
au FileType gitcommit,gitrebase let g:gutentags_enabled=0

" always go into insert mode when entering a terminal
autocmd BufWinEnter,WinEnter term://* startinsert

" save folds automatically. based on comments in http://vim.wikia.com/wiki/Make_views_automatic
let g:skipview_files = [ 'NERD_tree_1', '.git/COMMIT_EDITMSG']
function! MakeViewCheck()
    if &l:diff | return 0 | endif
    if &buftype != '' | return 0 | endif
    if expand('%') =~ '\[.*\]' | return 0 | endif
    if empty(glob(expand('%:p'))) | return 0 | endif
    if &modifiable == 0 | return 0 | endif
    if len($TEMP) && expand('%:p:h') == $TEMP | return 0 | endif
    if len($TMP) && expand('%:p:h') == $TMP | return 0 | endif

    let file_name = expand('%:p')
    for ifiles in g:skipview_files
        if file_name =~ ifiles
            return 0
        endif
    endfor

    return 1
endfunction

augroup AutoView
    autocmd!
    " Autosave & Load Views.
    autocmd BufWritePre,BufWinLeave ?* if MakeViewCheck() | silent! mkview | endif
    autocmd BufWinEnter ?* if MakeViewCheck() | silent! loadview | endif
augroup END
