" Toggle between Absolute Line Numbers and Relative Line Numbers
function! NumberToggle()
  " Determine the Current Setting
  let rn = execute(":set relativenumber?")[1:]
  " Set the inverse of the Current Setting
  execute(":set "..rn.."!")
endfunc
command TNum call NumberToggle()
command NT call NumberToggle()
command NumberToggle call NumberToggle()
command ToggleNumber call NumberToggle()

" Alternative version
" toggle between number and relativenumber
function! ToggleNumber()
    if(&relativenumber == 1)
        set norelativenumber
        set number
    else
        set relativenumber
    endif
endfunc