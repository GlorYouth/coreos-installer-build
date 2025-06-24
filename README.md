### VPS重装至CoreOS示例

``` bash
curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh || wget -O reinstall.sh $_
bash reinstall.sh alpine --hold=1 --password 123456@
sudo reboot

wget -O coreos-installer https://github.com/GlorYouth/coreos-installer-build/releases/latest/download/coreos-installer-x86_64 && chmod +x coreos-installer
apk update && apk add udev gpg gpg-agent lsblk && rc-update add udev sysinit && rc-service udev start
./coreos-installer install /dev/vda  --stream stable --ignition-file ./myconfig.ign --console tty0 --console ttyS0,115200n8
reboot
```
