import * as dotenv from 'dotenv';

import { HardhatUserConfig, task } from 'hardhat/config';
import { addFlatTask } from './flat';
import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-waffle';
import '@nomiclabs/hardhat-ethers';
import 'hardhat-deploy';
import '@typechain/hardhat';
import 'hardhat-gas-reporter';
import 'solidity-coverage';
import '@openzeppelin/hardhat-upgrades';
import { parseEther } from 'ethers/lib/utils';
import { BigNumber } from 'ethers';
import { randomBytes } from 'crypto';

dotenv.config();
addFlatTask();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task('accounts', 'Prints the list of accounts', async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// generate several tem address for test
const randomAccounts = Array.from({ length: 30 }, (x) => BigNumber.from(randomBytes(32))._hex.toString());

const accounts = process.env.ACCOUNTS ? process.env.ACCOUNTS.split(',') : [];

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.15',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    // currently fork mumbai for test. Make sure the first address have some $Link
    hardhat: {
      live: true,
      accounts: [
        ...[...accounts, ...randomAccounts].map((key) => {
          return { privateKey: key, balance: parseEther('100').toString() };
        }),
      ],
      chainId: 80001,
      forking: {
        enabled: true,
        url: process.env.MUMBAI_URL || '',
        // blockNumber: 28826235,
      },
      mining: {
        mempool: {
          order: 'fifo',
        },
      },
      deploy: ['deploy/hardhat'],
    },
    georli: {
      url: process.env.GEORLI_URL || '',
      live: true,
      accounts: accounts,
      deploy: ['deploy/georli'],
    },
    mumbaiTest: {
      url: process.env.MUMBAI_URL || '',
      // live: true,
      accounts: accounts,
      deploy: ['deploy/mumbaiTest'],
    },
    mumbai: {
      url: process.env.MUMBAI_URL || '',
      live: true,
      accounts: accounts,
      deploy: ['deploy/mumbai'],
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: 'USD',
  },
  namedAccounts: {
    deployer: {
      default: 0,
      georli: 0,
    },
  },

  external: {
    contracts: [
      {
        artifacts: 'node_modules/@openzeppelin/upgrades-core/artifacts/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol/',
      },
    ],
  },
};

export default config;
