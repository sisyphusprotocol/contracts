import { expect } from 'chai';
import { ethers } from 'hardhat';

async function getCurrentTime() {
  return (await ethers.provider.getBlock(await ethers.provider.getBlockNumber())).timestamp;
}

async function TimeGo(s: number) {
  await ethers.provider.send('evm_mine', [(await getCurrentTime()) + s]);
}

describe('General Test', () => {
  it('1', async () => {
    const [dev, ...users] = await ethers.getSigners();

    const TestERC20F = await ethers.getContractFactory('TestERC20');

    const testErc20 = await TestERC20F.deploy('TestERC20', 'TE', 100n * 10n * 18n);

    const requiredAmount = 10n * 10n * 18n;

    const CampaignF = await ethers.getContractFactory('Campaign');
    const campaign = await CampaignF.deploy(
      testErc20.address,
      requiredAmount,
      'Test',
      'T',
      (await getCurrentTime()) + 86400,
      2,
      86400,
    );

    await testErc20.approve(campaign.address, ethers.constants.MaxUint256);
    await campaign.signUp();

    for (const user of users) {
      await testErc20.mint(user.address, requiredAmount);
      await testErc20.connect(user).approve(campaign.address, ethers.constants.MaxUint256);
      await campaign.connect(user).signUp();
    }

    await campaign.admit([
      dev.address,
      ...users.map((user) => {
        return user.address;
      }),
    ]);

    await TimeGo(86400);

    expect(await campaign.currentEpoch()).to.be.equal(0);
    await campaign.checkIn(ethers.utils.formatBytes32String('ipfs://Qmxxxxx'));
    for (const user of users) {
      await campaign.connect(user).checkIn(ethers.utils.formatBytes32String('ipfs://Qmxxxxx'));
    }

    await TimeGo(86400);

    await campaign.checkIn(ethers.utils.formatBytes32String('ipfs://Qmxxxxx'));
    expect(await campaign.currentEpoch()).to.be.equal(1);
    for (const user of users) {
      await campaign.connect(user).checkIn(ethers.utils.formatBytes32String('ipfs://Qmxxxxx'));
    }

    await TimeGo(86400);

    await campaign.checkIn(ethers.utils.formatBytes32String('ipfs://Qmxxxxx'));
    for (const user of users) {
      await campaign.connect(user).checkIn(ethers.utils.formatBytes32String('ipfs://Qmxxxxx'));
    }
    expect(await campaign.currentEpoch()).to.be.equal(2);

    await TimeGo(86400);

    await campaign.claim();
    for (const user of users) {
      await campaign.connect(user).claim();

      expect(await testErc20.balanceOf(user.address)).to.be.equal(requiredAmount);
    }
  });
});
