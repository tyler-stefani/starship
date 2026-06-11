status is-interactive
or exit 0

# set temp file and signal for async prompts
if test -n "$XDG_RUNTIME_DIR"
    set -g starship_temp_dir "$XDG_RUNTIME_DIR"/fish-async-prompt
else
    set -g starship_temp_dir /tmp/fish-async-prompt
end
mkdir -p "$starship_temp_dir"
set -g starship_temp_file "$starship_temp_dir"/"$fish_pid"_last_prompt
set -g starship_async_signal SIGUSR1

# clean up stale temp files which weren't removed in remove_temp_prompt_on_exit
for f in "$starship_temp_dir"/*_last_prompt
    if test -f "$f"
        set -l pid (string match -rg '(\d+)_last_prompt' "$f")
        if not kill -0 $pid 2>/dev/null
            rm -f "$f"
        end
    end
end

function fish_prompt
    if test "$TRANSIENT" = 1 -o ! -e "$starship_temp_file"
        starship_transient_prompt_func
    else
        cat "$starship_temp_file"
    end
end

function starship_transient_prompt_func
    # Clear from cursor to end of screen as `commandline -f repaint` does not do this
    # See https://github.com/fish-shell/fish-shell/issues/8418
    printf \e[0J
    starship module character
end

function fish_right_prompt
    set STARSHIP_CMD_PIPESTATUS $pipestatus
    set STARSHIP_CMD_STATUS $STARSHIP_CMD_PIPESTATUS[-1]

    switch "$fish_key_bindings"
        case fish_hybrid_key_bindings fish_vi_key_bindings
            set STARSHIP_KEYMAP "$fish_bind_mode"
        case '*'
            set STARSHIP_KEYMAP insert
    end
    # Account for changes in variable name between v2.7 and v3.0
    set STARSHIP_DURATION "$CMD_DURATION$cmd_duration"
    set STARSHIP_JOBS (count (jobs -p))
    if test "$TRANSIENT" = 1
        type -q starship_transient_rprompt_func
        and starship_transient_rprompt_func
    else
        starship prompt --right --terminal-width="$COLUMNS" --status=$STARSHIP_CMD_STATUS --pipestatus="$STARSHIP_CMD_PIPESTATUS" --keymap=$STARSHIP_KEYMAP --cmd-duration=$STARSHIP_DURATION --jobs=$STARSHIP_JOBS
    end
end

# Disable virtualenv prompt, it breaks starship
set -g VIRTUAL_ENV_DISABLE_PROMPT 1

# Remove default mode prompt
builtin functions -e fish_mode_prompt

set -gx STARSHIP_SHELL fish

# Transience related functions
function reset-transient --on-event fish_postexec
    set -g TRANSIENT 0
end

function transient_execute
    if commandline --is-valid
        set -g TRANSIENT 1
        commandline -f repaint
    else
        set -g TRANSIENT 0
    end
    commandline -f execute
end

function transient_cancel
    if string length -q -- (commandline)
        set -g TRANSIENT 1
        commandline -f repaint
    end
    commandline -f cancel-commandline
end

# --user is the default, but listed anyway to make it explicit.
function enable_transience --description 'enable transient prompt keybindings'
    bind --user \r transient_execute
    bind --user -M insert \r transient_execute
    bind --user \cc transient_cancel
end

# Erase the transient prompt related key bindings.
# --user is the default, but listed anyway to make it explicit.
# Erasing a user binding will revert to the preset.
function disable_transience --description 'remove transient prompt keybindings'
    bind --user -e \r
    bind --user -M insert -e \r
    bind --user -e \cc
end

# Set up the session key that will be used to store logs
# We don't use `random [min] [max]` because it is unavailable in older versions of fish shell
set -gx STARSHIP_SESSION_KEY (string sub -s1 -l16 (random)(random)(random)(random)(random)0000000000000000)

# async related functions
function write_prompt_to_temp --on-event fish_prompt
    set STARSHIP_CMD_PIPESTATUS (string join ' ' $pipestatus)
    set STARSHIP_CMD_STATUS $pipestatus[-1]

    switch "$fish_key_bindings"
        case fish_hybrid_key_bindings fish_vi_key_bindings
            set STARSHIP_KEYMAP "$fish_bind_mode"
        case '*'
            set STARSHIP_KEYMAP insert
    end
    # Account for changes in variable name between v2.7 and v3.0
    set STARSHIP_DURATION "$CMD_DURATION$cmd_duration"
    set STARSHIP_JOBS (count (jobs -p))

    fish -c "starship prompt \
    --terminal-width=$COLUMNS \
    --status=$STARSHIP_CMD_STATUS \
    --pipestatus='$STARSHIP_CMD_PIPESTATUS' \
    --keymap=$STARSHIP_KEYMAP \
    --cmd-duration=$STARSHIP_DURATION \
    --jobs=$STARSHIP_JOBS \
    > '$starship_temp_file' \
    && kill -s $starship_async_signal $fish_pid" &
    disown
end

function repaint_prompt_on_signal --on-signal "$starship_async_signal"
    commandline -f repaint
end

function remove_temp_prompt_on_exit --on-event fish_exit
    rm -f $starship_temp_file
end
