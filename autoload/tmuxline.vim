" The MIT License (MIT)
"
" Copyright (c) 2013 Evgeni Kolev

let s:default_theme = 'powerline'
let s:default_preset = 'powerline'

let s:powerline_separators = {
    \ 'left' : '',
    \ 'left_alt': '',
    \ 'right' : '',
    \ 'right_alt' : '',
    \ 'space' : ' '}

let s:simple_separators = {
    \ 'left' : '',
    \ 'left_alt': '|',
    \ 'right' : '',
    \ 'right_alt' : '|',
    \ 'space' : ' '}

let s:snapshot = []

fun! tmuxline#get_separators()
    let use_powerline_separators = get(g:, 'tmuxline_powerline_separators', 1)
    let separators = use_powerline_separators ? s:powerline_separators : s:simple_separators

    return extend(separators, get(g:, 'tmuxline_separators', {}))
endfun

" wrapper around four builders, tmux settings
fun! tmuxline#new()
    let bar = {}
    let bar.left = tmuxline#builder#new()
    let bar.right = tmuxline#builder#new()
    let bar.win = tmuxline#builder#new()
    let bar.cwin = tmuxline#builder#new()
    let bar.set = {
          \ 'status-justify' : 'centre',
          \ 'status-left-length' : 100,
          \ 'status-right-length' : 100,
          \ 'status' : 'on',
          \ 'status-right-attr' : 'none',
          \ 'status-left-attr' : 'none',
          \ 'status-attr' : 'none',
          \ 'status-utf8' : 'on'}
    let bar.setw = {
          \ 'window-status-separator' : ''}
    return bar
endfun

fun! tmuxline#set_statusline(...) abort
    let theme_name = get(a:, 1, get(g:, 'tmuxline_theme', s:default_theme))
    let preset = get(a:, 2, get(g:, 'tmuxline_preset', s:default_preset))

    let line = tmuxline#load_line(preset)
    let colors = tmuxline#load_colors(theme_name)
    let separators = tmuxline#get_separators()

    let line_settings = tmuxline#get_line_settings(line, colors, separators)

    call tmuxline#apply(line_settings)
endfun

fun! tmuxline#load_colors(source) abort
    if type(a:source) == type("")
      let colors = tmuxline#util#load_colors_from_theme(a:source)
    else
      throw "Invalid type of g:tmuxline_preset"
    endif
    return colors
endfun

fun! tmuxline#load_line(source) abort
    if type(a:source) == type("")
      let builder = tmuxline#util#load_line_from_preset(a:source)
    elseif type(a:source) == type({})
      let builder = tmuxline#util#create_line_from_hash(a:source)
    else
      throw "Invalid type of g:tmuxline_preset"
    endif
    return builder
endfun

fun! tmuxline#apply(line_settings) abort
    for setting in a:line_settings
        call system("tmux " . setting)
    endfor

    let s:snapshot = a:line_settings
endfun

fun! tmuxline#snapshot(file, overwrite) abort
  let file = fnamemodify(a:file, ":p")
  let dir = fnamemodify(file, ':h')

  if (len(s:snapshot) == 0)
    echohl ErrorMsg | echomsg ":Tmuxline should be executed before :TmuxlineSnapshot" | echohl None
    return
  endif

  if empty(file)
    throw "Bad file name: \"" . file . "\""
  elseif (filewritable(dir) != 2)
    throw "Cannot write to directory \"" . dir . "\""
  elseif (glob(file) || filereadable(file)) && !a:overwrite
    echohl ErrorMsg | echomsg "File exists (add ! to override)" | echohl None
    return
  endif

  let lines = []
  let lines += [ '# This tmux statusbar config was created by tmuxline.vim']
  let lines += [ '# on ' . strftime("%a, %d %b %Y") ]
  let lines += [ '' ]
  let lines += s:snapshot

  call writefile(lines, file)
  echomsg "Snapshot created in \"" . file ."\""
endfun

fun! tmuxline#get_line_settings(line, theme, separators) abort
  let left = a:line.left.build(a:theme, a:separators)
  let right = a:line.right.build(a:theme, a:separators)
  let win = a:line.win.build(a:theme, a:separators)
  let cwin = a:line.cwin.build(a:theme, a:separators)
  let bg = tmuxline#util#normalize_color(a:theme.bg[1])

  let lines = []
  for [tmux_option, value] in items(a:line.set)
    let lines += [ 'set -g ' . tmux_option . ' ' . shellescape(value) ]
  endfor
  for [tmux_option, value] in items(a:line.setw)
    let lines += [ 'setw -g ' . tmux_option . ' ' . shellescape(value) ]
  endfor

  let lines += [
        \ 'set -g status-left ' . shellescape(left),
        \ 'set -g status-right ' . shellescape(right),
        \ 'setw -g window-status-format ' .shellescape(win),
        \ 'setw -g window-status-current-format ' . shellescape(cwin),
        \ 'set -g status-bg ' . shellescape(bg)]
  return lines

endfun

fun! tmuxline#set_theme(theme) abort
  let preset = get(g:, 'tmuxline_preset', s:default_preset)

  let line = tmuxline#load_line(preset)
  let separators = tmuxline#get_separators()
  let line_settings = tmuxline#get_line_settings(line, a:theme, separators)

  call tmuxline#apply(line_settings)
endfun

