set nocompatible               " be iMproved
set shell=/usr/local/bin/zsh

call plug#begin('~/.vim/plugged')

Plug 'MarcWeber/vim-addon-mw-utils'
Plug 'tomtom/tlib_vim'
Plug 'altercation/vim-colors-solarized'
Plug 'scrooloose/nerdtree' | Plug 'jistr/vim-nerdtree-tabs' | Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'scrooloose/syntastic'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-git'
Plug 'tpope/vim-fugitive'
Plug 'mattn/webapi-vim'
Plug 'mattn/gist-vim'
Plug 'ekalinin/Dockerfile.vim', { 'for': 'Dockerfile' }
Plug 'fatih/vim-go', { 'for': 'go' }
Plug 'Matt-Deacalion/vim-systemd-syntax'
Plug 'rizzatti/dash.vim'
Plug 'terryma/vim-multiple-cursors'
Plug 'rust-lang/rust.vim', { 'for': 'rust' }
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'elzr/vim-json'
Plug 'xolox/vim-misc'
Plug 'xolox/vim-session'
Plug 'jiangmiao/auto-pairs'
Plug 'majutsushi/tagbar'
Plug 'tpope/vim-eunuch'
Plug 'tpope/vim-commentary'
Plug 'exu/pgsql.vim'
Plug 'SirVer/ultisnips'

Plug 'benekastah/neomake'
Plug 'geoffharcourt/one-dark.vim'
Plug 'xolox/vim-easytags'
Plug 'mtth/scratch.vim'
Plug 'avakhov/vim-yaml'
Plug 'justinmk/vim-sneak'
Plug 'simeji/winresizer'
Plug 'joshdick/onedark.vim'
Plug 'joshdick/airline-onedark.vim'
Plug 'timonv/vim-cargo'

Plug 'Valloric/YouCompleteMe', { 'do': './install.py --clang-completer --gocode-completer --tern-completer --racer-completer', 'for': ['go', 'rust', 'c', 'c++', 'javascript', 'python'] }

function! BuildComposer(info)
  if a:info.status != 'unchanged' || a:info.force
    !cargo build --release
    UpdateRemotePlugins
  endif
endfunction

Plug 'euclio/vim-markdown-composer', { 'do': function('BuildComposer') }

Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'

call plug#end()

autocmd! User YouCompleteMe if !has('vim_starting') | call youcompleteme#Enable() | endif

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

syntax on
colorscheme onedark
let g:airline_theme='onedark'

" Comment below to turn off the mouse
set mouse=a
" Keybinds

" Remap leader to comma
let mapleader=","
" Fast saving
nmap <leader>w :w!<cr>
" Making paste work with indenting
set pastetoggle=<F2>

" Nerdtree keys
map <leader>n <plug>NERDTreeTabsToggle<CR>
map <C-e> :NERDTreeToggle<CR>:NERDTreeMirror<CR>
map <leader>e :NERDTreeFind<CR>
nmap <leader>nt :NERDTreeFind<CR>


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

" save session
" nnoremap <leader>s :mksession<CR>

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

" use the system clipboard
set clipboard=unnamed

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
command! TermBelow below 15new | execute 'terminal' | setlocal winfixheight
command! TermBottom bo 15new | execute 'terminal' | setlocal winfixheight

" airline
if !exists('g:airline_symbols')
  let g:airline_symbols = {}
endif
let g:airline_symbols.space = "\ua0"
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#buffer_nr_show = 1
let g:airline#extensions#branch#enabled = 0
let g:airline#extensions#syntastic#enabled = 1

" neomake on every save
" let g:neomake_go_gofmt_maker = {
"     'exe': 'gofmt',
"     'args': '-e',
" }
" autocmd! BufWritePost *.go Neomake

" multicursor
" let g:multi_cursor_next_key='<C-n>'
" let g:multi_cursor_prev_key='<C-p>'
" let g:multi_cursor_skip_key='<C-x>'

" vim-go
let g:go_highlight_functions = 1
let g:go_highlight_methods = 1
let g:go_highlight_structs = 1
let g:go_highlight_interfaces = 1
let g:go_highlight_operators = 1
let g:go_highlight_build_constraints = 1
let g:go_fmt_command = "goimports"
" Shows type info in status bar for function under cursor
" let g:go_auto_type_info = 1
" By default the testing commands run asynchronously in the background and
" display results with go#jobcontrol#Statusline(). To make them run in a new
" terminal
" let g:go_term_enabled = 1

" By default new terminals are opened in a vertical split. To change it:
let g:go_term_mode = "split"

" don't show errors from the fmt command
" let g:go_fmt_fail_silently = 1

" disable auto fmt on save:
" let g:go_fmt_autosave = 0

" vim-go keybindings
au FileType go nmap <leader>b <Plug>(go-build)
au FileType go nmap <leader>t <Plug>(go-test)

" rust.vim
let g:rustfmt_autosave = 1

" markdown composer
" dont start things by default
let g:markdown_composer_open_browser = 0
let g:markdown_composer_autostart = 0

" sessions
let g:session_autosave = 'no'

" Plugin key-mappings.
nmap <silent> <C-h> <Plug>DashSearch

let g:AutoPairsShortcutToggle = '<M-y>'

" fzf
let g:fzf_layout = { 'down': '~23%' }
" attmept at fixing resizing of Terminal from 'TermBottom'
" let g:fzf_layout = { 'down': '~23%', 'window': 'execute (tabpagenr()-1)."tabnew"' }
let g:fzf_buffers_jump = 1

let g:find_home = 'find $HOME -path "*/\.*" -prune -o -path "*/Applications*" -prune -o -path "*/Library*" -prune -o -type d -print 2> /dev/null'
command! FZFcd call fzf#run({
\   'source':   g:find_home,
\   'sink':     'cd',
\   'down':     '20%',
\   'options': '--prompt "cd> "'
\ })

command! FZFGoImport call fzf#run({
\   'source':   "cat $GOPATH/pkg_list.txt",
\   'sink':     'GoImport',
\   'down':     '20%',
\   'options': '--prompt "GoImport> "'
\ })

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

" YouCompleteMe options
let g:ycm_collect_identifiers_from_tags_files = 1
let g:ycm_use_ultisnips_completer = 1

" ultisnips options
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

" Commentary options
map <silent> <M-/> :Commentary<CR>

" Nerd Tree Options
let NERDTreeIgnore=['\.pyc', '\~$', '\.swo$', '\.swp$', '\.git', '\.hg', '\.svn', '\.bzr', 'Godeps', 'vendor']
let NERDTreeShowBookmarks=1
"let NERDTreeChDirMode=0
"let NERDTreeShowHidden=1
let g:nerdtree_tabs_open_on_console_startup=1
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
" let g:easytags_opts = ['--options=$HOME/.ctags']
set tags=./tags,tags
let g:easytags_dynamic_files = 2
let g:easytags_events = ['BufWritePost']
set cpoptions=aAceFsBd

" vim-sneak
let g:sneak#s_next = 1
"let g:sneak#streak = 1

nmap ;; <Plug>SneakNext
nmap ,, <Plug>SneakPrevious


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
autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS

" CoffeeScript
au BufNewFile,BufReadPost *.coffee setlocal shiftwidth=2 tabstop=2 expandtab
au BufNewFile,BufReadPost *.coffee setlocal foldmethod=indent nofoldenable

" Text files
au BufRead,BufNewFile *.txt setlocal textwidth=0 wrap

" Golang
au FileType go setl tabstop=4
au FileType go setl shiftwidth=4
au FileType go setl noexpandtab
" do not wrap generate go protobuf files
autocmd BufNewFile,BufRead *.pb.go set nowrap

" Show trailing whitespace and spaces.
:highlight ExtraWhiteSpace ctermbg=red guibg=red
"autocmd Syntax * syn match ExtraWhiteSpace /\s\+$\| \+\ze\t/ containedin=ALL
"autocmd BufWinLeave * call clearmatches()
autocmd BufWritePre * :%s/\s\+$//e


" Removes trailing white spaces
autocmd FileType asm,c,cpp,java,php,javascript,python,sql,twig,xml,yml autocmd BufWritePre <buffer> :call setline(1,map(getline(1,"$"),'substitute(v:val,"\\s\\+$","","")'))

au BufRead,BufNewFile user-data set filetype=yaml
au BufRead,BufNewFile *.yml set filetype=yaml
au FileType yaml setlocal tabstop=2
au FileType sh setlocal tabstop=4 shiftwidth=4

" always go into insert mode when entering a terminal
autocmd BufWinEnter,WinEnter term://* startinsert

