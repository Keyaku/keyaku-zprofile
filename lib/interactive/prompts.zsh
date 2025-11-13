### Dialog prompts

# Get the first installed dialog prompt from list
function get-prompt {
	local PROMPT_TYPES=(kdialog dialog)
	local ptype

	for ptype in ${PROMPT_TYPES[@]}; do
		command -v $ptype &>/dev/null && {
			echo "$ptype"
			return 0
		}
	done

	return 1
}

function prompt-user {
	check_argc 1 1 $#
	local message="$1"

	case $(get-prompt) in
	kdialog ) kdialog --msgbox "$message" &>/dev/null
	;;
	dialog ) dialog --msgbox "$message" 10 60
	;;
	zenity ) zenity --info --text="$message" &>/dev/null
	;;
	esac
}

function prompt-radio {
	check_argc 1 0 $#
	local title="$1"
	shift
	local arglist_off=() arglist=()

	local idx=1 opt
	for opt in $@; do
		arglist+=($idx "$opt")
		((idx++))
	done

	case $(get-prompt) in
	kdialog ) kdialog --radiolist "$title" $(printf '%d %s off ' ${arglist[@]})
	;;
	dialog ) dialog --radiolist "$title" 0 0 0 $(printf '%d %s off ' ${arglist[@]})
	;;
	zenity )
		zenity --title="title" --list --radiolist --column="" --column="Option" \
			${arglist[@]}
	;;
	esac
}

function prompt-yesno {
	check_argc 1 1 $#
	local message="$1"

	case $(get-prompt) in
	kdialog ) kdialog --yesno "$message" &>/dev/null
	;;
	dialog ) dialog --yesno "$message" 10 60
	;;
	zenity ) zenity --question --text="$message" &>/dev/null
	;;
	esac
}

function prompt-dir {
	check_argc 1 2 $#
	local title="$1"
	local startdir="${2:-$HOME}"

	case $(get-prompt) in
	kdialog ) cd ${startdir}
		echo $(kdialog --getexistingdirectory)
		cd - &>/dev/null
	;;
	dialog ) echo $(dialog --dselect "${startdir}" 10 60 --stdout)
	;;
	zenity ) echo $(zenity --file-selection --directory)
	;;
	esac
}
