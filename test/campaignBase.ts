import { deployments } from 'hardhat';

import { getCurrentTime, getContract, TimeGo } from './utils';
import { CampaignBase, TestERC20 } from '../typechain';
import { BigNumber, Wallet } from 'ethers';
import { parseEther } from 'ethers/lib/utils';
import { expect } from 'chai';

const requiredAmount = 10n * 10n ** 18n;
const dayLength = 86400n;
const defaultChallengeLength = 86400;

const setupTest = deployments.createFixture(
  // eslint-disable-next-line no-unused-vars
  async ({ deployments, getNamedAccounts, ethers }, options) => {
    const [host, A, B, ...users] = await ethers.getSigners();

    // make C as a account with fix address
    const C = new Wallet('0x0000000000000000000000000000000000000000000000000000000000000001', A.provider);
    A.sendTransaction({ to: C.address, value: parseEther('2') });

    const testErc20 = await getContract<TestERC20>('TestERC20');
    const campaign = await getContract<CampaignBase>('CampaignBase');
    await deployments.fixture(); // ensure you start from a fresh deployments

    const now = await getCurrentTime();
    // initialize the campaign with 3 days
    campaign.initialize(
      host.address,
      testErc20.address,
      requiredAmount,
      'TestCampaign',
      'TC',
      BigInt(now) + dayLength / 2n,
      30,
      dayLength,
      defaultChallengeLength,
      'ipfs://',
    );

    // mint erc20
    await testErc20.connect(C).mint(C.address, requiredAmount);
    // signUp
    await testErc20.connect(C).approve(campaign.address, requiredAmount);
    await campaign.connect(C).signUp();
    // admit
    await campaign.admit([0]);

    return {
      testErc20: testErc20,
      campaign: campaign,
      host: host,
      A: A,
      B: B,
      C: C,
      users: users,
    };
  },
);

describe('CampaignBase', function () {
  it('Should No Delay Work properly', async () => {
    const { campaign, C } = await setupTest();

    await TimeGo(dayLength);
    await expect(campaign.connect(C).checkIn('', 0)).to.be.emit(campaign, 'EvCheckIn').withArgs(0, 0, '');
  });
  it('Should Delay Start Time Work properly', async () => {
    const { campaign, C } = await setupTest();

    const startTimeBefore = await campaign.startTime();

    await expect(campaign.delayStartTime(dayLength * 2n))
      .to.be.emit(campaign, 'StartTimeDelay')
      .withArgs(startTimeBefore.add(BigNumber.from(dayLength * 2n)));

    await TimeGo(dayLength);
    await expect(campaign.connect(C).checkIn('', 0)).to.be.revertedWith('Campaign: not start');
  });
  it('Can not delay after the campaign start', async () => {
    const { campaign } = await setupTest();

    await TimeGo(dayLength);
    await expect(campaign.delayStartTime(dayLength * 2n)).to.be.revertedWith('DelayStartTooLate');
  });
});
