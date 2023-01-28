# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "debian/bullseye64"
  config.ssh.forward_agent = true
  config.ssh.forward_x11 = true
  # config.vm.network "forwarded_port", guest: 80, host: 8080
  # config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"
  # config.vm.network "private_network", ip: "192.168.33.10"
  # config.vm.network "public_network"
  # config.vm.synced_folder "../data", "/vagrant_data"
  config.vm.provider "virtualbox" do |vb|
    vb.gui = false
    vb.memory = "1024"
    vb.customize ["modifyvm", :id, "--audio", "pulse", "--audiocontroller", "hda", "--audioout", "on"]
  end
  config.vm.provision "shell", inline: <<-SHELL
    apt update
    apt install -y xauth pulseaudio
  SHELL
end
