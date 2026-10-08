[English](ssh-chave.md) | **Português (BR)**

# SSH só com chave (sem senha)

Objetivo: entrar no servidor com uma chave criptográfica em vez de senha e depois desativar o login por senha. Isso elimina ataques de força bruta contra a senha.

> ⚠️ Faça tudo com **uma sessão SSH já aberta** e só feche essa sessão depois de testar o login com chave em **outra** janela. Se algo der errado, a sessão aberta (ou o teclado do próprio notebook) serve para desfazer.

## 1. No PC com Windows (PowerShell): criar a chave

```powershell
ssh-keygen -t ed25519 -C "pc-leonardo"
```

Aperte Enter para aceitar o caminho padrão (`C:\Users\SEU_USUARIO\.ssh\id_ed25519`). Uma senha para a chave (*passphrase*) é recomendada.

## 2. Copiar a chave pública para o servidor

O Windows não tem `ssh-copy-id`, então:

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh leonardo@IP_DO_TAILSCALE "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

## 3. Testar (numa janela NOVA)

```powershell
ssh leonardo@IP_DO_TAILSCALE
```

Se entrar **sem pedir a senha do usuário** (só a passphrase da chave, se você criou uma), funcionou.

## 3.1 Antes de desativar a senha: o celular

O Solid Explorer (SFTP) também entra pelo SSH. Se ele estiver configurado com senha, vai parar de conectar no passo 4. Gere uma chave para o celular (ou importe uma chave privada no app), adicione a chave pública dele no `~/.ssh/authorized_keys` do servidor e teste a conexão SFTP com chave **antes** de seguir.

## 4. No servidor: desativar login por senha

```bash
sudo tee /etc/ssh/sshd_config.d/10-sem-senha.conf > /dev/null <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
EOF
sudo sshd -t && sudo systemctl reload ssh
```

`sshd -t` testa a configuração antes de recarregar. Se der erro, nada muda.

## 5. Confirmar

Numa janela nova, teste de novo o login com chave. Para ver que a senha foi recusada:

```powershell
ssh -o PubkeyAuthentication=no leonardo@IP_DO_TAILSCALE
```

Deve responder `Permission denied (publickey)`.

## Como desfazer

```bash
sudo rm /etc/ssh/sshd_config.d/10-sem-senha.conf && sudo systemctl reload ssh
```
