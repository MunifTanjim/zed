# vim: set filetype=zsh foldmethod=marker foldmarker=[[[,]]] :

declare -gA ZED
ZED[name]="${ZED[name]:-zed}"
ZED[self]="${0:A}"
ZED[CACHE_DIR]="${ZED[CACHE_DIR]:-${XDG_CACHE_HOME:-${HOME}/.cache}/zsh/.zed}"
ZED[DATA_DIR]="${ZED[DATA_DIR]:-${XDG_DATA_HOME:-${HOME}/.local/share}/zsh/.zed}"

# logging [[[
function __zed_log_err() {
  echo $@ >&2
}

function __zed_log_info() {
  echo $@
}
# ]]]

# completion [[[
function __zed_compinit() {
  local zcompdump
  for zcompdump in ${ZED[CACHE_DIR]}/.zcompdump(N.mh+24); do
    compinit -d "${zcompdump}"
    if [[ ! -s "${zcompdump}.zwc" ]] || [[ "${zcompdump}" -nt "${zcompdump}.zwc" ]]; then
      zcompile "${zcompdump}"
    fi
  done
  compinit -C -d "${ZED[CACHE_DIR]}/.zcompdump"
}

function __zed_compdef() {
  ZED_COMPDEF_REPLAY+=("${(j: :)${(q)@}}")
}

function __zed_compdef_intercept_on() {
  if (( ${+functions[compdef]} )); then
    ZED[function-compdef]="${functions[compdef]}"
  fi
  functions[compdef]='__zed_compdef "$@";'
}

function __zed_compdef_intercept_off() {
  if (( ${+ZED[function-compdef]} )); then
    functions[compdef]="${ZED[function-compdef]}"
  else
    unfunction compdef
  fi
}

function __zed_compdef_replay() {
  local compdef_entry pos
  for compdef_entry in ${ZED_COMPDEF_REPLAY[@]}; do
    pos=( "${(z)compdef_entry}" )
    if [[ ${#pos[@]} = 1 && -z ${pos[-1]} ]]; then
      continue
    fi
    pos=( "${(Q)pos[@]}" )
    compdef "${pos[@]}"
  done
}
# ]]]

# registry [[[
function :zed_plugin_registry() {
  local action="${1}"; shift

  local key val

  case ${action} in
    get)
      key="${1}"
      ZED_CTX=("${(@Q)${(@z)_zed_plugin_registry[${key}]}}")
      ;;
    set)
      key="${ZED_CTX[id]}"
      val="${(j: :)${(@qkv)ZED_CTX}}"
      _zed_plugin_registry[${key}]="${val}"
      ;;
  esac
}
# ]]]

function :zed_install_or_update() {
  local plugin_dir="${ZED[DATA_DIR]}/plugins/${ZED_CTX[name]}"
  local name="${ZED_CTX[name]}"
  local src_uri="${ZED_CTX[src]}"

  __zed_log_info "${name} pulling..."

  if [[ "${ZED_CTX[src][1]}" = "/" ]] || [[ "${ZED_CTX[src][1]}" = "~" ]]; then
    ZED_CTX[from]="file"

    mkdir -p "${plugin_dir}"

    if [[ -f "${src_uri}" ]]; then
      cp "${src_uri}" "${plugin_dir}/${ZED_CTX[name]}.plugin.zsh"
    elif [[ -d "${src_uri}" ]]; then
      cp -r ${src_uri}/** "${plugin_dir}/"
    fi
  else
    ZED_CTX[from]="git"

    if [[ ${src_uri} != *://* ]]; then
      src_uri="https://${src_uri%.git}.git"
    fi

    if [[ -d "${plugin_dir}" ]]; then
      command git -C "${plugin_dir}" pull --quiet --recurse-submodules --rebase --autostash
    else
      mkdir -p "${plugin_dir:h}"
      command git -C "${plugin_dir:h}" clone --depth 1 --recursive --shallow-submodules "${src_uri}" "${plugin_dir:t}"
    fi
  fi

  if [[ $? -ne 0 ]]; then
    __zed_log_err "${name} pull failed"
    return 1
  fi

  __zed_log_info "${name} pulled"

  pushd -q "${plugin_dir}${ZED_CTX[dir]}"

  eval "${ZED_CTX[onpull]}"

  if [[ ! -f "${ZED_CTX[pick]}" ]]; then
    return 1
  fi

  local file
  for file in ${(s: :)${ZED_CTX[compile]:-${ZED_CTX[pick]}}}; do
    zcompile -U "${(e)file}"
  done

  popd -q
}

function _zed_list() {
  local -a items=(${(k)ZED[(I)plugin-*]#plugin-})

  print -l ${items[@]}
}

function _zed_pull() {
  local -a ids=($@)

  if [[ ${#ids[@]} -eq 0 ]]; then
    ids=($(_zed_list))
  fi

  local -A pulled_ids

  local id
  for id in ${ids[@]}; do
    :zed_plugin_registry get "${id}"

    if [[ -z "${pulled_ids[${ZED_CTX[name]}]}" ]]; then
      :zed_install_or_update
    fi

    pulled_ids[${ZED_CTX[name]}]=true
  done
}

function _zed_pull-self() {
  __zed_log_info "zed pulling..."
  command git -C "${ZED[self]:h}" pull --quiet --recurse-submodules --rebase --autostash
  __zed_log_info "zed pulled"

  zcompile -U "${ZED[self]}"
}

function _zed_load() {
  ZED_CTX[src]="${1}"; shift

  local ctx_key ctx_val
  while (( $# )); do
    ctx_key="${1%%:*}"
    ctx_val="${1#*:}"
    ZED_CTX[${ctx_key}]="${ctx_val}"
    shift
  done

  if [[ -z "${ZED_CTX[name]}" ]]; then
    ZED_CTX[name]="${${ZED_CTX[src]:t}%.git}"
  fi

  if [[ -z "${ZED_CTX[pick]}" ]]; then
    if [[ -z "${ZED_CTX[dir]}" ]]; then
      ZED_CTX[pick]="${ZED_CTX[name]}.plugin.zsh"
    else
      ZED_CTX[pick]="${ZED_CTX[dir]:t}.plugin.zsh"
    fi
  fi

  ZED_CTX[dir]="${ZED_CTX[dir]:+/${ZED_CTX[dir]}}"

  ZED_CTX[id]="${ZED_CTX[name]}${ZED_CTX[dir]:+:::${ZED_CTX[dir]:t}}"

  :zed_plugin_registry set

  local plugin_dir="${ZED[DATA_DIR]}/plugins/${ZED_CTX[name]}"

  if [[ ! -f "${plugin_dir}${ZED_CTX[dir]}/${ZED_CTX[pick]}" ]]; then
    :zed_install_or_update
  fi

  if [[ ! -f "${plugin_dir}${ZED_CTX[dir]}/${ZED_CTX[pick]}" ]]; then
    __zed_log_err "failed to load plugin:"
    __zed_log_err "  ${ZED_CTX[src]} ${ZED_CTX[name]:+name:${ZED_CTX[name]}}"
    return 1
  fi

  fpath+="${plugin_dir}"

  if [[ -d "${plugin_dir}/functions" ]]; then
    fpath+="${plugin_dir}/functions"
  fi

  __zed_compdef_intercept_on
  pushd -q "${plugin_dir}${ZED_CTX[dir]}"
  source "${ZED_CTX[pick]}"
  eval "${ZED_CTX[onload]}"
  popd -q
  __zed_compdef_intercept_off

  ZED[plugin-${ZED_CTX[id]}]=true
}

function _zed_done() {
  __zed_compinit
  __zed_compdef_replay
}

function _zed_init() {
  declare -gA _zed_plugin_registry
  declare -ga ZED_COMPDEF_REPLAY

  if [[ ! -d "${ZED[CACHE_DIR]}" ]]; then
    mkdir -p "${ZED[CACHE_DIR]}"
  fi

  autoload -Uz compinit
}

function ${ZED[name]}() {
  local cmd="${1}"
  local REPLY

  if (( ${+functions[_zed_${cmd}]} )); then
    shift
    local -A ZED_CTX
    ZED_CTX=()
    _zed_${cmd} $@
    return $?
  else
    __zed_log_err "zed unknown command: ${cmd}"
    return 1
  fi
}
