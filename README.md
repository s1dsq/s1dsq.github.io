Website live [here](https://s1dsq.github.io/)

Generated using [barf](https://barf.btxx.org/) and the
[smu](https://git.btxx.org/smu) markdown parser

## Basic setup
- Clone this repo and navigate inside it. Edit the "header.html" and
  "footer.html" files with your own information, navigation, etc.
- Be sure to edit the RSS meta url or else your feed won't validate!
- Then, clone and build smu:
```sh
git clone https://git.btxx.org/smu && cd smu
```

## Testing locally
```
make watch
cd build && python3 -m http.server 3003
```

## Building
```
make build
```
This places build files inside the `docs` folder. `docs` was chosen because it
was the only other folder available other than the root where I could place
build artifacts. The root is reserved for the dev setup

## More info
Official barf [README](https://git.btxx.org/barf/about/)
