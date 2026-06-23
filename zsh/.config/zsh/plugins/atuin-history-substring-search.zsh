#!/usr/bin/env zsh
##############################################################################
#
# Copyright (c) 2023 Sophie Tyalie
# Copyright (c) 2023 @Nezteb
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  * Redistributions in binary form must reproduce the above
#    copyright notice, this list of conditions and the following
#    disclaimer in the documentation and/or other materials provided
#    with the distribution.
#
#  * Neither the name of the FIZSH nor the names of its contributors
#    may be used to endorse or promote products derived from this
#    software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
##############################################################################

# Taken from https://gist.github.com/tyalie/7e13cfe2ec62d99fa341a07ed12ef7c0
# and modified slightly.

# global configuration
: ${ATUIN_HISTORY_SEARCH_FILTER_MODE='global'}

# internal variables
typeset -g -i _atuin_history_match_index
typeset -g _atuin_history_search_result
typeset -g _atuin_history_search_query
typeset -g _atuin_history_refresh_display

atuin-history-up() {
  _atuin-history-search-begin

  # iteratively use the next mechanism to process up if the previous didn't succeed
  _atuin-history-up-buffer ||
  _atuin-history-up-search

  _atuin-history-search-end
}

atuin-history-down() {
  _atuin-history-search-begin

  # iteratively use the next mechanism to process down if the previous didn't succeed
  _atuin-history-down-buffer ||
  _atuin-history-down-search

  _atuin-history-search-end
}

zle -N atuin-history-up
zle -N atuin-history-down

bindkey '\eOA' atuin-history-up
bindkey '\eOB' atuin-history-down

_atuin-history-search-begin() {
  # assume we will not render anything
  _atuin_history_refresh_display=

  # If the buffer is the same as the previously displayed history substring
  # search result, then just keep stepping through the match list. Otherwise
  # start a new search.
  if [[ -n $BUFFER && $BUFFER == ${_atuin_history_search_result:-} ]]; then
    return;
  fi

  # Clear the previous result.
  _atuin_history_search_result=''

  # setup our search query
  if [[ -z $BUFFER ]]; then
    _atuin_history_search_query=
  else
    _atuin_history_search_query="$BUFFER"
  fi

  # reset search index
  _atuin_history_match_index=0
}

_atuin-history-search-end() {
  # if our index is <= 0 just print the query we started with
  if [[ $_atuin_history_match_index -le 0 ]]; then
    _atuin_history_search_result="$_atuin_history_search_query"
  fi

  # draw buffer if requested
  if [[ $_atuin_history_refresh_display -eq 1 ]]; then
    BUFFER="$_atuin_history_search_result"
    CURSOR="${#BUFFER}"
  fi

  # for debug purposes only
  #zle -R "mn: "$_atuin_history_match_index" / qr: $_atuin_history_search_result"
  #read -k -t 1 && zle -U $REPLY
}

_atuin-history-up-buffer() {
  # attribution to zsh-history-substring-search
  #
  # Check if the UP arrow was pressed to move the cursor within a multi-line
  # buffer. This amounts to three tests:
  #
  # 1. $#buflines -gt 1.
  #
  # 2. $CURSOR -ne $#BUFFER.
  #
  # 3. Check if we are on the first line of the current multi-line buffer.
  #    If so, pressing UP would amount to leaving the multi-line buffer.
  #
  #    We check this by adding an extra "x" to $LBUFFER, which makes
  #    sure that xlbuflines is always equal to the number of lines
  #    until $CURSOR (including the line with the cursor on it).
  #
  local buflines XLBUFFER xlbuflines
  buflines=(${(f)BUFFER})
  XLBUFFER=$LBUFFER"x"
  xlbuflines=(${(f)XLBUFFER})

  if [[ $#buflines -gt 1 && $CURSOR -ne $#BUFFER && $#xlbuflines -ne 1 ]]; then
    zle up-line-or-history
    return 0
  fi

  return 1
}

_atuin-history-down-buffer() {
  # attribution to zsh-history-substring-search
  #
  # Check if the DOWN arrow was pressed to move the cursor within a multi-line
  # buffer. This amounts to three tests:
  #
  # 1. $#buflines -gt 1.
  #
  # 2. $CURSOR -ne $#BUFFER.
  #
  # 3. Check if we are on the last line of the current multi-line buffer.
  #    If so, pressing DOWN would amount to leaving the multi-line buffer.
  #
  #    We check this by adding an extra "x" to $RBUFFER, which makes
  #    sure that xrbuflines is always equal to the number of lines
  #    from $CURSOR (including the line with the cursor on it).
  #
  local buflines XRBUFFER xrbuflines
  buflines=(${(f)BUFFER})
  XRBUFFER="x"$RBUFFER
  xrbuflines=(${(f)XRBUFFER})

  if [[ $#buflines -gt 1 && $CURSOR -ne $#BUFFER && $#xrbuflines -ne 1 ]]; then
    zle down-line-or-history
    return 0
  fi

  return 1
}

_atuin-history-up-search() {
  _atuin_history_match_index+=1

  offset=$((_atuin_history_match_index-1))
  search_result=$(_atuin-history-do-search $offset "$_atuin_history_search_query")

  if [[ -z $search_result ]]; then
    # if search result is empty, there's no more history
    # so just show the previous result
    _atuin_history_match_index+=-1
    return 1
  fi

  _atuin_history_refresh_display=1
  _atuin_history_search_result="$search_result"
  return 0
}

_atuin-history-down-search() {
  # we can't go below 0
  if [[ $_atuin_history_match_index -le 0 ]]; then
    return 1
  fi

  _atuin_history_refresh_display=1
  _atuin_history_match_index+=-1

  offset=$((_atuin_history_match_index-1))
  _atuin_history_search_result=$(_atuin-history-do-search $offset "$_atuin_history_search_query")

  return 0
}

_atuin-history-do-search() {
  if [[ $1 -ge 0 ]]; then
    atuin search --filter-mode "$ATUIN_HISTORY_SEARCH_FILTER_MODE" --search-mode prefix \
      --limit 1 --offset $1 --format "{command}" \
      "$2"
  fi
}
