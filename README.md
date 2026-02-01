# omni-secrets

Secrets and encrypted vault management for **bash** using [age](https://github.com/FiloSottile/age) (encryption) and [gocryptfs](https://github.com/rfjakob/gocryptfs) (encrypted filesystems).

**Requires bash** and external tools: `jq`, `age`, `gocryptfs`, `fusermount`, `uuidgen`.

## Dependencies

- [omni-ui-kit](https://github.com/omni-ecosystem/omni-ui-kit) — color variables and UI functions
- [omni-navigator](https://github.com/omni-ecosystem/omni-navigator) — file/directory browser for key selection and vault path picking

Menu primitives (`menu_cmd`, `menu_line`, etc), input helpers (`read_with_instant_back`, `read_with_esc_cancel`), and the help screen are all self-contained in `components.sh`.

## Config

**IMPORTANT:** omni-secrets requires `--data-dir` when sourced:

```bash
source omni-secrets/index.sh --data-dir=/path/to/data
```

**Example:**
```bash
source omni-secrets/index.sh --data-dir=$HOME/.local/share/omni-secrets
```

The data directory must exist before sourcing. Config files (`.secrets.json`, `.vaults.json`) are created automatically as empty arrays on first use.

## Standalone usage

### Full interactive menu

```bash
# From bash (run `bash` first if you're in zsh)
source omni-secrets/index.sh --data-dir=$HOME/.local/share/omni-secrets

show_secrets_menu
```

One liner:

```bash
bash -ic 'source omni-secrets/index.sh --data-dir=$HOME/path/to/desired/folder && show_secrets_menu'
```

### Storage functions only

# Secrets
save_secret "my-key" "/path/to/private.key" "/path/to/public.key" "/path/to/passphrase.age"
load_secrets my_array
get_secret_by_id "some-uuid"
delete_secret 0

# Vaults
save_vault "my-vault" "/path/to/cipher" "/path/to/mount" "secret-uuid"
load_vaults my_array
get_vault_status "/path/to/mount"
delete_vault 0
update_vault_secret 0 "new-secret-uuid"
```

### Vault operations

```bash
source omni-secrets/index.sh --data-dir=$HOME/.local/share/omni-secrets

mount_vault 0       # mount vault at index 0
unmount_vault 0     # unmount vault at index 0
init_vault "/path/to/cipher" "secret-uuid"
```

## API

### Secrets storage (`storage.sh`)

| Function | Parameters | Description |
|----------|-----------|-------------|
| `get_secrets_file` | — | Returns path to `.secrets.json` |
| `save_secret` | name, private_key, public_key, encrypted_passphrase | Add a secret (auto-generates UUID) |
| `load_secrets` | array_name | Load secrets into nameref array (`id:privateKey:publicKey:encryptedPassphrase`) |
| `delete_secret` | index (0-based) | Remove a secret by index |

### Vaults storage (`vaults/storage.sh`)

| Function | Parameters | Description |
|----------|-----------|-------------|
| `get_vaults_file` | — | Returns path to `.vaults.json` |
| `save_vault` | name, cipher_dir, mount_point, secret_id | Add a vault |
| `load_vaults` | array_name | Load vaults into nameref array (`name:cipherDir:mountPoint:secretId`) |
| `delete_vault` | index (0-based) | Remove a vault by index |
| `update_vault_secret` | vault_index, new_secret_id | Change which secret a vault uses |
| `get_secret_by_id` | secret_id | Returns `id:privateKey:publicKey:encryptedPassphrase` |
| `get_vault_status` | mount_point | Returns 0 if mounted, 1 if not |

### Vault operations (`vaults/ops.sh`)

| Function | Parameters | Description |
|----------|-----------|-------------|
| `mount_vault` | vault_index | Decrypt passphrase with age, mount with gocryptfs |
| `unmount_vault` | vault_index | Unmount with fusermount |
| `init_vault` | cipher_dir, secret_id | Initialize a new gocryptfs vault |

### Interactive flows

| Function | Description |
|----------|-------------|
| `show_secrets_menu` | Main secrets & vaults menu loop |
| `show_add_secret_flow` | Browser-based secret key selection |
| `show_add_vault_screen` | Create or add existing vault |

## File structure

```
omni-secrets/
  index.sh              — config resolution and imports
  storage.sh            — secrets JSON storage
  components.sh         — display components
  add.sh                — add secret flow
  menu.sh               — main menu and entry point
  vaults/
    storage.sh          — vaults JSON storage
    ops.sh              — mount/unmount/init
    add.sh              — add vault flow
  config/               — dev config dir
    .secrets.json
    .vaults.json
```
