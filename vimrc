set nocompatible               " be iMproved
filetype off

" Vundle, a vim bundle manager. Uses git.
set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

Bundle 'gmarik/vundle'
Bundle 'MarcWeber/vim-addon-mw-utils'
Bundle 'tomtom/tlib_vim'
Bundle 'altercation/vim-colors-solarized'
Bundle 'scrooloose/nerdtree'
Bundle 'scrooloose/syntastic'
Bundle 'tpope/vim-surround'
Bundle 'motemen/git-vim'
Bundle 'tpope/vim-fugitive'
Bundle 'fholgado/minibufexpl.vim'
Bundle 'HTML-AutoCloseTag'
Bundle 'Shougo/neocomplcache'
Bundle 'majutsushi/tagbar'
Bundle 'kien/ctrlp.vim'
Bundle 'mattn/webapi-vim'
Bundle 'mattn/gist-vim'
Bundle 'kchmck/vim-coffee-script'
Bundle 'LaTeX-Box-Team/LaTeX-Box'
Bundle 'vim-scripts/mips.vim'
" Bundle 'git://vim-latex.git.sourceforge.net/gitroot/vim-latex/vim-latex'

filetype plugin on
" Comment below to turn off the mouse
set mouse=a

" Remap leader to comma
let mapleader=","
" Fast saving
nmap <leader>w :w!<cr>

" Vim plugin keys
map <C-e> :NERDTreeToggle<CR>:NERDTreeMirror<CR>
map <leader>e :NERDTreeFind<CR>
nmap <leader>nt :NERDTreeFind<CR>

map <leader>m :MiniBufExplorer<CR>
nnoremap <silent> <leader>tt :TagbarToggle<CR>

call togglebg#map("<F6>")
:nnoremap <F5> :buffers<CR>:buffer<Space>

" This lets w!! sudo the write.
cmap w!! %!sudo tee > /dev/null %

" Get rid of annoying mistakes
cmap WQ wq
cmap wQ wq
cmap Q q
"cmap W w

" Keybinds
nnoremap ; :
inoremap jj <ESC>
nmap <silent> <leader>/ :nohlsearch<CR>

" Wrapped lines goes down/up to next row, rather than next line in file.
nnoremap j gj    
nnoremap k gk

" Make Y behave like other capitals
nnoremap Y y$

" Reselect visual block after indent:
vnoremap < <gv
vnoremap > >gv

" Move around windows
map <C-j> <C-W>j
map <C-k> <C-W>k
map <C-h> <C-W>h
map <C-l> <C-W>l

" Theme stuff
set background=dark

colorscheme solarized
let g:solarized_termcolors=16
"let g:solarized_termcolors=256
let g:solarized_contrast="normal"
let g:solarized_termtrans=1
let g:solarized_contrast="high"
let g:solarized_visibility="high"


set gfn=xft:inconsolata:medium:size=12:antialias=true
set go=

" General Settings
syntax enable
set hidden
set novisualbell		" Turn on the visual bell
set title		" Adjust title bar accordingly
set scrolloff=5	" Begin scrolling when cursor is at 5 from the edge
"set colorcolumn=80	" Highlight the 80th char column
set autoread		" Read a file if detect to have been changed outside of vim
set browsedir=current           " which directory to use for the file browser

" Searching options
set incsearch		" Searches as you type.
set ignorecase		" Ignore case when searching.
set smartcase		" If case seems to matter, use it
set hlsearch		" Highlight as you search.
set showmatch		" Show all matches.
set magic		" " :help magic

set number		" Show Line numbers
set ttyfast		" Speed option
set spell		" Spell checking on.
set showmode		" Shows what mode your on at the bottom left
set backspace=eol,start,indent		" Allow backspace in insertmode
set whichwrap+=<,>,h,l	" Allows you to wrap to a previous line with h  and l
set linespace=0	" Number of pixels between chars

autocmd BufEnter * if bufname("") !~ "^\[A-Za-z0-9\]*://" | lcd %:p:h | endif
" always switch to the current file directory.

" Allow undos and history to be persistant

set undofile
set undolevels=1000
set history=1000

" These are the directories
set undodir=~/.vim/tmp/undo/
set backupdir=~/.vim/tmp/backup/
set directory=~/.vim/tmp/swap/
set backup

" Auto complete stuff
set wildmenu
set wildmode=list:longest,full
set wildignore+=*.pyc
set completeopt=menuone,longest ",preview
set pumheight=6             " Keep a small completion window


" Indentation and wrapping
set autoindent		" Auto indentation stuff
set smartindent	" Indent based on file type.
set tabstop=4
set shiftwidth=4
set expandtab
set linebreak		" Wraps lines instead of inserting an EOL
set textwidth=79	" How many char to allow before inserting a newline
set wrap		    " Allows wrapping on display.

" Making paste work with indenting"
set pastetoggle=<F2>

set ruler                                           " show the ruler
set rulerformat=%30(%=\:b%n%y%m%r%w\ %l,%c%V\ %P%)  " a ruler on steroids
set showcmd			                                " show partial commands in status line and

" Status Line Options
set statusline=%<%f\    " Filename
set statusline+=%w%h%m%r " Options
set statusline+=%{fugitive#statusline()} " Git Hotness
set statusline+=\ [%{&ff}/%Y]            " filetype
set statusline+=\ [%{getcwd()}]          " current dir
set statusline+=%=%-14.(%l,%c%V%)\ %p%%  " Right aligned file nav info

 " neocomplcache {

let g:neocomplcache_enable_at_startup = 1
    let g:neocomplcache_enable_camel_case_completion = 1
    let g:neocomplcache_enable_smart_case = 1
    let g:neocomplcache_enable_underbar_completion = 1
    let g:neocomplcache_min_syntax_length = 3
    let g:neocomplcache_enable_auto_delimiter = 1

    " AutoComplPop like behavior.
    let g:neocomplcache_enable_auto_select = 0

    " SuperTab like snippets behavior.
    imap <expr><TAB> neocomplcache#sources#snippets_complete#expandable() ? "\<Plug>(neocomplcache_snippets_expand)" : pumvisible() ? "\<C-n>" : "\<TAB>"

    " Plugin key-mappings.
    imap <C-k>     <Plug>(neocomplcache_snippets_expand)
    smap <C-k>     <Plug>(neocomplcache_snippets_expand)
    inoremap <expr><C-g>     neocomplcache#undo_completion()
    inoremap <expr><C-l>     neocomplcache#complete_common_string()


    " <CR>: close popup
    " <s-CR>: close popup and save indent.
    inoremap <expr><CR>  pumvisible() ? neocomplcache#close_popup() : "\<CR>"
    inoremap <expr><s-CR> pumvisible() ? neocomplcache#close_popup() "\<CR>" : "\<CR>"
    " <TAB>: completion.
    inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"

    " <C-h>, <BS>: close popup and delete backword char.
    inoremap <expr><C-h> neocomplcache#smart_close_popup()."\<C-h>"
    inoremap <expr><BS> neocomplcache#smart_close_popup()."\<C-h>"
    inoremap <expr><C-y>  neocomplcache#close_popup()
    inoremap <expr><C-e>  neocomplcache#cancel_popup()

    " Enable heavy omni completion.
    if !exists('g:neocomplcache_omni_patterns')
        let g:neocomplcache_omni_patterns = {}
    endif
    let g:neocomplcache_omni_patterns.ruby = '[^. *\t]\.\h\w*\|\h\w*::'
    "autocmd FileType ruby setlocal omnifunc=rubycomplete#Complete
    let g:neocomplcache_omni_patterns.php = '[^. \t]->\h\w*\|\h\w*::'
    let g:neocomplcache_omni_patterns.c = '\%(\.\|->\)\h\w*'
    let g:neocomplcache_omni_patterns.cpp = '\h\w*\%(\.\|->\)\h\w*\|\h\w*::'

    " For snippet_complete marker.
    if has('conceal')
        set conceallevel=2 concealcursor=i
    endif

 " }

    " CtrlP options
        let g:ctrlp_working_path_mode = 2
        nnoremap <silent> <D-t> :CtrlP<CR>
        nnoremap <silent> <D-r> :CtrlPMRU<CR>
        let g:ctrlp_custom_ignore = {
            \ 'dir':  '\.git$\|\.hg$\|\.svn$',
            \ 'file': '\.exe$\|\.so$\|\.dll$|\.tar*$' }

    " Fugitive options
        nnoremap <silent> <leader>gs :Gstatus<CR>
        nnoremap <silent> <leader>gd :Gdiff<CR>
        nnoremap <silent> <leader>gc :Gcommit<CR>
        nnoremap <silent> <leader>gb :Gblame<CR>
        nnoremap <silent> <leader>gl :Glog<CR>
        nnoremap <silent> <leader>gp :Git push<CR>

    " GVIM- (here instead of .gvimrc)
    if has('gui_running')
        set guioptions-=T           " remove the toolbar
        set lines=40                " 40 lines of text instead of 24,
        set guifont=Andale\ Mono\ Regular:h16,Menlo\ Regular:h15,Consolas\ Regular:h16,Courier\ New\ Regular:h18
        if has('gui_macvim')
            set transparency=5          " Make the window slightly transparent
        endif
    else
        "set term=builtin_ansi       " Make arrow and other keys work
    endif


" MiniBufExplorer Options
let g:miniBufExplMapWindowNavArrows = 1
let g:miniBufExplMapCTabSwitchBufs = 1

" Coffee Lint Setting
let coffee_linter = '/usr/local/bin/coffeelint'

" Nerd Tree Options
let NERDTreeShowBookmarks=1
let NERDTreeIgnore=['\.pyc', '\~$', '\.swo$', '\.swp$', '\.git', '\.hg', '\.svn', '\.bzr']
let NERDTreeChDirMode=0
let NERDTreeQuitOnOpen=1
let NERDTreeShowHidden=1
let NERDTreeKeepTreeInNewTab=1

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
au FileType html,markdown set omnifunc=htmlcomplete#Complete

" CSS
au BufRead,BufNewFile *.css setlocal shiftwidth=2 tabstop=2 textwidth=0 wrapmargin=0
au BufRead,BufNewFile *.styl setlocal shiftwidth=2 tabstop=2 textwidth=0 wrapmargin=0
au FileType css set omnifunc=csscomplete#Complete

"JavaScript
autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS

" CoffeeScript
au BufNewFile,BufReadPost *.coffee setlocal shiftwidth=2 tabstop=2 expandtab
au BufNewFile,BufReadPost *.coffee setlocal foldmethod=indent nofoldenable

" Text files
au BufRead,BufNewFile *.txt setlocal textwidth=0 wrap

" LatexBox
let g:LatexBox_latexmk_options = "-pvc"
let g:LatexBox_output_type = "pdf"
let g:LatexBox_viewer = "evince"
let g:tex_flavor='latex'

" Show trailing whitespace and spaces.
:highlight ExtraWhiteSpace ctermbg=red guibg=red
autocmd Syntax * syn match ExtraWhiteSpace /\s\+$\| \+\ze\t/ containedin=ALL
autocmd BufWinLeave * call clearmatches()

" Removes trailing white spaces
autocmd FileType c,cpp,java,php,javascript,python,twig,xml,yml autocmd BufWritePre <buffer> :call setline(1,map(getline(1,"$"),'substitute(v:val,"\\s\\+$","","")'))
