{ config, pkgs, ... }:

let
	dotfiles = "${config.home.homeDirectory}/nixos/config";
	create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;
	configs = {
		nvim = "nvim";
		kitty = "kitty";
		rofi = "rofi";
	};
in

{
	home.username = "user";
	home.homeDirectory = "/home/user";
	programs.git.enable = true;
	home.stateVersion = "26.05";
	programs.bash = {
		enable = true;
		initExtra = ''
			export PS1="\[\e[38;5;75m\]\u@\h \[\e[38;5;113m\]\w \[\e[38;5;189m\]\$ \[\e[0m\]"
		'';
	};

	xdg.configFile = builtins.mapAttrs (name: subpath: {
		source = create_symlink "${dotfiles}/${subpath}";
		recursive = true;
	}) configs;

	home.packages = with pkgs; [
		neovim
		kitty
		ripgrep
		rofi
		nodejs
		firefox
		# opencode
		lazygit
	];
}
