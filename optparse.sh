# Optparse - a BASH wrapper for getopts
# https://github.com/nk412/optparse

# Copyright (c) 2015 Nagarjuna Kumarappan
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# Author: Nagarjuna Kumarappan <nagarjuna.412@gmail.com>
# Improvements: Alessio Biancone <alebian1996@gmail.com>

optparse_usage=""
optparse_contractions=""
optparse_defaults=""
optparse_process=""
optparse_arguments_string="h"
optparse_longarguments_string="help"
optparse_name="$(basename $0)"
optparse_usage_header="[OPTIONS]"
optparse_variable_set=''
optparse_description="${optparse_name}'s help#NL"

# -----------------------------------------------------------------------------------------------------------------------------
function optparse.throw_error(){
    local message="$1"
    echo "OPTPARSE ERROR: $message"
    exit 1
}

# -----------------------------------------------------------------------------------------------------------------------------
function optparse.define(){
    local short=""
    local shortname=""
    local long=""
    local longname=""
    local desc=""
    local default=""
    local behaviour="default"
    local list=""
    local variable=""
    local val="\$2"
    local has_default="false"

    for option in "$@"; do
        local key="${option%%=*}";
        local value="${option#*=}";

        case "$key" in
            "short")
                [ ${#value} -ne 1 ] &&
                    optparse.throw_error "short name expected to be one character long"
                shortname="$value"
                short="-$value"
            ;;
            "long")
                [ -z ${value} ] &&
                    optparse.throw_error "long name expected to be atleast one character long"
                longname="$value"
                long="--$value"
            ;;
            "desc")
                desc="$value"
            ;;
            "default")
                default="$value"
                has_default="true"
            ;;
            "behaviour")
                case $value in
                    default|list|flag)
                        behaviour="$value"
                    ;;
                    *)
                        optparse.throw_error "behaviour [$value] not supported"
                    ;;
                esac
                ;;
            "list")
                list="$value"
            ;;
            "variable")
                variable="$value"
            ;;
            "value")
                val="$value"
            ;;
        esac
    done

    flag=$([[ $behaviour == "flag" ]] && echo "true" || echo "false")
    is_list=$([[ $behaviour == "list" ]] && echo "true" || echo "false")

    $flag && {
        [ -z $default ] && default=false
        has_default=true
        [ $default = "true" ] && val="false"
        [ $default = "false" ] && val="true"
    }

    # check list behaviour
    $is_list && {
        [[ -z ${list:-} ]] &&
            optparse.throw_error "list is mandatory when using list behaviour"

        $has_default && {
            valid=false
            for i in $list; do
                [[ $default == $i ]] && valid=true
            done

            $valid || optparse.throw_error "default should be in list"
        }
    }

    [ -z "$desc" ] && optparse.throw_error "description is mandatory"

    [ -z "$variable" ] && optparse.throw_error "you must give a variable for option: ($longname)"

    # build OPTIONS and help
    optparse_usage+="#TB${short:=  }$([ ! -z $short ] && echo "," || echo " ") $(printf "%-15s %s" "${long}:" "${desc}")"

    $is_list && {
        optparse_usage+=" [one of: $list]"
    }

    $flag && {
        optparse_usage+=" [flag]"
    } || {
        ${has_default} &&
            optparse_usage+=" [default: $default]"
    }
    optparse_usage+="#NL"

    optparse_contractions+="#NL#TB#TB${long})#NL#TB#TB#TBparams=\"\$params ${short}\";;"
    $has_default &&
        optparse_defaults+="#NL${variable}='${default}'"

    optparse_arguments_string+="${shortname}"
    optparse_longarguments_string+=",${longname}"
    [ "$val" = "\$2" ] && {
        [ -z ${shortname:-} ] ||
            optparse_arguments_string+=":"
        optparse_longarguments_string+=":"
    }

    optparse_process+="
        -${shortname}|--${longname})
            ${variable}=\"$val\"
            $flag ||
                shift
            $is_list && {
                valid=false
                for i in $list; do
                    [[ \$${variable} == \$i ]] && valid=true
                done

                \$valid || {
                    echo 'ERROR: (--${longname}) value not in list'
                    usage
                    exit 1
                }
            }
        ;;"
    optparse_variable_set+="
        [[ -z \${${variable}:-$($has_default && echo 'DEF' || echo '')} ]] && {
            echo 'ERROR: (--${longname}) not set'
            usage
            exit 1
        } || true"
}

# -----------------------------------------------------------------------------------------------------------------------------
function optparse.build(){
    local build_file="/tmp/optparse-$$.tmp"

    # Building getopts header here

    # Function usage
    cat << EOF | sed -e 's/#NL/\n/g' -e 's/#TB/\t/g'
function usage(){
cat >&2 << XXX
${optparse_description}
usage: $optparse_name $optparse_usage_header
OPTIONS:
$optparse_usage
#TB-h, $(printf "%-15s %s" "--help:" "help")

XXX
exit 3
}

PARSED=\$(getopt --options="$optparse_arguments_string" --longoptions="$optparse_longarguments_string" -- "\$@")
[[ \$? != 0 ]] && usage
eval set -- "\$PARSED"

# Set default variable values
$optparse_defaults

# Process using getopts
while true; do
        case \$1 in
                # Substitute actions for different variables
                $optparse_process
                --)
                        shift
                        break;;
                --help|-h|*)
                        usage
                        exit 1;;
        esac
        shift
done

$optparse_variable_set

EOF

    # Unset global variables
    unset optparse_usage
    unset optparse_process
    unset optparse_arguments_string
    unset optparse_defaults
    unset optparse_contractions
    unset optparse_name
    unset optparse_longarguments_string
    unset optparse_name
    unset optparse_usage_header
    unset optparse_variable_set
}
