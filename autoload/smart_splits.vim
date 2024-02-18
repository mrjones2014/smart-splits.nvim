" This bit works better in Vimscript because Vimscript treats
" terminal escapes (e.g. \033]1337) as octal, whereas Lua treats
" them as base-10. This means to do this in Lua I'd have to translate
" the codes from what's in Wezterm's docs and convert them to base-10.
" I'd prefer to just use Vimscript and keep the codes consistent with
" Wezterm's docs.

let s:b64_table = [
  \ 'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
  \ 'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
  \ 'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
  \ 'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/']

function s:encode_b64(str, size)
  let bytes = map(range(len(a:str)), 'char2nr(a:str[v:val])')
  let b64 = []

  for i in range(0, len(bytes) - 1, 3)
    let n = bytes[i] * 0x10000
          \ + get(bytes, i + 1, 0) * 0x100
          \ + get(bytes, i + 2, 0)
    call add(b64, s:b64_table[n / 0x40000])
    call add(b64, s:b64_table[n / 0x1000 % 0x40])
    call add(b64, s:b64_table[n / 0x40 % 0x40])
    call add(b64, s:b64_table[n % 0x40])
  endfor

  if len(bytes) % 3 == 1
    let b64[-1] = '='
    let b64[-2] = '='
  endif

  if len(bytes) % 3 == 2
    let b64[-1] = '='
  endif

  let b64 = join(b64, '')
  if a:size <= 0
    return b64
  endif

  let chunked = ''
  while strlen(b64) > 0
    let chunked .= strpart(b64, 0, a:size) . "\n"
    let b64 = strpart(b64, a:size)
  endwhile

  return chunked
endfunction

function smart_splits#write_wezterm_var(var)
  if filewritable('/dev/fd/2') == 1
    let l:success = writefile([a:var], '/dev/fd/2', 'b') == 0
  else
    let l:success = chansend(v:stderr, a:var) > 0
  endif
  return l:success
endfunction

function smart_splits#format_wezterm_var(val)
  return printf("\033]1337;SetUserVar=IS_NVIM=%s\007", s:encode_b64(a:val, 0))
endfunction
