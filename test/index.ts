import { expect } from 'chai';
import { ethers } from 'hardhat';

async function getCurrentTime() {
  return (await ethers.provider.getBlock(await ethers.provider.getBlockNumber())).timestamp;
}

describe('General Test', () => {
  it('1', async () => {
    const [dev] = await ethers.getSigners();

    const TestERC20F = await ethers.getContractFactory('TestERC20');

    const testErc20 = await TestERC20F.deploy('TestERC20', 'TE', 100n * 10n * 18n);

    const CampaignF = await ethers.getContractFactory('Campaign');
    const campaign = await CampaignF.deploy(testErc20.address, 10n * 10n * 18n, 'Test', 'T', (await getCurrentTime()) + 86400);

    await testErc20.approve(campaign.address, ethers.constants.MaxUint256);
    await campaign.signUp();
    await campaign.admit([dev.address]);

    await ethers.provider.send('evm_mine', [(await getCurrentTime()) + 86400]);

    expect(await campaign.currentEpoch()).to.be.equal(0);
    await campaign.checkIn(ethers.utils.formatBytes32String('ipfs://Qmxxxxx'));

    await ethers.provider.send('evm_mine', [(await getCurrentTime()) + 86400]);

    await campaign.checkIn(ethers.utils.formatBytes32String('ipfs://Qmxxxxx'));

    expect(await campaign.currentEpoch()).to.be.equal(1);

    await ethers.provider.send('evm_mine', [(await getCurrentTime()) + 86400]);

    await campaign.checkIn(ethers.utils.formatBytes32String('ipfs://Qmxxxxx'));

    expect(await campaign.currentEpoch()).to.be.equal(2);

    await ethers.provider.send('evm_mine', [(await getCurrentTime()) + 86400]);

    await campaign.claim();
  });
});
