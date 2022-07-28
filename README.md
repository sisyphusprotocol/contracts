# Carbyne General Template

## Set up

```
$ npm install prepare
```

Copy `.env.example` to `.env`

```shell
$ cp .env.example .env
```

Config environment variables. By default, there is a configuration for rinkeby networks RPC url and private key config. You can fill in multiple private keys and separate them with commas.

```
RINKEBY_URL="https://rinkeby.infura.io/v3/<YOUR INFURA KEY>"
ACCOUNTS=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
```

## Compile contract

Compile contracts

```shell
$ npm run compile
```

## Lint

Use `cspell`, `prettier`, `eslint` to format and check code format.

```shell
$ npm run lint
```

## Test

Run all tests

```shell
$ npm run test
```

Run all tests and get estimating gas used in each contract

```shell
$ npm run test:analysis
```

Get Test coverage

```shell
$ npm run coverage
```

Test coverage will show in the terminal(stdout) and HTML files are generated in the `coverage` folder so that you can also open them in the browser to view.

## Smart flatten

Flatten all smart contracts in the `contracts` folder and generate files to the `flatten` folder according to their relative path, and all flattened contracts are ready for being verified. It helps a lot usually.

```shell
$ npm run flat
```

## Run some script

Check before you run it!

```
$ npm hardhat run scripts/xxxx.ts
```

# Directory Structure

```
.
├── contracts/
├── cspell.json
├── .eslintignore
├── .eslintrc.js
├── flat.ts
├── .git
├── .gitignore
├── hardhat.config.ts
├── .husky/
├── node_modules
├── package.json
├── package-lock.json
├── .prettierignore
├── .prettierrc.js
├── scripts/
├── .solhintignore
├── .solhint.json
├── test/
└── tsconfig.json

```

`contracts` is where you write your own smart contracts, there are some common subfolders you can refer to, such as `libraries` for shared libraries, and `tests` for contracts not written by you but used in test scripts. You can also make some subfolders for different features.

`scripts` is where you write some one-time scripts, such as deploying contracts to a specific chain or calling a contract to change some data. As it may write to the real blockchain, be careful before running it！

`tests` is where you write test scripts to test your contracts thoroughly. It uses hardhat framework to run tests and there is a temporary chain for you to read and write arbitrarily. For more, you can refer to hardhat [docs](https://hardhat.org/getting-started/)

`.husky` is a folder for git hook. By default, there is a pre-commit hook that runs `npm run lint` and `npm run test` before you make a git commit.

`flat.ts` is a custom file to run smart flatten as hardhat's origin command `flatten` doesn't work well.

`hardhat.config.ts` is the hardhat config file, you can use more environment variables after configuring them in `.env`.

`tsconfig.json` is the file for configuring typescript compiling options.

`.eslintrc.js` and `.eslintignore` for eslint config.

`.prettierignore` and `.prettierrc.js` for prettier config.

`.solhint.json` and `.solhintignore` for solhint config.
