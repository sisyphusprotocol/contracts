import { ethers } from 'hardhat';

describe('General Test', () => {
  it('1', async () => {
    const [dev] = await ethers.getSigners();

    const TestERC20F = await ethers.getContractFactory('TestERC20');

    const testErc20 = await TestERC20F.deploy('TestERC20', 'TE', 100n * 10n * 18n);

    const CampaignF = await ethers.getContractFactory('Campaign');
    const campaign = await CampaignF.deploy(1, testErc20.address, 10n * 10n * 18n, 'Test', 'T');

    await testErc20.approve(campaign.address, ethers.constants.MaxUint256);
    await campaign.register();
    await campaign.admit([dev.address]);
  });
});
