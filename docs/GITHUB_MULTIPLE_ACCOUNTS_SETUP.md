# How to Manage Multiple GitHub Accounts (Work vs Personal)

The best way to handle multiple GitHub accounts (e.g., `abhijeet-voiceboard` and `abhijeet-roy75`) on the same machine is using **SSH Config with Aliases**.

## Step 1: Check for Existing Keys

Open Terminal and check your SSH keys:
```bash
ls -la ~/.ssh/
```
You likely have:
- `id_ed25519` (Default/Work key for voiceboard)
- `id_ed25519_repo2` (Maybe your personal key?)

**If you don't have a specific key for abhijeet-roy75, generate one:**

```bash
ssh-keygen -t ed25519 -C "aroy75@gmail.com" -f ~/.ssh/id_ed25519_roy75
```
*(Press Enter for no passphrase)*

## Step 2: Configure SSH Aliases

Create or edit your SSH config file:
```bash
nano ~/.ssh/config
```

Add the following configuration:

```ssh
# Work Account (Default)
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519

# Personal Account (abhijeet-roy75)
Host github-personal
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_roy75
```
*(Replace `id_ed25519_roy75` with `id_ed25519_repo2` if that's the key using for personal)*

Save and exit (Ctrl+O, Enter, Ctrl+X).

## Step 3: Add Key to GitHub

1. **Copy the public key**:
   ```bash
   cat ~/.ssh/id_ed25519_roy75.pub | pbcopy
   ```
2. Go to **GitHub.com** > **Settings** > **SSH and GPG keys**.
3. Click **New SSH key**.
4. Title: "MacBook Pro Personal".
5. Paste the key and save.

## Step 4: Use the Alias in Your Repo

Now, simply update the git remote for your personal project to use `github-personal` instead of `github.com`.

**For JEEVibe:**
```bash
cd /Users/abhijeetroy/Documents/JEEVibe
git remote set-url origin git@github-personal:abhijeet-roy75/JEEVibe.git
```

## Step 5: Push!

Now you can push seamlessly without password prompts:
```bash
git push origin main
```

---

**Summary:**
- Clone work repos normally: `git clone git@github.com:work/repo.git`
- Clone personal repos with alias: `git clone git@github-personal:personal/repo.git`
