set nocompatible               " be iMproved
set shell=/bin/zsh

set rtp +=~/.vim

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
nnoremap <leader>ev :e ~/.vimrc<CR>
nnoremap <leader>ez :e ~/.zshrc<CR>
nnoremap <leader>sv :source $MYVIMRC<CR>

nnoremap <leader>: @:<CR>

" Move around windows
map <A-j> <C-W>j
map <A-k> <C-W>k
map <A-h> <C-W>h
map <A-l> <C-W>l

let g:Guifont="Inconsolata For Powerline:12"

" Wrapped lines goes down/up to next row, rather than next line in file.
nnoremap j gj    
nnoremap k gk

" Make Y behave like other capitals
nnoremap Y y$

" Reselect visual block after indent:
vnoremap < <gv
vnoremap > >gv


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

if !isdirectory($HOME."/.vim/tmp")
    silent! execute "!mkdir -p ~/.vim/tmp/{undo,backup,swap,neomake}"
endif

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


fun! JQFun(...)
    execute '%!jq .'
endfunction

command! -nargs=* -complete=file JQ call JQFun( '<f-args>' )

let g:python_host_prog = '~/.asdf/shims/python2'
let g:python3_host_prog = '~/.asdf/shims/python3'

" Autocmd Section

" If you prefer the Omni-Completion tip window to close when a selection is
" made, these lines close it on movement in insert mode or when leaving
" insert mode
" autocmd CursorMovedI * if pumvisible() == 0|pclose|endif
" autocmd InsertLeave * if pumvisible() == 0|pclose|endif

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

autocmd FileType markdown setlocal shiftwidth=2 tabstop=2 textwidth=0 wrapmargin=0
autocmd FileType markdown let b:noStripWhitespace=1
autocmd FileType diff let b:noStripWhitespace=1

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

" set .envrc to sh
au BufRead,BufNewFile .envrc set filetype=sh

" set user-data files to yaml file type
au BufRead,BufNewFile user-data set filetype=yaml
au FileType yml,yaml setlocal expandtab shiftwidth=2 tabstop=2 cursorcolumn
au FileType jsonnet setlocal expandtab shiftwidth=2 tabstop=2 cursorcolumn

au FileType sh setlocal tabstop=4 shiftwidth=4

" puppet
autocmd BufNewFile,BufRead *.pp setfiletype puppet
autocmd BufNewFile,BufRead *.pp set shiftwidth=2 softtabstop=2 filetype=puppet

" set .ts to typescript
au BufRead,BufNewFile *.ts set filetype=typescript
