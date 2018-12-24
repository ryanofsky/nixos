# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  nix.nixPath = [ "nixpkgs=/nix/nixpkgs" "nixos-config=/etc/nixos/configuration.nix" ];

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  networking.hostName = "vdud"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Select internationalisation properties.
  # i18n = {
  #   consoleFont = "Lat2-Terminus16";
  #   consoleKeyMap = "us";
  #   defaultLocale = "en_US.UTF-8";
  # };

  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    bindfs
    bup
    colordiff
    deluge
    emby
    encfs
    file
    git
    gptfdisk
    iotop
    openvpn
    parted
    psmisc
    python2
    python3
    rmlint
    screen
    smartmontools
    socat
    sshfs-fuse
    stun
    unzip
    vim
    zerotierone
    zip
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.bash.enableCompletion = true;
  # programs.mtr.enable = true;
  # programs.gnupg.agent = { enable = true; enableSSHSupport = true; };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.permitRootLogin = "yes";

  services.emby.enable = true;
  systemd.services.emby.after = pkgs.lib.mkForce [ "netns@pia.service" ];
  systemd.services.emby.bindsTo = pkgs.lib.mkForce [ "netns@pia.service" ];
  systemd.services.emby.wantedBy = pkgs.lib.mkForce [ ];
  systemd.services.emby.serviceConfig.PrivateNetwork = pkgs.lib.mkForce "yes";
  systemd.services.emby.serviceConfig.BindPaths = pkgs.lib.mkForce "/etc/netns/pia/resolv.conf:/etc/resolv.conf";
  systemd.services.emby.unitConfig.JoinsNamespaceOf = pkgs.lib.mkForce "netns@pia.service";

  services.deluge.enable = true;
  systemd.services.deluged.after = pkgs.lib.mkForce [ "netns@pia.service" ];
  systemd.services.deluged.bindsTo = pkgs.lib.mkForce [ "netns@pia.service" ];
  systemd.services.deluged.wantedBy = pkgs.lib.mkForce [ ];
  systemd.services.deluged.serviceConfig.PrivateNetwork = pkgs.lib.mkForce "yes";
  systemd.services.deluged.serviceConfig.BindPaths = pkgs.lib.mkForce "/etc/netns/pia/resolv.conf:/etc/resolv.conf";
  systemd.services.deluged.unitConfig.JoinsNamespaceOf = pkgs.lib.mkForce "netns@pia.service";

  services.deluge.web.enable = true;
  systemd.services.delugeweb.after = pkgs.lib.mkForce [ "netns@pia.service" ];
  systemd.services.delugeweb.bindsTo = pkgs.lib.mkForce [ "netns@pia.service" ];
  systemd.services.delugeweb.wantedBy = pkgs.lib.mkForce [ ];
  systemd.services.delugeweb.serviceConfig.PrivateNetwork = pkgs.lib.mkForce "yes";
  systemd.services.delugeweb.serviceConfig.BindPaths = pkgs.lib.mkForce "/etc/netns/pia/resolv.conf:/etc/resolv.conf";
  systemd.services.delugeweb.unitConfig.JoinsNamespaceOf = pkgs.lib.mkForce "netns@pia.service";

  services.zerotierone.enable = true;
  services.zerotierone.joinNetworks = [ "af78bf943692b694" ];

  programs.vim.defaultEditor = true;

  programs.bash.interactiveShellInit = ''
    shopt -s histappend
    export HISTCONTROL=ignoreboth
  '';

  # https://nixos.wiki/wiki/OpenVPN
  services.openvpn.servers = let
    name = "pia";
    path = (pkgs.lib.getAttr "openvpn-${name}" config.systemd.services).path;
    net = pkgs.writeScript "openvpn-${name}-net" ''
      #!/bin/sh
      export PATH=${path}

      PNS=${name}

      rx() {
        echo "$@"
        "$@"
      }

      nx() {
        echo ip netns exec "$PNS" "$@"
        ip netns exec "$PNS" "$@"
      }

      up() {
        rx ip link set dev "$dev" netns "$PNS"
        nx ip addr add dev "$dev" local "$ifconfig_local" peer "$ifconfig_remote"
        nx ip link set dev "$dev" up
        nx ip route add default via "$route_gateway_1" dev "$dev"
        mkdir -p /etc/netns/"$PNS"
        touch /etc/netns/"$PNS"/resolv.conf
        script_type=up nx ${pkgs.update-resolv-conf}/libexec/openvpn/update-resolv-conf
      }

      down() {
        script_type=down nx ${pkgs.update-resolv-conf}/libexec/openvpn/update-resolv-conf
        nx ip link set dev "$dev" netns 1
        rx ip addr add dev "$dev" local "$ifconfig_local" peer "$ifconfig_remote"
      }

      CMD="$1"
      shift
      "$CMD" "$@"
    '';
  in {
    pia = {
      config = ''
        config /etc/nixos/pia/openvpn-ip/Mexico.ovpn
        auth-user-pass /etc/nixos/pia/pia.auth
        #verb 4
        script-security 2
        route-noexec
        route-up "${net} up"
        route-pre-down "${net} down"
      '';
      autoStart = false;
    };
  };
  systemd.services."openvpn-pia".serviceConfig.Restart = pkgs.lib.mkForce "no";
  systemd.services."openvpn-pia".bindsTo = pkgs.lib.mkForce [ "netns@pia.service" ];
  systemd.services."openvpn-pia".after = pkgs.lib.mkForce [ "netns@pia.service" ];

  # https://github.com/systemd/systemd/issues/2741#issuecomment-433979748
  systemd.services."netns@" = let
    netns-add = pkgs.writeScript "netns-add" ''
      #!/bin/sh
      set -e
      set -x
      ${pkgs.iproute}/bin/ip netns add "$1"
      ${pkgs.utillinux}/bin/umount /var/run/netns/"$1"
      ${pkgs.utillinux}/bin/mount --bind /proc/self/ns/net /var/run/netns/"$1"
      ${pkgs.coreutils}/bin/mkdir -p /etc/netns/"$1"
      ${pkgs.coreutils}/bin/touch /etc/netns/"$1"/resolv.conf
    '';
    netns-del = pkgs.writeScript "netns-del" ''
      #!/bin/sh
      set -e
      set -x
      ${pkgs.iproute}/bin/ip netns del "$1"
    '';
  in {
    after = [ "network.target" ];
    description = "Named network namespace %I.";
    unitConfig.StopWhenUnneeded = true;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      PrivateNetwork = "yes";
      ExecStart = ''${netns-add} %I'';
      ExecStop = ''${netns-del} %I'';
    };
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 22 8096 8920 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable the X11 windowing system.
  # services.xserver.enable = true;
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e";

  # Enable touchpad support.
  # services.xserver.libinput.enable = true;

  # Enable the KDE Desktop Environment.
  # services.xserver.displayManager.sddm.enable = true;
  # services.xserver.desktopManager.plasma5.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.extraUsers.guest = {
  #   isNormalUser = true;
  #   uid = 1000;
  # };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "18.03"; # Did you read the comment?

}
