# Home Assistant CUPS Print Server Add-on

## About

This add-on installs the [Common UNIX Printing System (CUPS)](https://www.cups.org/) in a
Home Assistant OS/Supervised environment and shares your network printers with Android
phones and tablets via Mopria/IPP Everywhere. It is designed for Raspberry Pi 3 (both
32-bit and 64-bit) but also works on other supported Home Assistant architectures.

## Configuration

| Option | Description |
| ------ | ----------- |
| `log_level` | Optional. Controls add-on log verbosity. One of `debug`, `info`, `notice`, `warning`, or `error`. |
| `admin_user` | Optional. System user that can authenticate to the CUPS web interface. Defaults to `cupsadmin`. |
| `admin_password` | Optional. Password for the `admin_user`. Change this to something secret before exposing the add-on to your network. |
| `printers` | Optional list of printer definitions. Each item is formatted as `name=uri`. |

### Printer definitions

Each entry inside `printers` should describe a single network printer using the
pattern `friendly_name=device_uri`. Examples:

```yaml
printers:
  - Ricoh=socket://192.168.1.45:9100
  - Office_Laser=ipp://192.168.1.52/ipp/print
  - Brother_Lab=ipps://brother.local/ipp
```

The add-on automatically enables IPP Everywhere for every printer. This allows Android
and Mopria-compatible clients to use the printer without downloading vendor-specific
PPD files. The first printer in the list is set as the default printer.

Printer names are sanitized to contain only letters, numbers, and underscores. If you
include spaces or special characters, they are automatically converted to underscores
inside CUPS.

If you prefer to manage printers manually, leave the list empty and use the CUPS web
interface instead.

## Using the add-on

1. Install the add-on from your Home Assistant add-on store (copy this repository URL).
2. Configure at least one printer under **Configuration**.
3. Start the add-on.
4. Visit the CUPS web interface at `http://homeassistant.local:631` (replace hostname as needed).
5. Log in with the configured `admin_user` and `admin_password` when prompted.
6. From an Android device, open **Settings → Printing → Default Print Service** (or **Mopria Print Service**).
   The printers announced by CUPS should appear automatically. If not, add them manually using the IPP URL
   shown in the CUPS interface.

## Security notes

- CUPS authenticates against system users. The add-on creates (or updates) the configured `admin_user`
  with the supplied password every time the container starts.
- By default the web interface is reachable from your entire network. Consider placing the add-on
  behind a firewall or VPN if you need stricter access controls.
- Always change the default password before exposing the add-on to untrusted networks.

## Troubleshooting

- Review the add-on logs for detailed information about printer provisioning.
- Ensure the printer supports IPP Everywhere or raw TCP (JetDirect/RAW) printing.
- Android discovery relies on network multicast. Verify that your network allows mDNS/Bonjour traffic
  so Android devices can discover the printer automatically.
