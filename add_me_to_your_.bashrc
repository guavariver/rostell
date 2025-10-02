# simply add this to your ~/.bashrc file to be able to use my rostell function
# guavariver - my custom functions to figure out utilized topics by packages, on the fly, without having to run their nodes:
_ros_find_source_path() {
    local workspace_src_path=$(echo $ROS_PACKAGE_PATH | cut -d':' -f1)
    local local_pkg_path="$workspace_src_path/$1"
    if [ -d "$local_pkg_path" ]; then
        echo "$local_pkg_path"
    else
        rospack find "$1" 2>/dev/null
    fi
}

# A helper function to extract and clean topic names from grep output.
_ros_extract_topics() {
    # This uses a robust grep command to find and print only the contents of quoted strings.
    grep -oP '(?<=["'\''])[^"'\''"]+' | grep -E '^/|^\w'
}

# Finds Python publishers (rospy.Publisher)
ros_find_py_pubs() {
    if [ -z "$1" ]; then return 1; fi
    local pkg_path=$(_ros_find_source_path "$1")
    if [ ! -d "$pkg_path" ]; then return; fi
    local results=$(grep --include=\*.py -r "rospy.Publisher" "$pkg_path" 2>/dev/null)
    if [ -z "$results" ]; then echo "  (none found)"; return; fi
    if [ "$2" == "-v" ]; then echo "$results"; else echo "$results" | _ros_extract_topics | sort -u; fi
}

# Finds C++ publishers (advertise<)
ros_find_cpp_pubs() {
    if [ -z "$1" ]; then return 1; fi
    local pkg_path=$(_ros_find_source_path "$1")
    if [ ! -d "$pkg_path" ]; then return; fi
    local results=$(grep --include=\*.{cpp,h,hpp} -r "advertise<" "$pkg_path" 2>/dev/null)
    if [ -z "$results" ]; then echo "  (none found)"; return; fi
    if [ "$2" == "-v" ]; then echo "$results"; else echo "$results" | _ros_extract_topics | sort -u; fi
}

# Finds Python subscribers (rospy.Subscriber)
ros_find_py_subs() {
    if [ -z "$1" ]; then return 1; fi
    local pkg_path=$(_ros_find_source_path "$1")
    if [ ! -d "$pkg_path" ]; then return; fi
    local results=$(grep --include=\*.py -r "rospy.Subscriber" "$pkg_path" 2>/dev/null)
    if [ -z "$results" ]; then echo "  (none found)"; return; fi
    if [ "$2" == "-v" ]; then echo "$results"; else echo "$results" | _ros_extract_topics | sort -u; fi
}

# Finds C++ subscribers (.subscribe() call)
ros_find_cpp_subs() {
    if [ -z "$1" ]; then return 1; fi
    local pkg_path=$(_ros_find_source_path "$1")
    if [ ! -d "$pkg_path" ]; then return; fi
    local results=$(grep --include=\*.{cpp,h,hpp} -r ".subscribe(" "$pkg_path" 2>/dev/null)
    if [ -z "$results" ]; then echo "  (none found)"; return; fi
    if [ "$2" == "-v" ]; then echo "$results"; else echo "$results" | _ros_extract_topics | sort -u; fi
}

# A master function that runs all of the above searches.
rostell() {
    # Help Text Handling
    case "$1" in
        '?'|'-?'|'--?'|'help'|'-h'|'-help'|'--h'|'--help')
            echo -e "rostell: A tool to inspect ROS package source code for topics.\n"
            echo -e "USAGE:"
            echo -e "  rostell [options] <package_name>\n"
            echo -e "DESCRIPTION:"
            echo -e "  By default, prints a unique, grouped list of published and subscribed topics found in the package's source code.\n"
            echo -e "OPTIONS:"
            echo -e "  -v, --verbose\t  Display verbose output, showing the full line of code where each topic is defined.\n"
            echo -e "  -h, --help\t  Display this help message."
            return 0
            ;;
    esac

    local verbose_flag=""
    local pkg_name=""
    if [ "$1" == "-v" ] || [ "$1" == "--verbose" ]; then verbose_flag="-v"; pkg_name="$2"; else pkg_name="$1"; fi
    if [ -z "$pkg_name" ]; then echo "Usage: rostell [-v] <package_name>"; echo "Use 'rostell --help' for more info."; return 1; fi
    
    # Grouped output for non-verbose mode
    if [ -z "$verbose_flag" ]; then
        echo "========================================="
        echo "Inspecting package: $pkg_name"
        echo "========================================="
        echo -e "\n--- C++ Published Topics ---"
        ros_find_cpp_pubs "$pkg_name"
        echo -e "\n--- Python Published Topics ---"
        ros_find_py_pubs "$pkg_name"
        echo -e "\n--- C++ Subscribed Topics ---"
        ros_find_cpp_subs "$pkg_name"
        echo -e "\n--- Python Subscribed Topics ---"
        ros_find_py_subs "$pkg_name"
        echo "========================================="
        return
    fi
    
    # Verbose mode
    echo "========================================="
    echo "Inspecting package: $pkg_name (Verbose)"
    echo "========================================="
    echo -e "\n--- Python Publishers in '$pkg_name' ---"
    ros_find_py_pubs "$pkg_name" "$verbose_flag"
    echo -e "\n--- C++ Publishers in '$pkg_name' ---"
    ros_find_cpp_pubs "$pkg_name" "$verbose_flag"
    echo -e "\n--- Python Subscribers in '$pkg_name' ---"
    ros_find_py_subs "$pkg_name" "$verbose_flag"
    echo -e "\n--- C++ Subscribers in '$pkg_name' ---"
    ros_find_cpp_subs "$pkg_name" "$verbose_flag"
    echo "========================================="
}

_rostell_complete() {
    # COMPREPLY is the special array variable that bash uses to store completion suggestions.
    # We use 'compgen' to generate a list of words to suggest.
    #   -W "$(rospack list-names)" tells compgen that the list of all possible words
    #     is the output of the 'rospack list-names' command.
    #   -- "${COMP_WORDS[COMP_CWORD]}" is the current word the user is typing.
    # compgen will filter the word list based on the current word.
    COMPREPLY=( $(compgen -W "$(rospack list-names)" -- "${COMP_WORDS[COMP_CWORD]}") )
}

# This is the command that registers my completion function.
# It tells bash: "When the user requests completion for the 'rostell' command,
# run the '_rostell_complete' function to get the suggestions."
complete -F _rostell_complete rostell
