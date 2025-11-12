#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
set -euo pipefail

bashio::log.info "Preparing CUPS environment"

LOG_LEVEL=$(bashio::config 'log_level')
if bashio::var.has_value "${LOG_LEVEL}"; then
    bashio::log.level "${LOG_LEVEL}"
    sed -i "s/^LogLevel .*/LogLevel ${LOG_LEVEL}/" /etc/cups/cupsd.conf
fi

# Ensure runtime directories are owned by lp
for path in /etc/cups /var/log/cups /run/cups /var/spool/cups; do
    mkdir -p "${path}"
    chown -R lp:lp "${path}"
    chmod 755 "${path}"
done

# Prepare admin user
ADMIN_USER=$(bashio::config 'admin_user')
ADMIN_PASSWORD=$(bashio::config 'admin_password')
if bashio::var.has_value "${ADMIN_USER}" && bashio::var.has_value "${ADMIN_PASSWORD}"; then
    if id "${ADMIN_USER}" >/dev/null 2>&1; then
        bashio::log.info "Updating password for ${ADMIN_USER}"
    else
        bashio::log.info "Creating admin user ${ADMIN_USER}"
        useradd --system --no-create-home --shell /sbin/nologin "${ADMIN_USER}"
    fi
    usermod -a -G lp,lpadmin "${ADMIN_USER}"
    echo "${ADMIN_USER}:${ADMIN_PASSWORD}" | chpasswd
    touch /etc/cups/certs/0
    chown "${ADMIN_USER}":lpadmin /etc/cups/certs/0
else
    bashio::log.warning "Admin credentials are not fully configured. Web interface authentication may fail."
fi

# Configure printers from options
configured_printers=()
raw_printers=$(bashio::config 'printers')
if [[ "${raw_printers}" != "null" ]]; then
    mapfile -t configured_printers < <(
        printf '%s' "${raw_printers}" | jq -er '.[] | select(. != null)'
    ) || true
fi

if [[ ${#configured_printers[@]} -gt 0 ]]; then
    bashio::log.info "Configuring ${#configured_printers[@]} printer(s) from options"

    existing_printers=()
    mapfile -t existing_printers < <((lpstat -p 2>/dev/null || true) | awk '{print $2}')
    for printer in "${existing_printers[@]}"; do
        keep=false
        for definition in "${configured_printers[@]}"; do
            name=${definition%%=*}
            sanitized=${name//[^A-Za-z0-9_]/_}
            if [[ "${sanitized}" == "${printer}" ]]; then
                keep=true
                break
            fi
        done
        if [[ ${keep} == false ]]; then
            bashio::log.info "Removing printer ${printer} not present in configuration"
            lpadmin -x "${printer}" || true
        fi
    done

    index=0
    for definition in "${configured_printers[@]}"; do
        if [[ "${definition}" != *"="* ]]; then
            bashio::log.warning "Skipping invalid printer definition: ${definition}"
            continue
        fi

        name=${definition%%=*}
        uri=${definition#*=}
        sanitized_name=${name//[^A-Za-z0-9_]/_}

        if lpstat -p "${sanitized_name}" >/dev/null 2>&1; then
            bashio::log.info "Updating existing printer ${sanitized_name}"
            lpadmin -x "${sanitized_name}"
        fi

        bashio::log.info "Adding printer ${sanitized_name} with URI ${uri}"
        if ! lpadmin -p "${sanitized_name}" -E -v "${uri}" -m everywhere -o printer-is-shared=true; then
            bashio::log.error "Failed to add printer ${sanitized_name}. Check URI and compatibility."
            continue
        fi

        if [[ ${index} -eq 0 ]]; then
            bashio::log.info "Setting ${sanitized_name} as the default printer"
            lpadmin -d "${sanitized_name}" || true
        fi
        ((index++))
    done
else
    bashio::log.info "No printers defined in configuration. Manage printers via the web interface."
fi

