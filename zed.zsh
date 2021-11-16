# vim: set filetype=zsh foldmethod=marker foldmarker=[[[,]]] :

declare -gA ZED
ZED[name]="${ZED[name]:-zed}"

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

function :zed_install() {
  local plugin_dir="${ZED[DATA_DIR]}/plugins/${ZED_CTX[name]}"

  if [[ ! -d "${plugin_dir:h}" ]]; then
    mkdir -p "${plugin_dir:h}"
  fi

  local name="${ZED_CTX[name]}"

  __zed_log_info "${name} installing..."

  local src_uri="${ZED_CTX[src]}"

  if [[ "${ZED_CTX[from]}" = "git" ]]; then
    if [[ ${src_uri} != *://* ]]; then
      src_uri="https://${src_uri%.git}.git"
    fi

    command git -C "${plugin_dir:h}" clone --depth 1 --recursive --shallow-submodules "${src_uri}" "${plugin_dir:t}"

    if [[ $? -ne 0 ]]; then
      __zed_log_err "${name} install failed"
      return 1
    fi
  fi

  if [[ "${ZED_CTX[from]}" = "file" ]]; then
    if [[ -f "${src_uri}" ]]; then
      mkdir -p "${plugin_dir}"
      cp "${src_uri}" "${plugin_dir}/${ZED_CTX[name]}.plugin.zsh"
    elif [[ -d "${src_uri}" ]]; then
      mkdir -p "${plugin_dir}"
      cp -r ${src_uri}/** "${plugin_dir}/"
    fi
  fi

  __zed_log_info "${name} installed"
}

function :zed_update() {
  if [[ ${__zed_skip_update} = true ]]; then
    return 0
  fi

  local plugin_dir="${ZED[DATA_DIR]}/plugins/${ZED_CTX[name]}"

  local name="${ZED_CTX[name]}"

  __zed_log_info "${name} updating..."

  local src_uri="${ZED_CTX[src]}"

  if [[ "${ZED_CTX[from]}" = "git" ]]; then
    command git -C "${plugin_dir}" pull --quiet --recurse-submodules --depth 1 --rebase --autostash

    if [[ $? -ne 0 ]]; then
      __zed_log_err "${name} update failed"
      return 1
    fi
  fi

  if [[ "${ZED_CTX[from]}" = "file" ]]; then
    if [[ -f "${src_uri}" ]]; then
      cp "${src_uri}" "${plugin_dir}/${ZED_CTX[name]}.plugin.zsh"
    elif [[ -d "${src_uri}" ]]; then
      cp -r ${src_uri}/** "${plugin_dir}/"
    fi
  fi

  __zed_log_info "${name} updated"
}

function :zed_install_or_update() {
  local plugin_dir="${ZED[DATA_DIR]}/plugins/${ZED_CTX[name]}"

  if [[ "${ZED_CTX[src][1]}" = "/" ]] || [[ "${ZED_CTX[src][1]}" = "~" ]]; then
    ZED_CTX[from]="file"
  else
    ZED_CTX[from]="git"
  fi

  if [[ -d "${plugin_dir}" ]]; then
    :zed_update
  else
    :zed_install
  fi

  if [[ $? -ne 0 ]]; then
    return $?
  fi

  pushd "${plugin_dir}${ZED_CTX[dir]}" > /dev/null

  eval "${ZED_CTX[onpull]}"

  if [[ ! -f "${ZED_CTX[pick]}" ]]; then
    return 1
  fi

  for file in ${(s: :)${ZED_CTX[compile]:-${ZED_CTX[pick]}}}; do
    zcompile -U "${file}"
  done

  popd > /dev/null
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
  local __zed_skip_update=false

  local id
  for id in ${ids[@]}; do
    :zed_plugin_registry get "${id}"

    __zed_skip_update=${pulled_ids[${ZED_CTX[name]}]}

    :zed_install_or_update

    pulled_ids[${ZED_CTX[name]}]=true
  done
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
  pushd "${plugin_dir}${ZED_CTX[dir]}" > /dev/null
  source "${ZED_CTX[pick]}"
  eval "${ZED_CTX[onload]}"
  popd > /dev/null
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

  if [[ -z "${ZED[CACHE_DIR]}" ]]; then
    ZED[CACHE_DIR]="${XDG_CACHE_HOME:-${HOME}/.cache}/zsh/.zed"
  fi

  if [[ -z "${ZED[DATA_DIR]}" ]]; then
    ZED[DATA_DIR]="${XDG_DATA_HOME:-${HOME}/.local/share}/zsh/.zed"
  fi

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
