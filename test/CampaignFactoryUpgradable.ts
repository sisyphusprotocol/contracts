import { ethers, deployments } from 'hardhat';
import { expect } from 'chai';

import { getCurrentTime, TimeGo, getContract } from './utils';
import { BigNumber, ContractReceipt, ContractTransaction } from 'ethers';
import { defaultAbiCoder, parseEther } from 'ethers/lib/utils';
import { Campaign, CampaignFactoryUpgradable, TestERC20 } from '../typechain';

const requiredAmount = 10n * 10n ** 18n;
const protocolRecipient = '0xd8da6bf26964af9d7eed9e03e53415d37aa96045';
const PROTOCOL_FEE = 10n ** 5n;
const HOST_REWARD = 2n * 10n ** 5n;

const setupTest = deployments.createFixture(async ({ deployments, ___, ethers }, __) => {
  const [deployer] = await ethers.getSigners();
  const testErc20 = await getContract<TestERC20>('TestERC20');
  const link = await deployments.get('Link');
  const LinkToken = await ethers.getContractAt('TestERC20', link.address);

  await deployments.fixture(); // ensure you start from a fresh deployments
  const campaignFactory = await getContract<CampaignFactoryUpgradable>('CampaignFactoryUpgradable');

  // fund it campaignFactory enough $link
  await expect(LinkToken.connect(deployer).transfer(campaignFactory.address, parseEther('10')))
    .to.be.emit(LinkToken, 'Transfer')
    .withArgs(deployer.address, campaignFactory.address, parseEther('10'));
  // set WhiteToken
  await campaignFactory.modifyWhiteToken(testErc20.address, requiredAmount).then((tx) => tx.wait());
  return {
    testErc20: testErc20,
    LinkToken: LinkToken,
    campaignFactory: campaignFactory,
  };
});

describe('CampaignFactoryUpgradable', function () {
  it('Factory', async () => {
    const { campaignFactory, testErc20 } = await setupTest();
    // eslint-disable-next-line no-unused-vars
    const [_deployer, host] = await ethers.getSigners();

    const startTime = (await getCurrentTime()) + 86400 / 2;

    const campaign = await ethers.getContractAt<Campaign>(
      'Campaign',
      await campaignFactory
        .connect(host)
        .callStatic.createCampaign(testErc20.address, requiredAmount, 'Test', 'T', startTime, 2, 86400, 'ipfs://Qmxxxx', '0x'),
    );

    await expect(
      campaignFactory
        .connect(host)
        .createCampaign(testErc20.address, requiredAmount, 'Test', 'T', startTime, 2, 86400, 'ipfs://Qmxxxx', '0x'),
    )
      .to.be.emit(campaignFactory, 'EvCampaignCreated')
      .withArgs(host.address, campaign.address);

    await testErc20.connect(host).mint(host.address, requiredAmount);
    await testErc20.connect(host).approve(campaign.address, ethers.constants.MaxUint256);

    await campaign.connect(host).signUp();

    await expect(
      campaign.connect(host).transferFrom(host.address, ethers.utils.computeAddress(ethers.utils.randomBytes(32)), 0),
    ).to.be.revertedWith('Campaign: Could not transfer');

    await campaign.connect(host).admit([0]);

    // time pass then the host fail
    await TimeGo(86400);
    await TimeGo(86400);

    expect((await campaign.checkUpkeep('0x')).upkeepNeeded).to.be.equal(true);

    await TimeGo(86400);
    // await campaign.claim(0);
    await expect(campaign.connect(host).claimAndWithdraw(0))
      .to.be.emit(testErc20, 'Transfer')
      .withArgs(campaign.address, host.address, (requiredAmount * 2n) / 10n);

    expect(await testErc20.balanceOf(host.address)).to.be.equal((requiredAmount * 2n) / 10n);
  });

  it('Campaign', async () => {
    const { LinkToken, campaignFactory, testErc20 } = await setupTest();

    // deployer
    const [deployer, ...users] = await ethers.getSigners();
    const host = users[0];
    const userCount = users.length;

    await testErc20.mint(
      ethers.utils.computeAddress(ethers.utils.randomBytes(32)),
      await testErc20.balanceOf(users[0].address),
    );

    // fund it just before use it, as there is fixture in hardhat test
    await expect(LinkToken.transfer(campaignFactory.address, parseEther('10')))
      .to.be.emit(LinkToken, 'Transfer')
      .withArgs(deployer.address, campaignFactory.address, parseEther('10'));

    const startTime = (await getCurrentTime()) + 86400;

    const campaign = await ethers.getContractAt<Campaign>(
      'Campaign',
      await campaignFactory
        .connect(host)
        .callStatic.createCampaign(testErc20.address, requiredAmount, 'Test', 'T', startTime, 3, 86400, 'ipfs://Qmxxxx', '0x'),
    );

    await expect(
      campaignFactory
        .connect(host)
        .createCampaign(testErc20.address, requiredAmount, 'Test', 'T', startTime, 3, 86400, 'ipfs://Qmxxxx', '0x'),
    )
      .to.be.emit(campaignFactory, 'EvCampaignCreated')
      .withArgs(host.address, campaign.address);

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

    await campaign.connect(host).admit([
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

    // except the first one. Others success
    for (const user of users.slice(1)) {
      await campaign.connect(user).claim(holderInfo[user.address]);
      expect(await testErc20.balanceOf(user.address)).to.be.equal(
        requiredAmount + (requiredAmount * 1n * (10n ** 6n - PROTOCOL_FEE - HOST_REWARD)) / 10n ** 6n / BigInt(userCount - 1),
      );
    }

    await campaign.connect(host).claim(holderInfo[host.address]);
    expect(await testErc20.balanceOf(host.address)).to.be.equal(0);

    await expect(campaign.connect(host).withdraw()).to.changeTokenBalances(
      testErc20,
      [
        host,
        {
          getAddress() {
            return protocolRecipient;
          },
        },
      ],
      [(requiredAmount * HOST_REWARD) / 10n ** 6n, (requiredAmount * PROTOCOL_FEE) / 10n ** 6n],
    );

    await campaign.connect(host).setCampaignUri('ipfs://Qmxxxxy');

    expect(await campaign.campaignUri()).to.be.equal('ipfs://Qmxxxxy');
  });

  it('Campaign KeepUp', async () => {
    const { campaignFactory, testErc20 } = await setupTest();
    const [deployer, host] = await ethers.getSigners();
    const startTime = (await getCurrentTime()) + 86400;

    // create campaign
    const campaign = await ethers.getContractAt<Campaign>(
      'Campaign',
      await campaignFactory
        .connect(host)
        .callStatic.createCampaign(testErc20.address, requiredAmount, 'Test', 'T', startTime, 3, 60, 'ipfs://Qmxxxx', '0x'),
    );
    await campaignFactory
      .connect(host)
      .createCampaign(testErc20.address, requiredAmount, 'Test', 'T', startTime, 3, 60, 'ipfs://Qmxxxx', '0x');

    // time pass and campaign start
    await TimeGo(86400);
    // time pass and should checkEpoch
    await TimeGo(61);
    const { upkeepNeeded, performData } = await campaign.checkUpkeep('0x');
    expect(upkeepNeeded).to.be.equal(true);
    expect(performData).to.be.equals(defaultAbiCoder.encode(['uint256'], [1]));
    expect(campaign.performUpkeep(performData)).to.be.emit(campaign, 'EpochUpdated').withArgs(1);

    // should upkeepNeed to false after performUpKeep
    const { upkeepNeeded: upkeepNeededShouldFalse } = await campaign.checkUpkeep('0x');
    expect(upkeepNeededShouldFalse).to.be.equal(false);

    // time pass and should checkEpoch again
    await TimeGo(60);
    const { upkeepNeeded: upkeepNeeded2, performData: performData2 } = await campaign.checkUpkeep('0x');
    expect(upkeepNeeded2).to.be.equal(true);
    expect(performData2).to.be.equals(defaultAbiCoder.encode(['uint256'], [1]));
    expect(campaign.performUpkeep(performData2)).to.be.emit(campaign, 'EpochUpdated').withArgs(2);

    // time pass and should settle finally
    await TimeGo(60);
    const { upkeepNeeded: upkeepNeeded3, performData: performData3 } = await campaign.checkUpkeep('0x');
    expect(upkeepNeeded3).to.be.equal(true);
    expect(performData3).to.be.equals(defaultAbiCoder.encode(['uint256'], [0]));
    expect(campaign.performUpkeep(performData3)).to.be.emit(campaign, 'EvSettle').withArgs(deployer.address);
  });
});
