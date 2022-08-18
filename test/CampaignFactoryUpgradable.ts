import { getNamedAccounts, ethers } from 'hardhat';
import { expect } from 'chai';

import { getCurrentTime, TimeGo, getContract } from './utils';
import { BigNumber, Contract, ContractReceipt, ContractTransaction } from 'ethers';

describe('CampaignFactoryUpgradable', () => {
  let campaignFactory: Contract;
  let testErc20: Contract;
  let deployer: string;
  const requiredAmount = 10n * 10n ** 18n;

  const PROTOCOL_FEE = 10n ** 5n;
  const HOST_REWARD = 2n * 10n ** 5n;

  before(async () => {
    campaignFactory = await getContract('CampaignFactoryUpgradable');
    testErc20 = await getContract('TestERC20');
    deployer = (await getNamedAccounts()).deployer;
  });

  it('Factory', async () => {
    const testErc20 = await getContract('TestERC20');

    await campaignFactory.modifyWhiteUser(deployer, true);

    await campaignFactory.modifyWhiteToken(testErc20.address, ethers.utils.parseEther('100'));

    await campaignFactory.createCampaign(
      testErc20.address,
      requiredAmount,
      'Test',
      'T',
      (await getCurrentTime()) + 86400 / 2,
      2,
      86400,
    );
  });

  it('Campaign', async () => {
    const users = await ethers.getSigners();

    const tx: ContractTransaction = await campaignFactory.createCampaign(
      testErc20.address,
      requiredAmount,
      'Test',
      'T',
      (await getCurrentTime()) + 86400,
      3,
      86400,
    );

    const receipt: ContractReceipt = await tx.wait();

    const c = receipt.events?.filter((x) => {
      return x.event === 'EvCampaignCreated';
    });

    const campaign = await ethers.getContractAt('Campaign', c![0].args!.campaignAddress);

    const holderInfo: {
      [x: string]: BigNumber;
    } = {};

    for (const user of users) {
      await testErc20.mint(user.address, requiredAmount);
      await testErc20.connect(user).approve(campaign.address, ethers.constants.MaxUint256);
      const tx: ContractTransaction = await campaign.connect(user).signUp();
      const receipt: ContractReceipt = await tx.wait();

      const c = receipt.events?.filter((x) => {
        return x.event === 'EvSignUp';
      });

      holderInfo[user.address] = c![0].args!.tokenId;
    }

    await campaign.admit([
      ...users.map((user) => {
        return holderInfo[user.address];
      }),
    ]);

    await TimeGo(86400);

    for (const user of users) {
      await campaign.connect(user).checkIn(ethers.utils.formatBytes32String('ipfs://Qmxxxxx'), holderInfo[user.address]);
    }

    expect(await campaign.currentEpoch()).to.be.equal(0);

    await TimeGo(86400);

    for (const user of users) {
      await campaign.connect(user).checkIn(ethers.utils.formatBytes32String('ipfs://Qmxxxxx'), holderInfo[user.address]);
    }

    expect(await campaign.currentEpoch()).to.be.equal(1);

    await TimeGo(86400);

    // first one forget to checkIn
    for (const user of users.slice(1)) {
      await campaign.connect(user).checkIn(ethers.utils.formatBytes32String('ipfs://Qmxxxxx'), holderInfo[user.address]);
    }
    expect(await campaign.currentEpoch()).to.be.equal(2);

    await TimeGo(86400);

    for (const user of users.slice(1)) {
      await campaign.connect(user).claim(holderInfo[user.address]);
      expect(await testErc20.balanceOf(user.address)).to.be.equal(
        requiredAmount + (requiredAmount * 1n * (10n ** 6n - PROTOCOL_FEE - HOST_REWARD)) / 10n ** 6n / 19n,
      );
    }

    await campaign.connect(users[0]).claim(holderInfo[users[0].address]);
    expect(await testErc20.balanceOf(users[0].address)).to.be.equal(0);

    await campaign.connect(users[0]).withdraw();

    expect(await testErc20.balanceOf(users[0].address)).to.be.equal((requiredAmount * HOST_REWARD) / 10n ** 6n);

    expect(await testErc20.balanceOf('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045')).to.be.equal(
      (requiredAmount * PROTOCOL_FEE) / 10n ** 6n,
    );
  });
});