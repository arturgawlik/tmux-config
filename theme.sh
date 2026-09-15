#!/usr/bin/env bash
# Applies catppuccin to tmux and the session picker for one flavour:
#   theme.sh latte|mocha
# Run at the end of tmux.conf and by its client-light-theme / client-dark-theme
# hooks.
#
# Colours keep WCAG contrast in both flavours (text 4.5:1, icons and borders
# 3:1). Mocha's defaults already pass; several of Latte's light accents do not
# on its light background, so a few elements use darker catppuccin colours.
set -euo pipefail

flavor=${1:?usage: theme.sh latte|mocha}
case $flavor in latte | mocha) ;; *) echo "theme.sh: unknown flavour $flavor" >&2; exit 1 ;; esac

ctp="$HOME/.config/tmux/plugins/tmux"
sessionx="$HOME/.config/tmux/plugins/tmux-sessionx/sessionx.tmux"

# Two quick theme switches must not interleave.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/tmux-theme.lock"
flock 9

# The terminal can report the same theme more than once. tmux.conf clears this
# marker on reload, because reloading re-runs catppuccin with its defaults.
[ "$(tmux show-options -gqv @theme-applied)" = "$flavor" ] && exit 0

# Steps 1-4 go to tmux as one batch: it runs them in order without redrawing
# in between, so the bar never shows a half-cleared theme.
{
	# 1. Forget the previous flavour. catppuccin stores most colours already
	#    expanded and only sets options that are still empty, so clear them.
	#    tmux still redraws while it reads catppuccin's files in step 3, so keep
	#    what the bar shows until then: the status modules (catppuccin always
	#    rebuilds them) and their texts, which contain no colours.
	modules=$(for f in "$ctp"/status/*.conf; do basename "$f" .conf; done | paste -sd'|')
	tmux show-options -g | awk -v m="$modules" '
		$1 ~ /^@(_ctp_|catppuccin_)/ &&
		$1 !~ ("^@catppuccin_status_(" m ")$") &&
		$1 !~ ("^@catppuccin_(" m ")_text$") { print "set -gu " $1 }'
	#    The palette is replaced here rather than cleared, so it is never empty.
	sed -n 's/^set -ogq \(@thm_[a-z0-9_]* \)/set -gq \1/p' "$ctp/themes/catppuccin_${flavor}_tmux.conf"

	# 2. Options catppuccin reads while loading.
	cat <<EOF
set -g @catppuccin_flavor "$flavor"

# tab name as set with rename-window (the default #T shows the pane title, ~)
set -g @catppuccin_window_text " #W"
set -g @catppuccin_window_current_text " #W"
# inactive tab: name on the bar, number on subtext_0
set -g @catppuccin_window_text_color "#{@thm_mantle}"
set -g @catppuccin_window_number_color "#{@thm_subtext_0}"
set -g @catppuccin_window_number "#[fg=#{@thm_bg}]#I"
# current tab: name on surface_0, number keeps catppuccin's mauve
set -g @catppuccin_window_current_text_color "#{@thm_surface_0}"
set -g @catppuccin_window_current_number "#[fg=#{@thm_bg}]#I"

# status module icons (session turns red while the prefix is pressed)
set -g @catppuccin_session_color "#{?client_prefix,#{E:@thm_red},#{E:@thm_teal}}"
set -g @catppuccin_status_session_icon_fg "#{@thm_bg}"
set -g @catppuccin_date_time_color "#{@thm_blue}"
set -g @catppuccin_status_date_time_icon_fg "#{@thm_bg}"

# pane borders and right-click menu
set -g @catppuccin_pane_border_style "fg=#{@thm_overlay_2}"
set -g @catppuccin_pane_active_border_style "##{?pane_in_mode,fg=#{@thm_blue},##{?pane_synchronized,fg=#{@thm_mauve},fg=#{@thm_blue}}}"
set -g @catppuccin_menu_selected_style "fg=#{@thm_fg},bold,bg=#{@thm_surface_0}"
EOF

	# 3. Load catppuccin (the same two files its catppuccin.tmux sources).
	echo "source-file \"$ctp/catppuccin_options_tmux.conf\""
	echo "source-file \"$ctp/catppuccin_tmux.conf\""

	# 4. Styles catppuccin sets directly, or tmux leaves on ANSI colours.
	cat <<'EOF'
# prompts: rename-window, command line, messages (fill clears the bar behind
# the prompt; without it the tab list stays visible around what you type)
set -gF message-style "fg=#{@thm_fg},bg=#{@thm_surface_0},fill=#{@thm_surface_0}"
set -gF message-command-style "fg=#{@thm_fg},bg=#{@thm_surface_0},fill=#{@thm_surface_0}"
# tabs with activity or a bell
set -gF window-status-activity-style "fg=#{@thm_bg},bg=#{@thm_mauve}"
set -gF window-status-bell-style "fg=#{@thm_bg},bg=#{@thm_red}"
# copy-mode search matches and mark
set -gF copy-mode-match-style "fg=#{@thm_bg},bg=#{@thm_mauve}"
set -gF copy-mode-current-match-style "fg=#{@thm_bg},bg=#{@thm_red}"
set -gF copy-mode-mark-style "fg=#{@thm_bg},bg=#{@thm_red}"
# pane numbers (prefix q)
set -gF display-panes-colour "#{@thm_overlay_2}"
set -gF display-panes-active-colour "#{@thm_blue}"
EOF
} | tmux source-file -

# 5. Session picker: catppuccin's official fzf colours. Latte swaps the ones
#    below contrast (pointer, spinner, marker, border, selected line, match on
#    the current line) for darker catppuccin colours.
case $flavor in
latte) fzf_colors="--color=bg+:#CCD0DA,bg:#EFF1F5,spinner:#8839EF,hl:#D20F39,fg:#4C4F69,header:#D20F39,info:#8839EF,pointer:#D20F39,marker:#1E66F5,fg+:#4C4F69,prompt:#8839EF,hl+:#4C4F69:bold:underline,selected-bg:#CCD0DA,border:#7C7F93,label:#4C4F69" ;;
mocha) fzf_colors="--color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8,fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC,marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8,selected-bg:#45475A,border:#6C7086,label:#CDD6F4" ;;
esac
tmux set-option -g @sessionx-additional-options "$fzf_colors"
# sessionx builds its fzf options when it loads, so load it again.
bash "$sessionx"

tmux set-option -g @theme-applied "$flavor"
