{ config, lib, pkgs, ... }:

{
	imports = [ /etc/nixos/hardware-configuration.nix ];

	nixpkgs.config.allowUnfree = true;

	boot.loader.systemd-boot.enable = true;
	boot.loader.efi.canTouchEfiVariables = true;

	networking.hostName = "nix";
	networking.networkmanager.enable = true;

	time.timeZone = "Asia/Kolkata";
	i18n.defaultLocale = "en_IN";

	users.users."user" = {
		isNormalUser = true;
		description = "user";
		extraGroups = [ "networkmanager" "wheel" ];
		packages = with pkgs; [];
	};

	services.xserver.xkb = {
		layout = "us";
	};

	services.libinput = {
		enable = true;
		mouse.naturalScrolling = true;
		touchpad = {
			naturalScrolling = true;
			tapping = true;
		};
	};

	services.xserver = {
		enable = true;
		autoRepeatDelay = 200;
		autoRepeatInterval = 35;
	};

	services.getty.autologinUser = "user";

	environment.systemPackages = with pkgs; [ wget git tmux fzf fastfetch xinit ];

	fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

	nix.settings.experimental-features = [ "nix-command" "flakes" ];
	system.stateVersion = "26.05";
}
