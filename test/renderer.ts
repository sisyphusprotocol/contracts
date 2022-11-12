import { deployments } from 'hardhat';

import { getCurrentTime, getContract } from './utils';
import { CampaignBase, TestERC20 } from '../typechain';

const requiredAmount = 10n * 10n ** 18n;
const dayLength = 86400;

const setupTest = deployments.createFixture(
  // eslint-disable-next-line no-unused-vars
  async ({ deployments, getNamedAccounts, ethers }, options) => {
    const [host, A, B, ...users] = await ethers.getSigners();
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
      now + dayLength / 2,
      dayLength,
      30,
      'ipfs://',
    );

    // mint erc20
    await testErc20.connect(A).mint(A.address, requiredAmount);
    // signUp
    await testErc20.connect(A).approve(campaign.address, requiredAmount);
    await campaign.connect(A).signUp();

    return {
      testErc20: testErc20,
      campaign: campaign,
      host: host,
      A: A,
      B: B,
      users: users,
    };
  },
);

describe('CampaignChallenge', function () {
  it('Should print the svg', async () => {
    const { campaign } = await setupTest();

    const uri = await campaign.tokenURI(0);

    const metadata = Buffer.from(uri.split(',')[1], 'base64').toString('utf-8');

    const img = JSON.parse(metadata).image;

    const svg = Buffer.from(img.split(',')[1], 'base64').toString('utf-8');

    console.log(svg);
  });
});
