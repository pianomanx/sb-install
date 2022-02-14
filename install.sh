#!/bin/bash
# Owner : SudoBox-IO
# https://sudobox.io
#
clear
function installation() {
    echo -e "\e[34m\e[1m--------------- Sudobox Installer ---------------"
    echo "  Pre Installer for SudoBox.io "
    echo "  Version 0.0.1 "
    echo "  All documentation can be found at https://docs.sudobox.io"
    echo ""
    echo -e "  \e[33mTasks :"
    echo "     - Create SudoBox installation directories at /opt/sudobox"
    echo "     - Install Docker & Docker-Compose"
    echo "     - Create Docker Networks: sudobox & sudobox_private"
    echo "     - Install the SudoBox CLI, Backend & Database Containers"
    echo ""
    echo "     y) Would you like to continue?"
    echo "     e) Exit "
    echo ""

    read n
    case $n in
    y) checkIfSudo ;;
    e) exit ;;
    *) echo -e "\e[91mInvalid Option" ;;

    esac
}

function checkIfSudo() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "\e[91mError, Please run as root, exiting...."
        exit
    else
        echo -e "\e[32mProceeding with the Pre Installation..."
        createdir
        downloadDependencies
        dockernetworkcheckpublic
        dockernetworkcheck
        installsbbackend
        runcontainers
        installsbcli
        echo "Finished installing all Dependencies, Moving to CLI Questions..."
        echo "You can run SudoBox CLI at anytime using 'sb'"
    fi

}

echo "alias sb='docker run -it --network=sudobox_private --name sb-cli sudobox/sb-cli'" >~/.bash_aliases

function downloadDependencies() {
    echo -e "\e[34m\e[1mInstalling and ensuring your system is upto date"
    sudo apt-get -qq update -y && sudo apt-get -qq upgrade -y
    echo -e "\e[34m\e[1mProceeding with installation dependencies..."

    if [[ $(which docker) && $(docker --version) ]]; then
        echo -e "\e[32mDocker Installed, Skipping..."
    else
        echo -e "\e[34m\e[1mInstalling Docker"
        sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
        sudo apt install docker-ce -y
    fi

    if [[ $(which docker-compose) ]]; then
        echo -e "\e[32mDocker-Compose installed, Skipping..."
    else
        echo -e "\e[34m\e[1mInstalling docker-compose"
        sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
}

function createdir() {
    mkdir -p /opt/sudobox/configs
    mkdir -p /opt/sudobox/appdata
    mkdir -p /opt/sudobox/compose
    echo -e "\e[34m\e[1mCreated SudoBox Directories"

}
function dockernetworkcheckpublic() {
    donetcheck=$(docker network ls | grep --only-matching sudobox | head -1)
    if [[ "$donetcheck" == "sudobox" ]]; then
        echo -e "\e[32mDocker Network ( sudobox )Exists, Skipping..."
    else
        echo -e "\e[34m\e[1mCreating Docker Network sudobox"
        docker network create sudobox
        echo -e "\e[32mCreated Docker Network sudobox"
    fi
}
function dockernetworkcheck() {
    donetcheck=$(docker network ls | grep --only-matching sudobox_private)
    if [[ "$donetcheck" == "sudobox_private" ]]; then
        echo -e "\e[32mDocker Network ( sudobox_private )Exists, Skipping..."
    else
        echo -e "\e[34m\e[1mCreating Docker Network sudobox_private"
        docker network create sudobox_private
        echo -e "\e[32mCreated Docker Network sudobox_private"
    fi
}
function installsbcli() {
    alias sb='docker run -it --rm --network=sudobox_private --name sb-cli ghcr.io/sudobox/sb-cli'
    echo "alias sb='docker run -it --network=sudobox_private --rm --name sb-cli ghcr.io/sudobox/sb-cli && clear'" >>~/.bash_aliases
    echo -e "\e[34m\e[1mCreating SudoBox CLI Container"
    docker run -it --network=sudobox_private --name sb-cli sudobox/sb-cli
    echo -e "\e[32mCreated SudoBox CLI Container"
}

function installsbbackend() {
    cd /opt/sudobox/compose
    echo 'version: "3.5"
services:
  sb_backend:
    image: ghcr.io/sudobox/sb-backend
    container_name: sb-backend
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
      - "/opt/sudobox/appdata:/appdata"
      - "/opt/sudobox/configs:/configs"
      - "/opt/sudobox/compose:/compose"
    networks:
      - sudobox_private
    depends_on:
      - sb_database

  sb_database:
    image: mongo:latest
    container_name: sb-database
    volumes:
      - "/opt/sudobox/appdata/sbdb:/data/db"
    networks:
      - sudobox_private

networks:
  sudobox_private:
    driver: bridge
    external: true' >sb-backend.yml
    echo -e "\e[32mCreated SudoBox backend compose file"
}

function runcontainers() {
    containerdbcheck=$(docker ps -a | grep --only-matching sb-database)
    if [[ "$containerdbcheck" == "sb-database" ]]; then
        echo "SudoBox database Container exists removing Container..."
        docker rm sb-database
    else
        containerbackcheck=$(docker ps -a | grep --only-matching sb-backend)
        if [[ "$containerbackcheck" == "sb-backend" ]]; then
            echo "SudoBox backend Container exists removing Container..."
            docker rm sb-backend
        else
            docker-compose -f sb-database.yml up -d
            docker-compose -f sb-backend.yml up -d
        fi
    fi
}

installation
