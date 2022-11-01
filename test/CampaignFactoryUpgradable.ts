import { ethers, deployments } from 'hardhat';
import { expect } from 'chai';

import { getCurrentTime, TimeGo, getContract } from './utils';
import { BigNumber, Contract, ContractReceipt, ContractTransaction } from 'ethers';
import { parseEther } from 'ethers/lib/utils';
import { CampaignFactoryUpgradable, TestERC20 } from '../typechain';

describe('CampaignFactoryUpgradable', () => {
  let campaignFactory: CampaignFactoryUpgradable;
  let testErc20: TestERC20;
  let LinkToken: Contract;
  const requiredAmount = 10n * 10n ** 18n;

  const PROTOCOL_FEE = 10n ** 5n;
  const HOST_REWARD = 2n * 10n ** 5n;

  before(async () => {
    campaignFactory = await getContract<CampaignFactoryUpgradable>('CampaignFactoryUpgradable');
    testErc20 = await getContract<TestERC20>('TestERC20');

    const link = await deployments.get('Link');
    LinkToken = await ethers.getContractAt('TestERC20', link.address);
  });

  it('Factory', async () => {
    const [dev] = await ethers.getSigners();
    const testErc20 = await getContract('TestERC20');

    await campaignFactory.modifyWhiteToken(testErc20.address, requiredAmount);

    const startTime = (await getCurrentTime()) + 86400 / 2;

    // fund it just before use it, as there is fixture in hardhat test
    await expect(LinkToken.transfer(campaignFactory.address, parseEther('10')))
      .to.be.emit(LinkToken, 'Transfer')
      .withArgs(dev.address, campaignFactory.address, parseEther('10'));

    const campaign = await ethers.getContractAt(
      'Campaign',
      await campaignFactory.callStatic.createCampaign(
        testErc20.address,
        requiredAmount,
        'Test',
        'T',
        startTime,
        2,
        86400,
        'ipfs://Qmxxxx',
        '0x',
      ),
    );

    await campaignFactory.createCampaign(
      testErc20.address,
      requiredAmount,
      'Test',
      'T',
      startTime,
      2,
      86400,
      'ipfs://Qmxxxx',
      '0x',
    );

    await testErc20.mint(dev.address, requiredAmount);
    await testErc20.connect(dev).approve(campaign.address, ethers.constants.MaxUint256);

    await campaign.signUp();
    await expect(
      campaign.transferFrom(dev.address, ethers.utils.computeAddress(ethers.utils.randomBytes(32)), 0),
    ).to.be.revertedWith('Campaign: Could not transfer');

    await campaign.admit([0]);

    await TimeGo(86400);
    await TimeGo(86400);
    await TimeGo(86400);
    // await campaign.claim(0);
    await expect(campaign.claimAndWithdraw(0))
      .to.be.emit(testErc20, 'Transfer')
      .withArgs(campaign.address, dev.address, (requiredAmount * 2n) / 10n);

    expect(await testErc20.balanceOf(dev.address)).to.be.equal((requiredAmount * 2n) / 10n);
  });

  it('Campaign', async () => {
    const users = await ethers.getSigners();
    const userCount = users.length;

    await testErc20.transfer(
      ethers.utils.computeAddress(ethers.utils.randomBytes(32)),
      await testErc20.balanceOf(users[0].address),
    );

    // fund it just before use it, as there is fixture in hardhat test
    await expect(LinkToken.transfer(campaignFactory.address, parseEther('10')))
      .to.be.emit(LinkToken, 'Transfer')
      .withArgs(users[0].address, campaignFactory.address, parseEther('10'));

    const tx: ContractTransaction = await campaignFactory.createCampaign(
      testErc20.address,
      requiredAmount,
      'Test',
      'T',
      (await getCurrentTime()) + 86400,
      3,
      86400,
      'ipfs://Qmxxxx',
      '0x',
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
      await campaign.connect(user).checkIn('ipfs://Qmxxxx', holderInfo[user.address]);
    }

    expect(await campaign.currentEpoch()).to.be.equal(0);

    await TimeGo(86400);

    for (const user of users) {
      await campaign.connect(user).checkIn('ipfs://Qmxxxx', holderInfo[user.address]);
    }

    expect(await campaign.currentEpoch()).to.be.equal(1);

    await TimeGo(86400);

    // first one forget to checkIn
    for (const user of users.slice(1)) {
      await campaign.connect(user).checkIn('ipfs://Qmxxxx', holderInfo[user.address]);
    }

    expect(await campaign.currentEpoch()).to.be.equal(2);

    await TimeGo(86400);

    for (const user of users.slice(1)) {
      await campaign.connect(user).claim(holderInfo[user.address]);
      expect(await testErc20.balanceOf(user.address)).to.be.equal(
        requiredAmount + (requiredAmount * 1n * (10n ** 6n - PROTOCOL_FEE - HOST_REWARD)) / 10n ** 6n / BigInt(userCount - 1),
      );
    }

    await campaign.connect(users[0]).claim(holderInfo[users[0].address]);
    expect(await testErc20.balanceOf(users[0].address)).to.be.equal(0);

    await campaign.connect(users[0]).withdraw();

    expect(await testErc20.balanceOf(users[0].address)).to.be.equal((requiredAmount * HOST_REWARD) / 10n ** 6n);

    expect(await testErc20.balanceOf('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045')).to.be.equal(
      (requiredAmount * PROTOCOL_FEE) / 10n ** 6n + (requiredAmount * 8n) / 10n,
    );

    await campaign.setCampaignUri('ipfs://Qmxxxxy');

    expect(await campaign.campaignUri()).to.be.equal('ipfs://Qmxxxxy');
  });
});
