set nocompatible               " be iMproved
filetype off
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
Plug 'easymotion/vim-easymotion'
Plug 'elzr/vim-json'
Plug 'xolox/vim-misc'
Plug 'xolox/vim-session'
Plug 'jiangmiao/auto-pairs'
Plug 'majutsushi/tagbar'
Plug 'tpope/vim-eunuch'
Plug 'tpope/vim-commentary'
Plug 'exu/pgsql.vim'
Plug 'SirVer/ultisnips'

Plug 'Valloric/YouCompleteMe', { 'do': './install.py --clang-completer --gocode-completer --tern-completer --racer-completer', 'for': ['go', 'rust', 'c', 'c++', 'javascript', 'python'] }
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'

call plug#end()

filetype plugin indent on

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

" Toggle tagbar
nmap <silent> <leader>t :TagbarToggle<CR>


" Toggle background color
" call togglebg#map("<F6>")

" Write the current file with sudo w!!
cmap w!! %!sudo tee > /dev/null %

" Get rid of annoying mistakes
cmap WQ wq
cmap wQ wq
"cmap Q q
nnoremap ; :
" Escape insert by hitting jj
inoremap jj <ESC>
" Clear the current search highlights
nmap <silent> <leader>/ :nohlsearch<CR>

" edit vimrc/zshrc and load vimrc bindings
nnoremap <leader>ev :vsp $MYVIMRC<CR>
nnoremap <leader>ez :vsp ~/.zshrc<CR>
nnoremap <leader>sv :source $MYVIMRC<CR>

" save session
nnoremap <leader>s :mksession<CR>

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

" Theme
set t_Co=16
set background=dark
let g:solarized_contrast="high"
let g:solarized_visibility="low"
colorscheme solarized

" UI
syntax enable
set hidden
set novisualbell		" Turn on the visual bell
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
set ttyfast		    " Speed option
set spell		    " Spell checking on.
set showmode		" Shows what mode your on at the bottom left
set backspace=eol,start,indent		" Allow backspace in insertmode
set whichwrap+=<,>,h,l	" Allows you to wrap to a previous line with h  and l
set linespace=0	" Number of pixels between chars

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

" airline
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#buffer_nr_show = 1
let g:airline#extensions#branch#enabled = 0

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
" Run tests in a new terminal
let g:go_term_enabled = 1

nmap <silent> <leader>T :TagbarOpen fj<CR>

" sessions
let g:session_autosave = 'no'

" Plugin key-mappings.
nmap <silent> <C-h> <Plug>DashSearch

let g:AutoPairsShortcutToggle = '<M-y>'

" fzf
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

let g:fzf_layout = { 'down': '~20%' }

" YouCompleteMe options
let g:ycm_collect_identifiers_from_tags_files = 1

" ultisnips options
let g:UltiSnipsExpandTrigger="<c-space>"
let g:UltiSnipsJumpForwardTrigger="<c-b>"
let g:UltiSnipsJumpBackwardTrigger="<c-z>"

" Fugitive options
nnoremap <silent> <leader>gs :Gstatus<CR>
nnoremap <silent> <leader>gd :Gdiff<CR>
nnoremap <silent> <leader>gc :Gcommit<CR>
nnoremap <silent> <leader>gb :Gblame<CR>
nnoremap <silent> <leader>gl :Glog<CR>
nnoremap <silent> <leader>gp :Git push<CR>

" Gist options
let g:gist_show_privates = 1

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
autocmd Syntax * syn match ExtraWhiteSpace /\s\+$\| \+\ze\t/ containedin=ALL
autocmd BufWinLeave * call clearmatches()

" Removes trailing white spaces
autocmd FileType asm,c,cpp,java,php,javascript,python,sql,twig,xml,yml autocmd BufWritePre <buffer> :call setline(1,map(getline(1,"$"),'substitute(v:val,"\\s\\+$","","")'))

au BufRead,BufNewFile user-data set filetype=yaml
au FileType yaml setlocal shiftwidth=2 tabstop=2

