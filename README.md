# openwrt-dawn-builder

This project uses docker to build the [DAWN](https://github.com/berlin-open-wireless-lab/DAWN) package for [OpenWRT](https://github.com/openwrt/openwrt).

## How to use

1. Clone this repo: `git clone --recurse-submodules https://github.com/notpeelz/openwrt-dawn-builder.git`
2. Generate a base configuration file (aka build seed)
    1. Clone the OpenWRT repo, e.g: `git clone https://github.com/openwrt/openwrt.git ~/openwrt && cd ~/openwrt`
    2. Invoke the graphical configuration menu: `make menuconfig`
    3. From this menu, choose the suitable "Target System", "Subtarget" and "Target Profile"
    4. Exit the menu (**make sure to save your changes**)
    5. Generate your build seed: `./scripts/diffconfig.sh > config.buildinfo`
3. Once you have generated `config.buildinfo`, you can start the build process

```
# Make sure to change the `-j` value to a value appropriate for your CPU
./build.sh -j24 --build-seed ~/openwrt/config.buildinfo --openwrt-version openwrt-22.03 master
```
