#!/usr/bin/env python3
"""
SSM Session Manager with profile support
"""

import os
import sys
import argparse
import configparser
import subprocess
import re
from pathlib import Path
from typing import Dict, Optional, List

def check_script_in_path(script_path: str) -> None:
    """
    Check if the script is in PATH and provide setup instructions if not.
    
    Args:
        script_path: Absolute path to the script
    """
    script_name = os.path.basename(script_path)
    script_dir = os.path.dirname(script_path)
    
    # Check if script is in PATH
    if not any(
        os.path.exists(os.path.join(path, script_name))
        for path in os.environ.get('PATH', '').split(os.pathsep)
    ):
        print("\n\033[33mNote:\033[0m The script is not in your PATH. For easier access:")
        print("\n\033[34m# Add to ~/.bashrc, ~/.zshrc, or your shell's equivalent\033[0m")
        print(f'export PATH="{script_dir}:$PATH"')
        print("\nThen run: source ~/.bashrc  # or your shell's config file")
        print("\nOr create a symlink in a directory that's already in your PATH:")
        print(f'ln -s "{script_path}" ~/.local/bin/{script_name}')
        print("\nAfter adding to PATH, you can simply run:", f'\033[32m{script_name}\033[0m')
        print("\033[33mNote:\033[0m You may need to create ~/.local/bin if it doesn't exist")
        print("and log out/in for changes to take effect.\n")

# Constants
APP_NAME = "ssm-login"
DEFAULT_CONFIG = {
    "region": "",
    "target_instance": "",
    "host": "",
    "port": "",
    "local_port": "",
    "document_name": "AWS-StartPortForwardingSessionToRemoteHost"
}

def get_config_dir() -> Path:
    """Get the configuration directory following XDG spec."""
    xdg_config_home = os.environ.get("XDG_CONFIG_HOME")
    if xdg_config_home:
        return Path(xdg_config_home) / APP_NAME
    return Path.home() / ".config" / APP_NAME

def get_config_file() -> Path:
    """Get the path to the config file."""
    return get_config_dir() / "config"

def ensure_config_dir() -> None:
    """Ensure the config directory exists."""
    config_dir = get_config_dir()
    config_dir.mkdir(parents=True, exist_ok=True)
    config_file = config_dir / "config"
    if not config_file.exists():
        config_file.touch(mode=0o600)  # Secure permissions

def load_config(session: str) -> Dict[str, str]:
    """Load configuration for a session."""
    config = configparser.ConfigParser()
    config_file = get_config_file()
    
    if not config_file.exists():
        return {}
    
    config.read(config_file)
    return dict(config[session]) if session in config else {}

def save_config(session: str, config: Dict[str, str]) -> None:
    """Save configuration for a session."""
    config_parser = configparser.ConfigParser()
    config_file = get_config_file()
    
    # Load existing config if it exists
    if config_file.exists():
        config_parser.read(config_file)
    
    # Update the session config
    config_parser[session] = config
    
    # Write back to file
    ensure_config_dir()
    with open(config_file, 'w') as f:
        config_parser.write(f)
    
    # Set secure permissions
    config_file.chmod(0o600)

def configure_session(session: str) -> Dict[str, str]:
    """Interactively configure a new session."""
    print(f"\nConfiguring session: {session}")
    print("Please provide the following information (press Enter to keep default):\n")
    
    # Load existing config if it exists
    config = load_config(session)
    
    # Prompt for each field
    for key, default in DEFAULT_CONFIG.items():
        current_value = config.get(key, default)
        prompt = f"{key.replace('_', ' ').title()}"
        if current_value:
            prompt += f" [{current_value}]: "
        else:
            prompt += ": "
            
        value = input(prompt).strip()
        if value:
            config[key] = value
        elif key in config:
            # Keep existing value
            pass
        elif default:
            config[key] = default
    
    # Save the configuration
    save_config(session, config)
    
    # Create the box content
    box_width = 70
    cmd1 = f"{os.path.basename(__file__)} --session {session} --configure"
    cmd2 = f"ssm {session}"
    
    def print_centered(text, color_code=''):
        text = text.strip()
        padding = (box_width - 2 - len(text)) // 2
        left_pad = ' ' * padding
        right_pad = ' ' * (box_width - 2 - len(text) - padding)
        print(f"\033[1;32m║\033[0m{left_pad}{color_code}{text}\033[0m{right_pad}\033[1;32m║\033[0m")
    
    def print_left_aligned(text, color_code=''):
        # Remove ANSI codes for length calculation
        clean_text = re.sub(r'\x1b\[([0-9A-Za-z;]+)?m', '', text)
        padding = ' ' * (box_width - 2 - len(clean_text))
        print(f"\033[1;32m║\033[0m {color_code}{text}\033[0m{padding} \033[1;32m║\033[0m")
    
    # Top border
    print("\n\033[1;32m╔" + "═" * (box_width-2) + "╗\033[0m")
    
    # Title line (centered)
    print_centered("✅ Configuration Saved!")
    
    # Session line (centered with color)
    session_text = f"Session: {session}"
    print_centered(session_text, '\033[1;36m')
    
    # Divider
    print("\033[1;32m╟" + "─" * (box_width-2) + "╢\033[0m")
    
    # Commands section (left-aligned)
    print_left_aligned("\033[1;33mYou can now start this session using:")
    # Split cmd1 to add strikethrough to --configure
    cmd1_base = f"{os.path.basename(__file__)} --session {session}"
    print_left_aligned(f"  \033[1;37m{cmd1_base} \033[0m\033[9m--configure\033[0m")
    print_left_aligned("\033[1;33mNote: The strikethrough indicates you don't need --configure next time")
    print(f"\033[1;32m║{' ' * (box_width-2)}\033[1;32m║")
    print_left_aligned("\033[1;33mOr with the shell alias:")
    print_left_aligned(f"  \033[1;37m{cmd2}")
    
    # Bottom border
    print("\033[1;32m╚" + "═" * (box_width-2) + "╝\033[0m")
    return config

def list_sessions() -> None:
    """List all configured sessions."""
    config_file = get_config_file()
    if not config_file.exists():
        print("No sessions configured.")
        return
    
    config = configparser.ConfigParser()
    config.read(config_file)
    
    if not config.sections():
        print("No sessions configured.")
        return
    
    print("\nConfigured sessions:")
    for session in config.sections():
        print(f"- {session}")

def start_ssm_session(config: Dict[str, str]) -> None:
    """Start an SSM session with the given configuration."""
    print(f"\nStarting SSM session...")
    print(f"Instance: {config['target_instance']}")
    print(f"Region: {config['region']}")
    print(f"Remote: {config['host']}:{config['port']}")
    print(f"Local port: {config['local_port']}")
    
    # Build the SSM command
    cmd = [
        "aws", "ssm", "start-session",
        "--target", config["target_instance"],
        "--document-name", config["document_name"],
        "--parameters", 
        f"host={config['host']},portNumber={config['port']},localPortNumber={config['local_port']}",
        "--region", config["region"]
    ]
    
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error starting SSM session: {e}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nSession terminated by user.")
        sys.exit(0)

def parse_arguments():
    parser = argparse.ArgumentParser(description='SSM Session Manager')
    parser.add_argument('-s', '--session', help='Session/profile name to use')
    parser.add_argument('-c', '--configure', action='store_true', 
                      help='Configure a new session')
    parser.add_argument('-l', '--list-sessions', action='store_true',
                      help='List all configured sessions')
    return parser.parse_args()

def main():
    # Check if script is in PATH
    script_path = os.path.abspath(__file__)
    check_script_in_path(script_path)
    
    args = parse_arguments()
    
    if args.list_sessions:
        list_sessions()
        return
    
    if not args.session:
        print("Error: Session name is required. Use -h for help.", file=sys.stderr)
        sys.exit(1)
    
    if args.configure:
        config = configure_session(args.session)
    else:
        config = load_config(args.session)
        if not config:
            print(f"No configuration found for session: {args.session}", file=sys.stderr)
            print("Run with --configure to set up this session.", file=sys.stderr)
            sys.exit(1)
    
    # Start the SSM session
    start_ssm_session(config)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\033[1;33mOperation cancelled by user. Exiting...\033[0m")
        sys.exit(130)  # Standard exit code for Ctrl+C
    except Exception as e:
        print(f"\n\033[1;31mAn error occurred: {e}\033[0m", file=sys.stderr)
        sys.exit(1)
