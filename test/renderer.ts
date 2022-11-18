import { deployments } from 'hardhat';

import { getCurrentTime, getContract, TimeGo } from './utils';
import { CampaignBase, TestERC20 } from '../typechain';
import fs from 'fs-extra';
import { Wallet } from 'ethers';
import { parseEther } from 'ethers/lib/utils';
import { expect } from 'chai';

const NOT_START_SVG = fs.readFileSync('./resources/NotStarted.min.svg', 'utf-8');
const ON_GOING_SVG = fs.readFileSync('./resources/OnGoing.min.svg', 'utf-8');
const BRAVO_SVG = fs.readFileSync('./resources/Bravo.min.svg', 'utf-8');
const FAILED_SVG = fs.readFileSync('./resources/Failed.min.svg', 'utf-8');

const requiredAmount = 10n * 10n ** 18n;
const dayLength = 86400;
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
      now + dayLength / 2,
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

describe('Render', function () {
  it('Should Not Start Svg show successfully', async () => {
    const { campaign } = await setupTest();

    const uri = await campaign.tokenURI(0);

    const metadata = Buffer.from(uri.split(',')[1], 'base64').toString('utf-8');

    const img = JSON.parse(metadata).image;

    const svg = Buffer.from(img.split(',')[1], 'base64').toString('utf-8');

    expect(svg).to.be.equal(NOT_START_SVG);
  });

  it('Should On Going Svg show successfully', async () => {
    const { campaign, C } = await setupTest();

    await TimeGo(86400 * 15);
    await campaign.connect(C).checkIn('ipfs://', 0);

    const uri = await campaign.tokenURI(0);
    const metadata = Buffer.from(uri.split(',')[1], 'base64').toString('utf-8');

    const img = JSON.parse(metadata).image;

    const svg = Buffer.from(img.split(',')[1], 'base64').toString('utf-8');

    expect(svg).to.be.equal(ON_GOING_SVG);
  });

  it('Should Bravo Svg show successfully', async () => {
    const { campaign, C } = await setupTest();

    // eslint-disable-next-line no-unused-vars
    for (const _ in Array.from({ length: 30 }, () => 0)) {
      await TimeGo(86400);
      await campaign.connect(C).checkIn('ipfs://', 0);
    }

    await TimeGo(86400);

    await campaign.connect(C).claim(0);

    const uri = await campaign.tokenURI(0);
    const metadata = Buffer.from(uri.split(',')[1], 'base64').toString('utf-8');

    const img = JSON.parse(metadata).image;

    const svg = Buffer.from(img.split(',')[1], 'base64').toString('utf-8');

    expect(svg).to.be.equal(BRAVO_SVG);
  });

  it('Should Failed Svg show successfully', async () => {
    const { campaign, C } = await setupTest();

    await TimeGo(86400);
    await campaign.connect(C).checkIn('ipfs://', 0);

    await TimeGo(86400 * 29);
    await campaign.connect(C).checkIn('ipfs://', 0);

    await TimeGo(86400);
    await campaign.connect(C).claim(0);

    const uri = await campaign.tokenURI(0);
    const metadata = Buffer.from(uri.split(',')[1], 'base64').toString('utf-8');

    const img = JSON.parse(metadata).image;

    const svg = Buffer.from(img.split(',')[1], 'base64').toString('utf-8');

    expect(svg).to.be.equal(FAILED_SVG);
  });
});
