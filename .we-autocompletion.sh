# bash completion for we                                   -*- shell-script -*-

__we_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__we_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

__we_index_of_word()
{
    local w word=$1
    shift
    index=0
    for w in "$@"; do
        [[ $w = "$word" ]] && return
        index=$((index+1))
    done
    index=-1
}

__we_contains_word()
{
    local w word=$1; shift
    for w in "$@"; do
        [[ $w = "$word" ]] && return
    done
    return 1
}

__we_handle_reply()
{
    __we_debug "${FUNCNAME[0]}"
    case $cur in
        -*)
            if [[ $(type -t compopt) = "builtin" ]]; then
                compopt -o nospace
            fi
            local allflags
            if [ ${#must_have_one_flag[@]} -ne 0 ]; then
                allflags=("${must_have_one_flag[@]}")
            else
                allflags=("${flags[*]} ${two_word_flags[*]}")
            fi
            COMPREPLY=( $(compgen -W "${allflags[*]}" -- "$cur") )
            if [[ $(type -t compopt) = "builtin" ]]; then
                [[ "${COMPREPLY[0]}" == *= ]] || compopt +o nospace
            fi

            # complete after --flag=abc
            if [[ $cur == *=* ]]; then
                if [[ $(type -t compopt) = "builtin" ]]; then
                    compopt +o nospace
                fi

                local index flag
                flag="${cur%=*}"
                __we_index_of_word "${flag}" "${flags_with_completion[@]}"
                COMPREPLY=()
                if [[ ${index} -ge 0 ]]; then
                    PREFIX=""
                    cur="${cur#*=}"
                    ${flags_completion[${index}]}
                    if [ -n "${ZSH_VERSION}" ]; then
                        # zsh completion needs --flag= prefix
                        eval "COMPREPLY=( \"\${COMPREPLY[@]/#/${flag}=}\" )"
                    fi
                fi
            fi
            return 0;
            ;;
    esac

    # check if we are handling a flag with special work handling
    local index
    __we_index_of_word "${prev}" "${flags_with_completion[@]}"
    if [[ ${index} -ge 0 ]]; then
        ${flags_completion[${index}]}
        return
    fi

    # we are parsing a flag and don't have a special handler, no completion
    if [[ ${cur} != "${words[cword]}" ]]; then
        return
    fi

    local completions
    completions=("${commands[@]}")
    if [[ ${#must_have_one_noun[@]} -ne 0 ]]; then
        completions=("${must_have_one_noun[@]}")
    fi
    if [[ ${#must_have_one_flag[@]} -ne 0 ]]; then
        completions+=("${must_have_one_flag[@]}")
    fi
    COMPREPLY=( $(compgen -W "${completions[*]}" -- "$cur") )

    if [[ ${#COMPREPLY[@]} -eq 0 && ${#noun_aliases[@]} -gt 0 && ${#must_have_one_noun[@]} -ne 0 ]]; then
        COMPREPLY=( $(compgen -W "${noun_aliases[*]}" -- "$cur") )
    fi

    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
        declare -F __custom_func >/dev/null && __custom_func
    fi

    # available in bash-completion >= 2, not always present on macOS
    if declare -F __ltrim_colon_completions >/dev/null; then
        __ltrim_colon_completions "$cur"
    fi

    # If there is only 1 completion and it is a flag with an = it will be completed
    # but we don't want a space after the =
    if [[ "${#COMPREPLY[@]}" -eq "1" ]] && [[ $(type -t compopt) = "builtin" ]] && [[ "${COMPREPLY[0]}" == --*= ]]; then
       compopt -o nospace
    fi
}

# The arguments should be in the form "ext1|ext2|extn"
__we_handle_filename_extension_flag()
{
    local ext="$1"
    _filedir "@(${ext})"
}

__we_handle_subdirs_in_dir_flag()
{
    local dir="$1"
    pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1
}

__we_handle_flag()
{
    __we_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    # if a command required a flag, and we found it, unset must_have_one_flag()
    local flagname=${words[c]}
    local flagvalue
    # if the word contained an =
    if [[ ${words[c]} == *"="* ]]; then
        flagvalue=${flagname#*=} # take in as flagvalue after the =
        flagname=${flagname%=*} # strip everything after the =
        flagname="${flagname}=" # but put the = back
    fi
    __we_debug "${FUNCNAME[0]}: looking for ${flagname}"
    if __we_contains_word "${flagname}" "${must_have_one_flag[@]}"; then
        must_have_one_flag=()
    fi

    # if you set a flag which only applies to this command, don't show subcommands
    if __we_contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
      commands=()
    fi

    # keep flag value with flagname as flaghash
    # flaghash variable is an associative array which is only supported in bash > 3.
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        if [ -n "${flagvalue}" ] ; then
            flaghash[${flagname}]=${flagvalue}
        elif [ -n "${words[ $((c+1)) ]}" ] ; then
            flaghash[${flagname}]=${words[ $((c+1)) ]}
        else
            flaghash[${flagname}]="true" # pad "true" for bool flag
        fi
    fi

    # skip the argument to a two word flag
    if __we_contains_word "${words[c]}" "${two_word_flags[@]}"; then
        c=$((c+1))
        # if we are looking for a flags value, don't show commands
        if [[ $c -eq $cword ]]; then
            commands=()
        fi
    fi

    c=$((c+1))

}

__we_handle_noun()
{
    __we_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    if __we_contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
        must_have_one_noun=()
    elif __we_contains_word "${words[c]}" "${noun_aliases[@]}"; then
        must_have_one_noun=()
    fi

    nouns+=("${words[c]}")
    c=$((c+1))
}

__we_handle_command()
{
    __we_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    local next_command
    if [[ -n ${last_command} ]]; then
        next_command="_${last_command}_${words[c]//:/__}"
    else
        if [[ $c -eq 0 ]]; then
            next_command="_we_root_command"
        else
            next_command="_${words[c]//:/__}"
        fi
    fi
    c=$((c+1))
    __we_debug "${FUNCNAME[0]}: looking for ${next_command}"
    declare -F "$next_command" >/dev/null && $next_command
}

__we_handle_word()
{
    if [[ $c -ge $cword ]]; then
        __we_handle_reply
        return
    fi
    __we_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
    if [[ "${words[c]}" == -* ]]; then
        __we_handle_flag
    elif __we_contains_word "${words[c]}" "${commands[@]}"; then
        __we_handle_command
    elif [[ $c -eq 0 ]]; then
        __we_handle_command
    elif __we_contains_word "${words[c]}" "${command_aliases[@]}"; then
        # aliashash variable is an associative array which is only supported in bash > 3.
        if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
            words[c]=${aliashash[${words[c]}]}
            __we_handle_command
        else
            __we_handle_noun
        fi
    else
        __we_handle_noun
    fi
    __we_handle_word
}

_we_autocompletion()
{
    last_command="we_autocompletion"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    flags+=("--stdout")
    local_nonpersistent_flags+=("--stdout")

    must_have_one_flag=()
    must_have_one_noun=()
    must_have_one_noun+=("bash")
    must_have_one_noun+=("zsh")
    noun_aliases=()
}

_we_busy()
{
    last_command="we_busy"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_ci_create()
{
    last_command="we_ci_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--project=")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--project=")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_ci_lint()
{
    last_command="we_ci_lint"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_ci_status()
{
    last_command="we_ci_status"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--wait")
    local_nonpersistent_flags+=("--wait")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_ci_trace()
{
    last_command="we_ci_trace"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_ci_trigger()
{
    last_command="we_ci_trigger"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--project=")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--project=")
    flags+=("--token=")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--token=")
    flags+=("--variable=")
    two_word_flags+=("-v")
    local_nonpersistent_flags+=("--variable=")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_ci_view()
{
    last_command="we_ci_view"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_ci()
{
    last_command="we_ci"

    command_aliases=()

    commands=()
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("run")
        aliashash["run"]="create"
    fi
    commands+=("lint")
    commands+=("status")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("run")
        aliashash["run"]="status"
    fi
    commands+=("trace")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("logs")
        aliashash["logs"]="trace"
    fi
    commands+=("trigger")
    commands+=("view")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_clone()
{
    last_command="we_clone"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--recursive")
    flags+=("-r")
    local_nonpersistent_flags+=("--recursive")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_config_edit()
{
    last_command="we_config_edit"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_config()
{
    last_command="we_config"

    command_aliases=()

    commands=()
    commands+=("edit")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_fork()
{
    last_command="we_fork"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_idle()
{
    last_command="we_idle"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--reset")
    local_nonpersistent_flags+=("--reset")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_issue_browse()
{
    last_command="we_issue_browse"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--project=")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_issue_close()
{
    last_command="we_issue_close"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--project=")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_issue_create()
{
    last_command="we_issue_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--assignees=")
    two_word_flags+=("-a")
    local_nonpersistent_flags+=("--assignees=")
    flags+=("--estimate=")
    two_word_flags+=("-e")
    local_nonpersistent_flags+=("--estimate=")
    flags+=("--label=")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--label=")
    flags+=("--message=")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--message=")
    flags+=("--spend=")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--spend=")
    flags+=("--project=")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_issue_edit()
{
    last_command="we_issue_edit"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--assign=")
    two_word_flags+=("-a")
    local_nonpersistent_flags+=("--assign=")
    flags+=("--estimate=")
    two_word_flags+=("-e")
    local_nonpersistent_flags+=("--estimate=")
    flags+=("--label=")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--label=")
    flags+=("--message=")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--message=")
    flags+=("--spend=")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--spend=")
    flags+=("--unassign=")
    local_nonpersistent_flags+=("--unassign=")
    flags+=("--unlabel=")
    local_nonpersistent_flags+=("--unlabel=")
    flags+=("--project=")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_issue_finish()
{
    last_command="we_issue_finish"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--project=")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_issue_list()
{
    last_command="we_issue_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    local_nonpersistent_flags+=("--all")
    flags+=("--label=")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--label=")
    flags+=("--number=")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--number=")
    flags+=("--state=")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--state=")
    flags+=("--project=")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_issue_note()
{
    last_command="we_issue_note"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--message=")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--message=")
    flags+=("--project=")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_issue_show()
{
    last_command="we_issue_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--comments")
    flags+=("-c")
    local_nonpersistent_flags+=("--comments")
    flags+=("--project=")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
    noun_aliases+=("s")
}

_we_issue_switch()
{
    last_command="we_issue_switch"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--project=")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_issue_take()
{
    last_command="we_issue_take"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--auto")
    flags+=("-a")
    local_nonpersistent_flags+=("--auto")
    flags+=("--interactive")
    flags+=("-i")
    local_nonpersistent_flags+=("--interactive")
    flags+=("--project=")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_issue()
{
    last_command="we_issue"

    command_aliases=()

    commands=()
    commands+=("browse")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("b")
        aliashash["b"]="browse"
    fi
    commands+=("close")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("delete")
        aliashash["delete"]="close"
    fi
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("add")
        aliashash["add"]="create"
        command_aliases+=("new")
        aliashash["new"]="create"
    fi
    commands+=("edit")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("update")
        aliashash["update"]="edit"
    fi
    commands+=("finish")
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
        command_aliases+=("search")
        aliashash["search"]="list"
    fi
    commands+=("note")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("comment")
        aliashash["comment"]="note"
    fi
    commands+=("show")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("get")
        aliashash["get"]="show"
    fi
    commands+=("switch")
    commands+=("take")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--project=")
    two_word_flags+=("-p")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_label_apply()
{
    last_command="we_label_apply"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--group=")
    two_word_flags+=("-g")
    local_nonpersistent_flags+=("--group=")
    flags+=("--ramp-up=")
    local_nonpersistent_flags+=("--ramp-up=")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_label_list()
{
    last_command="we_label_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--group=")
    local_nonpersistent_flags+=("--group=")
    flags+=("--real")
    local_nonpersistent_flags+=("--real")
    flags+=("--short")
    local_nonpersistent_flags+=("--short")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_label_mod()
{
    last_command="we_label_mod"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--group=")
    two_word_flags+=("-g")
    local_nonpersistent_flags+=("--group=")
    flags+=("--ramp-up=")
    local_nonpersistent_flags+=("--ramp-up=")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_label()
{
    last_command="we_label"

    command_aliases=()

    commands=()
    commands+=("apply")
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
        command_aliases+=("search")
        aliashash["search"]="list"
    fi
    commands+=("mod")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_mr_approve()
{
    last_command="we_mr_approve"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_mr_browse()
{
    last_command="we_mr_browse"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_mr_checkout()
{
    last_command="we_mr_checkout"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--branch=")
    two_word_flags+=("-b")
    local_nonpersistent_flags+=("--branch=")
    flags+=("--track")
    flags+=("-t")
    local_nonpersistent_flags+=("--track")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_mr_close()
{
    last_command="we_mr_close"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_mr_create()
{
    last_command="we_mr_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--allow-collaboration")
    local_nonpersistent_flags+=("--allow-collaboration")
    flags+=("--assignee=")
    two_word_flags+=("-a")
    local_nonpersistent_flags+=("--assignee=")
    flags+=("--label=")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--label=")
    flags+=("--message=")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--message=")
    flags+=("--milestone=")
    local_nonpersistent_flags+=("--milestone=")
    flags+=("--remove-source-branch")
    flags+=("-d")
    local_nonpersistent_flags+=("--remove-source-branch")
    flags+=("--squash")
    flags+=("-s")
    local_nonpersistent_flags+=("--squash")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_mr_list()
{
    last_command="we_mr_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    local_nonpersistent_flags+=("--all")
    flags+=("--label=")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--label=")
    flags+=("--number=")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--number=")
    flags+=("--state=")
    flags_with_completion+=("--state")
    flags_completion+=("(opened closed merged)")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("(opened closed merged)")
    local_nonpersistent_flags+=("--state=")
    flags+=("--target-branch=")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--target-branch=")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_mr_merge()
{
    last_command="we_mr_merge"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_mr_note()
{
    last_command="we_mr_note"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--message=")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--message=")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_mr_rebase()
{
    last_command="we_mr_rebase"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_mr_show()
{
    last_command="we_mr_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
    noun_aliases+=("s")
}

_we_mr_thumb_down()
{
    last_command="we_mr_thumb_down"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_mr_thumb_up()
{
    last_command="we_mr_thumb_up"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_mr_thumb()
{
    last_command="we_mr_thumb"

    command_aliases=()

    commands=()
    commands+=("down")
    commands+=("up")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_mr()
{
    last_command="we_mr"

    command_aliases=()

    commands=()
    commands+=("approve")
    commands+=("browse")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("b")
        aliashash["b"]="browse"
    fi
    commands+=("checkout")
    commands+=("close")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("delete")
        aliashash["delete"]="close"
    fi
    commands+=("create")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("new")
        aliashash["new"]="create"
    fi
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi
    commands+=("merge")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("delete")
        aliashash["delete"]="merge"
    fi
    commands+=("note")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("comment")
        aliashash["comment"]="note"
    fi
    commands+=("rebase")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("delete")
        aliashash["delete"]="rebase"
    fi
    commands+=("show")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("get")
        aliashash["get"]="show"
    fi
    commands+=("thumb")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_pm()
{
    last_command="we_pm"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_project_browse()
{
    last_command="we_project_browse"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_project_create()
{
    last_command="we_project_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--description=")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--description=")
    flags+=("--internal")
    local_nonpersistent_flags+=("--internal")
    flags+=("--name=")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name=")
    flags+=("--private")
    flags+=("-p")
    local_nonpersistent_flags+=("--private")
    flags+=("--public")
    local_nonpersistent_flags+=("--public")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_project_list()
{
    last_command="we_project_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    local_nonpersistent_flags+=("--all")
    flags+=("--member")
    local_nonpersistent_flags+=("--member")
    flags+=("--mine")
    flags+=("-m")
    local_nonpersistent_flags+=("--mine")
    flags+=("--number=")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--number=")
    flags+=("--starred")
    local_nonpersistent_flags+=("--starred")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_project()
{
    last_command="we_project"

    command_aliases=()

    commands=()
    commands+=("browse")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("b")
        aliashash["b"]="browse"
    fi
    commands+=("create")
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
        command_aliases+=("search")
        aliashash["search"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_snippet_browse()
{
    last_command="we_snippet_browse"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--global")
    flags+=("-g")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_snippet_create()
{
    last_command="we_snippet_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--message=")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--message=")
    flags+=("--name=")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name=")
    flags+=("--private")
    flags+=("-p")
    local_nonpersistent_flags+=("--private")
    flags+=("--public")
    local_nonpersistent_flags+=("--public")
    flags+=("--global")
    flags+=("-g")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_snippet_delete()
{
    last_command="we_snippet_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--global")
    flags+=("-g")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_snippet_list()
{
    last_command="we_snippet_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    local_nonpersistent_flags+=("--all")
    flags+=("--number=")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--number=")
    flags+=("--global")
    flags+=("-g")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_snippet()
{
    last_command="we_snippet"

    command_aliases=()

    commands=()
    commands+=("browse")
    commands+=("create")
    commands+=("delete")
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("ls")
        aliashash["ls"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--global")
    flags+=("-g")
    flags+=("--message=")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--message=")
    flags+=("--name=")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name=")
    flags+=("--private")
    flags+=("-p")
    local_nonpersistent_flags+=("--private")
    flags+=("--public")
    local_nonpersistent_flags+=("--public")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_update()
{
    last_command="we_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--quiet")
    flags+=("-q")
    local_nonpersistent_flags+=("--quiet")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_user_list()
{
    last_command="we_user_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_user()
{
    last_command="we_user"

    command_aliases=()

    commands=()
    commands+=("list")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("l")
        aliashash["l"]="list"
        command_aliases+=("ls")
        aliashash["ls"]="list"
        command_aliases+=("search")
        aliashash["search"]="list"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_version()
{
    last_command="we_version"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()


    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_we_root_command()
{
    last_command="we"

    command_aliases=()

    commands=()
    commands+=("autocompletion")
    commands+=("busy")
    commands+=("ci")
    commands+=("clone")
    commands+=("config")
    commands+=("fork")
    commands+=("idle")
    commands+=("issue")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("i")
        aliashash["i"]="issue"
        command_aliases+=("iss")
        aliashash["iss"]="issue"
        command_aliases+=("issues")
        aliashash["issues"]="issue"
    fi
    commands+=("label")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("l")
        aliashash["l"]="label"
        command_aliases+=("lab")
        aliashash["lab"]="label"
        command_aliases+=("labels")
        aliashash["labels"]="label"
        command_aliases+=("labs")
        aliashash["labs"]="label"
    fi
    commands+=("mr")
    commands+=("pm")
    commands+=("project")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("repo")
        aliashash["repo"]="project"
    fi
    commands+=("snippet")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("snip")
        aliashash["snip"]="snippet"
    fi
    commands+=("update")
    commands+=("user")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("u")
        aliashash["u"]="user"
        command_aliases+=("us")
        aliashash["us"]="user"
        command_aliases+=("users")
        aliashash["users"]="user"
        command_aliases+=("usrs")
        aliashash["usrs"]="user"
    fi
    commands+=("version")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--version")
    local_nonpersistent_flags+=("--version")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

__start_we()
{
    local cur prev words cword
    declare -A flaghash 2>/dev/null || :
    declare -A aliashash 2>/dev/null || :
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        __we_init_completion -n "=" || return
    fi

    local c=0
    local flags=()
    local two_word_flags=()
    local local_nonpersistent_flags=()
    local flags_with_completion=()
    local flags_completion=()
    local commands=("we")
    local must_have_one_flag=()
    local must_have_one_noun=()
    local last_command
    local nouns=()

    __we_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_we we
else
    complete -o default -o nospace -F __start_we we
fi

# ex: ts=4 sw=4 et filetype=sh
