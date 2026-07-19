```sh
sudo cp ./rtt /usr/local/bin/rtt
sudo chmod +x /usr/local/bin/rtt

cd ~
rtt build --release

mkdir -p ~/.local/bin
cp ./rtt ~/.local/bin/rtt
chmod +x ~/.local/bin/rtt

export PATH="$HOME/.local/bin:$PATH"
```
