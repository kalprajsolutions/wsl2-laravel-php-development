# WSL2 Laravel‑PHP Development Toolkit

Spin up a complete Nginx + Redis + multi‑version PHP stack on **WSL2 Ubuntu 22.04** with just a handful of commands.

---

## Prerequisites

| What | Why |
|------|-----|
| **Windows 10/11 + WSL 2** | Follow Microsoft’s [WSL 2 guide](https://learn.microsoft.com/windows/wsl/install) if you haven’t. |
| **Ubuntu 22.04** inside WSL 2 | Other distros work, but the commands below assume Deb/Ubuntu paths. |
| **_Optional but recommended_ – systemd enabled in WSL** | Lets `systemctl` manage Nginx, Redis, PHP‑FPM, etc. |

### Enable systemd (once)

1. Edit `/etc/wsl.conf` in the _WSL_ terminal:

```ini
# /etc/wsl.conf
[boot]
systemd=true
```

## 2 Install Nginx
```bash 
sudo apt update
sudo apt install -y nginx
sudo systemctl enable --now nginx   # starts it and autostarts at boot
```
### Install Redis (server + CLI)
```bash 
sudo apt install -y redis-server
sudo systemctl enable --now redis-server
```

Test Redis is accepting commands:

```bash
redis-cli ping   # → PONG
```
> **Firewall note (Windows):**
> WSL2 listens only on the VM’s virtual NIC. If you need external access (e.g., from the host to Redis), create a Windows firewall rule or use `wsl --ip` forwarding.

---

## 3  Install the PHP Helper Toolkit

The toolkit gives you two commands:

* `phpinstall <version>` – installs PHP x.y with a full extension set
* `phpswitch <version>`  – flips CLI + FPM + Nginx socket to that version

Run the one‑liner (no `sudo`—the script uses it internally where needed):

```bash
curl -fsSL https://raw.githubusercontent.com/kalprajsolutions/wsl2-laravel-php-development/main/install.sh | bash
# – or –
wget -qO- https://raw.githubusercontent.com/kalprajsolutions/wsl2-laravel-php-development/main/install.sh | bash
```

> **What it does**
>
> * Downloads `functions.sh` to `~/.local/lib/wsl2-php-toolkit/`
> * Appends `source ~/.local/lib/wsl2-php-toolkit/functions.sh` to your `~/.bashrc`
> * You’ll have the commands in every new shell.

Reload the shell once:

```bash
source ~/.bashrc   # or open a new tab
```

---

## 4  Example workflow

```bash
# Install PHP 8.3 + common extensions + FPM
phpinstall 8.3

# Install PHP 8.1 side‑by‑side
phpinstall 8.1

# Switch Nginx + CLI to PHP 8.1 (creates /run/php/php-fpm.sock link)
phpswitch 8.1
```

Verify:

```bash
php -v
curl -s http://localhost | grep "PHP Version"
```
