#!/bin/bash

while true
do

# Logo

echo -e '\e[40m\e[91m'
echo -e '  ____                  _                    '
echo -e ' / ___|_ __ _   _ _ __ | |_ ___  _ __        '
echo -e '| |   |  __| | | |  _ \| __/ _ \|  _ \       '
echo -e '| |___| |  | |_| | |_) | || (_) | | | |      '
echo -e ' \____|_|   \__  |  __/ \__\___/|_| |_|      '
echo -e '            |___/|_|                         '
echo -e '\e[0m'

sleep 2

# Menu

PS3='Select an action: '
options=(
"Install"
"Create Wallet"
"Create Validator"
"Exit")
select opt in "${options[@]}"
do
case $opt in

"Install")
echo "============================================================"
echo "Install start"
echo "============================================================"

# set vars
if [ ! $NODENAME ]; then
	read -p "Enter node name: " NODENAME
	echo 'export NODENAME='$NODENAME >> $HOME/.bash_profile
fi
if [ ! $WALLET ]; then
	echo "export WALLET=wallet" >> $HOME/.bash_profile
fi
echo "export STABLE_CHAIN_ID=stabletestnet_2201-1" >> $HOME/.bash_profile
source $HOME/.bash_profile

# update
sudo apt update && sudo apt upgrade -y

# packages
sudo apt install curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev tar clang bsdmainutils ncdu unzip libleveldb-dev lz4 screen bc fail2ban -y

# install go
sudo rm -rf /usr/local/go
curl -L https://go.dev/dl/go1.22.7.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.profile
source .profile

# download binary
wget -O stabled-1.1.1-linux-amd64-testnet.tar.gz \
  https://stable-testnet-data.s3.us-east-1.amazonaws.com/stabled-1.1.1-linux-amd64-testnet.tar.gz
tar -xvzf stabled-1.1.1-linux-amd64-testnet.tar.gz
sudo mv stabled /usr/bin/
stabled version

# config
#stabled config chain-id $STABLE_CHAIN_ID
#stabled config keyring-backend os

# init
stabled init $NODENAME --chain-id $STABLE_CHAIN_ID

# download genesis and addrbook
mv ~/.stabled/config/genesis.json ~/.stabled/config/genesis.json.backup
wget https://stable-testnet-data.s3.us-east-1.amazonaws.com/stable_testnet_genesis.zip
unzip stable_testnet_genesis.zip
cp genesis.json ~/.stabled/config/genesis.json

curl -Ls https://file.blocksync.me/stable/addrbook.json > $HOME/.stabled/config/addrbook.json

#opti
wget https://stable-testnet-data.s3.us-east-1.amazonaws.com/rpc_node_config.zip
unzip rpc_node_config.zip
cp ~/.stabled/config/config.toml ~/.stabled/config/config.toml.backup
cp config.toml ~/.stabled/config/config.toml
sed -i "s/^moniker = \".*\"/moniker = \"$NODENAME\"/" ~/.stabled/config/config.toml

# set minimum gas price
#sed -i 's|minimum-gas-prices =.*|minimum-gas-prices = "0.0001ustable"|g' $HOME/.stabled/config/app.toml

# set peers and seeds
SEEDS=""
PEERS="5ed0f977a26ccf290e184e364fb04e268ef16430@37.187.147.27:26656,128accd3e8ee379bfdf54560c21345451c7048c7@37.187.147.22:26656,9d1150d557fbf491ec5933140a06cdff40451dee@164.68.97.210:26656,e33988e27710ee1a7072f757b61c3b28c922eb59@185.232.68.94:11656,ff4ff638cee05df63d4a1a2d3721a31a70d0debc@141.94.138.48:26664"
sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.stabled/config/config.toml

# disable indexing
indexer="null"
sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $HOME/.stabled/config/config.toml

# config pruning
pruning="custom"
pruning_keep_recent="100"
pruning_keep_every="0"
pruning_interval="10"
sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/.stabled/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/.stabled/config/app.toml
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/.stabled/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/.stabled/config/app.toml
sed -i "s/snapshot-interval *=.*/snapshot-interval = 0/g" $HOME/.stabled/config/app.toml

#be
#sed -i -e "s/^app-db-backend *=.*/app-db-backend = \"goleveldb\"/;" $HOME/.stabled/config/app.toml
#sed -i -e "s/^db_backend *=.*/db_backend = \"pebbledb\"/" $HOME/.stabled/config/config.toml

# enable prometheus
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.stabled/config/config.toml

# create service
sudo tee /etc/systemd/system/stabled.service > /dev/null <<EOF
[Unit]
Description=Stable node
After=network-online.target
[Service]
User=$USER
WorkingDirectory=$HOME/.stabled
ExecStart=$(which stabled) start --home $HOME/.stabled
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

# reset
stabled tendermint unsafe-reset-all --home $HOME/.stabled --keep-addr-book
SNAP_NAME=$(curl -s https://file.blocksync.me/stable/ | grep -o 'snapshot_[0-9]\+\.tar\.lz4' | sort | tail -n 1)
curl -o - -L https://file.blocksync.me/stable/${SNAP_NAME}  | lz4 -c -d - | tar -x -C $HOME/.stabled

# start service
sudo systemctl daemon-reload
sudo systemctl enable stabled
sudo systemctl restart stabled

break
;;

"Create Wallet")
stabled keys add $WALLET
echo "============================================================"
echo "Save address and mnemonic"
echo "============================================================"
STABLE_WALLET_ADDRESS=$(stabled keys show $WALLET -a)
STABLE_VALOPER_ADDRESS=$(stabled keys show $WALLET --bech val -a)
echo 'export STABLE_WALLET_ADDRESS='${STABLE_WALLET_ADDRESS} >> $HOME/.bash_profile
echo 'export STABLE_VALOPER_ADDRESS='${STABLE_VALOPER_ADDRESS} >> $HOME/.bash_profile
source $HOME/.bash_profile

break
;;

"Create Validator")
stabled tx staking create-validator \
--amount=1000000ustable \
--pubkey=$(stabled tendermint show-validator) \
--moniker=$NODENAME \
--chain-id=stabletestnet_2201-1 \
--commission-rate=0.05 \
--commission-max-rate=0.20 \
--commission-max-change-rate=0.01 \
--min-self-delegation=1 \
--from=wallet \
--fees=30ustable \
--gas=300000 \
--gas-adjustment 1.5 \
-y 
  
break
;;

"Exit")
exit
;;
*) echo "invalid option $REPLY";;
esac
done
done
