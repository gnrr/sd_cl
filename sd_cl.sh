#################################################################################
#The MIT License (MIT)
#
#Copyright (c) 2013 rcmdnk
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of
#this software and associated documentation files (the "Software"), to deal in
#the Software without restriction, including without limitation the rights to
#use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
#the Software, and to permit persons to whom the Software is furnished to do so,
#subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
#FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
#COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
#IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
#CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#################################################################################


# Directory store file
export LASTDIRFILE=${LASTDIRFILE:-$HOME/.lastDir}
export PREDEFDIRFILE=${PREDEFDIRFILE:-$HOME/.predefDir}
export WINDOWDIRFILE=${WINDOWDIRFILE:-$HOME/.windowDir}
# Number of store directories
export NLASTDIR=${NLASTDIR:-20}

# post cd (overwrite cd (Bash) or chpwd (Zsh)
export ISPOSTCD=${ISPOSTCD:-1}

# COMPLETION
export NOCOMPLETION=${NOCOMPLETION:-0}
export NOCOMPINIT=${NOCOMPLETION:-0}

# cd wrap to pushd/popd
export ISCDWRAP=${ISCDWRAP:-1}

function sd () { # Save dir {{{
  # Edit predefined dir
  if [ $# -eq 1 ] && [ "$1" = "-e" ];then
    ${EDITOR:-"vim"} ${PREDEFDIRFILE:-$HOME/.predefDir}
    return 0
  fi

  # Fix array index for ZSH
  if [ "$ZSH_VERSION" != "" ];then
    setopt localoptions ksharrays
  fi

  # Set values
  local ldf=${LASTDIRFILE:-$HOME/.lastDir}
  local nld="${NLASTDIR:-20}"

  # Set Save Dir
  local curdir="$1"
  if [ $# -eq 0 ];then
    # Current directory
    curdir=$(pwd -P)
  fi

  # Renew last directories
  touch "$ldf"
  local -a dirs
  dirs=("$curdir")
  while read d;do
    if [ "$d" != "$curdir" ];then
      dirs=("${dirs[@]}" "$d")
    fi
  done < "$ldf"
  local ndirs=${#dirs[@]}

  # Store directories
  local i=0
  rm -f "$ldf"
  while [ $i -lt $ndirs ] && [ $i -lt $NLASTDIR ];do
    echo "${dirs[$i]}" >> "$ldf"
    i=$((i+1))
  done
} # }}}

function cl () { # Change directory to the Last directory {{{
  # Fix array index for ZSH
  if [ "$ZSH_VERSION" != "" ];then
    setopt localoptions ksharrays
  fi

  # Set values
  local ldf=${LASTDIRFILE:-$HOME/.lastDir}
  touch $ldf

  # Change to the last dir
  if [ $# -eq 0 ];then
    local ld=$(head -n1 $ldf)
    if [ "$ld" != "" ];then
      cd "$ld"
      return 0
    else
      echo "There is no saved directory."
      return 1
    fi
  fi

  local HELP="
  Usage: cl [-lcph] [-n <number> ]
  If there are no arguments, you will move to the last saved directory by sd command

  Arguments:
     -l              Show saved directories
     -c              Show saved directories and choose a directory
     -C              Clear directories
     -n              Move to <number>-th last directory
     -N              No header for selection window
     -p              Move to pre-defiend dirctory in $PREDEFDIRFILE
     -w              Move to other window's (screen/tmux) dirctory in $WINDOWDIRFILE
     -v              Move from current directory, like Vim
     -h              Print this HELP and exit
"

  # Initialize variables
  local nth=-1
  local list=0
  local choice=0
  local predef=0
  local window=0
  local vim=0
  local cleardir=0
  local noheader=0

  # OPTIND must be reset in function
  local optind_tmp=$OPTIND
  OPTIND=1

  # Get option
  while getopts clpwvCNn:h OPT;do
    case $OPT in
      "l" ) list=1 ;;
      "c" ) choice=1 ;;
      "n" ) nth="$OPTARG" ;;
      "p" ) predef=1; window=0; vim=0;;
      "w" ) window=1; predef=0; vim=0;;
      "v" ) vim=1; predef=0; window=0;;
      "C" ) cleardir=1 ;;
      "N" ) noheader=1 ;;
      "h" ) echo "$HELP" 1>&2;OPTIND=$optind_tmp;return ;;
      * ) echo "$HELP" 1>&2;OPTIND=$optind_tmp;return ;;
    esac
  done
  shift $(($OPTIND - 1))
  OPTIND=$optind_tmp

  # Use pre-defined directory file
  if [ $predef -eq 1 ];then
    ldf=${PREDEFDIRFILE:-$HOME/.predefDir}
    if [ $choice -eq 0 ] && [ $list -eq 0 ] && [ $nth -eq -1 ] && [ $# -eq 0 ];then
      local ld=$(head -n1 "$ldf"|sed "s|^~|${HOME}|")
      if [ "$ld" != "" ];then
        cd "$ld"
        return 0
      else
        echo "There is no saved directory."
        return 1
      fi
    fi
  elif [ $window -eq 1 ];then
    ldf=${WINDOWDIRFILE:-$HOME/.windowDir}
  fi

  # Change to given directory
  if [ $# -gt 0 ];then
    local d="${*}"
    if [ $window -eq 1 ];then
      d=$(grep "^$d" $ldf|head -n1|cut -d' ' -f 3-)
    fi
    cd "${d/#\~/${HOME}}"
    return 0
  fi

  # Clear
  if [ $cleardir -eq 1 ];then
    echo > $ldf
    return 0
  fi

  # Get last directories
  local cols="$(tput cols)"
  local max_width="$((cols-8))"
  touch $ldf
  local -a dirs
  local -a dirs_show
  local ndirs
  if [ $vim -ne 1 ];then
    while read d;do
      local d_show="${d/#${HOME}/~}"
      if [ $window -eq 1 ];then
        local dtmp=$(echo $d|cut -d' ' -f 3-)
        dirs=("${dirs[@]}" "${dtmp/#\~/${HOME}}")
      else
        dirs=("${dirs[@]}" "${d/#\~/${HOME}}")
      fi
      if [ ${#d_show} -ge $max_width ];then
        dirs_show=("${dirs_show[@]}" "...${d_show: $((${#d_show}-$max_width+3))}")
      else
        dirs_show=("${dirs_show[@]}" "${d_show}")
      fi
    done < $ldf
    ndirs=${#dirs[@]}
  else
    IFS=$'\n'
    dirs=($(ls -d */ 2>/dev/null))
    unset IFS
    if [ "$(pwd)" != "/" ];then
      dirs=("../" "${dirs[@]}")
    fi
    dirs_show=("${dirs[@]}")
    ndirs=${#dirs[@]}
  fi

  # Check dirs
  if [ $ndirs -eq 0 ];then
    echo "There is no saved directory."
    return 1
  fi

  # Change to nth
  if [ $nth != -1 ];then
    if ! echo $nth|grep -q "^[0-9]\+$";then
      echo "Wrong number? was given: $nth"
      return 1
    elif [ $nth -gt $ndirs ];then
      echo "$ndirs (< $nth) directories are stored."
      return 1
    fi
    cd "${dirs[$((nth-1))]}"
    if [ $predef -ne 1 ];then
      sd "${dirs[$((nth-1))]}"
    fi
    return 0
  fi

  # List up
  if [ $list -eq 1 ];then
    local pager=${PAGER:-less}
    {
      local i
      for ((i=0; i<$ndirs; i++));do
        printf "%3d %-${max_width}s %3d\n" $((i+1)) "${dirs_show[$i]}" $((i+1))
      done
    } | less
    return 0
  fi

  # Set trap
  trap "clear; tput cnorm; stty echo; return 1" 1 2 3 11 15

  # Hide cursor
  tput civis 2>/dev/null || tput vi 2>/dev/null

  # Save current display
  tput smcup 2>/dev/null || tput ti 2>/dev/null

  # Hide any input
  stty -echo

  # List up and choose directory
  local header
  local ext_row
  local lines
  local max_show
  function cl_setheader () {
    if [ $noheader -eq 0 ];then
      if [ $vim -eq 1 ];then
        header=" Current: $(pwd)
 [n]  j(down), [n]k(up), gg(top), G(bottom), [n]gg/G(go to n)
 Ent  er(move), q(exit)
"
      elif [ $window -eq 1 ];then
        header=" $ndirs directories in total
 [n]  j(down), [n]k(up), d(delete), p(put to pre-defined)
 gg(  top), G(bottom), [n]gg/G, (go to n), Enter(select), q(exit)
 n W  indow Pane Directory
"
      elif [ $predef -eq 1 ];then
        header=" $ndirs directories in total
 [n]  j(down), [n]k(up), d(delete), gg(top), G(bottom), [n]gg/G(go to n)
 Ent  er(select), q(exit)
"
      else
        header=" $ndirs directories in total
 [n]  j(down), [n]k(up), d(delete), p(put to pre-defined)
 gg(  top), G(bottom), [n]gg/G, (go to n), Enter(select), q(exit)
"
      fi
    else
      header=""
    fi
    if [ $noheader -eq 1 ];then
      ext_row=0
    else
      ext_row="$(echo "$header"|wc -l)"
    fi
    lines="$(tput lines)"
    max_show="$ndirs"
    if [ $ndirs -gt $((lines-ext_row)) ];then
      max_show=$((lines-ext_row))
    fi
  }
  cl_setheader

  function cl_printline () {
    tput cup $(($2)) 0
    local i="$(($3+1))"
    if [ $1 -eq 1 ];then
      printf "\e[7m%3d %-${max_width}s %3d\e[m" $i "${dirs_show[$3]}" $i
    else
      printf "%3d %-${max_width}s %3d" $i "${dirs_show[$3]}" $i
    fi
    tput cup $(($2)) 0
  }

  function cl_printall () {
    local offset=0
    local select=0
    if [ $# -gt 0 ];then
      offset=$1
      if [ $# -gt 1 ];then
        select=$2
      fi
    fi

    clear

    # Header
    echo "$header"

    local i
    for ((i=0; i<$((max_show)); i++));do
      if [ $((i+offset)) -eq $select ];then
        cl_printline 1 $((i+ext_row)) $((i+offset))
      else
        cl_printline 0 $((i+ext_row)) $((i+offset))
      fi
    done
  }

  # First view
  cl_printall

  # Select
  local n=0
  local n_offset=0
  local cursor_r="$ext_row"
  local ret=0
  local g=0
  local n_move=0
  tput cup $cursor_r 0

  while : ;do
    local c=""
    if [ "$ZSH_VERSION" != "" ];then
      read -s -k 1 c
    else
      read -s -n 1 c
    fi
    case $c in
      "j" )
        if [ $n_move -eq 0 ];then
          n_move=1
        fi
        for ((i=0; i<n_move; i++));do
          if [ $n -eq $((ndirs-1)) ];then
            break
          elif [ $cursor_r -eq $((lines-1)) ];then
            ((n_offset++));((n++))
            cl_printall $n_offset $n
          else
            cl_printline 0 $((cursor_r)) $n
            ((cursor_r++));((n++))
            cl_printline 1 $((cursor_r)) $n
          fi
        done
        g=0
        n_move=0
        continue
        ;;
      "k" )
        if [ $n_move -eq 0 ];then
          n_move=1
        fi
        for ((i=0; i<n_move; i++));do
          if [ $cursor_r -ne $ext_row ];then
            cl_printline 0 $((cursor_r)) $n
            ((cursor_r--));((n--))
            cl_printline 1 $((cursor_r)) $n
          elif [ $n_offset -gt 0 ];then
            ((n_offset--));((n--))
            cl_printall $n_offset $n
          else
            break
          fi
        done
        g=0
        n_move=0
        continue
        ;;
      "g" )
        if [ $g -eq 0 ];then
          g=1
          continue
        fi

        if [ $n_move -eq 0 ];then
          n=0
          n_offset=0
          cursor_r="$ext_row"
        elif [ $n_move -gt $ndirs ];then
          :
        elif [ $n_move -le $n_offset ];then
          n=$((n_move-1))
          n_offset=$n
          cursor_r=$ext_row
        elif [ $((n_move)) -gt $((n_offset+max_show)) ];then
          n=$((n_move-1))
          n_offset=$((n-max_show+1))
          cursor_r=$((lines-1))
        else
          n=$((n_move-1))
          cursor_r=$((ext_row+n-n_offset))
        fi
        cl_printall $n_offset $n
        n_move=0
        g=0
        continue
        ;;
      "G" )
        if [ $n_move -eq 0 ];then
          n=$((ndirs-1))
          if [ $n -ge $max_show ];then
            n_offset=$((ndirs-max_show))
            cursor_r=$((lines-1))
          else
            n_offset=0
            cursor_r=$((ext_row+n))
          fi
        elif [ $n_move -gt $ndirs ];then
          :
        elif [ $n_move -le $n_offset ];then
          n=$((n_move-1))
          n_offset=$n
          cursor_r=$ext_row
        elif [ $n_move -gt $((n_offset+max_show)) ];then
          n=$((n_move-1))
          n_offset=$((n-max_show+1))
          cursor_r=$((lines-1))
        else
          n=$((n_move-1))
          cursor_r=$((ext_row+n-n_offset))
        fi
        cl_printall $n_offset $n
        n_move=0
        continue
        ;;
      "d" )
        if [ $vim -eq 1 ];then
          continue
        fi
        unset dirs[$n];dirs=("${dirs[@]}")
        unset dirs_show[$n];dirs_show=("${dirs_show[@]}")
        ndirs=${#dirs[@]}
        sed -i ".bak" "$((n+1))d" $ldf
        rm -f ${ldf}.bak
        if [ $ndirs -eq 0 ];then
          break
        fi
        if [ $n -eq $ndirs ];then
          if [ $n_offset -gt 0 ];then
            ((n_offset--));((n--))
          else
            ((cursor_r--));((n--))
          fi
        fi
        cl_setheader
        cl_printall $n_offset $n
        continue
        ;;
      "p" )
        if [ $predef -eq 1 ] || [ $vim -eq 1 ];then
          continue
        fi
        local pdf=${PREDEFDIRFILE:-$HOME/.predefDir}
        touch $pdf
        if ! grep -q "^${dirs[$n]}$" "$pdf";then
          echo "${dirs[$n]}" >> "$pdf"
        fi
        continue
        ;;
      "q" ) break;;
      # Choose, for bash|zsh
      ""|"
")
        if [ $vim -eq 0 ];then
          d=`sh -c "echo ${dirs[$n]}"`
          if [ -d "${d}" ];then
            cd "${d}"
            if [ $predef -ne 1 ];then
              sd "${d}"
            fi
          else
            ret=1
          fi
          break
        fi
        cd "${dirs[$n]}"
        IFS=$'\n'
        dirs=($(ls -d */ 2>/dev/null))
        unset IFS
        if [ "$(pwd)" != "/" ];then
          dirs=("../" "${dirs[@]}")
        fi
        dirs_show=("${dirs[@]}")
        ndirs=${#dirs[@]}
        n=0
        n_offset=0
        cursor_r="$ext_row"
        cl_setheader
        cl_printall $n_offset $n
        continue
        ;;
      [0-9])
        if [ $n_move -gt 0 ];then
          n_move="$n_move""$c"
        else
          n_move=$c
        fi
        continue
        ;;
      "*" )
        g=0
        n_move=0
        continue;;
    esac
  done

  clear

  # Show cursor
  tput cnorm 2>/dev/null || tput vs 2>/dev/null

  # Restore display
  tput rmcup 2>/dev/null || tput te 2>/dev/null

  # Enable echo input
  stty echo

  if [ $ret -eq 1 ];then
    echo "${dirs[$n]} doesn't exist"
    return $ret
  fi
  return $ret

} # }}}

# Completion {{{
if [ $NOCOMPLETION -eq 0 ];then
  if [ "$ZSH_VERSION" != "" ];then
    if [ $NOCOMPINIT -eq 0 ];then
      autoload -Uz compinit
      compinit
    fi

    _cl () { # {{{
      typeset -A opt_args
      local context state line
      _arguments \
        '-p:: :->predef'\
        '-w:: :->window'\
        '-c:: :->non'\
        '-l:: :->non'\
        '-n:: :->non'\
        '-h:: :->non'\
        '*:: :->lastdir'
      local ldf
      if echo $state|grep -q non;then
        return 0
      elif echo $state|grep -q predef;then
        ldf=${PREDEFDIRFILE:-$HOME/.predefDir}
      elif echo $state|grep -q window;then
        ldf=${WINDOWDIRFILE:-$HOME/.windowDir}
      elif echo $state|grep -q lastdir;then
        ldf=${LASTDIRFILE:-$HOME/.lastDir}
      else
        return 0
      fi
      IFS=$'\n'
      compadd $(cat $ldf)
      unset IFS
    } # }}}
    compdef _cl cl
  elif [ "$BASH_VERSION" != "" ];then
    function _cl () { # {{{
      COMPREPLY=()
      local cur=${COMP_WORDS[COMP_CWORD]}
      local prev=${COMP_WORDS[COMP_CWORD-1]}
      local ldf=${LASTDIRFILE:-$HOME/.lastDir}
      if [[ $prev = -p ]];then
        ldf=${PREDEFDIRFILE:-$HOME/.predefDir}
      elif [[ $prev = -w ]];then
        ldf=${WINDOWDIRFILE:-$HOME/.windowDir}
      fi
      IFS=$'\n'
      if [[ "$cur" != -* && ( "$prev" == $1 || "$prev" == -p ) || "$prev" == -w ]];then
        COMPREPLY=($( compgen -W "$(cat $ldf)" -- $cur))
      fi
      unset IFS
    } # }}}
    complete -F _cl cl
  fi
fi
# }}}

# function for post cd in screen or tmux{{{
function post_cd () {
  :
}
if [ $ISPOSTCD -eq 1 ];then
  if [ -n "$STY" ];then
    function post_cd () {
      local wdf=${WINDOWDIRFILE:-$HOME/.windowDir}
      touch $wdf
      if grep -q "^$WINDOW 0 " "$wdf";then
        sed "s|^$WINDOW 0 .*$|$WINDOW 0 $(pwd)|" "$wdf"|sort > "${wdf}.tmp"
        mv "${wdf}.tmp" ${wdf}
      else
        (cat "$wdf" && echo "$WINDOW 0 $(pwd)")|sort > "${wdf}.tmp"
        mv "${wdf}.tmp" ${wdf}
      fi
    }
  elif [ -n "$TMUX" ];then
    function post_cd () {
      local window="$(tmux display -p '#I')"
      local pane="$(tmux display -p '#P')"
      local wdf=${WINDOWDIRFILE:-$HOME/.windowDir}
      touch $wdf
      if grep -q "^$window $pane " "$wdf";then
        sed "s|^$window $pane .*$|$window $pane $(pwd)|" "$wdf"|sort > "${wdf}.tmp"
        mv "${wdf}.tmp" ${wdf}
      else
        (cat "$wdf" && echo "$window $pane $(pwd)")|sort > "${wdf}.tmp"
        mv "${wdf}.tmp" ${wdf}
      fi
    }
  fi
fi
# }}}

# function for cd wrap to pushd/popd {{{
function wrap_cd () {
  builtin cd "$@"
}
if [ $ISCDWRAP -eq 1 ];then
  function wrap_cd () {
    if [ $# = 0 ];then
      builtin cd
    elif [ "$1" = "-" ];then
      local opwd=$OLDPWD
      pushd . >/dev/null
      builtin cd $opwd
    elif [ -f "$1" ];then
      pushd . >/dev/null
      builtin cd $(dirname "$@")
    else
      pushd . >/dev/null
      builtin cd "$@"
    fi
  }
fi

# Alias for popd
alias bd="popd >/dev/null"
# }}}

# Set cd/chpwd
if [ "$ZSH_VERSION" != "" ];then
  if [ $ISPOSTCD -eq 1 ];then
    function chpwd () {
      post_cd
    }
  fi
  if [ $ISCDWRAP -eq 1 ];then
    function cd () {
      wrap_cd "$@"
    }
  fi
else
  if [ $ISPOSTCD -eq 1 ] || [ $ISCDWRAP -eq 1 ];then
    function cd () {
      wrap_cd "$@"
      local ret=$?
      if [ $ret -eq 0 ];then
        post_cd
      fi
      return $ret
    }
  fi
fi
# }}}
