#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

clear
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}     Backhaul Profile Changer Tool      ${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

while true; do
    echo -e "${YELLOW}[1]${NC} Change Profile Mode"
    echo -e "${YELLOW}[2]${NC} Exit"
    echo ""
    read -p "Select option: " OPTION

    case $OPTION in
        1)
            echo ""
            read -p "TunnelName (e.g. iran16443): " TUNNEL_NAME

            if [[ -z "$TUNNEL_NAME" ]]; then
                echo -e "${RED}[ERROR] TunnelName cannot be empty!${NC}"
                echo ""
                continue
            fi

            echo ""
            echo -e "${CYAN}Profile Mode examples:${NC}"
            echo -e "  tcp | udp | tcp-bip | ipip | tcp-bip-ipip | ..."
            echo ""
            read -p "ProfileMode: " PROFILE_MODE

            if [[ -z "$PROFILE_MODE" ]]; then
                echo -e "${RED}[ERROR] ProfileMode cannot be empty!${NC}"
                echo ""
                continue
            fi

            # Navigate to backhaul-core directory
            CONFIG_DIR="./backhaul-core"
            CONFIG_FILE="${CONFIG_DIR}/${TUNNEL_NAME}.toml"

            if [[ ! -d "$CONFIG_DIR" ]]; then
                echo -e "${RED}[ERROR] Directory '$CONFIG_DIR' not found!${NC}"
                echo ""
                continue
            fi

            if [[ ! -f "$CONFIG_FILE" ]]; then
                echo -e "${RED}[ERROR] Config file '$CONFIG_FILE' not found!${NC}"
                echo ""
                continue
            fi

            echo ""
            echo -e "${CYAN}[INFO] Opening config file: ${CONFIG_FILE}${NC}"

            # Check if [ipx] section exists
            if ! grep -q "^\[ipx\]" "$CONFIG_FILE"; then
                echo -e "${RED}[ERROR] [ipx] section not found in config file!${NC}"
                echo ""
                continue
            fi

            # Show current profile
            CURRENT_PROFILE=$(awk '/^\[ipx\]/{found=1} found && /^profile/{print; exit}' "$CONFIG_FILE" | grep -oP '(?<=")[^"]+')
            echo -e "${YELLOW}[INFO] Current profile: ${CURRENT_PROFILE}${NC}"

            # Replace profile value inside [ipx] section only
            awk -v new_profile="$PROFILE_MODE" '
                /^\[ipx\]/ { in_ipx=1 }
                /^\[/ && !/^\[ipx\]/ { in_ipx=0 }
                in_ipx && /^profile[[:space:]]*=/ {
                    sub(/"[^"]*"/, "\"" new_profile "\"")
                }
                { print }
            ' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

            # Verify the change
            NEW_PROFILE=$(awk '/^\[ipx\]/{found=1} found && /^profile/{print; exit}' "$CONFIG_FILE" | grep -oP '(?<=")[^"]+')

            if [[ "$NEW_PROFILE" == "$PROFILE_MODE" ]]; then
                echo -e "${GREEN}[SUCCESS] Profile updated: '${CURRENT_PROFILE}' → '${NEW_PROFILE}'${NC}"
            else
                echo -e "${RED}[ERROR] Profile update failed! Please check the config file.${NC}"
                echo ""
                continue
            fi

            # Restart the service
            SERVICE_NAME="backhaul-${TUNNEL_NAME}.service"
            echo ""
            echo -e "${CYAN}[INFO] Restarting service: ${SERVICE_NAME}${NC}"

            systemctl restart "$SERVICE_NAME"

            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}[SUCCESS] Service '${SERVICE_NAME}' restarted successfully!${NC}"
            else
                echo -e "${RED}[ERROR] Failed to restart service '${SERVICE_NAME}'!${NC}"
            fi

            # Show logs
            echo ""
            echo -e "${CYAN}========== Service Logs (last 30 lines) ==========${NC}"
            journalctl -u "$SERVICE_NAME" -n 30 --no-pager
            echo -e "${CYAN}==================================================${NC}"
            echo ""
            ;;

        2)
            echo ""
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;

        *)
            echo -e "${RED}[ERROR] Invalid option! Please select 1 or 2.${NC}"
            echo ""
            ;;
    esac
done