**English** | [Português (BR)](ssh-chave.pt-BR.md)

# SSH with a key only (no password)

Goal: log in to the server with a cryptographic key instead of a password, then disable password login. This eliminates brute-force attacks against the password.

> ⚠️ Do everything with **an SSH session already open**, and only close that session after testing the key login in **another** window. If something goes wrong, the open session (or the laptop's own keyboard) lets you undo it.

## 1. On the Windows PC (PowerShell): create the key

```powershell
ssh-keygen -t ed25519 -C "pc-leonardo"
```

Press Enter to accept the default path (`C:\Users\YOUR_USER\.ssh\id_ed25519`). A passphrase for the key is recommended.

## 2. Copy the public key to the server

Windows has no `ssh-copy-id`, so:

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh leonardo@TAILSCALE_IP "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

## 3. Test (in a NEW window)

```powershell
ssh leonardo@TAILSCALE_IP
```

If you get in **without being asked for the user password** (only the key passphrase, if you set one), it worked.

## 3.1 Before disabling the password: your phone

Solid Explorer (SFTP) also connects over SSH. If it is set up with a password, it will stop connecting at step 4. Generate a key for the phone (or import a private key in the app), add its public key to the server's `~/.ssh/authorized_keys`, and test the SFTP connection with the key **before** moving on.

## 4. On the server: disable password login

```bash
sudo tee /etc/ssh/sshd_config.d/10-no-password.conf > /dev/null <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
EOF
sudo sshd -t && sudo systemctl reload ssh
```

`sshd -t` tests the configuration before reloading. If it reports an error, nothing changes.

## 5. Confirm

In a new window, test the key login again. To see that the password is refused:

```powershell
ssh -o PubkeyAuthentication=no leonardo@TAILSCALE_IP
```

It should answer `Permission denied (publickey)`.

## How to undo

```bash
sudo rm /etc/ssh/sshd_config.d/10-no-password.conf && sudo systemctl reload ssh
```
