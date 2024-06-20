#!/bin/bash
: ${USER:=stack}
: ${UC:=10.0.0.11}
: ${UC_CIDR:=192.168.24.1/24}
: ${SSH_CMD:="ssh -i ~/.ssh/osm-ci"}

# Check if sshuttle is installed
if ! command -v sshuttle &> /dev/null
then
    echo "sshuttle n'est pas installé. Installation..."
    # in case of MacOSx
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        brew install sshuttle
    else
        # Fedora
        if ! sudo dnf install -y sshuttle; then
            echo "dnf install failed, sshuttle not found, install from source..."
            git clone https://github.com/sshuttle/sshuttle.git
            cd sshuttle
            sudo python3 setup.py install
            sudo mv run /usr/bin/sshuttle
            cd ..
            rm -rf sshuttle
        fi
    fi
fi

# Create tunnel
(sshuttle -r $USER@$UC -v $UC_CIDR -e "$SSH_CMD" > sshuttle.log 2>&1 &)
